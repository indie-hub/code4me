# Probe: codex-developer spike mode produces throwaway prototype, bypasses V/R/QA gates

> **SUPERSEDED IN v0.10.** Pre-v0.10 shim-mode behaviour. The spike-mode contract (`PROTOTYPE_NOT_FOR_MERGE` marker, ≥ 2 options, bypass of V/R/QA gates) is preserved in v0.10's `skills/codex-bridge/references/developer.md` under "Prompt template (spike mode)"; the mechanism is now skill invocation rather than subagent dispatch.

**Subject:** team-composition
**Coverage:** Verifies the orchestrator can invoke `codex-developer` with `mode=spike` for a throwaway prototype, that Codex returns at least two options considered with tradeoffs, that `throwaway_marker` is exactly `PROTOTYPE_NOT_FOR_MERGE`, and that the orchestrator does NOT route spike output through Verification, Code Review, or QA gates. Spike output is explicitly throwaway — running it through merge-path gates would waste reviewer cycles on code that will never ship.

## Input prompt

> Spike: use codex-developer in spike mode to prototype whether RxJava or coroutines would be a better fit for the new event-bus subsystem. Scope: src/event-bus/spike/. Timebox: 90 minutes.

## Expected

- **Kind:** product
- **Weight:** Conversation (timeboxed prototype, no merge intent, no symptom class)
- **Auto-escalation:** none
- **Team:** single dispatch to `codex-developer (openai:<model>) [mode=spike]` with the explicit timebox (90 minutes) and scope (`src/event-bus/spike/`) forwarded in the Context Pack
- **Order/notes:** Return payload includes `outcome: FINDING | INCONCLUSIVE`, `options_considered` array with at least two entries each carrying tradeoffs, `throwaway_marker: "PROTOTYPE_NOT_FOR_MERGE"` (exact string), `next_step_recommendation`, `timebox_used_minutes`. Orchestrator's announcement explicitly notes the spike output is not for merge. No `verification`, `code-reviewer`, or `qa` subagents fire after the spike returns.

## Pass criterion

Orchestrator dispatches a single `codex-developer (openai:<model>) [mode=spike]` with the timebox and scope intact, surfaces a response containing all five spike-mode fields (`outcome`, `options_considered` with ≥ 2 entries with tradeoffs, `throwaway_marker: "PROTOTYPE_NOT_FOR_MERGE"`, `next_step_recommendation`, `timebox_used_minutes`), and the summary to the user explicitly states the prototype is not for merge. No V/R/QA gates are dispatched.

## Failure modes this catches

- Orchestrator routes spike output through `verification` + `code-reviewer` + `qa` as if it were merge-bound work, wasting reviewer cycles on throwaway code.
- Orchestrator drops the timebox or scope when constructing the Context Pack, leaving Codex to spike open-endedly.
- Shim returns `outcome: COMPLETE` (the standard developer outcome) instead of `FINDING` or `INCONCLUSIVE`, causing the orchestrator to treat the prototype as production-ready.
- Orchestrator omits the `throwaway_marker` from its summary or paraphrases it ("this was a prototype") instead of surfacing the exact string `PROTOTYPE_NOT_FOR_MERGE`, defeating the audit-trail signal that downstream tooling keys off.
- Spike returns only one option in `options_considered` — defeats the purpose of a comparative spike and should surface as an invalid-spike blocker.
