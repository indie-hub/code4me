# Probe: codex-architect consult mode returns focused answer without approval gate

> **SUPERSEDED IN v0.10.** Pre-v0.10 shim-mode behaviour. The consult-mode contract is preserved in v0.10's `skills/codex-bridge/references/architect.md` under "Prompt template (consult mode)"; the mechanism is now skill invocation rather than subagent dispatch.

**Subject:** team-composition
**Coverage:** Verifies the orchestrator can invoke `codex-architect` with `mode=consult` for a focused architecture question, that Codex returns a prose answer plus `named_tradeoffs` (not a full critique), and that the response does NOT include `five_area_examination` or `approved` fields — those are `challenge`-mode only. Consult mode has no approval gate, so the Co-Approval Rule must not be cited and no architecture-introducing hard floor should fire on a question that is not introducing architecture.

## Input prompt

> Use codex-architect in consult mode to answer: should the matchmaker batch state updates every 100ms, or stream them immediately? Context: 5k concurrent matches, latency budget per AC3 is 250ms, players see scoreboard reactively.

## Expected

- **Kind:** product
- **Weight:** Conversation (focused architecture question, no implementation, no symptom class)
- **Auto-escalation:** none
- **Team:** single dispatch to `codex-architect (openai:<model>) [mode=consult]`
- **Order/notes:** No Co-Approval Rule cited (consult has no approval gate per the modes table in `agents/codex-architect.md`). Return payload includes `mode: "consult"`, `answer`, `named_tradeoffs`, `missing_information`, `follow_up_questions`. Return payload does NOT include `five_area_examination`, `approved`, `named_alternatives`, or `amendments_required` — those are challenge-mode/review-spec fields.

## Pass criterion

Orchestrator's transparency announcement names `codex-architect (openai:<model>) [mode=consult]` with the mode explicit, does not cite the Co-Approval Rule, does not dispatch `lead-architect` alongside, and surfaces a response containing exactly the consult-mode payload fields (`answer`, `named_tradeoffs`, `missing_information`, `follow_up_questions`).

## Failure modes this catches

- Orchestrator dispatches `codex-architect` without specifying `mode`, causing the shim to default to `challenge` and produce a full five-area critique for a question that only wanted a focused answer.
- Orchestrator cites the Co-Approval Rule on consult mode and waits for an `approved: true` flag that consult mode never emits, deadlocking the workflow.
- Orchestrator adds `lead-architect` to satisfy a perceived co-approval requirement, doubling cost for a focused consultation.
- Shim returns a response with `five_area_examination` or `approved` populated for consult mode — a schema confusion the orchestrator should surface as `blocker_type: codex_response_invalid`.
