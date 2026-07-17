#!/usr/bin/env bash

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
VENDORS="$ROOT/skills/code4me/references/vendor-models.yaml"
SELECTION="$ROOT/skills/code4me/references/model-selection.yaml"
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

yaml_value() {
    awk -v section="$1" -v key="$2" '
        $0 == section ":" { active = 1; next }
        active && /^[^[:space:]#]/ { exit }
        active {
            k = $1
            sub(/:$/, "", k)
            if (k == key) { print $2; exit }
        }
    ' "$VENDORS"
}

expect() {
    local label="$1" got="$2" want="$3"
    if [ "$got" = "$want" ]; then ok "$label"; else bad "$label (got [$got], want [$want])"; fi
}

expect "anthropic low"      "$(yaml_value anthropic low)"      "claude-haiku-4-5"
expect "anthropic mid"      "$(yaml_value anthropic mid)"      "claude-sonnet-5"
expect "anthropic high"     "$(yaml_value anthropic high)"     "claude-opus-4-8"
expect "anthropic frontier" "$(yaml_value anthropic frontier)" "claude-fable-5"
expect "openai low"         "$(yaml_value openai low)"         "gpt-5.6-luna"
expect "openai mid"         "$(yaml_value openai mid)"         "gpt-5.6-terra"
expect "openai high"        "$(yaml_value openai high)"        "gpt-5.6-sol"
expect "deepseek low"       "$(yaml_value deepseek low)"       "deepseek-v4-flash"
expect "deepseek mid"       "$(yaml_value deepseek mid)"       "deepseek-v4-pro"
expect "deepseek high"      "$(yaml_value deepseek high)"      "deepseek-v4-pro"
expect "reasonix flash alias" "$(yaml_value reasonix_aliases deepseek-v4-flash)" "deepseek-flash"
expect "reasonix pro alias"   "$(yaml_value reasonix_aliases deepseek-v4-pro)"   "deepseek-pro"

if grep -Eq 'high_code|gpt-5\.3-codex|deepseek-v4-pro\[1m\]' "$VENDORS"; then
    bad "removed legacy model aliases"
else
    ok "removed legacy model aliases"
fi

for expected in \
    'effort_defaults:' \
    'explicit_backend_supported_only: [xhigh, max]' \
    'legacy_effort_fallback:' \
    'effort_source: legacy_tier_fallback'; do
    if grep -Fq "$expected" "$SELECTION"; then ok "selection has $expected"; else bad "selection missing $expected"; fi
done

for expected in \
    'reasonix_aliases' \
    'alias equal to the concrete model ID' \
    'reasonix_provider_alias_missing' \
    'reasonix_provider_model_mismatch'; do
    if grep -Fq "$expected" "$ROOT/skills/deepseek-bridge/SKILL.md"; then ok "deepseek bridge has $expected"; else bad "deepseek bridge missing $expected"; fi
done

printf '\nPASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
