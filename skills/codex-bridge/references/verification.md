# Codex Verification Role Reference

Used by the codex-bridge skill when the orchestrator invokes a cross-vendor verification dispatch — substituting for `verification` so the verifier is on the opposite vendor from the implementer (completing the alternation chain on Critical milestones). Read-only via Codex's own shell access; the bridge does not invoke the test runner directly.

## Modes

| `mode` | Purpose | Runs the test suite? | Default? |
|---|---|---|---|
| `suite-run` | Full verification: run tests + AC coverage + test integrity | Yes (via Codex's shell) | ✓ |
| `ac-coverage` | Read-only AC traceability against Tech Spec + diff | No | — |

## Inputs

Common: task ID, parent milestone, Milestone Spec excerpt, Tech Spec, Test Spec, acceptance criteria (numbered), implementation diff or files-touched list, coding standards, optional Codex model identifier.

Mode-specific:

**suite-run:** Test command (e.g., `make test`, `pytest`, `npm test`, `go test ./...`); protected-tests manifest paths from `.code4me/protected-tests.txt` or directly supplied; optional Developer completion summary.

**ac-coverage:** No additional inputs.

## Prompt template (suite-run mode)

Write to `/tmp/codex-ver-{task_id}.txt`:

```
ROLE: You are the Verification Engineer for a multi-agent SDLC workflow. Your job is to verify the implementation against the approved Tech Spec, the Test Spec, and the acceptance criteria — and to confirm the full test suite is green. You are NOT to write code, modify tests, or fix failing tests.

INPUTS:
- Test command: {verbatim — single shell command to run the full suite}
- Milestone Spec (excerpt): {verbatim}
- Tech Spec: {verbatim}
- Test Spec: {verbatim}
- Acceptance Criteria (numbered list): {verbatim}
- Implementation diff / files touched: {verbatim}
- Protected-tests manifest paths: {verbatim list}
- Developer completion summary (if available): {verbatim}
- Coding standards (project CLAUDE.md): {verbatim}

PROCEDURE:
1. Read the Tech Spec and AC list.
2. Read the implementation diff.
3. Run the test command via shell. Capture stdout, stderr, exit code.
4. Parse test results: passed / failed / skipped counts; failing test names.
5. Check protected-tests integrity: for each path in the manifest, confirm the file exists, has not been deleted, and assertions have not been weakened. Note findings.
6. Map each AC to evidence: PASS / PARTIAL / FAIL / NOT_VERIFIED.
7. Compute outcome:
   - FAIL: any test failed anywhere in repo OR any AC FAIL OR integrity violated OR implementation contradicts spec.
   - PASS_WITH_FIXES: tests green AND all ACs ≥ PARTIAL, minor gaps remain.
   - PASS: tests green, all ACs PASS, no integrity issues.
   - BLOCKED: cannot execute the test command.

TEST SUITE RULE: You are the designated owner of full-suite confirmation. A red test ANYWHERE → FAIL.

TEST INTEGRITY RULE: Any of removed/commented-out/weakened/expected-value-changed/skip-added/unauthorised-new → FAIL.

RETURN SCHEMA:
{
  "mode": "suite-run",
  "outcome": "PASS" | "PASS_WITH_FIXES" | "FAIL" | "BLOCKED",
  "summary": "<one-line>",
  "test_suite_status": "GREEN" | "RED",
  "test_runner_exit_code": <int>,
  "tests_passed": <int>, "tests_failed": <int>, "tests_skipped": <int>,
  "failing_tests": ["<test name>", ...],
  "ac_coverage_table": [
    {
      "ac_id": "<AC ID>",
      "requirement_summary": "<one-line>",
      "evidence": "<reference: test name, file:line, or 'no evidence'>",
      "status": "PASS" | "PARTIAL" | "FAIL" | "NOT_VERIFIED",
      "notes": "<one-line, optional>"
    }
  ],
  "ac_coverage_summary": {"pass": <int>, "partial": <int>, "fail": <int>, "not_verified": <int>},
  "missing_or_partial_items": [{"item": "<spec reference>", "location": "<where>", "issue": "<one-line>"}],
  "test_integrity_findings": [
    {"test_path": "<path>", "issue": "removed" | "weakened" | "expected_value_changed" | "skip_added" | "new_unauthorised", "detail": "<one-line>"}
  ],
  "qa_optional_veto": <bool>, "qa_optional_veto_rationale": "<one-line, if true>",
  "rework_required": <bool>,
  "test_runner_output_excerpt": "<last 50 lines of output, only when test_suite_status is RED>"
}
```

## Prompt template (ac-coverage mode)

Write to `/tmp/codex-ver-{task_id}.txt`:

```
ROLE: You are the Verification Engineer for a multi-agent SDLC workflow, running an AC-coverage-only pass. You are NOT to run the test suite. You are NOT to write code. Return per-AC evidence and status.

INPUTS:
- Milestone Spec (excerpt): {verbatim}
- Tech Spec: {verbatim}
- Test Spec: {verbatim}
- Acceptance Criteria (numbered list): {verbatim}
- Implementation diff / files touched: {verbatim}
- Coding standards (project CLAUDE.md): {verbatim}

PROCEDURE:
1. For each AC, locate evidence in (a) Test Spec's mapping, (b) diff (specific function or line implementing it), or (c) explicit documentation.
2. Assess status: PASS / PARTIAL / FAIL / NOT_VERIFIED.
3. Be concrete. Vague evidence → NOT_VERIFIED. Required: test name, file:line, or explicit documentation reference.

OUTCOME:
- PASS: every AC is PASS.
- PASS_WITH_FIXES: at least one PARTIAL; none FAIL.
- FAIL: at least one FAIL or NOT_VERIFIED.
- BLOCKED: required input missing.

RETURN SCHEMA:
{
  "mode": "ac-coverage",
  "outcome": "PASS" | "PASS_WITH_FIXES" | "FAIL" | "BLOCKED",
  "summary": "<one-line>",
  "ac_coverage_table": [
    {
      "ac_id": "<AC ID>",
      "requirement_summary": "<one-line>",
      "evidence": "<reference>",
      "status": "PASS" | "PARTIAL" | "FAIL" | "NOT_VERIFIED",
      "notes": "<one-line, optional>"
    }
  ],
  "ac_coverage_summary": {"pass": <int>, "partial": <int>, "fail": <int>, "not_verified": <int>},
  "rework_required": <bool>
}
```

## Invocation

```
timeout 360 codex exec --model {resolved_model} --prompt-file /tmp/codex-ver-{task_id}.txt \
  > /tmp/codex-ver-{task_id}.out 2> /tmp/codex-ver-{task_id}.err
```

360s for `suite-run` (includes Codex running the test suite — raise to 600s if your suite is slow). 240s sufficient for `ac-coverage`. Exit codes: standard mapping.

## Validation

1. `JSON.parse`; mode match.
2. Read-only: `files_touched` non-empty → `review_mode_files_touched`.
3. **Both modes (common):**
   - `outcome` is one of the four allowed values.
   - `ac_coverage_table` has one entry per AC in input. Missing → `ac_coverage_incomplete` with the missing AC IDs.
   - `ac_coverage_summary` counts match the table. Mismatch → `ac_coverage_count_mismatch`.
4. **suite-run specific:**
   - `test_suite_status` is `GREEN` or `RED`.
   - **Outcome / suite-status consistency:** RED → outcome MUST be `FAIL`. Mismatch → `suite_status_outcome_mismatch`.
   - **Failing-test list integrity:** RED → `failing_tests` non-empty.
   - **Tests-passed / tests-failed consistency:** `tests_failed > 0` → status MUST be RED.
   - **Test-integrity findings:** non-empty → outcome MUST be `FAIL`. Mismatch → `test_integrity_outcome_mismatch`.
   - **Rework-required:** `outcome: FAIL` → `rework_required: true`.
5. **ac-coverage specific:**
   - Outcome derives from AC table only. Inconsistency → `ac_outcome_mismatch`.

## Return shape

Envelope: `task_id`, `sender_role: codex-verification`, `vendor: openai`, `model`, `model_tier`, `mode`, `outcome`, `summary`, `artifact_refs`, `files_touched: []`, `raw_response_path`, `insights: []`, `vendor_pairing`.

Mode-specific payload on success:
- **suite-run:** `test_suite_status`, `test_runner_exit_code`, `tests_passed`, `tests_failed`, `tests_skipped`, `failing_tests`, `ac_coverage_table`, `ac_coverage_summary`, `missing_or_partial_items`, `test_integrity_findings`, `qa_optional_veto`, `qa_optional_veto_rationale`, `rework_required`, `test_runner_output_excerpt`
- **ac-coverage:** `ac_coverage_table`, `ac_coverage_summary`, `rework_required`

On failure: `blocker_type` (one of: `missing_input`, `codex_cli_not_installed`, `codex_timeout`, `codex_error`, `codex_response_invalid`, `review_mode_files_touched`, `suite_status_outcome_mismatch`, `ac_coverage_incomplete`, `ac_coverage_count_mismatch`, `ac_outcome_mismatch`, `test_integrity_outcome_mismatch`) and `blocker_detail`.
