#!/usr/bin/env bash
# Adapt Codex PreToolUse payloads and decisions to the existing Claude hooks.

set -u

HOOK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOOK_NAME="${1:-}"

case "$HOOK_NAME" in
    check-test-protection.sh|check-forbidden-conditions.sh|check-critical-write-allowlist.sh|check-structural-first-on-source.sh) ;;
    *) printf '{}'; exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || { printf '{}'; exit 0; }

CODEX_HOOK_RUNTIME=0
[ -n "${PLUGIN_ROOT:-}" ] && CODEX_HOOK_RUNTIME=1

# Claude project hooks invoke the write guards directly. The shared plugin
# manifest includes these adapter entries only so Codex receives them.
if [ "$CODEX_HOOK_RUNTIME" -eq 0 ] && [ "$HOOK_NAME" != "check-structural-first-on-source.sh" ]; then
    printf '{}'
    exit 0
fi

run_guard() {
    local payload="$1" output decision context
    output="$(printf '%s' "$payload" | bash "$HOOK_DIR/$HOOK_NAME" 2>/dev/null || true)"
    decision="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null || true)"
    context="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
    if [ "$decision" = "ask" ] && [ "$CODEX_HOOK_RUNTIME" -eq 1 ]; then
        printf '%s' "$output" | jq '
            .hookSpecificOutput.permissionDecision = "deny"
            | .hookSpecificOutput.permissionDecisionReason += "\n\nCodex blocked this call because PreToolUse hooks do not support an ask decision. Resolve the condition or update the relevant .code4me policy file before retrying."
        '
        return 10
    fi
    if [ "$decision" = "ask" ]; then
        printf '%s' "$output"
        return 10
    fi
    if [ -n "$context" ]; then
        printf '%s' "$output"
        return 10
    fi
    return 0
}

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"

if [ "$TOOL_NAME" != "apply_patch" ] || [ "$HOOK_NAME" = "check-structural-first-on-source.sh" ]; then
    run_guard "$INPUT"
    status=$?
    [ "$status" -eq 10 ] && exit 0
    printf '{}'
    exit 0
fi

PATCH="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -n "$PATCH" ] || { printf '{}'; exit 0; }

while IFS=$'\t' read -r ACTION TARGET || [ -n "${TARGET:-}" ]; do
    [ -n "${TARGET:-}" ] || continue
    case "$ACTION" in
        Add|Move) CLAUDE_TOOL="Write" ;;
        Update|Delete) CLAUDE_TOOL="Edit" ;;
        *) continue ;;
    esac
    PAYLOAD="$(jq -nc --arg t "$CLAUDE_TOOL" --arg p "$TARGET" '{tool_name:$t,tool_input:{file_path:$p}}')"
    run_guard "$PAYLOAD"
    status=$?
    [ "$status" -eq 10 ] && exit 0
done < <(printf '%s\n' "$PATCH" | sed -n -E 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\1\t\2/p; s/^\*\*\* Move to: (.*)$/Move\t\1/p')

printf '{}'
