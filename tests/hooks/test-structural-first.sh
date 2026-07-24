#!/usr/bin/env bash
# Regression test for hooks/check-structural-first-on-source.sh.

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
HOOK="$ROOT/hooks/check-structural-first-on-source.sh"
HOOK_PATH="/usr/bin:/bin"
PASS=0
FAIL=0

ok() { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

assert_pass() {
    local desc="$1" output="$2"
    local decision
    decision="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "pass"' 2>/dev/null || printf invalid)"
    if [ "$decision" = "pass" ]; then ok "$desc -> pass"; else bad "$desc (got $decision: $output)"; fi
}

assert_context() {
    local desc="$1" output="$2" pattern="$3"
    local context
    context="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
    if printf '%s' "$context" | grep -q "$pattern"; then ok "$desc"; else bad "$desc (missing $pattern: $output)"; fi
}

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }
bash -n "$HOOK" || exit 1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src"
printf 'class Foo: pass\n' > "$TMP/src/foo.py"

echo "== no structural surface -> pass =="
payload="$(jq -n --arg p "$TMP/src/foo.py" '{tool_name:"Read",tool_input:{file_path:$p}}')"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_pass "whole-file Read without index" "$out"

echo "== codegraph -> non-blocking nudge =="
mkdir -p "$TMP/.codegraph"
: > "$TMP/.codegraph/codegraph.db"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_pass "whole-file Read with codegraph" "$out"
assert_context "guidance names codegraph" "$out" "codegraph_explore"

echo "== CocoIndex -> non-blocking nudge =="
rm -rf "$TMP/.codegraph"
mkdir -p "$TMP/.cocoindex_code"
payload="$(jq -n '{tool_name:"Grep",tool_input:{pattern:"Foo",type:"py"}}')"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_pass "bare-symbol Grep with CocoIndex" "$out"
assert_context "guidance names CocoIndex" "$out" "CocoIndex"

echo "== ctx_batch_execute -> non-blocking nudge =="
payload="$(jq -n '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute",tool_input:{commands:[{label:"find foo",command:"rg Foo src/foo.py"}]}}')"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_pass "ctx_batch_execute source grep" "$out"
assert_context "ctx_batch_execute receives guidance" "$out" "Use the code indexes"

echo ""
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
