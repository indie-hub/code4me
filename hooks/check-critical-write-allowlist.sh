#!/usr/bin/env bash
# Code4Me PreToolUse hook — Critical-mode write-allowlist enforcement.
#
# Reads `.code4me/critical-allowlist.txt` (one path or glob per line; lines
# starting with `#` are comments; blank lines ignored). The orchestrator
# writes this file at Critical-mode dispatch (containing the Tech Spec's
# modules-in-scope plus the Test Spec's test paths) and deletes it at task
# close. The file's presence is the signal that a Critical milestone is
# currently active and scope-bounded.
#
# When present, the hook ask-gates any Edit, Write, or MultiEdit whose
# target path does NOT match any allowlist entry. The inversion vs.
# check-test-protection.sh is deliberate: protected-tests is a deny-list;
# critical-allowlist is an allow-list. Editing inside scope passes through
# silently; editing outside scope is a scope-expansion request.
#
# Defensive behaviour: if the data file is missing, empty, or malformed,
# the hook passes through silently. The hook never returns `deny` — only
# `ask` — so a misconfigured hook degrades to a warning, never a hard
# block.
#
# Wired in `.claude/settings.json` under `hooks.PreToolUse[*].hooks[*]`
# with matcher `Edit|Write|MultiEdit`. See README "Hook protections" for
# the install snippet.

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

# Locate the project root. Slashify so Git Bash / MSYS Windows paths
# (C:\Users\...) resolve correctly for the .code4me lookup and matching.
PROJECT_DIR="$(c4m_slashify "${CLAUDE_PROJECT_DIR:-$PWD}")"
ALLOWLIST_FILE="$PROJECT_DIR/.code4me/critical-allowlist.txt"

# Opt-in diagnostics: when .code4me/.hook-debug exists, append what this hook
# sees and computes to .code4me/.hook-debug.log. Delete the sentinel to stop.
# (Temporary aid for the Windows path investigation; safe to leave in.)
c4m_debug() {
    [ -f "$PROJECT_DIR/.code4me/.hook-debug" ] || return 0
    printf '%s\n' "$*" >> "$PROJECT_DIR/.code4me/.hook-debug.log" 2>/dev/null || true
}

# Pass through if no allowlist (orchestrator only writes it during a
# Critical-mode milestone).
[ -r "$ALLOWLIST_FILE" ] || emit_pass_through

# Read tool_input from stdin.
INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || emit_pass_through

if ! command -v jq >/dev/null 2>&1; then
    emit_pass_through
fi

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

[ -n "$TARGET" ] || emit_pass_through

# Gate Edit, Write, MultiEdit. Pass through anything else (Read,
# Grep, Bash, etc.) — those don't mutate file state.
case "$TOOL_NAME" in
    Edit|Write|MultiEdit) ;;
    *) emit_pass_through ;;
esac

# Normalise the target path (handles Windows backslashes + drive letters).
ABS_TARGET="$(c4m_resolve "$TARGET" "$PROJECT_DIR")"

c4m_debug "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] tool=[$TOOL_NAME] raw_CLAUDE_PROJECT_DIR=[${CLAUDE_PROJECT_DIR:-<unset>}] PROJECT_DIR=[$PROJECT_DIR] raw_TARGET=[$TARGET] ABS_TARGET=[$ABS_TARGET] windows_bash=$(c4m_is_windows_bash && echo yes || echo no)"

# The orchestrator's own state directories are never scope-gated. The allowlist
# bounds the *codebase* changes (Tech Spec modules-in-scope + Test Spec paths),
# not the orchestrator's own bookkeeping. Per the STRICT PROTOCOL, orchestrator
# writes are confined to .code4me/ (milestone tracker, specs, dispatch log, hook
# state files) and .wolf/ (OpenWolf cerebrum updates when a required-change
# INSIGHT lands). Without this carve-out, every such write would ask-gate as
# "out of scope" during a Critical milestone.
_FOLDED_PROJECT_DIR="$(c4m_fold "$PROJECT_DIR")"
case "$(c4m_fold "$ABS_TARGET")" in
    "$_FOLDED_PROJECT_DIR"/.code4me/* | "$_FOLDED_PROJECT_DIR"/.wolf/*)
        c4m_debug "  EXEMPT orchestrator state dir (.code4me/ or .wolf/) -> pass-through"
        emit_pass_through
        ;;
esac

# macOS bash 3.2 lacks globstar; same regex polyfill as the sister hooks.
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

# Walk the allowlist. If ANY pattern matches, pass through. If we reach
# the end of the file without a match, ask-gate.
MATCHED_PATTERNS=""
PATTERN_COUNT=0
while IFS= read -r PATTERN || [ -n "$PATTERN" ]; do
    case "$PATTERN" in
        ''|'#'*) continue ;;
    esac

    PATTERN="${PATTERN#"${PATTERN%%[![:space:]]*}"}"
    PATTERN="${PATTERN%"${PATTERN##*[![:space:]]}"}"
    [ -n "$PATTERN" ] || continue

    PATTERN_COUNT=$((PATTERN_COUNT + 1))
    MATCHED_PATTERNS="${MATCHED_PATTERNS}${PATTERN}; "

    ABS_PATTERN="$(c4m_resolve "$PATTERN" "$PROJECT_DIR")"

    if matches_glob "$(c4m_fold "$ABS_TARGET")" "$(c4m_fold "$ABS_PATTERN")"; then
        # Match — target is in scope; pass through silently.
        c4m_debug "  MATCH  pattern=[$PATTERN] ABS_PATTERN=[$ABS_PATTERN] -> pass-through"
        emit_pass_through
    fi
    c4m_debug "  no-match  pattern=[$PATTERN] ABS_PATTERN=[$ABS_PATTERN]"
done < "$ALLOWLIST_FILE"

# Empty allowlist → pass through. An empty file is the user's signal to
# disable the gate without removing the hook; treat it as "no scope
# declared, allow everything." A populated file with zero matches is the
# gating case.
if [ "$PATTERN_COUNT" -eq 0 ]; then
    emit_pass_through
fi

# No match — ask-gate with reason.
# Trim the trailing "; " from MATCHED_PATTERNS for display.
MATCHED_PATTERNS="${MATCHED_PATTERNS%; }"
emit_ask "$(printf 'Edit/Write target is OUTSIDE the Critical-milestone scope allowlist.\n\nTarget: %s\nTool: %s\nAllowlist patterns (%d): %s\n\nA Critical milestone is currently active and the orchestrator has declared an explicit scope for it via .code4me/critical-allowlist.txt (typically derived from the Tech Spec'\''s modules-in-scope and the Test Spec'\''s test paths). The target path does not match any allowlist entry.\n\nThe Developer subagent should return outcome=OUT_OF_SCOPE_TARGET with the target path and the allowlist patterns it failed to match. The orchestrator will surface this to the user as a scope-expansion request — the user decides whether to re-scope the milestone (which updates the allowlist) or reject the edit.\n\nType "yes" only if the user has explicitly authorised this edit as a one-off without re-scoping the milestone. Re-scoping via the orchestrator is the safer path because it keeps the dispatch log'\''s record of scope changes accurate.' "$TARGET" "$TOOL_NAME" "$PATTERN_COUNT" "$MATCHED_PATTERNS")"
