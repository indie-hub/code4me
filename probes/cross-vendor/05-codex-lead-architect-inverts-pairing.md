# Probe: codex-bridge[lead-architect] inverts the architect pairing (v0.8+)

**Subject:** cross-vendor
**Coverage:** Verifies the orchestrator can invert the v0.7 default architect pairing — instead of Claude-Lead + Codex-Challenger, it dispatches Codex-Lead + Claude-Challenger when the user signals that direction. The Co-Approval Rule still applies (both must return `approved: true`). The mandatory-alternatives check on `codex-bridge[lead-architect]` `mode=propose` is enforced (≥ 2 named alternatives or convergence_notes citing classes ruled out).

## Input prompt

> Standard milestone: design the architecture for a new event-pipeline component that ingests user-action events from the web frontend, normalises them, and routes them to two destinations (analytics warehouse + real-time fraud-detection service). Enable cross-vendor pairing for this milestone, and **use codex-bridge[lead-architect] as the Lead** for the architecture phase — I want Claude's challenger to pressure-test Codex's design rather than the default direction.

## Fixture

No fixture required.

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none
- **Cross-vendor:** enabled with the architect pairing inverted (user-specified)
- **Team (architecture phase):**
  - `codex-bridge[lead-architect] (codex:high, mode=propose)` — Lead on Codex per user direction
  - `challenger-architect (claude:high)` — Challenger on Claude (the alternation rule resolves opposite-vendor)
- **Team (post-architecture):**
  - `codex-bridge[spec-to-test] (codex:mid)` — alternates with developer
  - `developer (claude:mid)` — implementer
  - `codex-bridge[verification] (codex:mid)` — alternates with developer
  - `codex-bridge[code-reviewer] (codex:mid)` — alternates with developer
  - `qa (claude:mid)`
  - `doc-writer (claude:mid)`
- **Order/notes:** Architecture-introducing hard floor fires (new component with new public interfaces and data flow). Co-Approval Rule cited explicitly — both `codex-bridge[lead-architect]` and `challenger-architect` must return `approved: true` (after the propose → amend → re-review loop converges).

## Pass criterion

Orchestrator's transparency announcement:

1. Names `codex-bridge[lead-architect] (codex:high, mode=propose)` as the Lead — NOT `lead-architect (claude:high)`.
2. Names `challenger-architect (claude:high)` as the Challenger — NOT `codex-bridge[architect] (codex:high)`. The alternation flips because Codex is now the Lead vendor.
3. Cites the Co-Approval Rule by name — explicitly notes that the rule applies regardless of which vendor is on which side of the pair.
4. The mandatory-alternatives check for `codex-bridge[lead-architect] mode=propose` is referenced: the propose dispatch will BLOCK with `blocker_type: mandatory_alternatives_violation` if Codex returns a proposal with `named_alternatives` array of < 2 entries AND no "ruled out" rationale in `convergence_notes`.
5. The downstream non-architect roles follow the standard alternation: spec-to-test on opposite vendor from developer, etc.
6. The dispatch-log entries reflect the inverted vendor assignment: `codex-bridge[lead-architect]` dispatch with `vendor: openai`, `model_tier: high`; `challenger-architect` dispatch with `vendor: anthropic`, `model_tier: high`.

## Failure modes this catches

- Orchestrator ignores the user's "use codex-bridge[lead-architect] as the Lead" signal and dispatches the v0.7 default (Claude-Lead + Codex-Challenger).
- Orchestrator dispatches `codex-bridge[lead-architect]` but also dispatches `lead-architect` alongside it — doubling the Lead role instead of substituting.
- Orchestrator inverts the Lead vendor but forgets to flip the Challenger to Claude — both architects end up on Codex, defeating the cross-vendor dialectic.
- Co-Approval Rule citation omitted because "the user explicitly chose the Lead vendor" — the rule is independent of pairing direction; both architects must still approve.
- Mandatory-alternatives check not surfaced — if Codex returns a proposal with no alternatives, the shim must BLOCK, and the announcement should reference this safety.
- Downstream alternation breaks because the orchestrator "anchors" everything to Codex now that the Lead is on Codex — the producer/verifier alternation should still apply per role-pair, not be globally inverted.

## Notes

This probe is a real test of the alternation rule's symmetry. v0.7's default direction (Claude-Lead + Codex-Challenger) was the easy direction to ship; supporting the inverse direction in v0.8 means the orchestrator's pairing resolution algorithm has to work bidirectionally, not just "Codex is the verifier." If this probe passes, the framework has earned the right to claim true cross-vendor symmetry.
