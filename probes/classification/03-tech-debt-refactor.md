# Probe: Tech Debt refactor (no architecture introduction)

**Subject:** classification
**Coverage:** Catches mis-classification of internal refactors as product work, and over-eager dispatch of the Lead+Challenger pair when no new architecture is being introduced.

## Input prompt

> Refactor the ScoreFormatter to use string interpolation instead of concatenation.

## Fixture

This probe requires `probes/fixture-skeleton/` to be copied into the runtime fixture folder. Specifically:
- `src/ScoreFormatter.cs` — must exist with at least one string-concatenation path so the refactor target is real and the kind/weight classification has something to grip on.

If running in an empty folder, the orchestrator will correctly refuse with "no ScoreFormatter in this directory" — that's a separate Pass condition (orchestrator doesn't hallucinate targets), but it short-circuits the classification + dispatch this probe is measuring.

## Expected

- **Kind:** Tech Debt
- **Weight:** Standard (refactor is not pattern-following Light work, but is also not architecture-introducing)
- **Auto-escalation:** none
- **Team:** one architect (scope description only) → developer → code-reviewer → qa
- **Order/notes:** No Lead+Challenger pair — the work does not introduce a new public interface, new data flow, or new cross-cutting concern, so the architecture-introducing hard floor does not fire. Single architect contributes scope description only.

## Pass criterion

Orchestrator announces kind = Tech Debt, dispatches a single architect (scope only) rather than the Lead+Challenger pair, and follows the Tech Debt / Refactor default order: architect → developer → code-reviewer → qa.

## Failure modes this catches

- Orchestrator misclassifies as product because "Refactor" sounds like a change to behaviour — but the Order of Evaluation step 4 in `workflow-weights.md` routes "task does not change observable user behaviour" to Tech Debt.
- Orchestrator pulls both Lead and Challenger architects because it confuses *any architecture review* with *architecture-introducing*. No new public interface, data flow, or cross-cutting concern is being introduced here.
- Orchestrator skips qa entirely on the grounds that the change is internal — the Tech Debt template lists qa as a default member of the team.
