#!/usr/bin/env bash
# Regression test for hooks/check-session-wiring.sh (read-only SessionStart detector).
set -u
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
HOOK="$ROOT/hooks/check-session-wiring.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
quiet(){ [ "$1" = "{}" ] && ok "$2" || bad "$2 (expected {} got: $1)"; }
nudges(){ printf '%s' "$1" | jq -e '.hookSpecificOutput.additionalContext|test("code4me-install")' >/dev/null 2>&1 && ok "$2" || bad "$2 (expected nudge)"; }
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }
bash -n "$HOOK" || exit 1

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

echo "== silent when nothing configured =="
quiet "$(CLAUDE_PROJECT_DIR="$T" bash "$HOOK")" "no config -> {}"

echo "== silent when correctly wired =="
mkdir -p "$T/.claude"
printf '{"hooks":{"PreToolUse":[{"matcher":"Read|Grep","hooks":[{"type":"command","command":"bash %s/hooks/check-structural-first-on-source.sh"}]}]}}' "$ROOT" > "$T/.claude/settings.json"
quiet "$(CLAUDE_PROJECT_DIR="$T" bash "$HOOK")" "valid wiring -> {}"

echo "== nudges on unsubstituted <PLUGIN_DIR> =="
printf '{"hooks":{"PreToolUse":[{"matcher":"Read|Grep","hooks":[{"type":"command","command":"bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh"}]}]}}' > "$T/.claude/settings.json"
nudges "$(CLAUDE_PROJECT_DIR="$T" bash "$HOOK")" "<PLUGIN_DIR> -> nudge"

echo "== nudges on missing hook path =="
printf '{"hooks":{"PreToolUse":[{"matcher":"Read|Grep","hooks":[{"type":"command","command":"bash /gone/hooks/check-structural-first-on-source.sh"}]}]}}' > "$T/.claude/settings.json"
nudges "$(CLAUDE_PROJECT_DIR="$T" bash "$HOOK")" "missing path -> nudge"

echo "== nudges on invalid .lsp.json + never writes =="
printf '{"hooks":{"PreToolUse":[]}}' > "$T/.claude/settings.json"
printf '{ this is not json ' > "$T/.lsp.json"
nudges "$(CLAUDE_PROJECT_DIR="$T" bash "$HOOK")" "invalid .lsp.json -> nudge"
# detector must not have modified anything
BEFORE="$(cat "$T/.lsp.json")"; CLAUDE_PROJECT_DIR="$T" bash "$HOOK" >/dev/null
[ "$(cat "$T/.lsp.json")" = "$BEFORE" ] && ok "detector did not modify files (read-only)" || bad "detector mutated a file"

echo ""; printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
