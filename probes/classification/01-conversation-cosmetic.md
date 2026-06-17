# Probe: Conversation-weight cosmetic change

**Subject:** classification
**Coverage:** Catches over-classification — a reversible cosmetic edit should land as Conversation, not Light or Standard, and should not pull architects.

## Input prompt

> Change the homepage CTA button colour from green to blue.

## Fixture

This probe requires `probes/fixture-skeleton/` to be copied into the runtime fixture folder. Specifically:
- `src/ui/Homepage.tsx` — must exist with a green-tokened CTA button so the orchestrator has a concrete cosmetic target to dispatch against.

If running in an empty folder, the orchestrator will correctly refuse with "no homepage in this directory" — that's a separate Pass condition (orchestrator doesn't hallucinate targets), but it short-circuits the classification + dispatch this probe is measuring.

## Expected

- **Kind:** product
- **Weight:** Conversation
- **Auto-escalation:** none
- **Team:** developer, combined-reviewer
- **Order/notes:** dev → combined-reviewer (loop on REWORK). No architect; no spec-to-test; no doc-writer. Producer should also mention the `PROVISIONAL — promote-or-revert by {date}` tag and the Conversation Note step.

## Pass criterion

Orchestrator announces a Conversation-weight product change with exactly `developer` and `combined-reviewer` on the team, cites the Conversation Note + smoke-test path, and does not invoke or threaten to invoke any architect, spec-to-test, verification, code-reviewer, qa, or doc-writer subagent.

## Failure modes this catches

- Orchestrator escalates to Light or Standard "just to be safe" — defeats the purpose of Conversation Mode.
- Orchestrator dispatches a code-reviewer or qa pass — Conversation Mode uses combined-reviewer, full stop.
- Orchestrator skips the Conversation Note step or fails to apply the `PROVISIONAL` changelog tag.
- Orchestrator auto-escalates with no symptom class actually firing (no auth, no migration, no external dep, no cross-cutting concern, no new interface).
- Orchestrator omits the promote-or-revert deadline.
