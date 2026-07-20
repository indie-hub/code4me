#!/usr/bin/env bash
# Regression coverage for native Windows jq CRLF output and corrupted commands.

set -u
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
PREFLIGHT="$ROOT/bin/code4me-preflight"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PROJECT="$WORK/project"; mkdir -p "$PROJECT/.claude"
REAL_JQ="$(command -v jq)"; export C4M_REAL_JQ="$REAL_JQ"

write_settings() {
    jq -n --arg root "$ROOT" '{hooks:{PreToolUse:[{matcher:"Edit|Write|MultiEdit",hooks:[
        {type:"command",command:("bash "+$root+"/hooks/check-test-protection.sh")},
        {type:"command",command:("bash "+$root+"/hooks/check-forbidden-conditions.sh")},
        {type:"command",command:("bash "+$root+"/hooks/check-critical-write-allowlist.sh")}
    ]},{matcher:"Read|Grep",hooks:[
        {type:"command",command:("bash "+$root+"/hooks/check-structural-first-on-source.sh")}
    ]}]}}' > "$PROJECT/.claude/settings.json"
}

echo "== native jq CRLF records =="
write_settings
FAKE_BIN="$WORK/fake-bin"; mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/jq" <<'EOF'
#!/usr/bin/env bash
set -o pipefail
"$C4M_REAL_JQ" "$@" | sed 's/\r$//' | sed $'s/$/\r/'
EOF
chmod +x "$FAKE_BIN/jq"
printf '#!/usr/bin/env sh\nexit 0\n' > "$FAKE_BIN/context-mode"
chmod +x "$FAKE_BIN/context-mode"
if CLAUDE_PROJECT_DIR="$PROJECT" PATH="$FAKE_BIN:$PATH" bash "$PREFLIGHT" > "$WORK/crlf-report" 2>&1 &&
   grep -q '| Hook command paths | .* ok |' "$WORK/crlf-report"; then
    ok "CRLF jq records do not corrupt hook paths"
else
    bad "CRLF jq records do not corrupt hook paths"
fi
if grep -q '| context-mode plugin (optional) | .* ok |' "$WORK/crlf-report"; then
    ok "preflight detects context-mode on PATH"
else
    bad "preflight detects context-mode on PATH"
fi

echo "== carriage return inside command =="
jq --arg command $'bash C:/stale/code4me/hooks/check-test-protection.sh\r' \
    '.hooks.PreToolUse[0].hooks[0].command = $command' \
    "$PROJECT/.claude/settings.json" > "$WORK/corrupt.json"
mv "$WORK/corrupt.json" "$PROJECT/.claude/settings.json"
if CLAUDE_PROJECT_DIR="$PROJECT" bash "$PREFLIGHT" > "$WORK/corrupt-report" 2>&1; then
    bad "corrupted command fails preflight"
elif grep -q 'managed hook command ends with a carriage return' "$WORK/corrupt-report"; then
    ok "corrupted command fails with an actionable diagnosis"
else
    bad "corrupted command fails with an actionable diagnosis"
fi

echo ""
echo "================================"
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
echo "================================"
[ "$FAIL" -eq 0 ]
