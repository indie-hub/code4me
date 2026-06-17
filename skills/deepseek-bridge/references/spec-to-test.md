# DeepSeek Spec-to-Test Role Reference

Used by the deepseek-bridge skill when the orchestrator invokes a cross-vendor Spec-to-Test dispatch — substituting for `spec-to-test` so the test author is on the opposite vendor from the planned implementer (test author ≠ implementer pairing), or for a read-only soundness pass on an existing Test Spec.

## Modes

| `mode` | Purpose | Writes test files? | Writes manifest? | Default? |
|---|---|---|---|---|
| `generate` | Produce Test Spec + initial test files from a Tech Spec | Yes | Yes | ✓ |
| `review-test-spec` | Read-only soundness pass on an existing Test Spec | No | No | — |

## Inputs

Common: task ID, parent milestone, Tech Spec (`approved: true` from both architects), acceptance criteria, coding/testing standards, optional DeepSeek model identifier.

Mode-specific:

**generate:** Paired implementation task ID (`{task_id}-DEV`); test directory conventions + test-runner framework; existing test patterns (canonical example file); optional prior protected-test paths to merge.

**review-test-spec:** The existing Test Spec artifact.

## Prompt template (generate mode)

Write to `/tmp/deepseek-s2t-{task_id}.txt`:

```
ROLE: You are the Spec-to-Test Engineer for a multi-agent SDLC workflow. Your job is to translate an approved Tech Spec into concrete pre-implementation test assets: a Test Spec, initial test files (failing tests or non-compiling stubs), and a test case mapping traceable to acceptance criteria. You are NOT to invent product behaviour, redesign architecture, or expand coverage beyond the gate.

INPUTS:
- Milestone Spec: {verbatim}
- Tech Spec (approved by both architects): {verbatim}
- Acceptance Criteria (numbered): {verbatim}
- Paired implementation task ID: {{task_id}-DEV}
- Test directory conventions: {verbatim — path layout, runner framework, naming rules}
- Existing test patterns (canonical example): {verbatim file content or excerpt}
- Coding / testing standards (project CLAUDE.md): {verbatim}
- Plugin language guidance: {verbatim}

GATE SCOPE RULE (non-negotiable):
- ONE primary happy-path test per acceptance criterion by default.
- A boundary, invalid-input, or failure test ONLY when the AC explicitly names that behaviour.
- Defer broader boundary, fuzzing, and runtime-risk coverage to QA.
- A Test Spec with 5 ACs should have ~5-7 test cases, not 12-15.

GIVEN / WHEN / THEN DISCIPLINE:
- Every test function name follows test_given_<ctx>_when_<action>_then_<outcome> (or language-appropriate equivalent).
- The Test Case Mapping table is the canonical G/W/T record.
- Do NOT triplicate G/W/T (table + name + docstring).

TEST SKELETON RULES:
- Compilable failing tests when interfaces / types already exist.
- Non-compiling stubs when the Tech Spec introduces new types — note explicitly.
- No vague placeholder tests like "// test something".

AMBIGUITY HANDLING:
- Design / testability ambiguity → outcome=NEEDS_DESIGN_CLARIFICATION with proposed interpretation X and alternative Y.
- Product behaviour ambiguity → outcome=NEEDS_PRODUCT_CLARIFICATION with proposed interpretation X and alternative Y.

RETURN SCHEMA:
{
  "mode": "generate",
  "outcome": "COMPLETE" | "BLOCKED" | "NEEDS_DESIGN_CLARIFICATION" | "NEEDS_PRODUCT_CLARIFICATION" | "TESTABILITY_CONCERN",
  "summary": "<one-line>",
  "test_spec_content": "<full Test Spec markdown — to be written to .code4me/test-specs/{task_id}-testspec.md>",
  "test_files": [
    {"path": "<project-relative path>", "content": "<full file content>", "compilable": <bool>}
  ],
  "test_case_mapping": [
    {
      "ac_id": "<AC number or label>",
      "test_function": "<test function name>",
      "given": "<one-line>", "when": "<one-line>", "then": "<one-line>",
      "kind": "happy-path" | "failure-path",
      "ac_names_failure": <bool>
    }
  ],
  "behaviours_covered": ["<one entry per AC>"],
  "deferred_to_qa": ["<behaviour deferred and why>"],
  "stubs_non_compiling": <bool>,
  "ambiguities_flagged": [
    {"kind": "design" | "product" | "testability", "description": "<one-line>", "proposed_interpretation": "<one-line>", "alternative": "<one-line>"}
  ]
}
```

## Prompt template (review-test-spec mode)

Write to `/tmp/deepseek-s2t-{task_id}.txt`:

```
ROLE: You are reviewing a Test Spec for soundness. You are NOT to author new tests or amendments. Return either approval or a list of amendment requests.

INPUTS:
- Tech Spec: {verbatim}
- Test Spec (existing): {verbatim}
- Acceptance Criteria (numbered): {verbatim}

For each of the following, mark "sound" or "needs amendment with rationale":
- AC traceability (every AC has at least one happy-path test mapped)
- Gate Scope Rule respected (no over-coverage)
- Given / When / Then discipline
- Test naming clarity
- Stub markings honest

Return approved=true only if all five are sound.

RETURN SCHEMA:
{
  "mode": "review-test-spec",
  "approved": <bool>,
  "spec_review": {
    "ac_traceability": "sound" | "<amendment with rationale>",
    "gate_scope": "sound" | "<amendment>",
    "given_when_then": "sound" | "<amendment>",
    "naming_clarity": "sound" | "<amendment>",
    "stub_honesty": "sound" | "<amendment>"
  },
  "amendments_required": [{"target": "<test-spec:section>", "change": "<one-line>", "rationale": "<one-line>"}],
  "summary": "<one-paragraph>"
}
```

## Invocation

```
timeout 300 reasonix run \
  --model {resolved_model} \
  --effort {resolved_effort} \
  --transcript /tmp/deepseek-s2t-{task_id}.transcript.jsonl \
  "$(cat /tmp/deepseek-s2t-{task_id}.txt)" \
  > /tmp/deepseek-s2t-{task_id}.out \
  2> /tmp/deepseek-s2t-{task_id}.err
```

360s — generation needs more headroom than review. Exit codes: 0 → parse; 124 → `deepseek_timeout`; 127 → `reasonix_cli_not_installed`; other → `deepseek_subprocess_error`.

## Validation + post-processing

1. `JSON.parse`; mode match.
2. **generate:**
   - `outcome` is one of the five allowed values.
   - **Gate Scope check:** for every `kind: failure-path` entry in `test_case_mapping`, `ac_names_failure` must be true. Any failure test where `ac_names_failure: false` → `gate_scope_violation`.
   - **G/W/T naming check:** every entry's `test_function` name must follow the language-appropriate G/W/T pattern. Lacking G/W/T → `gwt_naming_violation`.
   - **Coverage check:** every AC in input must have ≥ 1 entry in `test_case_mapping`. Unmapped ACs → `ac_coverage_missing`.
   - **Per-AC count guard:** total mapping entries ÷ AC count ≤ 2.0. Ratio > 2.0 → `gate_scope_overcoverage`.
   - **Post-processing — write the files:**
     - For each entry in `test_files`, write the content to the declared path (Write tool). Failure → `test_file_write_failure`.
     - Write `test_spec_content` to `.code4me/test-specs/{task_id}-testspec.md`. Failure → `test_spec_write_failure`.
     - **Write the protected-tests manifest:** assemble `.code4me/protected-tests.txt` containing every path in `test_files` plus any prior protected paths supplied. Overwrite (not append).
3. **review-test-spec:**
   - `approved` bool; `spec_review` has all five keys.
   - If `approved: false`, `amendments_required` non-empty.

## Return shape

Envelope: `task_id`, `sender_role: deepseek-spec-to-test`, `vendor: deepseek`, `model`, `model_tier`, `mode`, `outcome`, `summary`, `artifact_refs`, `files_touched`, `raw_response_path`, `insights: []`, `vendor_pairing`.

Mode-specific payload on success:
- **generate:** `paired_implementation_task_id`, `test_case_count`, `test_case_mapping_path`, `behaviours_covered`, `stubs_non_compiling`, `deferred_to_qa`, `protected_tests_manifest_path: .code4me/protected-tests.txt`
- **review-test-spec:** `approved`, `spec_review`, `amendments_required`

On failure: `blocker_type` (one of: `missing_input`, `reasonix_cli_not_installed`, `deepseek_timeout`, `deepseek_subprocess_error`, `deepseek_response_invalid`, `gate_scope_violation`, `gate_scope_overcoverage`, `gwt_naming_violation`, `ac_coverage_missing`, `test_file_write_failure`, `test_spec_write_failure`) and `blocker_detail`.
