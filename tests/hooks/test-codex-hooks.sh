#!/usr/bin/env bash
# Contract and behavior tests for plugin-bundled Codex hooks.

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
MANIFEST="$ROOT/hooks/hooks.json"
ADAPTER="$ROOT/hooks/codex-pretool-adapter.sh"
PASS=0
FAIL=0

ok() { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

assert_decision() {
    local desc="$1" want="$2" output="$3" got
    got="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "pass"' 2>/dev/null || printf invalid)"
    if [ "$got" = "$want" ]; then ok "$desc -> $got"; else bad "$desc (expected $want, got $got: $output)"; fi
}

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }
bash -n "$ADAPTER" || exit 1
jq -e . "$MANIFEST" >/dev/null && ok "Codex hook manifest is valid JSON" || bad "Codex hook manifest is valid JSON"
jq -e '.hooks.PreToolUse | length == 2' "$MANIFEST" >/dev/null && ok "Codex PreToolUse groups bundled" || bad "Codex PreToolUse groups bundled"
jq -e '.hooks.SessionStart | length == 1' "$MANIFEST" >/dev/null && ok "Codex SessionStart bundled" || bad "Codex SessionStart bundled"
grep -F -q 'codex-pretool-adapter.sh' "$MANIFEST" && ok "standard plugin hook manifest owns adapter" || bad "standard plugin hook manifest owns adapter"

preflight="$(cd "$ROOT" && CODEX_THREAD_ID=test bash bin/code4me-preflight 2>&1 || true)"
printf '%s' "$preflight" | grep -q '| Codex hook bundle | .* ok |' && ok "Codex preflight requires bundled hooks" || bad "Codex preflight requires bundled hooks"
if printf '%s' "$preflight" | grep -q '| Hook installation |'; then bad "Codex preflight ignores Claude project hooks"; else ok "Codex preflight ignores Claude project hooks"; fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.code4me" "$TMP/tests" "$TMP/src/auth" "$TMP/src/billing" "$TMP/migrations" "$TMP/.codegraph"
printf 'tests/**\n' > "$TMP/.code4me/protected-tests.txt"
printf 'src/auth/**\n' > "$TMP/.code4me/critical-allowlist.txt"
printf '{"forbidden_globs":["migrations/**"]}\n' > "$TMP/.code4me/forbidden-conditions.json"
: > "$TMP/.codegraph/codegraph.db"
: > "$TMP/tests/AuthTest.cs"

payload="$(jq -nc --arg patch $'*** Begin Patch\n*** Update File: tests/AuthTest.cs\n@@\n-old\n+new\n*** End Patch' '{tool_name:"apply_patch",tool_input:{command:$patch}}')"
out="$(cd "$TMP" && printf '%s' "$payload" | PLUGIN_ROOT="$ROOT" bash "$ADAPTER" check-test-protection.sh)"
assert_decision "protected apply_patch path" deny "$out"

payload="$(jq -nc --arg patch $'*** Begin Patch\n*** Add File: migrations/001_init.sql\n+create table x;\n*** End Patch' '{tool_name:"apply_patch",tool_input:{command:$patch}}')"
out="$(cd "$TMP" && printf '%s' "$payload" | PLUGIN_ROOT="$ROOT" bash "$ADAPTER" check-forbidden-conditions.sh)"
assert_decision "forbidden added path" deny "$out"

payload="$(jq -nc --arg patch $'*** Begin Patch\n*** Update File: src/billing/Charge.cs\n@@\n-old\n+new\n*** End Patch' '{tool_name:"apply_patch",tool_input:{command:$patch}}')"
out="$(cd "$TMP" && printf '%s' "$payload" | PLUGIN_ROOT="$ROOT" bash "$ADAPTER" check-critical-write-allowlist.sh)"
assert_decision "out-of-scope apply_patch path" deny "$out"

payload="$(jq -nc --arg patch $'*** Begin Patch\n*** Update File: src/auth/Login.cs\n@@\n-old\n+new\n*** End Patch' '{tool_name:"apply_patch",tool_input:{command:$patch}}')"
out="$(cd "$TMP" && printf '%s' "$payload" | PLUGIN_ROOT="$ROOT" bash "$ADAPTER" check-critical-write-allowlist.sh)"
assert_decision "in-scope apply_patch path" pass "$out"

payload="$(jq -nc '{tool_name:"Bash",tool_input:{command:"rg Login src/auth/Login.cs"}}')"
out="$(cd "$TMP" && printf '%s' "$payload" | PLUGIN_ROOT="$ROOT" bash "$ADAPTER" check-structural-first-on-source.sh)"
assert_decision "source Bash search" deny "$out"

direct="$(cd "$TMP" && jq -nc --arg p "$TMP/tests/AuthTest.cs" '{tool_name:"Edit",tool_input:{file_path:$p}}' | bash "$ROOT/hooks/check-test-protection.sh")"
assert_decision "Claude direct hook remains ask" ask "$direct"

adapter_direct="$(cd "$TMP" && jq -nc --arg p "$TMP/tests/AuthTest.cs" '{tool_name:"Edit",tool_input:{file_path:$p}}' | bash "$ADAPTER" check-test-protection.sh)"
assert_decision "Claude plugin adapter avoids duplicate write gate" pass "$adapter_direct"

printf '\nPASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
