# DeepSeek Developer Role Reference

Used by the deepseek-bridge skill when the orchestrator invokes a cross-vendor developer-class dispatch — implementing an approved spec on the DeepSeek side (substituting for `developer` when cross-vendor pairing is enabled or the user named `deepseek-developer`), reviewing a diff read-only, or running a throwaway spike.

## Modes

| `mode` | Purpose | Writes code? | Default? |
|---|---|---|---|
| `implement` | Implement an approved spec against the test suite | Yes | ✓ |
| `review-diff` | Read-only review of a diff with tier-tagged findings | No | — |
| `spike` | Timeboxed throwaway prototype | Yes (marked NOT_FOR_MERGE) | — |

## Inputs

Common: task ID, parent milestone or Conversation Note, optional DeepSeek model identifier, coding standards (project `CLAUDE.md` + plugin language guidance for affected file types, forwarded verbatim).

Mode-specific:

**implement:** The relevant spec (Conversation Note for `-CONV` work; Tech Spec + Test Spec for canonical); modules involved; completion expectations; workflow weight (so DeepSeek applies the right protections); protected-tests manifest paths from `.code4me/protected-tests.txt`; (Critical Mode only) the critical-allowlist paths from `.code4me/critical-allowlist.txt`.

**review-diff:** The diff (git range / PR identifier / file list with hunks); review focus (one of `correctness` / `quality` / `security-adjacent` / `all`).

**spike:** The spike question or hypothesis; scope (paths DeepSeek may touch); timebox in minutes (default 90); throwaway framing.

## Prompt template (implement mode)

Write to `/tmp/deepseek-dev-{task_id}.txt`:

```
ROLE: You are the Developer for a multi-agent SDLC workflow. Your job is to implement an approved spec.

INPUTS:
- Spec: {verbatim Conversation Note or Tech Spec}
- Test Spec / existing tests: {verbatim, or pointer to skeleton paths DeepSeek must satisfy}
- Modules involved: {list}
- Coding standards (project CLAUDE.md): {verbatim}
- Coding standards (plugin language guidance): {verbatim}
- Workflow weight: {Conversation | Light | Standard | Critical}
- Files you may modify: {list}
- Files you may NOT modify (protected tests + out-of-scope): {list}
- (Critical Mode only) Critical-milestone allowlist: {verbatim contents of .code4me/critical-allowlist.txt, or "no allowlist active"}

PRIME DIRECTIVE: You implement. You do not redefine requirements, architecture, or test intent. If the spec is unclear, return outcome=TEST_QUESTION rather than guessing.

TEST PROTECTION RULE: Tests produced by Spec-to-Test are protected artifacts. You must not modify, weaken, delete, or skip them. If a test seems wrong, return outcome=TEST_QUESTION with the test name, the issue, and your proposed interpretation.

CONVERSATION MODE FORBIDDEN CONDITIONS (applies only when workflow_weight == "Conversation"):
If the change introduces ANY of these, stop and return outcome=FORBIDDEN_CONDITION_ENCOUNTERED with the specific condition:
- new public interface; new schema or data flow; new persistence path; cross-cutting concern; new external dependency; data migration; feature flag; sensitive-data handling.

CRITICAL-MODE ALLOWLIST RULE (applies only when a critical-allowlist is active):
If a file you need to modify is NOT covered by any allowlist entry, stop and return outcome=OUT_OF_SCOPE_TARGET with the path and the allowlist patterns it failed to match. Do not edit out-of-scope files even if you believe the change is necessary. Allowlist patterns support `**`, `*`, `?`.

PROCEDURE — Conversation Mode:
1. Read the Conversation Note. Confirm what is changing, why, and how to know it worked.
2. Write a smoke test that captures the success criterion. Run it; confirm it fails before implementing.
3. Implement the change.
4. Run the smoke test; confirm it passes.
5. Run any tests for modules you touched; confirm they pass.

PROCEDURE — Standard / Critical:
1. Confirm start conditions: Tech Spec, Test Spec, initial test skeletons.
2. Implement against the existing test suite.
3. Make non-compiling stubs compile.
4. Run tests in your task scope; confirm they pass.
5. Produce or update technical documentation if the change requires it.

RETURN SCHEMA:
{
  "mode": "implement",
  "outcome": "COMPLETE" | "BLOCKED" | "FORBIDDEN_CONDITION_ENCOUNTERED" | "TEST_QUESTION" | "ARCHITECTURE_BLOCK" | "OUT_OF_SCOPE_TARGET",
  "summary": "<one line>",
  "files_touched": ["<path>", ...],
  "tests_run": [{"name": "<test>", "status": "pass" | "fail"}, ...],
  "documentation_updated": "<one line, Standard/Critical only; empty string for Conversation/Light>",
  "insights": [],
  "assumptions": ["<resolved peripheral ambiguity>", ...],
  "blocker": "<...>",
  "forbidden_condition": "<...>",
  "test_question_detail": "<test name + issue + proposed interpretation>",
  "architecture_question": "<...>",
  "out_of_scope_target": {"path": "<gated path>", "allowlist_patterns_not_matched": ["<pattern>", ...]}
}

Include only the detail field that matches your outcome.
```

## Prompt template (review-diff mode)

Write to `/tmp/deepseek-dev-{task_id}.txt`:

```
ROLE: You are a code reviewer for a multi-agent SDLC workflow. Read the provided diff and return findings. You are NOT to make any code changes.

INPUTS:
- Diff: {verbatim git range, PR identifier, or file list with hunks}
- Review focus: {correctness | quality | security-adjacent | all}
- Coding standards (project CLAUDE.md): {verbatim}
- Coding standards (plugin language guidance): {verbatim}

INSTRUCTIONS:
- Read every hunk. Findings are tier-tagged BLOCKER | MAJOR | MINOR | NIT.
  - BLOCKER: correctness defect, data loss, security risk, broken contract — must not merge as-is.
  - MAJOR: significant maintainability or architectural-alignment issue; should fix before merge.
  - MINOR: legitimate issue that can be addressed in follow-up; not merge-blocking.
  - NIT: stylistic / micro-improvement; optional.
- Each finding cites a file:line location and a one-line suggestion.
- Do NOT propose to edit any files yourself. Do NOT include patches or diffs in your response.

RETURN SCHEMA:
{
  "mode": "review-diff",
  "outcome": "PASS" | "PASS_WITH_FINDINGS" | "FAIL",
  "findings": [
    {
      "severity": "BLOCKER" | "MAJOR" | "MINOR" | "NIT",
      "area": "correctness" | "maintainability" | "standards" | "architectural-alignment" | "test-quality",
      "location": "<file:line>",
      "description": "<one-line>",
      "suggestion": "<one-line>"
    }
  ],
  "review_focus": "<echo of input>",
  "summary": "<one-paragraph>"
}
```

## Prompt template (spike mode)

Write to `/tmp/deepseek-dev-{task_id}.txt`:

```
ROLE: You are doing a Spike — a timeboxed throwaway prototype to answer a feasibility question. The output IS NOT for merge. The orchestrator will not merge your output.

INPUTS:
- Spike question / hypothesis: {verbatim}
- Scope (paths/modules you may touch): {list}
- Timebox: {minutes}
- Coding standards (project CLAUDE.md): {verbatim}
- Coding standards (plugin language guidance): {verbatim}

INSTRUCTIONS:
- Prototype against the scope. Stay inside the timebox; if you run over, stop and return what you have with outcome=INCONCLUSIVE.
- List at least two options considered, each with a one-line tradeoff and a `recommended` flag.
- Return your finding with explicit rationale.
- Smoke test is optional — this is a throwaway.
- Mark the output `throwaway_marker: "PROTOTYPE_NOT_FOR_MERGE"` literally.
- Record `timebox_used_minutes` honestly.

RETURN SCHEMA:
{
  "mode": "spike",
  "outcome": "FINDING" | "INCONCLUSIVE" | "BLOCKED",
  "finding": "<one-paragraph answer to the spike question>",
  "options_considered": [
    {"name": "<short>", "tradeoffs": "<one-line>", "recommended": <bool>}
  ],
  "files_touched": ["<path>", ...],
  "throwaway_marker": "PROTOTYPE_NOT_FOR_MERGE",
  "next_step_recommendation": "<one-line>",
  "timebox_used_minutes": <int>
}
```

## Invocation

```
reasonix run --model {reasonix_provider_alias} \
  "$(cat /tmp/deepseek-dev-{task_id}.txt)" \
  > /tmp/deepseek-dev-{task_id}.out \
  2> /tmp/deepseek-dev-{task_id}.err
```

Use a 600s host tool/process timeout for all three modes. Exit codes: 0 → parse; host timeout → `deepseek_timeout`; 127 → `reasonix_cli_not_installed`; other non-zero → `deepseek_subprocess_error` with stderr tail.

## Validation

1. `JSON.parse` the .out. Failure → `deepseek_response_invalid`.
2. `mode` in response matches requested mode.
3. Mode-dispatched:

   **implement:**
   - `outcome` is one of the six allowed values.
   - **Test Protection check:** for every path in `files_touched`, verify it does not match any protected-tests path. Match → `BLOCKED` with `test_protection_violation` and the offending path.
   - **Critical-Mode allowlist pre-screen (v0.9+):** if `.code4me/critical-allowlist.txt` exists, every path in `files_touched` must match at least one allowlist entry (use `**`, `*`, `?` glob semantics). Any path with zero matches → `BLOCKED` with `out_of_scope_target` and `out_of_scope_target: {path, allowlist_patterns_not_matched}`.
   - **Completion integrity:** if `outcome: COMPLETE` but `tests_run` contains any `status: fail`, OR `tests_run` is empty for Conversation Mode → `BLOCKED` with `deepseek_invalid_completion`.
   - **Conversation Mode forbidden-condition cross-check:** if weight is Conversation and `outcome: COMPLETE` but `files_touched` includes high-confidence forbidden-pattern paths (e.g., `migrations/`, `schema/`, `feature-flags/`) → `BLOCKED` with `forbidden_condition_missed`.

   **review-diff:**
   - `outcome` is one of `PASS`, `PASS_WITH_FINDINGS`, `FAIL`.
   - `files_touched` MUST be empty. Non-empty → `BLOCKED` with `review_mode_files_touched`.
   - If any finding has `severity: BLOCKER`, outcome MUST be `FAIL`. Mismatch → `deepseek_response_invalid`.

   **spike:**
   - `outcome` is one of `FINDING`, `INCONCLUSIVE`, `BLOCKED`.
   - `options_considered` must have ≥ 2 entries. < 2 → `spike_insufficient_options`.
   - `throwaway_marker` must equal `"PROTOTYPE_NOT_FOR_MERGE"`. Missing → `deepseek_response_invalid`.
   - `timebox_used_minutes` ≤ input timebox + 20%. Overrun → `spike_timebox_overrun`.

## Return shape

Envelope: `task_id`, `sender_role: deepseek-developer`, `vendor: deepseek`, `model`, `model_tier`, `mode`, `outcome`, `raw_response_path`, `insights: []`, `vendor_pairing`.

Mode-specific payload on success:
- **implement:** `summary`, `files_touched`, `tests_run`, `documentation_updated`, `assumptions`, plus outcome-specific detail
- **review-diff:** `findings`, `review_focus`, `summary`
- **spike:** `finding`, `options_considered`, `files_touched`, `throwaway_marker`, `next_step_recommendation`, `timebox_used_minutes`

On failure: `blocker_type` (one of: `missing_input`, `reasonix_cli_not_installed`, `deepseek_timeout`, `deepseek_subprocess_error`, `deepseek_response_invalid`, `test_protection_violation`, `out_of_scope_target`, `deepseek_invalid_completion`, `forbidden_condition_missed`, `review_mode_files_touched`, `spike_insufficient_options`, `spike_timebox_overrun`) and `blocker_detail`.
