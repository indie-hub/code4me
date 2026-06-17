# Probe: pairing degrades gracefully when Codex is unavailable

**Subject:** cross-vendor
**Coverage:** Verifies the orchestrator falls back to the anchor vendor and records `pairing_degraded: codex_unavailable` when cross-vendor pairing requires a Codex shim that isn't reachable (CLI missing, key missing, opt-out). The milestone continues — the pairing layer never blocks work.

## Input prompt

> Standard milestone: add a CSV export endpoint to the user-profile API. Enable cross-vendor pairing for this milestone.
>
> [simulated environment condition: `codex` CLI is not on PATH for this run — neither shim pre-flight check for `codex-bridge[code-reviewer]` will pass]

## Fixture

To simulate the "Codex CLI unavailable" condition for the probe run, temporarily ensure the runtime shell's `PATH` does not resolve `codex`. On a system where Codex is installed: `PATH=/usr/bin:/bin claude` for the probe session. On a system where Codex is not installed: no setup needed.

The `OPENAI_API_KEY` environment variable is irrelevant for this probe — the pre-flight check fails at step 1 (`command -v codex`) before key checking runs.

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none
- **Cross-vendor:** enabled by the user
- **Team:**
  - `lead-architect (claude:high)`
  - `codex-bridge[architect] (codex:high, mode=challenge)` — Co-Approval pair; the pairing layer assigns Codex, the shim's pre-flight fails on dispatch
  - `spec-to-test (claude:mid)` — alternation requested `codex-spec-to-test`, shim pre-flight failed → fell back to claude with `pairing_degraded: codex_unavailable`
  - `developer (claude:mid)`
  - `verification (claude:mid)` — single-vendor (no codex-verification in v0.7)
  - `code-reviewer (claude:mid)` — alternation requested `codex-bridge[code-reviewer]`, shim pre-flight failed → fell back to claude with `pairing_degraded: codex_unavailable`
  - `qa (claude:mid)`
  - `doc-writer (claude:mid)`
- **Order/notes:** The transparency announcement explicitly lists which pairings degraded and the reason. The milestone proceeds — degraded pairings do not block the workflow.

The orchestrator should also surface an INSIGHT recommending the user install / configure the Codex CLI if they want the cross-vendor benefit on subsequent milestones. Impact tier: `suggested change`.

## Pass criterion

Orchestrator's transparency announcement:

1. Names every dispatched agent with the `(claude:tier)` annotation where shims fell back, and `(codex:tier)` for `codex-bridge[architect]` even though its pre-flight will fail at dispatch (the announcement reflects the pairing decision; the shim's failure surfaces as a BLOCKED return).
2. Lists the degraded pairings explicitly with `pairing_degraded: codex_unavailable` and the reason (`codex CLI not on PATH` or similar).
3. Does NOT silently swap a Codex role for a Claude role without recording the degradation.
4. Continues the milestone — no halt, no escalation, no "cannot proceed without Codex" framing.
5. Emits an INSIGHT recommending Codex CLI setup, impact tier `suggested change`.

## Failure modes this catches

- Orchestrator blocks the milestone because a required cross-vendor shim is unavailable — the policy says fall back gracefully, never block.
- Orchestrator silently substitutes Claude for the missing Codex shim without recording the degradation in either the transparency announcement or the dispatch log.
- Orchestrator records `pairing_degraded` but lists the wrong reason (e.g., `user_override` when the actual cause is `codex_unavailable`).
- Orchestrator escalates the issue to the user as a `HUMAN_DIRECTOR_ESCALATION` — shim unavailability is a routine degradation, not a circuit-breaker condition.
- Orchestrator skips the INSIGHT — the user has no signal that Codex setup would have improved this milestone's coverage.
