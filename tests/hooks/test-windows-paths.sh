#!/usr/bin/env bash
# Regression test for Windows path normalisation in the path-matching hooks.
#
# Covers the bug where, under Git Bash / MSYS, Claude Code passes Windows-style
# paths (C:\Users\... or C:/Users/...). The old POSIX-only `case "$p" in /*)`
# absolute-path test mis-classified those as relative, so the project dir was
# wrongly prepended and NO allowlist / protected / forbidden pattern matched.
# Net effect on the critical-write hook: every Edit/Write ask-gated ("all files
# protected"); on test-protection: protected tests silently editable.
#
# Strategy:
#   * Unit-test the helper functions in hooks/c4m-pathlib.sh (fully portable).
#   * End-to-end test all three hooks with POSIX paths (regression guard).
#   * End-to-end test with a faithful Windows simulation: a project rooted at a
#     literal "C:/proj" directory (':' is a legal Linux filename char, and a
#     leading "C:" is not absolute on Linux, so it resolves under the test cwd),
#     with CLAUDE_PROJECT_DIR passed in backslash form and C4M_FORCE_WINDOWS=1
#     to exercise drive-letter detection, backslash separators, and the
#     case-insensitive fold.
#
# Requires: bash and jq. Exits non-zero on any failure.

set -u

HOOKS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../hooks" && pwd )"
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

# --- unit tests for c4m-pathlib.sh -----------------------------------------

# shellcheck source=../../hooks/c4m-pathlib.sh
. "$HOOKS_DIR/c4m-pathlib.sh"

eq() { # desc  got  want
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got [$2] want [$3])"; fi
}
truthy() { if "$@"; then ok "is_abs: $*"; else bad "is_abs: $* (expected true)"; fi; }
falsy()  { if "$@"; then bad "is_abs: $* (expected false)"; else ok "is_abs: $*"; fi; }

echo "== unit: c4m_slashify =="
eq "backslashes -> slashes"      "$(c4m_slashify 'C:\Users\FVR\proj')" "C:/Users/FVR/proj"
eq "posix unchanged"             "$(c4m_slashify '/home/u/proj')"      "/home/u/proj"

echo "== unit: c4m_is_abs =="
truthy c4m_is_abs "/home/u"
truthy c4m_is_abs "C:/Users"
truthy c4m_is_abs "C:"
falsy  c4m_is_abs "src/auth/Foo.cs"
falsy  c4m_is_abs "Foo.cs"

echo "== unit: c4m_resolve =="
eq "relative joined to win base"  "$(c4m_resolve 'src/auth/Foo.cs' 'C:\proj')"        "C:/proj/src/auth/Foo.cs"
eq "win-abs target unchanged"     "$(c4m_resolve 'C:\proj\src\auth\Foo.cs' 'C:\proj')" "C:/proj/src/auth/Foo.cs"
eq "relative joined to posix"     "$(c4m_resolve 'src/auth/Foo.cs' '/home/u/proj')"   "/home/u/proj/src/auth/Foo.cs"
eq "posix-abs target unchanged"   "$(c4m_resolve '/home/u/proj/x.cs' '/home/u/proj')" "/home/u/proj/x.cs"

echo "== unit: c4m_fold =="
eq "posix: identity (no fold)"    "$(C4M_FORCE_WINDOWS=0 c4m_fold 'C:/Proj/SRC')"     "C:/Proj/SRC"
eq "windows: lowercased"          "$(C4M_FORCE_WINDOWS=1 c4m_fold 'C:/Proj/SRC')"     "c:/proj/src"

# --- end-to-end harness ----------------------------------------------------

# run_hook <hook-file> <tool_name> <file_path>  -> prints hook stdout
run_hook() {
    jq -n --arg t "$2" --arg p "$3" '{tool_name:$t, tool_input:{file_path:$p}}' \
        | bash "$HOOKS_DIR/$1"
}
# assert <desc> <pass|ask> <hook-output>
assert() {
    local got
    if printf '%s' "$3" | grep -q 'permissionDecision'; then got=ask; else got=pass; fi
    if [ "$got" = "$2" ]; then ok "$1 -> $got"; else bad "$1 (expected $2, got $got)"; fi
}

# ---- POSIX project ----
PROOT="$(mktemp -d)"
mkdir -p "$PROOT/.code4me"
printf 'src/auth/**\ntests/**\n'                 > "$PROOT/.code4me/critical-allowlist.txt"
printf 'tests/**\n'                              > "$PROOT/.code4me/protected-tests.txt"
printf '{"forbidden_globs":["migrations/**","schema/*.sql"]}\n' > "$PROOT/.code4me/forbidden-conditions.json"

echo "== e2e POSIX: critical-write-allowlist =="
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-critical-write-allowlist.sh Edit "$PROOT/src/auth/Login.cs")";   assert "in-scope edit"      pass "$out"
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-critical-write-allowlist.sh Edit "$PROOT/src/billing/Charge.cs")"; assert "out-of-scope edit" ask  "$out"
# case-sensitivity preserved on POSIX (must NOT fold): different case -> out of scope
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-critical-write-allowlist.sh Edit "$PROOT/SRC/AUTH/Login.cs")";   assert "case differs (posix sensitive)" ask "$out"
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-critical-write-allowlist.sh Edit "$PROOT/.code4me/milestone-status-tracker-M05.md")"; assert ".code4me bookkeeping exempt" pass "$out"
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-critical-write-allowlist.sh Edit "$PROOT/.code4me/basic-memory/decision.md")"; assert ".code4me memory exempt" pass "$out"

echo "== e2e POSIX: test-protection =="
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-test-protection.sh Edit "$PROOT/tests/AuthTest.cs")";  assert "protected test edit" ask  "$out"
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-test-protection.sh Edit "$PROOT/src/auth/Login.cs")";  assert "non-test edit"       pass "$out"

echo "== e2e POSIX: forbidden-conditions =="
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-forbidden-conditions.sh Write "$PROOT/migrations/001_init.sql")"; assert "new migration"   ask  "$out"
out="$(CLAUDE_PROJECT_DIR="$PROOT" run_hook check-forbidden-conditions.sh Write "$PROOT/src/auth/New.cs")";         assert "ordinary new file" pass "$out"

# ---- Windows simulation (drive-letter, backslashes, case-insensitive) ----
WROOT="$(mktemp -d)"
_OLDPWD="$PWD"
cd "$WROOT" || bad "cd into windows test root"
mkdir -p 'C:/proj/.code4me'
printf 'src/auth/**\ntests/**\n'                 > 'C:/proj/.code4me/critical-allowlist.txt'
printf 'tests/**\n'                              > 'C:/proj/.code4me/protected-tests.txt'
printf '{"forbidden_globs":["migrations/**","schema/*.sql"]}\n' > 'C:/proj/.code4me/forbidden-conditions.json'

export C4M_FORCE_WINDOWS=1
export CLAUDE_PROJECT_DIR='C:\proj'

echo "== e2e WINDOWS: critical-write-allowlist =="
out="$(run_hook check-critical-write-allowlist.sh Edit 'C:\proj\src\auth\Login.cs')";    assert "win in-scope (backslash)"   pass "$out"
out="$(run_hook check-critical-write-allowlist.sh Edit 'C:\proj\src\billing\Charge.cs')"; assert "win out-of-scope"           ask  "$out"
out="$(run_hook check-critical-write-allowlist.sh Edit 'C:\proj\SRC\AUTH\Login.cs')";    assert "win in-scope (case-insens)" pass "$out"
out="$(run_hook check-critical-write-allowlist.sh Edit 'C:\proj\.code4me\milestone-status-tracker-M05.md')"; assert "win .code4me exempt" pass "$out"
out="$(run_hook check-critical-write-allowlist.sh Edit 'C:\proj\.code4me\basic-memory\decision.md')"; assert "win .code4me memory exempt" pass "$out"

echo "== e2e WINDOWS: test-protection =="
out="$(run_hook check-test-protection.sh Edit 'C:\proj\tests\AuthTest.cs')"; assert "win protected test" ask  "$out"
out="$(run_hook check-test-protection.sh Edit 'C:\proj\src\auth\Login.cs')"; assert "win non-test edit"  pass "$out"

echo "== e2e WINDOWS: forbidden-conditions =="
out="$(run_hook check-forbidden-conditions.sh Write 'C:\proj\migrations\001_init.sql')"; assert "win new migration"  ask  "$out"
out="$(run_hook check-forbidden-conditions.sh Write 'C:\proj\src\auth\New.cs')";         assert "win ordinary file"  pass "$out"

unset C4M_FORCE_WINDOWS CLAUDE_PROJECT_DIR
cd "$_OLDPWD" || true

rm -rf "$PROOT" "$WROOT"

echo ""
echo "================================"
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
echo "================================"
[ "$FAIL" -eq 0 ]
