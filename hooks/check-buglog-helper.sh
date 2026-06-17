#!/usr/bin/env bash
# Code4Me PreToolUse hook — OpenWolf buglog consult/update redirection.
#
# OpenWolf's documented flow is "read .wolf/buglog.json before fixing, append
# after." That file grows to hundreds of entries (~90k+ tokens), so a whole-file
# Read is a large, avoidable token cost, and hand-edits drift the format / collide
# ids. This hook redirects those operations to `bin/code4me-buglog`, which queries
# and edits a single entry without loading the whole log:
#
#   * whole-file Read / Grep / raw-shell read of .wolf/buglog.json
#       -> code4me-buglog search | get | stats
#   * Edit / Write / shell-write of .wolf/buglog.json
#       -> code4me-buglog add | update <id>
#
# Like the LSP-first hook, it returns `permissionDecision: ask` (never deny) and
# self-disables (silent pass-through) when there is no .wolf/buglog.json. The
# code4me-buglog helper itself runs via Bash (python3), and Bash commands that
# invoke `code4me-buglog` are explicitly exempt, so the hook never blocks the
# very tool it points to. Auto-enabled via .claude-plugin/hooks.json.

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

# Shared path helpers (Windows normalisation). Degrade to pass-through if absent.
C4M_HOOK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=hooks/c4m-pathlib.sh
. "$C4M_HOOK_DIR/c4m-pathlib.sh" 2>/dev/null || emit_pass_through

# Auto-opt-out: no .wolf/buglog.json → this project doesn't use OpenWolf's buglog.
PROJECT_DIR="$(c4m_slashify "${CLAUDE_PROJECT_DIR:-$PWD}")"
[ -r "$PROJECT_DIR/.wolf/buglog.json" ] || emit_pass_through

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || emit_pass_through
command -v jq >/dev/null 2>&1 || emit_pass_through

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
case "$TOOL_NAME" in
    Read|Grep|Edit|Write|MultiEdit|Bash) ;;
    *) emit_pass_through ;;
esac

# Does a path point at <project>/.wolf/buglog.json? (slash-normalised suffix match)
is_buglog_path() {
    local p
    p="$(c4m_slashify "$1")"
    case "$p" in
        */.wolf/buglog.json|.wolf/buglog.json) return 0 ;;
        *) return 1 ;;
    esac
}

REASON=""
MODE=""   # read | write

case "$TOOL_NAME" in
    Read)
        rp="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
        roff="$(printf '%s' "$INPUT" | jq -r '.tool_input.offset // empty' 2>/dev/null || true)"
        rlim="$(printf '%s' "$INPUT" | jq -r '.tool_input.limit // empty' 2>/dev/null || true)"
        if [ -n "$rp" ] && is_buglog_path "$rp"; then
            # A narrowed read (offset/limit) is cheap and fine; only gate whole-file reads.
            if [ -z "$roff" ] && [ -z "$rlim" ]; then
                REASON="whole-file Read of .wolf/buglog.json"; MODE="read"
            fi
        fi
        ;;
    Grep)
        gp="$(printf '%s' "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)"
        if [ -n "$gp" ] && is_buglog_path "$gp"; then
            REASON="Grep over .wolf/buglog.json"; MODE="read"
        fi
        ;;
    Edit|Write|MultiEdit)
        wp="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
        if [ -n "$wp" ] && is_buglog_path "$wp"; then
            REASON="direct $TOOL_NAME of .wolf/buglog.json"; MODE="write"
        fi
        ;;
    Bash)
        cmd="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
        # Only consider commands that reference the buglog and are NOT the helper itself.
        if printf '%s' "$cmd" | grep -E -q '\.wolf[/\\]+buglog\.json' \
           && ! printf '%s' "$cmd" | grep -q 'code4me-buglog'; then
            # write signals: output redirection into it, or in-place editors
            if printf '%s' "$cmd" | grep -E -q '>>?[[:space:]]*[^|;&]*\.wolf[/\\]+buglog\.json' \
               || printf '%s' "$cmd" | grep -E -q '(^|[^a-zA-Z0-9_])(sed[[:space:]]+-i|tee|truncate)([[:space:]]|$)'; then
                REASON="shell write to .wolf/buglog.json"; MODE="write"
            # read signals: raw readers/parsers of the file
            elif printf '%s' "$cmd" | grep -E -q '(^|[^a-zA-Z0-9_])(cat|head|tail|less|more|grep|rg|ag|sed|awk|jq|type|Get-Content)([[:space:]]|$)'; then
                REASON="raw shell read of .wolf/buglog.json"; MODE="read"
            fi
        fi
        ;;
esac

[ -n "$REASON" ] || emit_pass_through

# Log the redirect for audit-tool surveillance (best-effort).
log_event() {
    local dir="$PROJECT_DIR/.code4me"
    [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null || return 0
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    jq -nc --arg ts "$ts" --arg tool "$TOOL_NAME" --arg reason "$REASON" --arg mode "$MODE" \
        '{ts:$ts, tool:$tool, reason:$reason, mode:$mode, event:"ask-gate"}' \
        >> "$dir/buglog-redirect-events.jsonl" 2>/dev/null || true
    return 0
}
log_event

if [ "$MODE" = "write" ]; then
    emit_ask "Direct write to .wolf/buglog.json detected (${REASON}).

Use the code4me-buglog helper instead of hand-editing — it writes in OpenWolf's exact format (so it never fights OpenWolf's own auto-logger), dedups recurrences, and keeps ids unique:

  code4me-buglog add --error \"<msg>\" --file \"<path>\" --root-cause \"…\" --fix \"…\" [--tag T …]
      (dedup-aware: a recurrence bumps occurrences/last_seen instead of duplicating)
  code4me-buglog update <bug-id> [--fix … | --resolution … | --add-tag T | --bump | --touch | …]

Hand-edits are how the log accreted inline-array formatting drift and duplicate ids. Type \"yes\" to edit the file directly anyway."
else
    emit_ask "Buglog consult detected (${REASON}).

Don't read the whole file — it's hundreds of entries (~90k+ tokens). Query just what you need with the code4me-buglog helper:

  code4me-buglog search --error \"<substring>\"     (also --tag T, --file S, --since Nd; add --full for full entries)
  code4me-buglog get <bug-id>                       (one entry; --field F for a single field)
  code4me-buglog stats                              (overview: recurring, tag/file hotspots)

That returns the 1-3 relevant entries instead of the whole log. See \`skills/code4me/references/tooling.md\` for the consult order. Type \"yes\" to read the raw file anyway."
fi
