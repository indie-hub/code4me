#!/usr/bin/env bash
# Code4Me SessionStart hook — read-only wiring detector.
#
# Fires at session start and surfaces (as session context) when code4me's
# configuration has paths that can't resolve on this machine:
#   * a hook command in .claude/settings.json with an unsubstituted <PLUGIN_DIR>
#     or a script path that no longer exists, OR
#   * a project .lsp.json that is invalid JSON, still contains <PLUGIN_DIR>, or
#     points at a clangd-didopen-proxy that isn't there.
#
# It NEVER writes anything and NEVER blocks — it only nudges you to run
# `bin/code4me-install`. It is SILENT when wiring is correct or absent (so it
# doesn't nag plugin-system installs whose hooks come from hooks/hooks.json, and
# doesn't fire on a brand-new project that hasn't been set up yet). It only
# speaks up about config that exists but is broken — the "hardcoded path that
# can't exist here" failure mode.
set -u

emit_quiet() { printf '{}'; exit 0; }

command -v jq >/dev/null 2>&1 || emit_quiet

HOOK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_ROOT="$( cd "$HOOK_DIR/.." && pwd )"
. "$HOOK_DIR/c4m-pathlib.sh" 2>/dev/null || emit_quiet
PROJECT_DIR="$(c4m_slashify "${CLAUDE_PROJECT_DIR:-$PWD}")"

PROBLEMS=""

SETTINGS="$PROJECT_DIR/.claude/settings.json"
if [ -r "$SETTINGS" ] && jq -e . "$SETTINGS" >/dev/null 2>&1; then
    while IFS= read -r cmdpath; do
        [ -n "$cmdpath" ] || continue
        case "$cmdpath" in
            *"<PLUGIN_DIR>"*) PROBLEMS="${PROBLEMS}  - settings.json hook path not substituted: ${cmdpath}\n"; continue ;;
        esac
        [ -r "$cmdpath" ] || PROBLEMS="${PROBLEMS}  - settings.json hook path missing: ${cmdpath}\n"
    done < <(jq -r '.hooks.PreToolUse[]?.hooks[]?.command // empty
                    | select(test("/hooks/(check-test-protection|check-forbidden-conditions|check-critical-write-allowlist|check-buglog-helper|check-lsp-first-on-source)\\.sh"))
                    | sub("^bash +";"")' "$SETTINGS" 2>/dev/null)
fi

LSP="$PROJECT_DIR/.lsp.json"
if [ -r "$LSP" ]; then
    if ! jq -e . "$LSP" >/dev/null 2>&1; then
        PROBLEMS="${PROBLEMS}  - .lsp.json is not valid JSON\n"
    elif grep -q "<PLUGIN_DIR>" "$LSP" 2>/dev/null; then
        PROBLEMS="${PROBLEMS}  - .lsp.json has an unsubstituted <PLUGIN_DIR>\n"
    else
        PX="$(jq -r '.cpp.args[]? | select(type=="string" and endswith("clangd-didopen-proxy.mjs"))' "$LSP" 2>/dev/null | head -1)"
        if [ -n "$PX" ] && [ ! -r "$PX" ]; then
            PROBLEMS="${PROBLEMS}  - .lsp.json C++ proxy path missing: ${PX}\n"
        fi
    fi
fi

[ -n "$PROBLEMS" ] || emit_quiet

MSG="code4me: some configuration paths don't resolve on this machine —\n${PROBLEMS}\nFix (idempotent, backs up to .bak, --dry-run to preview):\n  bash ${PLUGIN_ROOT}/bin/code4me-install --project \"${PROJECT_DIR}\"\nThen run /code4me-preflight to confirm."

jq -nc --arg ctx "$(printf '%b' "$MSG")" \
    '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$ctx}}'
