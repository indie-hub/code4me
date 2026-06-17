# Probe: codex-bridge[verification] completes the alternation chain (v0.8+)

**Subject:** cross-vendor
**Coverage:** Verifies that with `codex-bridge[verification]` shipped (v0.8 Tier-2), the alternation rule no longer degrades on the verification gate. This is the v0.7 probe 01 scenario re-run: the orchestrator should now dispatch `codex-bridge[verification]` on the opposite vendor from the implementer rather than recording `pairing_degraded: shim_unavailable`. The full cross-vendor chain (test author Codex → implementer Claude → verifier + reviewer Codex) is now end-to-end alternated.

## Input prompt

> Standard milestone: add a CSV export endpoint to the user-profile API. The endpoint returns the user's own data as CSV; the implementation goes in `internal/profile/export.go` with a paired test file. Enable cross-vendor pairing for this milestone.

## Fixture

No fixture required — this probe measures team-composition and announcement format. Assumes `codex` CLI is on PATH and `OPENAI_API_KEY` is set (otherwise individual shim dispatches will BLOCKED at pre-flight; the team-composition decision is still measurable from the announcement).

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none
- **Cross-vendor:** enabled
- **Team:**
  - `lead-architect (claude:high)`
  - `codex-bridge[architect] (codex:high, mode=challenge)` — Co-Approval Rule with Lead
  - `codex-bridge[spec-to-test] (codex:mid)` — test author on opposite vendor from developer
  - `developer (claude:mid)` — implementer
  - `codex-bridge[verification] (codex:mid, mode=suite-run)` — **new in v0.8: no longer degrades; runs on Codex per the alternation rule**
  - `codex-bridge[code-reviewer] (codex:mid, mode=review-diff)` — opposite vendor from developer
  - `qa (claude:mid)` — single-vendor by choice (no codex-qa)
  - `doc-writer (claude:mid)` — single-vendor (no codex-doc-writer)
- **Order/notes:** Architecture-introducing hard floor fires (new public interface). Co-Approval Rule cited. Pairing summary in the announcement: "spec author (Codex) ≠ implementer (Claude); implementer (Claude) ≠ verifier (Codex); implementer (Claude) ≠ reviewer (Codex)." **No `pairing_degraded` should appear in the announcement for the verification dispatch** — that's the v0.8 regression check.

## Pass criterion

Orchestrator's transparency announcement:

1. Names `codex-bridge[verification] (codex:mid)` on the team, NOT `verification (claude:mid)`.
2. Does NOT include any `pairing_degraded` annotation on the verification row.
3. The dispatch-log entry for the verification dispatch carries `vendor: openai`, `model_tier: mid`, and `vendor_pairing.degraded: null`.
4. Pairing summary in the announcement explicitly mentions the implementer-≠-verifier alternation now applies (it was degraded in v0.7).
5. The other pairings (architect Co-Approval, spec-author≠implementer, implementer≠reviewer) remain as in v0.7 probe 01.

## Failure modes this catches

- Orchestrator still dispatches `verification (claude:mid)` and records `pairing_degraded: shim_unavailable` — the v0.7 behaviour that v0.8 was supposed to fix.
- Orchestrator dispatches both `verification` and `codex-bridge[verification]` in parallel — the rule is alternation, not doubling.
- Orchestrator picks the wrong tier for `codex-bridge[verification]` (e.g., `low` instead of `mid`) — the model-selection.yaml entry must resolve correctly.
- `codex-bridge[verification]` is dispatched but the announcement still claims "v0.7 chain" or describes the verifier as Claude — stale wording.
- Codex-verification mode defaults to `ac-coverage` instead of `suite-run` for a Standard milestone — the shim's default is `suite-run`, and the orchestrator should pick `suite-run` for full verification on a Standard milestone (use `ac-coverage` only for fast pre-checks).

## Comparison to v0.7 probe 01

This probe is the **same input** as v0.7 probe 01 (`01-pairing-fires-on-standard.md`). The only difference is the expected verification dispatch: v0.7 expected `verification (claude:mid)` with `pairing_degraded: shim_unavailable` because `codex-bridge[verification]` did not exist; v0.8 expects `codex-bridge[verification] (codex:mid)` with `degraded: null` because the shim now exists. If both probes pass on a v0.8 build, the alternation regression is closed and the framework has stable behaviour across the version bump.
