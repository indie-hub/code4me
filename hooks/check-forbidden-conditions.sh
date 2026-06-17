#!/usr/bin/env bash
# Code4Me PreToolUse hook — Conversation-Mode forbidden-condition enforcement.
#
# Reads `.code4me/forbidden-conditions.json` (written by the orchestrator at
# Conversation Mode dispatch; deleted at task close). When present, the file
# contains:
#
#   { "forbidden_globs": ["migrations/**", "schema/*.sql", ...] }
#
# If the Write tool is creating a new file whose path matches any forbidden
# glob, the hook returns `permissionDecision: ask` so the user can confirm.
# Existing-file Edits are not gated by this hook — forbidden conditions are
# triggered by *introducing* a new artifact (a new migration, a new schema
# file, a new feature flag), not by editing an existing one.
#
# Defensive behaviour identical to `check-test-protection.sh`: missing file,
# malformed JSON, or jq unavailable → pass through. Never `deny`, only `ask`.
#
# Wired in `.claude/settings.json` alongside `check-test-protection.sh` under
# `hooks.PreToolUse[*].hooks[*]` with matcher `Edit|Write`. See README "Hook
# installation" for the install snippet.

set -u

PASS_THROUGH='{}'

emit_pass_through() {
    printf '%s' "$PASS_THROUGH"
    exit 0
}

emit_ask() {
    local reason="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg r "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: $r
            }
        }'
    else
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

# Slashify so Git Bash / MSYS Windows paths (C:\Users\...) resolve correctly.
PROJECT_DIR="$(c4m_slashify "${CLAUDE_PROJECT_DIR:-$PWD}")"
FORBIDDEN_FILE="$PROJECT_DIR/.code4me/forbidden-conditions.json"

# Pass through if no forbidden-conditions file (orchestrator only writes it
# during Conversation Mode dispatches).
[ -r "$FORBIDDEN_FILE" ] || emit_pass_through

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || emit_pass_through

if ! command -v jq >/dev/null 2>&1; then
    emit_pass_through
fi

# Determine which tool fired.
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

[ -n "$TARGET" ] || emit_pass_through

# Only gate Write of a *new* file. Skip Edit (existing file mutation isn't a
# forbidden-condition trigger — the condition is introducing a new artifact).
case "$TOOL_NAME" in
    Write|MultiEdit)
        # Write/MultiEdit may target a non-existent path; proceed with the check.
        ;;
    Edit)
        # Existing file mutation — not a forbidden-condition trigger.
        emit_pass_through
        ;;
    *)
        emit_pass_through
        ;;
esac

# If the target file already exists, Write is overwriting — also not a
# new-artifact creation. Skip the check. (Handles Windows backslashes +
# drive letters.)
ABS_TARGET="$(c4m_resolve "$TARGET" "$PROJECT_DIR")"
[ -e "$ABS_TARGET" ] && emit_pass_through

# Read the forbidden globs.
GLOBS_JSON="$(jq -r '.forbidden_globs[]?' "$FORBIDDEN_FILE" 2>/dev/null || true)"
[ -n "$GLOBS_JSON" ] || emit_pass_through

# macOS bash 3.2 lacks globstar, so we use a regex polyfill for ** support.
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
    shopt -s globstar nullglob extglob 2>/dev/null || true
    USE_NATIVE_GLOB=1
else
    USE_NATIVE_GLOB=0
fi

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

while IFS= read -r PATTERN; do
    PATTERN="${PATTERN#"${PATTERN%%[![:space:]]*}"}"
    PATTERN="${PATTERN%"${PATTERN##*[![:space:]]}"}"
    [ -n "$PATTERN" ] || continue

    ABS_PATTERN="$(c4m_resolve "$PATTERN" "$PROJECT_DIR")"

    if matches_glob "$(c4m_fold "$ABS_TARGET")" "$(c4m_fold "$ABS_PATTERN")"; then
        emit_ask "$(printf 'Creating this file would trip a Conversation-Mode forbidden condition.\n\nTarget: %s\nPattern: %s\n\nConversation Mode is reserved for small, well-understood, reversible work. Creating files matching this pattern (new migrations, schemas, feature flags, persistence paths, etc.) is a signal that the work has outgrown Conversation weight. The Developer subagent should return outcome=FORBIDDEN_CONDITION_ENCOUNTERED to the orchestrator so the weight is escalated to Standard. Type "yes" only if the user has explicitly authorised this edit despite the forbidden-condition trigger.' "$TARGET" "$PATTERN")"
    fi
done <<< "$GLOBS_JSON"

emit_pass_through
