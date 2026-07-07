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

assert_decision() {
    local desc="$1" want="$2" got="$3"
    local actual
    if printf '%s' "$got" | grep -q 'permissionDecision'; then
        actual=ask
    else
        actual=pass
    fi
    if [ "$actual" = "$want" ]; then
        ok "$desc -> $actual"
    else
        bad "$desc (expected $want, got $actual: $got)"
    fi
}

mentions() {
    local desc="$1" text="$2" pattern="$3"
    if printf '%s' "$text" | grep -q "$pattern"; then
        ok "$desc"
    else
        bad "$desc (missing $pattern: $text)"
    fi
}

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }
bash -n "$HOOK" || exit 1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src"
printf 'class Foo: pass\n' > "$TMP/src/foo.py"

echo "== no structural surface -> pass =="
payload="$(jq -n --arg p "$TMP/src/foo.py" '{tool_name:"Read", tool_input:{file_path:$p}}')"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_decision "whole-file Read without index" pass "$out"

echo "== codegraph -> ask =="
mkdir -p "$TMP/.codegraph"
: > "$TMP/.codegraph/codegraph.db"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_decision "whole-file Read with codegraph" ask "$out"
mentions "redirect names codegraph" "$out" "codegraph_explore"

echo "== CocoIndex -> ask =="
rm -rf "$TMP/.codegraph"
mkdir -p "$TMP/.cocoindex_code"
payload="$(jq -n '{tool_name:"Grep", tool_input:{pattern:"Foo", type:"py"}}')"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_decision "bare-symbol Grep with CocoIndex" ask "$out"
mentions "redirect names CocoIndex" "$out" "CocoIndex"

echo "== ctx_batch_execute command field -> ask =="
payload="$(jq -n '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute", tool_input:{commands:[{label:"find foo", command:"rg Foo src/foo.py"}]}}')"
out="$(PATH="$HOOK_PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$payload")"
assert_decision "ctx_batch_execute commands[].command source grep" ask "$out"

echo ""
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
