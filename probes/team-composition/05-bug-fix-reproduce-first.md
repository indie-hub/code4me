# Probe: Bug Fix with QA-reproduces-first ordering

**Subject:** team-composition
**Coverage:** Catches incorrect ordering on Bug Fix kind — the QA reproduce step must come *before* the developer, not after. A developer who patches without a reproduction risks shipping a fix for the wrong defect.

## Input prompt

> Users report the leaderboard sometimes shows stale scores after a match ends.

## Fixture

This probe requires `probes/fixture-skeleton/` to be copied into the runtime fixture folder. Specifically:
- `src/Leaderboard.cs` — must exist with a `getLatestScores()` method that has a plausible-looking stale-data bug (e.g., a static cache field with no invalidation) so QA has something concrete to reproduce against.

If running in an empty folder, the orchestrator will correctly refuse with "no leaderboard in this directory" — that's a separate Pass condition (orchestrator doesn't hallucinate targets), but it short-circuits the classification + dispatch this probe is measuring.

## Expected

- **Kind:** Bug Fix
- **Weight:** Standard (default; orchestrator may suggest based on severity)
- **Auto-escalation:** none on the surface; orchestrator should flag that "stale scores" could surface `shared-state corruption` or `concurrency-correlated regressions` mid-flight and re-evaluate when QA reports findings
- **Team:** qa (reproduce) → developer → qa (re-verify); add verification + code-reviewer if severity warrants
- **Order/notes:** QA reproduces first. Developer is not dispatched until QA returns with a reliable reproduction. QA re-verifies after the developer's fix.

## Pass criterion

Orchestrator announces kind = Bug Fix, dispatches `qa` first to reproduce, holds `developer` until QA reports a reproduction, and schedules a final `qa` re-verify pass. Any optional `verification` / `code-reviewer` additions are justified by stated severity.

## Failure modes this catches

- Orchestrator routes to the Standard product-engineering team because "users reported" sounds like a feature request — but the Order of Evaluation step 2 in `workflow-weights.md` routes known defects to Bug Fix before product weights are even consulted.
- Orchestrator dispatches `developer` first and asks QA to verify after the fix lands — inverts the reproduce-first order and risks fixing the wrong defect.
- Orchestrator skips the final `qa` re-verify on the grounds that the developer "added a test."
