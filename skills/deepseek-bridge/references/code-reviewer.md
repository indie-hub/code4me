# DeepSeek Code Reviewer Role Reference

Used by the deepseek-bridge skill when the orchestrator invokes a cross-vendor quality-only code-review dispatch — substituting for `code-reviewer` when cross-vendor pairing is enabled or the user named `deepseek-code-reviewer` explicitly. Read-only; no file edits.

## Modes

| `mode` | Purpose | Default? |
|---|---|---|
| `review-diff` | Quality review of a diff; tier-tagged findings; standard outcome | ✓ |
| `review-files` | Broader review across an explicit file list | — |
| `review-spec-fit` | Spec-implementation drift focused; flags where the diff diverges from the Tech Spec | — |

## Inputs

Common: task ID, parent milestone, coding standards (project CLAUDE.md + plugin language guidance), optional DeepSeek model identifier.

Mode-specific:

**review-diff:** Diff to review; Tech Spec (for orientation).

**review-files:** File list (paths, optionally with line ranges); review focus (`quality` / `architectural-alignment` / `standards` / `all`).

**review-spec-fit:** Diff; Tech Spec; (optional) AC list.

## Prompt template (review-diff mode)

Write to `/tmp/deepseek-cr-{task_id}.txt`:

```
ROLE: You are the Code Reviewer for a multi-agent SDLC workflow. Your job is quality-only review of a diff. You are NOT to make any code changes. You are NOT assessing whether the implementation satisfies acceptance criteria — that is Verification's job.

INPUTS:
- Diff: {verbatim git range, PR identifier, or file list with hunks}
- Tech Spec (orientation only): {verbatim}
- Coding standards (project CLAUDE.md): {verbatim}
- Coding standards (plugin language guidance): {verbatim}

REVIEW FOCUS (four areas):
1. Correctness-adjacent engineering quality (implementation risks, fragile patterns, hidden assumptions, error handling)
2. Maintainability (readability, complexity, naming, cohesion, coupling, clarity of responsibilities)
3. Standards compliance (coding conventions, module structure, logging, project-specific standards)
4. Architectural alignment (dependency boundaries, forbidden coupling, inappropriate shortcuts)

Plus test quality if tests are in the diff: G/W/T structure, clear naming, non-fragile assertions.

SEVERITY (each finding gets exactly one):
- BLOCKER: serious — dangerous pattern, severe maintainability risk, obvious architecture violation, critical missing error handling. Outcome must be REWORK REQUIRED.
- MAJOR: significant issue that should be fixed before acceptance.
- MINOR: useful improvement, not an acceptance blocker.
- NIT: tiny polish suggestion.

FINDING DISCIPLINE:
- Each finding: file:line location + one-line description + actionable recommendation.
- No vague "this is not great" / "feels wrong" comments — make it actionable.

OUTCOME:
- ACCEPT — no findings or only NIT findings.
- ACCEPT WITH CHANGES — MAJOR or MINOR findings, no BLOCKER.
- REWORK REQUIRED — at least one BLOCKER.

RETURN SCHEMA:
{
  "mode": "review-diff",
  "outcome": "ACCEPT" | "ACCEPT WITH CHANGES" | "REWORK REQUIRED",
  "findings": [
    {
      "severity": "BLOCKER" | "MAJOR" | "MINOR" | "NIT",
      "area": "correctness" | "maintainability" | "standards" | "architectural-alignment" | "test-quality",
      "location": "<file:line>",
      "description": "<one-line>",
      "recommendation": "<one-line>"
    }
  ],
  "blocker_count": <int>,
  "major_count": <int>,
  "minor_count": <int>,
  "nit_count": <int>,
  "summary": "<one-paragraph>"
}
```

## Prompt template (review-files mode)

Same template structure as `review-diff` but INPUTS carries a file list (with optional line ranges); instructions say "review the listed files in their entirety, not just changes." RETURN SCHEMA: `"mode": "review-files"` and adds `"files_reviewed": ["<path>", ...]` reflecting the input.

## Prompt template (review-spec-fit mode)

Write to `/tmp/deepseek-cr-{task_id}.txt`:

```
ROLE: You are reviewing a diff against a Tech Spec for spec-implementation drift. You are NOT performing general quality review. You are NOT assessing AC coverage (Verification's job) — you are flagging where the implementation diverges from what the spec specifies in module boundaries, interface contracts, data flow, error handling, or named constraints. You are NOT to make any code changes.

INPUTS:
- Diff: {verbatim}
- Tech Spec: {verbatim}
- Acceptance Criteria: {verbatim list, if separate}

FINDING DISCIPLINE:
For each divergence:
- Cite the Tech Spec section + the diff file:line
- State the spec's intent in one line
- State the implementation's deviation in one line
- Recommend either reconciling the implementation OR raising a spec amendment (orchestrator decides)

SEVERITY:
- BLOCKER: implementation contradicts a named spec constraint or interface contract.
- MAJOR: implementation introduces behaviour the spec doesn't authorise, or omits a spec-named behaviour.
- MINOR: implementation deviates in non-load-bearing ways (naming, ordering, internal structure).
- NIT: doc string or comment mismatch.

OUTCOME:
- ACCEPT — implementation matches the spec.
- ACCEPT WITH CHANGES — non-blocking divergences only.
- REWORK REQUIRED — at least one BLOCKER divergence.

RETURN SCHEMA:
{
  "mode": "review-spec-fit",
  "outcome": "ACCEPT" | "ACCEPT WITH CHANGES" | "REWORK REQUIRED",
  "divergences": [
    {
      "severity": "BLOCKER" | "MAJOR" | "MINOR" | "NIT",
      "spec_section": "<heading or section ID>",
      "diff_location": "<file:line>",
      "spec_intent": "<one-line>",
      "implementation_says": "<one-line>",
      "recommendation": "reconcile_implementation" | "raise_spec_amendment",
      "rationale": "<one-line>"
    }
  ],
  "summary": "<one-paragraph>"
}
```

## Invocation

```
timeout 300 reasonix run \
  --model {resolved_model} \
  --effort {resolved_effort} \
  --transcript /tmp/deepseek-cr-{task_id}.transcript.jsonl \
  "$(cat /tmp/deepseek-cr-{task_id}.txt)" \
  > /tmp/deepseek-cr-{task_id}.out \
  2> /tmp/deepseek-cr-{task_id}.err
```

240s timeout — review work is faster than implementation. Exit codes: 0 → parse; 124 → `deepseek_timeout`; 127 → `reasonix_cli_not_installed`; other → `deepseek_subprocess_error`.

## Validation

1. `JSON.parse`; mode match.
2. **All modes:** read-only. `files_touched` non-empty → `BLOCKED` with `review_mode_files_touched`.
3. **review-diff / review-files:**
   - `findings` is an array with required fields per entry.
   - **Severity / outcome consistency:** any `severity: BLOCKER` → outcome MUST be `REWORK REQUIRED`. All `NIT` or empty → outcome MUST be `ACCEPT`. Mismatch → `severity_outcome_mismatch`.
   - `blocker_count` / `major_count` / `minor_count` / `nit_count` match actual counts. Mismatch → `count_mismatch`.
   - **review-files:** `files_reviewed` is non-empty array.
4. **review-spec-fit:**
   - `divergences` entries have all required fields.
   - `recommendation` is one of `reconcile_implementation` or `raise_spec_amendment`.
   - Severity / outcome consistency same as above.

## Return shape

Envelope: `task_id`, `sender_role: deepseek-code-reviewer`, `vendor: deepseek`, `model`, `model_tier`, `mode`, `outcome`, `summary`, `artifact_refs`, `files_touched: []`, `raw_response_path`, `insights: []`, `vendor_pairing`.

Mode-specific payload on success:
- **review-diff / review-files:** `findings`, `blocker_count`, `major_count`, `minor_count`, `nit_count`, `rework_required`
- **review-spec-fit:** `divergences`, `rework_required`

On failure: `blocker_type` (one of: `missing_input`, `reasonix_cli_not_installed`, `deepseek_timeout`, `deepseek_subprocess_error`, `deepseek_response_invalid`, `review_mode_files_touched`, `severity_outcome_mismatch`, `count_mismatch`) and `blocker_detail`.
