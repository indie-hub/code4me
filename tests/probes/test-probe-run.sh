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

bad_with_log() {
    local label="$1" log="$2"
    bad "$label"
    if [ -r "$log" ]; then
        printf '%s\n' "--- captured log: $log ---" >&2
        cat "$log" >&2
        printf '%s\n' '--- end captured log ---' >&2
    fi
}

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
cat > "$WORK/bin/claude-p" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$@" > "$CAPTURE_FILE"
cwd=""
tools="__unset__"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --cwd) shift; cwd="$1" ;;
        --tools) shift; tools="$1" ;;
    esac
    shift
done
entries=$(find "$cwd" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
printf 'cwd=%s\ntools=%s\nentries=%s\n' "$cwd" "$tools" "$entries" > "$CAPTURE_STATE_FILE"
jq -cn --arg result "$FAKE_VERDICT" '{type:"result", result:$result}'
EOF
chmod +x "$WORK/bin/claude-p"
cat > "$WORK/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -u
entries=$(find "$PWD" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
printf 'cwd=%s\nentries=%s\n' "$PWD" "$entries" > "$CAPTURE_STATE_FILE"
printf '%s\n' "$@" > "$CAPTURE_FILE"
cat > "$CAPTURE_PROMPT_FILE"
printf '%s\n' "$FAKE_VERDICT"
EOF
chmod +x "$WORK/bin/codex"
cat > "$WORK/bin/reasonix" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "doctor" ]; then
    printf '%s\n' '{"providers":[{"name":"deepseek-pro","model":"deepseek-v4-pro"},{"name":"custom-provider","model":"custom-model"}]}'
    exit 0
fi
printf '%s\n' "$@" > "$CAPTURE_FILE"
dir=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-dir" ]; then shift; dir="$1"; break; fi
    shift
done
entries=$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
printf 'dir=%s\nentries=%s\n' "$dir" "$entries" > "$CAPTURE_STATE_FILE"
if [ "${REASONIX_RAW:-0}" = "1" ]; then
    printf '%s\n' "$FAKE_VERDICT"
else
    printf 'Reasonix result follows.\n```json\n%s\n```\n' "$FAKE_VERDICT"
fi
EOF
chmod +x "$WORK/bin/reasonix"
cat > "$WORK/bin/cygpath" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" != "-u" ] || [ "$#" -ne 2 ]; then
    exit 2
fi
case "$2" in
    C:/held-out/model-routing.md) printf '%s\n' "$CYGPATH_PROBE_PATH" ;;
    *) printf '%s\n' "$2" ;;
esac
EOF
chmod +x "$WORK/bin/cygpath"

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

printf '== judge backends ==\n'
valid_verdict=$(jq -c 'del(.probe, .judge)' "$model_output")

claude_output="$WORK/evidence/claude-p.jsonl"
if printf 'candidate response\nEOF\n' | \
    PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/claude-p.args" \
    CAPTURE_STATE_FILE="$WORK/claude-p.state" \
    FAKE_VERDICT="$valid_verdict" bash "$RUNNER" --no-budget \
    --judge-backend=claude-p --judge-effort=high \
    --output "$claude_output" "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    > "$WORK/claude-p.log" 2>&1; then
    ok "claude-p judge completes"
else
    bad_with_log "claude-p judge completes" "$WORK/claude-p.log"
fi
if jq -e '.judge == {backend:"claude-p", provider:null, model:"claude-sonnet-5", effort:"high"}' \
    "$claude_output" >/dev/null && \
    grep -Fxq -- '--model' "$WORK/claude-p.args" && \
    grep -Fxq -- '--effort' "$WORK/claude-p.args" && \
    grep -Fxq 'tools=' "$WORK/claude-p.state" && \
    grep -Fxq 'entries=0' "$WORK/claude-p.state"; then
    ok "claude-p isolated cwd, empty tools, defaults, and metadata"
else
    bad "claude-p isolated cwd, empty tools, defaults, and metadata"
fi

codex_output="$WORK/evidence/codex.jsonl"
if printf 'candidate response\nEOF\n' | \
    PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/codex.args" \
    CAPTURE_PROMPT_FILE="$WORK/codex.prompt" CAPTURE_STATE_FILE="$WORK/codex.state" \
    FAKE_VERDICT="$valid_verdict" \
    bash "$RUNNER" --no-budget --judge-backend=codex --judge-effort=xhigh \
    --output "$codex_output" "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    > "$WORK/codex.log" 2>&1; then
    ok "codex judge completes"
else
    bad_with_log "codex judge completes" "$WORK/codex.log"
fi
if jq -e '.judge == {backend:"codex", provider:null, model:"gpt-5.6-terra", effort:"xhigh"}' \
    "$codex_output" >/dev/null && \
    grep -Fxq 'model_reasoning_effort="xhigh"' "$WORK/codex.args" && \
    grep -Fxq -- '--sandbox' "$WORK/codex.args" && \
    grep -Fxq 'read-only' "$WORK/codex.args" && \
    grep -Fxq -- '--skip-git-repo-check' "$WORK/codex.args" && \
    grep -Fxq 'entries=0' "$WORK/codex.state" && \
    grep -Fq 'Return a single JSON object' "$WORK/codex.prompt"; then
    ok "codex isolated read-only stdin, defaults, and metadata"
else
    bad "codex isolated read-only stdin, defaults, and metadata"
fi

reasonix_output="$WORK/evidence/reasonix.jsonl"
if printf 'candidate response\nEOF\n' | \
    PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/reasonix.args" \
    CAPTURE_STATE_FILE="$WORK/reasonix.state" FAKE_VERDICT="$valid_verdict" \
    bash "$RUNNER" --no-budget \
    --judge-backend=reasonix --output "$reasonix_output" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    > "$WORK/reasonix.log" 2>&1; then
    ok "reasonix fenced judge output completes"
else
    bad_with_log "reasonix fenced judge output completes" "$WORK/reasonix.log"
fi
if jq -e '.judge == {backend:"reasonix", provider:"deepseek-pro", model:"deepseek-v4-pro", effort:null}' \
    "$reasonix_output" >/dev/null && \
    grep -Fxq -- '-dir' "$WORK/reasonix.args" && \
    grep -Fxq 'deepseek-pro' "$WORK/reasonix.args" && \
    grep -Fxq 'entries=0' "$WORK/reasonix.state"; then
    ok "reasonix isolated fenced output, provider identity, and metadata"
else
    bad "reasonix isolated fenced output, provider identity, and metadata"
fi

reasonix_raw_output="$WORK/evidence/reasonix-raw.jsonl"
if printf 'candidate response\nEOF\n' | \
    PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/reasonix-raw.args" \
    CAPTURE_STATE_FILE="$WORK/reasonix-raw.state" REASONIX_RAW=1 \
    FAKE_VERDICT="$valid_verdict" bash "$RUNNER" --no-budget \
    --judge-backend=reasonix --output "$reasonix_raw_output" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    > "$WORK/reasonix-raw.log" 2>&1 && \
    jq -e '.outcome == "pass"' "$reasonix_raw_output" >/dev/null; then
    ok "reasonix raw JSON judge output completes"
else
    bad_with_log "reasonix raw JSON judge output completes" "$WORK/reasonix-raw.log"
fi

if PATH="$WORK/bin:$PATH" bash "$RUNNER" --no-budget \
    --judge-backend=reasonix --judge-provider=deepseek-pro --judge-model=wrong-model \
    --output "$WORK/evidence/reasonix-mismatch.jsonl" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    </dev/null > "$WORK/reasonix-mismatch.log" 2>&1; then
    bad "reasonix provider/model mismatch is rejected"
elif grep -Fq 'reasonix provider deepseek-pro must resolve to model wrong-model' \
    "$WORK/reasonix-mismatch.log"; then
    ok "reasonix provider/model mismatch is rejected"
else
    bad_with_log "reasonix provider/model mismatch is rejected" "$WORK/reasonix-mismatch.log"
fi

if PATH="$WORK/bin:$PATH" bash "$RUNNER" --no-budget \
    --judge-backend=codex --judge-provider=deepseek-pro \
    --output "$WORK/evidence/codex-provider.jsonl" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    </dev/null > "$WORK/codex-provider.log" 2>&1; then
    bad "judge provider is rejected outside reasonix"
elif grep -Fq -- '--judge-provider is supported only by reasonix' \
    "$WORK/codex-provider.log"; then
    ok "judge provider is rejected outside reasonix"
else
    bad_with_log "judge provider is rejected outside reasonix" "$WORK/codex-provider.log"
fi

rm -f "$WORK/claude-p-fallback.args"
if PATH="$WORK/bin:$PATH" CODE4ME_CODEX_BIN=missing-codex \
    CAPTURE_FILE="$WORK/claude-p-fallback.args" ANTHROPIC_API_KEY=test-key \
    bash "$RUNNER" --no-budget --judge-backend=codex \
    --output "$WORK/evidence/no-fallback.jsonl" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    </dev/null > "$WORK/no-fallback.log" 2>&1; then
    bad "missing codex fails without fallback"
elif grep -Fq 'codex is required for judge backend codex' "$WORK/no-fallback.log" && \
    [ ! -e "$WORK/claude-p-fallback.args" ]; then
    ok "missing codex fails without fallback"
else
    bad_with_log "missing codex fails without fallback" "$WORK/no-fallback.log"
fi

if PATH="$WORK/bin:$PATH" bash "$RUNNER" --no-budget \
    --judge-backend=reasonix --judge-effort=high \
    --output "$WORK/evidence/reasonix-effort.jsonl" \
    "$ROOT/probes/model-routing/01-adaptive-model-effort.md" \
    </dev/null > "$WORK/reasonix-effort.log" 2>&1; then
    bad "unsupported reasonix effort is rejected"
elif grep -Fq -- '--judge-effort is not supported by reasonix' \
    "$WORK/reasonix-effort.log"; then
    ok "unsupported reasonix effort is rejected"
else
    bad_with_log "unsupported reasonix effort is rejected" "$WORK/reasonix-effort.log"
fi

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
if ln -s "$output_target" "$output_link" 2>/dev/null && [ -L "$output_link" ]; then
    if run_probe "$WORK/output-link-request.json" "$output_link" \
        "$ROOT/probes/model-routing/01-adaptive-model-effort.md"; then
        bad "--output rejects symbolic link"
    elif [ "$(cat "$output_target")" = "target-sentinel" ]; then
        ok "--output rejects symbolic link without following it"
    else
        bad "--output rejects symbolic link without following it"
    fi
else
    rm -rf "$output_link"
    ok "--output symlink test skipped: platform disallows symlinks"
fi

printf '== held-out manifest ==\n'
held_out_probe="$WORK/held-out/model-routing.md"
cp "$ROOT/probes/model-routing/01-adaptive-model-effort.md" "$held_out_probe"
held_out_hash=$(sha256_file "$held_out_probe")
manifest="$WORK/held-out-manifest.json"
MSYS2_ARG_CONV_EXCL='*' jq -n --arg path "$held_out_probe" --arg hash "$held_out_hash" \
    '{schema_version: 1, probes: [{path: $path, sha256: $hash}]}' > "$manifest"

if printf 'candidate response\nEOF\n' | \
    PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/held-out-request.json" \
    ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
    --manifest "$manifest" --output "$WORK/evidence/held-out.jsonl" \
    > "$WORK/held-out.log" 2>&1; then
    ok "verified external manifest runs through existing runner"
else
    bad_with_log "verified external manifest runs through existing runner" \
        "$WORK/held-out.log"
fi

drive_manifest="$WORK/drive-held-out-manifest.json"
export CYGPATH_PROBE_PATH="$held_out_probe"
MSYS2_ARG_CONV_EXCL='*' jq -n --arg path 'C:/held-out/model-routing.md' \
    --arg hash "$held_out_hash" \
    '{schema_version: 1, probes: [{path: $path, sha256: $hash}]}' \
    > "$drive_manifest"
if printf 'candidate response\nEOF\n' | \
    PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/drive-held-out-request.json" \
    ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
    --manifest "$drive_manifest" --output "$WORK/evidence/drive-held-out.jsonl" \
    > "$WORK/drive-held-out.log" 2>&1; then
    ok "drive-letter manifest probe path normalizes through cygpath"
else
    bad_with_log "drive-letter manifest probe path normalizes through cygpath" \
        "$WORK/drive-held-out.log"
fi
unset CYGPATH_PROBE_PATH

bad_manifest="$WORK/bad-manifest.json"
MSYS2_ARG_CONV_EXCL='*' jq -n --arg path "$held_out_probe" \
    '{schema_version: 1, probes: [{path: $path, sha256: ("0" * 64)}]}' \
    > "$bad_manifest"
if PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/should-not-exist.json" \
    ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
    --manifest "$bad_manifest" --output "$WORK/evidence/bad.jsonl" \
    </dev/null > "$WORK/bad-manifest.log" 2>&1; then
    bad_with_log "hash mismatch blocks held-out run" "$WORK/bad-manifest.log"
elif [ -e "$WORK/evidence/bad.jsonl" ]; then
    bad_with_log "hash mismatch blocks before output creation" \
        "$WORK/bad-manifest.log"
else
    ok "hash mismatch blocks before output creation"
fi

manifest_link="$WORK/manifest-link.json"
if ln -s "$ROOT/skills/code4me/schemas/held-out-manifest.schema.json" \
    "$manifest_link" 2>/dev/null && [ -L "$manifest_link" ]; then
    if PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/manifest-link-request.json" \
        ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
        --manifest "$manifest_link" --output "$WORK/evidence/manifest-link.jsonl" \
        </dev/null > "$WORK/manifest-link.log" 2>&1; then
        bad_with_log "final manifest symlink is rejected" \
            "$WORK/manifest-link.log"
    elif grep -Fq 'manifest must not be a symbolic link' "$WORK/manifest-link.log"; then
        ok "final manifest symlink is rejected"
    else
        bad_with_log "final manifest symlink is rejected" \
            "$WORK/manifest-link.log"
    fi
else
    rm -rf "$manifest_link"
    ok "manifest symlink test skipped: platform disallows symlinks"
fi

worktree_parent_link="$WORK/worktree-parent"
if ln -s "$ROOT" "$worktree_parent_link" 2>/dev/null && \
    [ -L "$worktree_parent_link" ]; then
    through_parent_link="$worktree_parent_link/skills/code4me/schemas/held-out-manifest.schema.json"
    if PATH="$WORK/bin:$PATH" CAPTURE_FILE="$WORK/parent-link-request.json" \
        ANTHROPIC_API_KEY=test-key bash "$RUNNER" --no-budget \
        --manifest "$through_parent_link" --output "$WORK/evidence/parent-link.jsonl" \
        </dev/null > "$WORK/parent-link.log" 2>&1; then
        bad_with_log "manifest parent symlink cannot bypass worktree isolation" \
            "$WORK/parent-link.log"
    elif grep -Fq 'manifest must live outside the candidate worktree' \
        "$WORK/parent-link.log"; then
        ok "manifest parent symlink cannot bypass worktree isolation"
    else
        bad_with_log "manifest parent symlink cannot bypass worktree isolation" \
            "$WORK/parent-link.log"
    fi
else
    rm -rf "$worktree_parent_link"
    ok "manifest parent symlink test skipped: platform disallows symlinks"
fi

printf '\nPASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
