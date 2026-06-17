#!/usr/bin/env bash
# Code4Me PreToolUse hook — structural-first redirection for source-code consultation.
#
# Wired against five tools (v0.11+):
#   * Read   — built-in file reader
#   * Grep   — built-in regex search
#   * mcp__plugin_context-mode_context-mode__ctx_execute
#   * mcp__plugin_context-mode_context-mode__ctx_execute_file
#   * mcp__plugin_context-mode_context-mode__ctx_batch_execute
#
# When the call looks like a SYMBOL LOOKUP on a SOURCE FILE (per the
# .lsp.json declared extensions), the hook returns `permissionDecision: ask`
# and points the agent at the structural tools first — LSP, plus codegraph
# (v0.13+) when the project is indexed.
#
# "Auto-opt-out": this hook self-disables (silent pass-through) when
# `.lsp.json` does not exist at the project root — no LSP wired, no redirect.
#
# Auto-enabled via `.claude-plugin/hooks.json` (v0.11+). Earlier versions
# wired it via `templates/project-starter/claude-settings.json.example` only;
# v0.11 moves the wiring into the plugin's hooks.json so it activates on
# install without a settings.json edit.
#
# v0.13+: codegraph detection. When `.codegraph/codegraph.db` exists at the
# project root (codegraph has been installed and indexed), the redirect
# message lists codegraph's MCP tools (codegraph_explore / codegraph_callers /
# codegraph_callees / codegraph_impact) alongside LSP. Both are structural;
# the agent picks the one shaped right for the question. When codegraph is
# absent, the redirect falls back to LSP-only (no behavior change for
# non-adopters).

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

# ─── Auto-opt-out: no .lsp.json → pass through ──────────────────────────────
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
LSP_CONFIG="$PROJECT_DIR/.lsp.json"
[ -r "$LSP_CONFIG" ] || emit_pass_through

# ─── Read tool_input from stdin ─────────────────────────────────────────────
INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || emit_pass_through

if ! command -v jq >/dev/null 2>&1; then
    emit_pass_through
fi

# Tool name dispatch.
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
case "$TOOL_NAME" in
    Read|Grep|\
    mcp__plugin_context-mode_context-mode__ctx_execute|\
    mcp__plugin_context-mode_context-mode__ctx_execute_file|\
    mcp__plugin_context-mode_context-mode__ctx_batch_execute) ;;
    *) emit_pass_through ;;
esac

# ─── Build the source-file extension regex from .lsp.json ───────────────────
EXTS="$(jq -r '
    [.[].extensionToLanguage // {} | keys[]?]
    | map(ltrimstr("."))
    | unique
    | join("|")
' "$LSP_CONFIG" 2>/dev/null || true)"

[ -n "$EXTS" ] || emit_pass_through

EXT_RE="\\.($EXTS)([[:space:]\"'/]|$)"

REASON=""

# ─── Tool-specific matching ─────────────────────────────────────────────────

if [ "$TOOL_NAME" = "Read" ]; then
    # Read with no offset+limit on a source file = "show me the whole file"
    # = strong signal the agent doesn't know what region it wants yet.
    READ_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    READ_OFFSET="$(printf '%s' "$INPUT" | jq -r '.tool_input.offset // empty' 2>/dev/null || true)"
    READ_LIMIT="$(printf '%s' "$INPUT" | jq -r '.tool_input.limit // empty' 2>/dev/null || true)"

    # Path must be a source extension.
    if [ -n "$READ_PATH" ] && printf '%s' "$READ_PATH" | grep -E -q "$EXT_RE"; then
        # If neither offset nor limit is set → whole-file read → ask-gate.
        # If either offset or limit is set → narrowed read → pass through.
        if [ -z "$READ_OFFSET" ] && [ -z "$READ_LIMIT" ]; then
            REASON="whole-file Read of a source file (no offset/limit)"
        fi
    fi

elif [ "$TOOL_NAME" = "Grep" ]; then
    # Grep with a bare-identifier pattern targeting source files = symbol search
    # by another name. LSP's workspace/symbol or textDocument/references would
    # answer this structurally.
    GREP_PATTERN="$(printf '%s' "$INPUT" | jq -r '.tool_input.pattern // empty' 2>/dev/null || true)"
    GREP_GLOB="$(printf '%s' "$INPUT" | jq -r '.tool_input.glob // empty' 2>/dev/null || true)"
    GREP_TYPE="$(printf '%s' "$INPUT" | jq -r '.tool_input.type // empty' 2>/dev/null || true)"
    GREP_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)"

    # Bare-identifier check: the pattern must look like a symbol name, not a regex.
    # Allow leading/trailing word boundary tokens (\b, ^, $) since agents sometimes
    # add those without it being a real regex.
    BARE_PATTERN="$(printf '%s' "$GREP_PATTERN" | sed -E 's|^[\\^]*||; s|[\\$]*$||; s|\\b||g')"
    if printf '%s' "$BARE_PATTERN" | grep -E -q '^[a-zA-Z_][a-zA-Z0-9_]{2,}$'; then
        # Pattern is bare-identifier shaped. Now check if it targets source files.
        # Three signals: explicit glob with source extension, type matching a
        # known LSP language, or path that smells like source (no glob, no type,
        # but the path is a source-extension file).
        SOURCE_TARGETED=0

        # Signal 1: explicit glob with source extension.
        if [ -n "$GREP_GLOB" ] && printf '%s' "$GREP_GLOB" | grep -E -q "$EXT_RE"; then
            SOURCE_TARGETED=1
        fi

        # Signal 2: type-filter matching a known LSP language (rough heuristic —
        # `type=cs` for C#, `type=cpp` for C++, etc.). Compare against the extension
        # set: if the type string matches a known extension after stripping the dot.
        if [ "$SOURCE_TARGETED" -eq 0 ] && [ -n "$GREP_TYPE" ]; then
            if printf '%s' "$EXTS" | tr '|' '\n' | grep -F -x -q -- "$GREP_TYPE"; then
                SOURCE_TARGETED=1
            fi
        fi

        # Signal 3: explicit path is a source file.
        if [ "$SOURCE_TARGETED" -eq 0 ] && [ -n "$GREP_PATH" ] && printf '%s' "$GREP_PATH" | grep -E -q "$EXT_RE"; then
            SOURCE_TARGETED=1
        fi

        # Signal 4: no glob, no type, no path — Grep runs across the whole workspace.
        # If the workspace has any source-extension files (which it does if .lsp.json
        # is wired), the grep WILL touch source. Conservative: treat as source-targeted.
        if [ "$SOURCE_TARGETED" -eq 0 ] && [ -z "$GREP_GLOB" ] && [ -z "$GREP_TYPE" ] && [ -z "$GREP_PATH" ]; then
            SOURCE_TARGETED=1
        fi

        if [ "$SOURCE_TARGETED" -eq 1 ]; then
            REASON="Grep with a bare-identifier pattern against source files"
        fi
    fi

else
    # context-mode ctx_execute / ctx_execute_file / ctx_batch_execute family.
    # Build the haystack: relevant tool_input fields concatenated.
    HAYSTACK="$(printf '%s' "$INPUT" | jq -r '
        [
            (.tool_input.code // empty),
            (.tool_input.path // empty),
            ((.tool_input.commands // []) | map((.code // "") + " " + (.path // "")) | join("\n"))
        ] | join("\n")
    ' 2>/dev/null || true)"

    [ -n "$HAYSTACK" ] || emit_pass_through

    # (a) grep/rg/ag/ack against source files
    if printf '%s' "$HAYSTACK" | grep -E -q "(^|[^a-zA-Z0-9_])(grep|rg|ag|ack)[[:space:]]"; then
        if printf '%s' "$HAYSTACK" | grep -E -q "$EXT_RE"; then
            REASON="grep/rg/ag/ack against a source file (declared in .lsp.json)"
        fi
    fi

    # (b) ctx_execute_file path on source + symbol-search verb in code
    if [ -z "$REASON" ]; then
        PATH_FIELD="$(printf '%s' "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)"
        if [ -n "$PATH_FIELD" ] && printf '%s' "$PATH_FIELD" | grep -E -q "$EXT_RE"; then
            if printf '%s' "$HAYSTACK" | grep -E -iq "(find|locate|where[[:space:]]+(is|does)|definition[[:space:]]+of|references[[:space:]]+to|declaration[[:space:]]+of|symbol[[:space:]]+for|all[[:space:]]+(uses|callers|functions|classes|methods)|implements[[:space:]])"; then
                REASON="ctx_execute_file on a source file with a symbol-search query"
            fi
        fi
    fi

    # (c) cat/head/tail/less/sed reading source + function/class/method regex
    if [ -z "$REASON" ]; then
        if printf '%s' "$HAYSTACK" | grep -E -q "(^|[^a-zA-Z0-9_])(cat|head|tail|less|sed[[:space:]]+-n)[[:space:]]"; then
            if printf '%s' "$HAYSTACK" | grep -E -q "$EXT_RE"; then
                if printf '%s' "$HAYSTACK" | grep -E -iq "(function|class|method|def[[:space:]]|interface|struct|enum)"; then
                    REASON="cat/head/tail/sed reading a source file paired with a function/class/method query"
                fi
            fi
        fi
    fi
fi

[ -n "$REASON" ] || emit_pass_through

# ─── Detect codegraph (v0.13+ optional integration) ────────────────────────
# Codegraph indexes the repo into .codegraph/codegraph.db; its MCP tools
# (codegraph_explore / codegraph_callers / codegraph_callees / codegraph_impact)
# are structural alternatives to LSP. Detection: presence of the SQLite db
# at the project root means codegraph is installed AND has indexed this project.
CODEGRAPH_AVAILABLE=0
if [ -r "$PROJECT_DIR/.codegraph/codegraph.db" ]; then
    CODEGRAPH_AVAILABLE=1
fi

# ─── Log the ask-gate for audit-tool surveillance ───────────────────────────
log_event() {
    local events_dir="$PROJECT_DIR/.code4me"
    local events_log="$events_dir/lsp-first-events.jsonl"
    [ -d "$events_dir" ] || mkdir -p "$events_dir" 2>/dev/null || return 0
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    if command -v jq >/dev/null 2>&1; then
        # For Read/Grep, capture the relevant input fields.
        local haystack_head
        case "$TOOL_NAME" in
            Read)
                haystack_head="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
                ;;
            Grep)
                haystack_head="$(printf '%s' "$INPUT" | jq -r '"\(.tool_input.pattern // empty) glob=\(.tool_input.glob // "") type=\(.tool_input.type // "") path=\(.tool_input.path // "")"' 2>/dev/null)"
                ;;
            *)
                haystack_head="$(printf '%s' "${HAYSTACK:-}" | head -c 500)"
                ;;
        esac
        jq -nc \
            --arg ts "$ts" \
            --arg tool "$TOOL_NAME" \
            --arg reason "$REASON" \
            --arg haystack "$haystack_head" \
            --argjson codegraph_available "$CODEGRAPH_AVAILABLE" \
            '{ts: $ts, tool: $tool, reason: $reason, haystack_head: $haystack, codegraph_available: ($codegraph_available == 1), event: "ask-gate"}' \
            >> "$events_log" 2>/dev/null || true
    fi
    return 0
}
log_event

# ─── Compose the redirect message ───────────────────────────────────────────
if [ "$CODEGRAPH_AVAILABLE" -eq 1 ]; then
    REDIRECT_MSG="Source-file symbol query detected (${REASON}).

This project has both LSP (via .lsp.json) and codegraph (.codegraph/codegraph.db) available. Either gives a structural answer in one call; pick whichever fits the question.

codegraph — graph-shaped, pre-indexed (fastest for cross-file structural questions):
  - codegraph_explore <symbol>        — \"tell me about X: definition, neighbors, cross-language edges\"
  - codegraph_callers <symbol>        — \"who calls X?\"
  - codegraph_callees <symbol>        — \"what does X call?\"
  - codegraph_impact <symbol>         — \"if I change X, what breaks downstream?\"
  - codegraph_search <query>          — full-text symbol search (FTS5)

LSP — language-aware, type-precise (best for type signatures and refactoring-grade accuracy):
  - textDocument/definition           — \"where is X defined?\"
  - textDocument/references           — \"who calls X?\" (precise, single-language)
  - textDocument/hover                — \"what type is X?\"
  - textDocument/documentSymbol       — \"what symbols are in this file?\"
  - workspace/symbol                  — \"find a symbol by name\"
  - textDocument/diagnostics          — \"what's wrong with this file?\"

If you're doing a whole-file Read because something already narrowed it down, re-issue the Read with explicit offset+limit and the gate won't fire. If you're grepping for a symbol name, prefer codegraph_explore or workspace/symbol — same answer, structural.

Fall back to ctx_execute / Read / Grep only when neither codegraph nor LSP can answer (regex inside comments, fuzzy text search, non-source surfaces).

See \`skills/code4me/references/code-consultation-precedence.md\` for the full ordering. Type \"yes\" to proceed anyway."
else
    REDIRECT_MSG="Source-file symbol query detected (${REASON}).

LSP gives a structural answer in one call — and this project has .lsp.json declared.

Prefer LSP first:
  - textDocument/definition       — \"where is X defined?\"
  - textDocument/references       — \"who calls X?\"
  - textDocument/hover            — \"what type is X?\"
  - textDocument/documentSymbol   — \"what symbols are in this file?\"
  - workspace/symbol              — \"find a symbol by name across the workspace\"
  - textDocument/diagnostics      — \"what's wrong with this file?\"

If you're doing a whole-file Read because LSP already narrowed it down, re-issue the Read with explicit offset+limit and the gate won't fire. If you're grepping for a symbol name, prefer workspace/symbol — same answer, structural.

Fall back to ctx_execute / Read / Grep only when LSP can't answer (regex inside comments, cross-language symbols, fuzzy text search, non-source surfaces).

See \`skills/code4me/references/code-consultation-precedence.md\` for the full ordering. Type \"yes\" to proceed anyway."
fi

emit_ask "$REDIRECT_MSG"
