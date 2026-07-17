---
description: Dispatch a task at an explicitly declared weight, bypassing intake clarification. Auto-escalation still applies (the symptom-class list overrides the declared weight when it fires). First argument is the weight (Conversation | Light | Standard | Critical); the rest is the task description. Optionally include "--cross-vendor" to enable cross-vendor pairing for this milestone, and/or "--solo" (v0.13+) to run the task solo — the orchestrator implements inline with one retained quality-gate dispatch, per references/solo-mode.md.
argument-hint: <weight> [--cross-vendor] [--solo] <task description>
---

Run the code4me orchestrator's dispatch flow with the user's explicitly declared weight, skipping the intake clarification step. Apply the auto-escalation override regardless of the declared weight — symptom-class detection still wins. If `--cross-vendor` appears in the arguments, enable the alternation policy from `references/cross-vendor-policy.md` for this milestone. If `--solo` appears, run the task in solo execution mode per `references/solo-mode.md` — the flag satisfies solo's explicit-entry gate.

Procedure:

1. Load the `code4me` skill.
2. Parse the first whitespace-delimited token as the weight. Validate it is one of `Conversation`, `Light`, `Standard`, `Critical` (case-insensitive). Anything else → ask the user to re-issue with a valid weight.
3. Detect the `--cross-vendor` flag anywhere in the arguments. If present, enable cross-vendor pairing for this milestone and remove the flag from the task description.
4. Detect the `--solo` flag anywhere in the arguments. If present, remove it from the task description and enable solo execution per `references/solo-mode.md`, subject to:
   - **Weight check:** solo applies to Conversation, Light, and Standard. If the declared weight is Critical, refuse the solo part (Critical's full-team floor is non-negotiable), announce why, and proceed with normal Critical dispatch.
   - **Auto-escalation check (step 6) runs first:** if escalation raises the weight to Critical, solo is dropped with an announcement. If it raises to Standard, solo continues at Standard semantics (verification gate, test-gate-first, decomposition).
   - When both `--solo` and `--cross-vendor` are present, run the retained gate on the opposite vendor per `references/solo-mode.md` §"Composition".
5. Treat the remaining text as the task description. Consult Basic Memory if its MCP tools are configured.
6. Run classification on **kind only** (Bug Fix / Tech Debt / Spike / Incident / Scope Change / product). The weight is already declared.
7. Apply auto-escalation override per `references/auto-escalation.md` — if a symptom class fires and the declared weight is below the floor, raise to the floor and announce the escalation. Do NOT ask the user; the override is non-negotiable.
8. Decide the team per `references/team-templates.md` + hard floors. In solo mode the "team" is the orchestrator inline plus the retained gate (combined-reviewer for Conversation/Light, verification for Standard) plus any escalation-mandated subagents. Resolve vendor, model profile, and effort independently.
9. Emit the Team Transparency announcement with backward-compatible `(vendor:tier)` annotations plus an explicit effort summary. For solo, use the solo announcement format from `references/solo-mode.md` — including the mandatory `Solo requested via: --solo flag` clause.
10. **Proceed with dispatch** through the canonical operating loop in `SKILL.md` (or the solo per-weight procedure in `references/solo-mode.md`) — persist `.code4me/` state, dispatch/implement, route returns, escalate per circuit breakers, present outcome.

Arguments:

$ARGUMENTS
