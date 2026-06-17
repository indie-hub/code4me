#!/usr/bin/env bash
# Code4Me PreToolUse hook — protected test enforcement.
#
# Reads `.code4me/protected-tests.txt` (one path or glob per line; lines starting
# with `#` are comments; blank lines ignored). If the Edit or Write tool's
# `file_path` matches any entry, the hook returns `permissionDecision: ask` so
# the user can confirm.
#
# Defensive behaviour: if the data file is missing, empty, or malformed, the
# hook passes through silently. The hook never returns `deny` — only `ask` —
# so a misconfigured hook degrades to a warning, never a hard block.
#
# Wired in `.claude/settings.json` under `hooks.PreToolUse[*].hooks[*]` with
# matcher `Edit|Write`. See README "External agents (Codex)" → "Hook
# installation" for the install snippet.

set -u

PASS_THROUGH='{}'

emit_pass_through() {
    printf '%s' "$PASS_THROUGH"
    exit 0
}

emit_ask() {
    local reason="$1"
    # jq is the safest way to emit valid JSON; fall back to a printf form if
    # jq is unavailable so the hook still degrades to "ask" rather than crashing.
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg r "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: $r
            }
        }'
    else
        # Minimal JSON escape: backslashes, quotes, newlines.
        local escaped="${reason//\\/\\\\}"
        escaped="${escaped//\"/\\\"}"
        escaped="${escaped//$'\n'/\\n}"
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}' "$escaped"
    fi
    exit 0
}

# Shared path helpers (Windows normalisation). Sourced relative to this hook;
# if the helper is missing, degrade to pass-through rather than crash.
C4M_HOOK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=hooks/c4m-pathlib.sh
. "$C4M_HOOK_DIR/c4m-pathlib.sh" 2>/dev/null || emit_pass_through

# Locate the project root. Hooks run with $CLAUDE_PROJECT_DIR set by the harness;
# fall back to PWD if not present. Slashify so Git Bash / MSYS Windows paths
# (C:\Users\...) resolve correctly.
PROJECT_DIR="$(c4m_slashify "${CLAUDE_PROJECT_DIR:-$PWD}")"
PROTECTED_FILE="$PROJECT_DIR/.code4me/protected-tests.txt"

# Pass through if no protected list exists.
[ -r "$PROTECTED_FILE" ] || emit_pass_through

# Read tool_input from stdin. Pass through if jq is unavailable or input is
# malformed — better to under-protect than to block all edits.
INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || emit_pass_through

if ! command -v jq >/dev/null 2>&1; then
    emit_pass_through
fi

TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$TARGET" ] || emit_pass_through

# Normalise the target path (handles Windows backslashes + drive letters).
ABS_TARGET="$(c4m_resolve "$TARGET" "$PROJECT_DIR")"

# Compare against each line of the protected file. Each entry is either an
# absolute path, a path relative to project root, or a glob (supports **, *, ?).
# macOS bash 3.2 lacks globstar, so we use a regex polyfill for ** support.
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
    shopt -s globstar nullglob extglob 2>/dev/null || true
    USE_NATIVE_GLOB=1
else
    USE_NATIVE_GLOB=0
fi

# Convert a glob pattern to an anchored regex. Handles **/, /**, **, *, ?, .
glob_to_regex() {
    printf '%s' "$1" | sed \
        -e 's|\\|\\\\|g' \
        -e 's|\.|\\.|g' \
        -e 's|\*\*/|<<DSTAR_S>>|g' \
        -e 's|/\*\*|<<S_DSTAR>>|g' \
        -e 's|\*\*|<<DSTAR>>|g' \
        -e 's|\*|[^/]*|g' \
        -e 's|?|[^/]|g' \
        -e 's|<<DSTAR_S>>|(.*/)?|g' \
        -e 's|<<S_DSTAR>>|/.*|g' \
        -e 's|<<DSTAR>>|.*|g'
}

matches_glob() {
    local target="$1" pattern="$2"
    if [ "$USE_NATIVE_GLOB" -eq 1 ]; then
        # shellcheck disable=SC2053
        [[ "$target" == $pattern ]]
    else
        local regex
        regex="$(glob_to_regex "$pattern")"
        [[ "$target" =~ ^${regex}$ ]]
    fi
}

while IFS= read -r PATTERN || [ -n "$PATTERN" ]; do
    # Skip comments and blank lines.
    case "$PATTERN" in
        ''|'#'*) continue ;;
    esac

    # Trim leading/trailing whitespace.
    PATTERN="${PATTERN#"${PATTERN%%[![:space:]]*}"}"
    PATTERN="${PATTERN%"${PATTERN##*[![:space:]]}"}"
    [ -n "$PATTERN" ] || continue

    # Resolve pattern relative to project root if not absolute.
    ABS_PATTERN="$(c4m_resolve "$PATTERN" "$PROJECT_DIR")"

    if matches_glob "$(c4m_fold "$ABS_TARGET")" "$(c4m_fold "$ABS_PATTERN")"; then
        emit_ask "$(printf 'Edit/Write target matches a protected test pattern.\n\nTarget: %s\nPattern: %s\n\nProtected tests are produced by the Spec-to-Test subagent and must not be modified, weakened, deleted, or skipped. If the test seems wrong, return outcome=TEST_QUESTION to the orchestrator rather than editing it. Type "yes" only if the user has explicitly authorised this edit.' "$TARGET" "$PATTERN")"
    fi
done < "$PROTECTED_FILE"

emit_pass_through
