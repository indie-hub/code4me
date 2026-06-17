#!/usr/bin/env bash
# Regression test for hooks/check-buglog-helper.sh — the PreToolUse hook that
# redirects whole-file reads / hand-edits of .wolf/buglog.json to code4me-buglog.
# Pure bash + jq. Exits non-zero on any failure.

set -u
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
HOOK="$ROOT/hooks/check-buglog-helper.sh"
PASS=0; FAIL=0
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }

PROJ="$(mktemp -d)"; mkdir -p "$PROJ/.wolf"; echo '{"version":1,"bugs":[]}' > "$PROJ/.wolf/buglog.json"
NOBUG="$(mktemp -d)"
trap 'rm -rf "$PROJ" "$NOBUG"' EXIT

j() { jq -nc --arg t "$1" --argjson ti "$2" '{tool_name:$t, tool_input:$ti}'; }
chk() { # desc expect(ask|pass) project json
    local out got
    out="$(printf '%s' "$4" | CLAUDE_PROJECT_DIR="$3" bash "$HOOK")"
    if printf '%s' "$out" | grep -q permissionDecision; then got=ask; else got=pass; fi
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s -> %s\n' "$1" "$got"
    else FAIL=$((FAIL+1)); printf '  FAIL %s expected %s got %s\n' "$1" "$2" "$got"; fi
}

echo "== reads redirect =="
chk "whole-file Read"          ask  "$PROJ" "$(j Read '{"file_path":".wolf/buglog.json"}')"
chk "narrowed Read passes"     pass "$PROJ" "$(j Read '{"file_path":".wolf/buglog.json","offset":1,"limit":50}')"
chk "Read other file passes"   pass "$PROJ" "$(j Read '{"file_path":"src/foo.cs"}')"
chk "Grep over buglog"         ask  "$PROJ" "$(j Grep '{"pattern":"x","path":".wolf/buglog.json"}')"
chk "Bash cat buglog"          ask  "$PROJ" "$(j Bash '{"command":"cat .wolf/buglog.json"}')"
chk "Bash helper exempt"       pass "$PROJ" "$(j Bash '{"command":"python3 bin/code4me-buglog --buglog .wolf/buglog.json search --tag cpp"}')"
chk "Bash unrelated passes"    pass "$PROJ" "$(j Bash '{"command":"ls -la"}')"

echo "== writes redirect =="
chk "Edit buglog"              ask  "$PROJ" "$(j Edit '{"file_path":".wolf/buglog.json","old_string":"a","new_string":"b"}')"
chk "Write buglog"            ask  "$PROJ" "$(j Write '{"file_path":".wolf/buglog.json","content":"{}"}')"
chk "Bash append >> buglog"   ask  "$PROJ" "$(j Bash '{"command":"echo {} >> .wolf/buglog.json"}')"
chk "Edit other file passes"  pass "$PROJ" "$(j Edit '{"file_path":"src/foo.cs","old_string":"a","new_string":"b"}')"

echo "== self-disable + format of message =="
chk "no buglog -> pass"        pass "$NOBUG" "$(j Read '{"file_path":".wolf/buglog.json"}')"
# read message mentions search; write message mentions add/update
rmsg="$(printf '%s' "$(j Read '{"file_path":".wolf/buglog.json"}')" | CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
printf '%s' "$rmsg" | grep -q 'code4me-buglog search' && { PASS=$((PASS+1)); echo "  ok   read redirect names 'search'"; } || { FAIL=$((FAIL+1)); echo "  FAIL read msg"; }
wmsg="$(printf '%s' "$(j Write '{"file_path":".wolf/buglog.json","content":"{}"}')" | CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
printf '%s' "$wmsg" | grep -q 'code4me-buglog add' && { PASS=$((PASS+1)); echo "  ok   write redirect names 'add'"; } || { FAIL=$((FAIL+1)); echo "  FAIL write msg"; }

echo ""
echo "================================"
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
echo "================================"
[ "$FAIL" -eq 0 ]
