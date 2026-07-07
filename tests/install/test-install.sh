#!/usr/bin/env bash
# Regression test for bin/code4me-install. Pure bash + jq. Uses stub server
# binaries on a temp PATH to simulate detection. Exits non-zero on any failure.

set -u
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
INSTALL="$ROOT/bin/code4me-install"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got [$2] want [$3])"; fi; }
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }
bash -n "$INSTALL" || { echo "install script syntax error"; exit 1; }
BASH_BIN="$(command -v bash)"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FAKE="$WORK/fakebin"; mkdir -p "$FAKE"
for s in roslyn-language-server clangd node sourcekit-lsp; do printf '#!/bin/sh\nexit 0\n' > "$FAKE/$s"; chmod +x "$FAKE/$s"; done
export PATH="$FAKE:$PATH"

echo "== fresh install =="
P1="$WORK/p1"; mkdir -p "$P1"
bash "$INSTALL" --project "$P1" >/dev/null
S1="$P1/.claude/settings.json"
eq "settings.json valid"        "$(jq -e . "$S1" >/dev/null 2>&1 && echo y)" "y"
    eq "2 PreToolUse blocks"        "$(jq '.hooks.PreToolUse|length' "$S1")" "2"
    eq "4 hook commands at plugin"  "$(jq -r '[.hooks.PreToolUse[].hooks[].command|select(startswith("bash '"$ROOT"'/hooks/"))]|length' "$S1")" "4"
    eq "no default .lsp.json"        "$([ -f "$P1/.lsp.json" ] && echo y || echo n)" "n"
eq "1 SessionStart detector"    "$(jq '.hooks.SessionStart|length' "$S1")" "1"
eq "SessionStart->wiring hook"  "$(jq -r '[.hooks.SessionStart[].hooks[].command|select(endswith("check-session-wiring.sh"))]|length' "$S1")" "1"

echo "== idempotent (no duplication) =="
bash "$INSTALL" --project "$P1" >/dev/null
    eq "still 2 PreToolUse blocks"  "$(jq '.hooks.PreToolUse|length' "$S1")" "2"
eq "still 1 SessionStart"       "$(jq '.hooks.SessionStart|length' "$S1")" "1"
eq "backup written"             "$([ -f "$S1.bak" ] && echo y)" "y"

echo "== preserve foreign settings + replace stale code4me path =="
P2="$WORK/p2"; mkdir -p "$P2/.claude"
cat > "$P2/.claude/settings.json" <<JSON
{"env":{"FOO":"bar"},"hooks":{"PreToolUse":[
  {"matcher":"Bash","hooks":[{"type":"command","command":"echo keepme"}]},
  {"matcher":"Edit","hooks":[{"type":"command","command":"bash /OLD/code4me-plugin/hooks/check-obsolete-memory.sh"}]}
]}}
JSON
bash "$INSTALL" --project "$P2" --no-lsp >/dev/null
eq "env preserved"              "$(jq -r '.env.FOO' "$P2/.claude/settings.json")" "bar"
eq "foreign hook preserved"     "$(jq '[.hooks.PreToolUse[].hooks[]|select(.command=="echo keepme")]|length' "$P2/.claude/settings.json")" "1"
eq "stale path removed"         "$(jq '[.hooks.PreToolUse[].hooks[]|select(.command|test("/OLD/"))]|length' "$P2/.claude/settings.json")" "0"
    eq "structural hook wired once" "$(jq '[.hooks.PreToolUse[].hooks[]|select(.command|test("'"$ROOT"'/hooks/check-structural-first-on-source.sh"))]|length' "$P2/.claude/settings.json")" "1"
    eq "obsolete code4me hook not re-added" "$(jq '[.hooks.PreToolUse[].hooks[]|select(.command|test("check-obsolete-memory.sh"))]|length' "$P2/.claude/settings.json")" "0"

echo "== dry-run writes nothing =="
P3="$WORK/p3"; mkdir -p "$P3"
bash "$INSTALL" --project "$P3" --dry-run >/dev/null
eq "no settings.json written"   "$([ -f "$P3/.claude/settings.json" ] && echo y || echo n)" "n"

echo "== clang-proxy modes =="
P4="$WORK/p4"; mkdir -p "$P4"
    bash "$INSTALL" --project "$P4" --no-hooks --with-lsp --clang-proxy always >/dev/null
eq "proxy mode: node"           "$(jq -r '.cpp.command' "$P4/.lsp.json")" "node"
eq "proxy path is plugin mjs"   "$(jq -r '.cpp.args[0]' "$P4/.lsp.json")" "$ROOT/bin/clangd-didopen-proxy.mjs"
P4b="$WORK/p4b"; mkdir -p "$P4b"
    bash "$INSTALL" --project "$P4b" --no-hooks --with-lsp --clang-proxy never >/dev/null
eq "no-proxy mode: clangd"      "$(jq -r '.cpp.command' "$P4b/.lsp.json")" "clangd"

echo "== no servers -> no lsp.json; --lsp-all -> all three =="
P5="$WORK/p5"; mkdir -p "$P5"
NO_LSP_BIN="$WORK/no-lsp-bin"; mkdir -p "$NO_LSP_BIN"
for c in jq uname dirname mkdir mktemp mv cp grep sed head diff; do
    ln -s "$(command -v "$c")" "$NO_LSP_BIN/$c"
done
PATH="$NO_LSP_BIN" "$BASH_BIN" "$INSTALL" --project "$P5" --no-hooks --with-lsp >/dev/null 2>&1 || true
eq "no .lsp.json when nothing detected" "$([ -f "$P5/.lsp.json" ] && echo y || echo n)" "n"
PATH="$NO_LSP_BIN" "$BASH_BIN" "$INSTALL" --project "$P5" --no-hooks --with-lsp --lsp-all >/dev/null 2>&1 || true
eq "--lsp-all writes 3 langs"   "$(jq 'keys|length' "$P5/.lsp.json" 2>/dev/null)" "3"

echo ""
echo "================================"
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
echo "================================"
[ "$FAIL" -eq 0 ]
