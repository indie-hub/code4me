#!/usr/bin/env bash
# Regression test for bin/code4me-claude-wrapper-run using a fake claude-p.

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
SCRIPT="$ROOT/bin/code4me-claude-wrapper-run"
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
contains() {
    case "$2" in
        *"$3"*) ok "$1" ;;
        *) bad "$1 (missing [$3])" ;;
    esac
}

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }
bash -n "$SCRIPT" || { echo "claude-wrapper helper syntax error"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAKE="$WORK/claude-p"
ARGS="$WORK/args.txt"
PROMPT="$WORK/prompt.md"

cat > "$FAKE" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CLAUDE_P_ARGS_FILE"
printf '{"answer":"CLAUDE_WRAPPER_OK","session_id":"fake"}\n'
SH
chmod +x "$FAKE"

printf 'Act as code4me verifier.\nReturn JSON only.\n' > "$PROMPT"

echo "== helper calls fake claude-p =="
OUT="$(CLAUDE_P_BIN="$FAKE" CLAUDE_P_ARGS_FILE="$ARGS" bash "$SCRIPT" --prompt-file "$PROMPT" --cwd "$WORK" --timeout-sec 7 --model sonnet --effort high --tools '' --session-id s1 2>&1)"
RC=$?
[ "$RC" -eq 0 ] && ok "helper exits 0" || bad "helper exits $RC"
printf '%s' "$OUT" | jq -e '.answer == "CLAUDE_WRAPPER_OK"' >/dev/null 2>&1 && ok "helper returns JSON" || bad "helper returns JSON"
ARGS_TEXT="$(cat "$ARGS")"
contains "passes output format" "$ARGS_TEXT" "--output-format"
contains "passes json mode" "$ARGS_TEXT" "json"
contains "passes timeout" "$ARGS_TEXT" "--timeout-sec"
contains "passes timeout value" "$ARGS_TEXT" "7"
contains "passes cwd" "$ARGS_TEXT" "--cwd"
contains "passes cwd value" "$ARGS_TEXT" "$WORK"
contains "passes model" "$ARGS_TEXT" "--model"
contains "passes model value" "$ARGS_TEXT" "sonnet"
contains "passes effort" "$ARGS_TEXT" "--effort"
contains "passes effort value" "$ARGS_TEXT" "high"
contains "passes tools" "$ARGS_TEXT" "--tools"
if awk 'previous == "--tools" && $0 == "" { found=1 } { previous=$0 } END { exit !found }' "$ARGS"; then
    ok "passes empty tools value"
else
    bad "passes empty tools value"
fi
contains "passes session id" "$ARGS_TEXT" "--session-id"
contains "passes session value" "$ARGS_TEXT" "s1"
contains "passes prompt content" "$ARGS_TEXT" "Act as code4me verifier."

echo "== dry-run does not require claude-p =="
OUT="$(CLAUDE_P_BIN="$WORK/missing" bash "$SCRIPT" --dry-run --prompt "hello" --cwd "$WORK" 2>&1)"
RC=$?
[ "$RC" -eq 0 ] && ok "dry-run exits 0 without binary" || bad "dry-run exits $RC"
contains "dry-run shows command" "$OUT" "DRY-RUN:"

echo "== invalid effort is rejected =="
OUT="$(bash "$SCRIPT" --dry-run --prompt "hello" --cwd "$WORK" --effort extreme 2>&1)"
RC=$?
[ "$RC" -eq 2 ] && ok "invalid effort exits 2" || bad "invalid effort exits $RC"
contains "invalid effort explains values" "$OUT" "low, medium, high, xhigh, max"

echo ""
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
