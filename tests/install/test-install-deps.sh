#!/usr/bin/env bash
# Regression test for bin/code4me-install-deps. Does not install anything.

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
SCRIPT="$ROOT/bin/code4me-install-deps"
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

bash -n "$SCRIPT" || { echo "install-deps syntax error"; exit 1; }

echo "== check mode =="
OUT="$(bash "$SCRIPT" --check 2>&1)"
RC=$?
[ "$RC" -eq 0 ] && ok "--check exits 0" || bad "--check exits $RC"
contains "--check reports dependency check" "$OUT" "code4me dependency check"
contains "--check reports claude-p" "$OUT" "claude-p"

echo "== dry-run install =="
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
printf '#!/usr/bin/env sh\nexit 0\n' > "$WORK/npm"
chmod +x "$WORK/npm"
OUT="$(PATH="$WORK" "$BASH" "$SCRIPT" --dry-run --install all 2>&1)"
RC=$?
[ "$RC" -eq 0 ] && ok "--dry-run --install all exits 0" || bad "--dry-run --install all exits $RC"
contains "dry-run includes wrapper install hint" "$OUT" "github:indie-hub/claude-wrapper"

echo "== bad group =="
if bash "$SCRIPT" --install nope >/dev/null 2>&1; then
    bad "unknown install group fails"
else
    ok "unknown install group fails"
fi

echo ""
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
