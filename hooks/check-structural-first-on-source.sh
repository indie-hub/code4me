#!/usr/bin/env bash
# Code4Me PreToolUse hook - structural-index-first nudge for source code.
#
# When a tool call looks like source-code consultation by text search or a
# whole-file read, nudge the agent to use codegraph or CocoIndex first when either
# index is available. LSP remains a legacy optional fallback when a project still
# has .lsp.json, but context-mode/grep/read should not jump ahead of the code
# indexes for source-code lookup.

set -u

PASS_THROUGH='{}'

emit_pass_through() {
    printf '%s' "$PASS_THROUGH"
    exit 0
}

emit_nudge() {
    local reason="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg r "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                additionalContext: $r
            }
        }'
    else
        local escaped="${reason//\\/\\\\}"
        escaped="${escaped//\"/\\\"}"
        escaped="${escaped//$'\n'/\\n}"
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}' "$escaped"
    fi
    exit 0
}

C4M_HOOK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=hooks/c4m-pathlib.sh
. "$C4M_HOOK_DIR/c4m-pathlib.sh" 2>/dev/null || emit_pass_through

PROJECT_DIR="$(c4m_slashify "${CLAUDE_PROJECT_DIR:-$PWD}")"

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || emit_pass_through
command -v jq >/dev/null 2>&1 || emit_pass_through

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
case "$TOOL_NAME" in
    Bash|Read|Grep|\
    mcp__plugin_context-mode_context-mode__ctx_execute|\
    mcp__plugin_context-mode_context-mode__ctx_execute_file|\
    mcp__plugin_context-mode_context-mode__ctx_batch_execute|\
    mcp__context_mode__ctx_execute|\
    mcp__context_mode__ctx_execute_file|\
    mcp__context_mode__ctx_batch_execute) ;;
    *) emit_pass_through ;;
esac

CODEGRAPH_AVAILABLE=0
[ -r "$PROJECT_DIR/.codegraph/codegraph.db" ] && CODEGRAPH_AVAILABLE=1

COCOINDEX_AVAILABLE=0
if command -v ccc >/dev/null 2>&1 || [ -d "$PROJECT_DIR/.cocoindex_code" ]; then
    COCOINDEX_AVAILABLE=1
fi

LSP_AVAILABLE=0
[ -r "$PROJECT_DIR/.lsp.json" ] && LSP_AVAILABLE=1

# If no structural code surface is present, stay quiet. The hook is a nudge,
# not a permission gate.
if [ "$CODEGRAPH_AVAILABLE" -eq 0 ] && [ "$COCOINDEX_AVAILABLE" -eq 0 ] && [ "$LSP_AVAILABLE" -eq 0 ]; then
    emit_pass_through
fi

BASE_EXTS="cs|csx|cshtml|swift|cpp|cxx|cc|c\\+\\+|hpp|hxx|hh|h\\+\\+|h|c|py|pyi|js|jsx|ts|tsx|mjs|cjs|java|go|rs|rb|php|kt|kts|scala|sql|sh|bash|zsh|fish|ps1"
LSP_EXTS=""
if [ "$LSP_AVAILABLE" -eq 1 ]; then
    LSP_EXTS="$(jq -r '[.[].extensionToLanguage // {} | keys[]? | ltrimstr(".")] | unique | join("|")' "$PROJECT_DIR/.lsp.json" 2>/dev/null || true)"
fi
if [ -n "$LSP_EXTS" ]; then
    EXT_RE="\\.(${BASE_EXTS}|${LSP_EXTS})([[:space:]\"'\'')/]|$)"
else
    EXT_RE="\\.(${BASE_EXTS})([[:space:]\"'\'')/]|$)"
fi

is_source_text() {
    printf '%s' "$1" | grep -E -q "$EXT_RE"
}

REASON=""

if [ "$TOOL_NAME" = "Read" ]; then
    READ_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    READ_OFFSET="$(printf '%s' "$INPUT" | jq -r '.tool_input.offset // empty' 2>/dev/null || true)"
    READ_LIMIT="$(printf '%s' "$INPUT" | jq -r '.tool_input.limit // empty' 2>/dev/null || true)"
    if [ -n "$READ_PATH" ] && is_source_text "$READ_PATH" && [ -z "$READ_OFFSET" ] && [ -z "$READ_LIMIT" ]; then
        REASON="whole-file Read of a source file before consulting a code index"
    fi
elif [ "$TOOL_NAME" = "Grep" ]; then
    GREP_PATTERN="$(printf '%s' "$INPUT" | jq -r '.tool_input.pattern // empty' 2>/dev/null || true)"
    GREP_GLOB="$(printf '%s' "$INPUT" | jq -r '.tool_input.glob // empty' 2>/dev/null || true)"
    GREP_TYPE="$(printf '%s' "$INPUT" | jq -r '.tool_input.type // empty' 2>/dev/null || true)"
    GREP_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)"

    BARE_PATTERN="$(printf '%s' "$GREP_PATTERN" | sed -E 's|^[\\^]*||; s|[\\$]*$||; s|\\b||g')"
    if printf '%s' "$BARE_PATTERN" | grep -E -q '^[a-zA-Z_][a-zA-Z0-9_]{2,}$'; then
        SOURCE_TARGETED=0
        [ -n "$GREP_GLOB" ] && is_source_text "$GREP_GLOB" && SOURCE_TARGETED=1
        [ "$SOURCE_TARGETED" -eq 0 ] && [ -n "$GREP_PATH" ] && is_source_text "$GREP_PATH" && SOURCE_TARGETED=1
        [ "$SOURCE_TARGETED" -eq 0 ] && [ -n "$GREP_TYPE" ] && printf '%s' "$BASE_EXTS|$LSP_EXTS" | tr '|' '\n' | grep -F -x -q -- "$GREP_TYPE" && SOURCE_TARGETED=1
        [ "$SOURCE_TARGETED" -eq 0 ] && [ -z "$GREP_GLOB" ] && [ -z "$GREP_TYPE" ] && [ -z "$GREP_PATH" ] && SOURCE_TARGETED=1
        [ "$SOURCE_TARGETED" -eq 1 ] && REASON="Grep with a bare-identifier pattern against source files"
    fi
else
    HAYSTACK="$(printf '%s' "$INPUT" | jq -r '
        [
            (.tool_input.code // empty),
            (.tool_input.command // empty),
            (.tool_input.path // empty),
            ((.tool_input.commands // []) | map((.command // "") + " " + (.code // "") + " " + (.path // "")) | join("\n"))
        ] | join("\n")
    ' 2>/dev/null || true)"
    [ -n "$HAYSTACK" ] || emit_pass_through

    if printf '%s' "$HAYSTACK" | grep -E -q "(^|[^a-zA-Z0-9_])(grep|rg|ag|ack)[[:space:]]" && is_source_text "$HAYSTACK"; then
        if [ "$TOOL_NAME" = "Bash" ]; then
            REASON="shell search against source files"
        else
            REASON="context-mode shell search against source files"
        fi
    fi

    if [ -z "$REASON" ]; then
        PATH_FIELD="$(printf '%s' "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)"
        if [ -n "$PATH_FIELD" ] && is_source_text "$PATH_FIELD"; then
            if printf '%s' "$HAYSTACK" | grep -E -iq "(find|locate|where[[:space:]]+(is|does)|definition[[:space:]]+of|references[[:space:]]+to|declaration[[:space:]]+of|symbol[[:space:]]+for|all[[:space:]]+(uses|callers|functions|classes|methods)|implements[[:space:]])"; then
                REASON="ctx_execute_file on a source file with a symbol-search query"
            fi
        fi
    fi

    if [ -z "$REASON" ]; then
        if printf '%s' "$HAYSTACK" | grep -E -q "(^|[^a-zA-Z0-9_])(cat|head|tail|less|sed[[:space:]]+-n)[[:space:]]" && is_source_text "$HAYSTACK"; then
            if printf '%s' "$HAYSTACK" | grep -E -iq "(function|class|method|def[[:space:]]|interface|struct|enum)"; then
                REASON="raw source-file read paired with a function/class/method query"
            fi
        fi
    fi
fi

[ -n "$REASON" ] || emit_pass_through

log_event() {
    local events_dir="$PROJECT_DIR/.code4me"
    local events_log="$events_dir/structural-first-events.jsonl"
    [ -d "$events_dir" ] || mkdir -p "$events_dir" 2>/dev/null || return 0
    local ts haystack_head
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    case "$TOOL_NAME" in
        Read) haystack_head="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" ;;
        Grep) haystack_head="$(printf '%s' "$INPUT" | jq -r '"\(.tool_input.pattern // empty) glob=\(.tool_input.glob // "") type=\(.tool_input.type // "") path=\(.tool_input.path // "")"' 2>/dev/null)" ;;
        *) haystack_head="$(printf '%s' "${HAYSTACK:-}" | head -c 500)" ;;
    esac
    jq -nc \
        --arg ts "$ts" \
        --arg tool "$TOOL_NAME" \
        --arg reason "$REASON" \
        --arg haystack "$haystack_head" \
        --argjson codegraph_available "$CODEGRAPH_AVAILABLE" \
        --argjson cocoindex_available "$COCOINDEX_AVAILABLE" \
        --argjson lsp_available "$LSP_AVAILABLE" \
        '{ts:$ts, tool:$tool, reason:$reason, haystack_head:$haystack, codegraph_available:($codegraph_available == 1), cocoindex_available:($cocoindex_available == 1), lsp_available:($lsp_available == 1), event:"nudge"}' \
        >> "$events_log" 2>/dev/null || true
    return 0
}
log_event

TOOLS_MSG=""
if [ "$CODEGRAPH_AVAILABLE" -eq 1 ]; then
    TOOLS_MSG="${TOOLS_MSG}
codegraph (preferred for exact structural graph questions):
  - codegraph_explore <symbol>   - definition, neighbors, call paths, blast radius
  - codegraph_callers <symbol>   - incoming calls
  - codegraph_callees <symbol>   - outgoing calls
  - codegraph_impact <symbol>    - downstream impact
"
fi
if [ "$COCOINDEX_AVAILABLE" -eq 1 ]; then
    TOOLS_MSG="${TOOLS_MSG}
CocoIndex Code (preferred for semantic/source discovery):
  - MCP search(query, limit, paths, languages)
  - ccc search \"natural language query\"
  - ccc index first if this repo has not been indexed
"
fi
if [ "$LSP_AVAILABLE" -eq 1 ]; then
    TOOLS_MSG="${TOOLS_MSG}
LSP (legacy optional, type-precise fallback):
  - textDocument/definition, references, hover, documentSymbol, diagnostics
"
fi

emit_nudge "Source-code consultation detected (${REASON}).

Use the code indexes before context-mode, Grep, or whole-file Read for source lookup.${TOOLS_MSG}
Use context-mode for derived analysis, logs, build output, docs, or non-source text after the code index has narrowed the area.

See skills/code4me/references/code-consultation-precedence.md for the ordering."
