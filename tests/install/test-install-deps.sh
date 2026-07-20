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

echo "== dry-run MCP configuration =="
for tool in uvx ccc codegraph; do
    printf '#!/usr/bin/env sh\nexit 0\n' > "$WORK/$tool"
    chmod +x "$WORK/$tool"
done
printf '#!/usr/bin/env sh\nprintf "22.5.0\\n"\n' > "$WORK/node"
chmod +x "$WORK/node"
cat > "$WORK/codex" <<'EOF'
#!/usr/bin/env sh
case "$1 $2" in
  "mcp get") exit 1 ;;
  "plugin list"|"plugin marketplace") printf '{"installed":[]}\n'; exit 0 ;;
esac
exit 0
EOF
cat > "$WORK/claude" <<'EOF'
#!/usr/bin/env sh
case "$1 $2" in
  "mcp get") exit 1 ;;
  "plugin list"|"plugin marketplace") printf '[]\n'; exit 0 ;;
esac
exit 0
EOF
chmod +x "$WORK/codex" "$WORK/claude"
OUT="$(PATH="$WORK:$PATH" "$BASH" "$SCRIPT" --dry-run --configure-mcp all 2>&1)"
RC=$?
[ "$RC" -eq 0 ] && ok "--configure-mcp all exits 0" || bad "--configure-mcp all exits $RC"
contains "configures Codex Basic Memory" "$OUT" "codex mcp add basic-memory -- uvx basic-memory mcp"
contains "configures Claude CocoIndex" "$OUT" "claude mcp add --scope user cocoindex-code -- ccc mcp"
contains "delegates codegraph configuration" "$OUT" "codegraph install --target codex,claude --location global --yes"
contains "installs Codex context-mode plugin" "$OUT" "codex plugin add context-mode@context-mode"
contains "prints restart checklist" "$OUT" "Restart Codex"

echo "== bad group =="
if bash "$SCRIPT" --install nope >/dev/null 2>&1; then
    bad "unknown install group fails"
else
    ok "unknown install group fails"
fi

echo ""
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
