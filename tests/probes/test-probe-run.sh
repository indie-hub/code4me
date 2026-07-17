#!/usr/bin/env bash

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
RUNNER="$ROOT/bin/code4me-probe-run"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

expect_contains() {
    local label="$1" file="$2" text="$3"
    if grep -Fq "$text" "$file"; then ok "$label"; else bad "$label"; fi
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

mkdir -p "$WORK/bin" "$WORK/evidence" "$WORK/held-out"
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -u
body=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-d" ]; then
        shift
        body="$1"
    fi
    shift
done
printf '%s' "$body" > "$CAPTURE_FILE"
verdict=${FAKE_VERDICT:-'{"outcome":"pass","coverage":{"expected":"complete","pass_criterion":"complete"},"criteria":[{"source":"expected","criterion":"expected contract","result":"match","reason":"matched"},{"source":"pass_criterion","criterion":"pass contract","result":"satisfied","reason":"satisfied"}],"kind":{"result":"not_applicable","reason":"not specified"},"weight":{"result":"not_applicable","reason":"not specified"},"team":{"result":"not_applicable","reason":"not specified"},"summary":"contract matched"}'}
jq -cn --arg text "$verdict" '{content:[{text:$text}]}'
EOF
chmod +x "$WORK/bin/curl"

run_probe() {
    local capture="$1" output="$2" probe="$3" verdict="${4:-}"
    printf 'candidate response\nEOF\n' | \
        PATH="$WORK/bin:$PATH" \
        CAPTURE_FILE="$capture" \
        FAKE_VERDICT="$verdict" \
        ANTHROPIC_API_KEY=test-key \
        bash "$RUNNER" --no-budget --output "$output" "$probe" \
        > "$WORK/run.log" 2>&1
}

printf '== full judge contract ==\n'
model_capture="$WORK/model-request.json"
model_output="$WORK/evidence/model.jsonl"
if run_probe "$model_capture" "$model_output" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md"; then
    ok "model-routing probe completed"
else
    bad "model-routing probe completed"
fi
jq -r '.messages[0].content' "$model_capture" > "$WORK/model-prompt.txt"
expect_contains "model Expected included" "$WORK/model-prompt.txt" \
    "both model profile and effort and records their defaults/deviation independently"
expect_contains "model Pass criterion included" "$WORK/model-prompt.txt" \
    'The dispatch contract includes `effort`, `default_effort`'
expect_contains "judge coverage schema included" "$WORK/model-prompt.txt" \
    '"coverage": {"expected": "complete", "pass_criterion": "complete"}'

improve_capture="$WORK/improve-request.json"
improve_output="$WORK/evidence/improve.jsonl"
if run_probe "$improve_capture" "$improve_output" \
    "$ROOT/probes/improve/01-supervised-improvement.md"; then
    ok "improve probe completed"
else
    bad "improve probe completed"
fi
jq -r '.messages[0].content' "$improve_capture" > "$WORK/improve-prompt.txt"
expect_contains "improve Expected included" "$WORK/improve-prompt.txt" \
    'creates a clean temporary worktree from exact `HEAD`'
expect_contains "improve Pass criterion included" "$WORK/improve-prompt.txt" \
    "No candidate edit occurs before explicit approval"

printf '== adversarial judge verdicts ==\n'
judge_fields='"kind":{"result":"not_applicable","reason":"not specified"},"weight":{"result":"not_applicable","reason":"not specified"},"team":{"result":"not_applicable","reason":"not specified"},"summary":"claimed outcome"'
coverage_complete='"coverage":{"expected":"complete","pass_criterion":"complete"}'
criteria_all_match='"criteria":[{"source":"expected","criterion":"expected requirement","result":"match","reason":"matched"},{"source":"pass_criterion","criterion":"pass requirement","result":"satisfied","reason":"satisfied"}]'
criteria_all_mismatch='"criteria":[{"source":"expected","criterion":"expected requirement","result":"mismatch","reason":"missing"},{"source":"pass_criterion","criterion":"pass requirement","result":"unsatisfied","reason":"missing"}]'
criteria_mixed='"criteria":[{"source":"expected","criterion":"expected requirement","result":"match","reason":"matched"},{"source":"pass_criterion","criterion":"pass requirement","result":"mismatch","reason":"missing"}]'

expect_judge_error() {
    local label="$1" slug="$2" verdict="$3" reason="$4"
    local output="$WORK/evidence/judge-${slug}.jsonl"
    if run_probe "$WORK/judge-${slug}-request.json" "$output" \
        "$ROOT/probes/model-routing/01-adaptive-model-effort.md" "$verdict"; then
        bad "$label"
    elif jq -e --arg reason "$reason" \
        '.outcome == "error" and .reason == $reason' "$output" >/dev/null; then
        ok "$label"
    else
        bad "$label"
    fi
}

empty_criteria="{\"outcome\":\"pass\",${coverage_complete},\"criteria\":[],${judge_fields}}"
expect_judge_error "pass with empty criteria is rejected as judge error" \
    empty "$empty_criteria" "judge response schema invalid"

omitted_source="{\"outcome\":\"pass\",${coverage_complete},\"criteria\":[{\"source\":\"expected\",\"criterion\":\"one\",\"result\":\"match\",\"reason\":\"matched\"}],${judge_fields}}"
expect_judge_error "criteria omitting pass_criterion source are rejected" \
    omitted-source "$omitted_source" "judge response schema invalid"

incomplete_coverage="{\"outcome\":\"pass\",\"coverage\":{\"expected\":\"complete\",\"pass_criterion\":\"incomplete\"},${criteria_all_match},${judge_fields}}"
expect_judge_error "incomplete coverage is rejected" \
    incomplete-coverage "$incomplete_coverage" "judge response schema invalid"

pass_mismatch="{\"outcome\":\"pass\",${coverage_complete},${criteria_mixed},${judge_fields}}"
expect_judge_error "pass with mismatch is rejected" \
    pass-mismatch "$pass_mismatch" "judge outcome inconsistent with criteria"

partial_all_match="{\"outcome\":\"partial\",${coverage_complete},${criteria_all_match},${judge_fields}}"
expect_judge_error "partial with all matches is rejected" \
    partial-all-match "$partial_all_match" "judge outcome inconsistent with criteria"

partial_all_mismatch="{\"outcome\":\"partial\",${coverage_complete},${criteria_all_mismatch},${judge_fields}}"
expect_judge_error "partial with all mismatches is rejected" \
    partial-all-mismatch "$partial_all_mismatch" "judge outcome inconsistent with criteria"

fail_all_match="{\"outcome\":\"fail\",${coverage_complete},${criteria_all_match},${judge_fields}}"
expect_judge_error "fail with all matches is rejected" \
    fail-all-match "$fail_all_match" "judge outcome inconsistent with criteria"

printf '== output path ==\n'
if [ -s "$model_output" ] && jq -e '.outcome == "pass"' "$model_output" >/dev/null; then
    ok "--output writes JSONL to requested path"
else
    bad "--output writes JSONL to requested path"
fi
if PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/unused.json" ANTHROPIC_API_KEY=test-key \
    bash "$RUNNER" --no-budget --output "$WORK/missing/result.jsonl" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    </dev/null > "$WORK/invalid-output.log" 2>&1; then
    bad "--output rejects missing parent"
else
    ok "--output rejects missing parent"
fi

existing_output="$WORK/evidence/existing.jsonl"
printf 'sentinel\n' > "$existing_output"
if run_probe "$WORK/existing-request.json" "$existing_output" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md"; then
    bad "--output rejects existing file"
elif [ "$(cat "$existing_output")" = "sentinel" ]; then
    ok "--output rejects existing file without overwriting"
else
    bad "--output rejects existing file without overwriting"
fi

output_target="$WORK/evidence/output-target.jsonl"
output_link="$WORK/evidence/output-link.jsonl"
printf 'target-sentinel\n' > "$output_target"
if ln -s "$output_target" "$output_link" 2>/dev/null; then
    if run_probe "$WORK/output-link-request.json" "$output_link" \
        "$ROOT/probes/model-routing/01-adaptive-model-effort.md"; then
        bad "--output rejects symbolic link"
    elif [ "$(cat "$output_target")" = "target-sentinel" ]; then
        ok "--output rejects symbolic link without following it"
    else
        bad "--output rejects symbolic link without following it"
    fi
else
    ok "--output symlink test skipped: platform disallows symlinks"
fi

printf '== held-out manifest ==\n'
held_out_probe="$WORK/held-out/model-routing.md"
cp "$ROOT/probes/model-routing/01-adaptive-model-effort.md" "$held_out_probe"
held_out_hash=$(sha256_file "$held_out_probe")
manifest="$WORK/held-out-manifest.json"
jq -n --arg path "$held_out_probe" --arg hash "$held_out_hash" \
    '{schema_version: 1, probes: [{path: $path, sha256: $hash}]}' > "$manifest"

if printf 'candidate response\nEOF\n' | \
    PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/held-out-request.json" \
    ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
    --manifest "$manifest" --output "$WORK/evidence/held-out.jsonl" \
    > "$WORK/held-out.log" 2>&1; then
    ok "verified external manifest runs through existing runner"
else
    bad "verified external manifest runs through existing runner"
fi

bad_manifest="$WORK/bad-manifest.json"
jq -n --arg path "$held_out_probe" \
    '{schema_version: 1, probes: [{path: $path, sha256: ("0" * 64)}]}' \
    > "$bad_manifest"
if PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/should-not-exist.json" \
    ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
    --manifest "$bad_manifest" --output "$WORK/evidence/bad.jsonl" \
    </dev/null > "$WORK/bad-manifest.log" 2>&1; then
    bad "hash mismatch blocks held-out run"
elif [ -e "$WORK/evidence/bad.jsonl" ]; then
    bad "hash mismatch blocks before output creation"
else
    ok "hash mismatch blocks before output creation"
fi

manifest_link="$WORK/manifest-link.json"
if ln -s "$ROOT/skills/code4me/schemas/held-out-manifest.schema.json" \
    "$manifest_link" 2>/dev/null; then
    if PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/manifest-link-request.json" \
        ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
        --manifest "$manifest_link" --output "$WORK/evidence/manifest-link.jsonl" \
        </dev/null > "$WORK/manifest-link.log" 2>&1; then
        bad "final manifest symlink is rejected"
    elif grep -Fq 'manifest must not be a symbolic link' "$WORK/manifest-link.log"; then
        ok "final manifest symlink is rejected"
    else
        bad "final manifest symlink is rejected"
    fi
else
    ok "manifest symlink test skipped: platform disallows symlinks"
fi

worktree_parent_link="$WORK/worktree-parent"
if ln -s "$ROOT" "$worktree_parent_link" 2>/dev/null; then
    through_parent_link="$worktree_parent_link/skills/code4me/schemas/held-out-manifest.schema.json"
    if PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/parent-link-request.json" \
        ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
        --manifest "$through_parent_link" --output "$WORK/evidence/parent-link.jsonl" \
        </dev/null > "$WORK/parent-link.log" 2>&1; then
        bad "manifest parent symlink cannot bypass worktree isolation"
    elif grep -Fq 'manifest must live outside the candidate worktree' \
        "$WORK/parent-link.log"; then
        ok "manifest parent symlink cannot bypass worktree isolation"
    else
        bad "manifest parent symlink cannot bypass worktree isolation"
    fi
else
    ok "manifest parent symlink test skipped: platform disallows symlinks"
fi

printf '\nPASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
