# Probe: cross-vendor pairing fires on a Standard milestone

**Subject:** cross-vendor
**Coverage:** Verifies the orchestrator applies the alternation rule from `references/cross-vendor-policy.md` when cross-vendor pairing is enabled — Claude-side roles dispatch as Task subagents, Codex-side roles invoke the `codex-bridge` skill inline from the orchestrator's thread, the tier system resolves the model per vendor, and the transparency announcement uses `(vendor:tier)` format with `codex-bridge[role]` for bridge invocations.

## Input prompt

> Standard milestone: add a CSV export endpoint to the user-profile API. The endpoint returns the user's own data as CSV; the implementation goes in `internal/profile/export.go` with a paired test file. Enable cross-vendor pairing for this milestone — I want the alternation policy on.

## Fixture

No fixture required — this probe measures team-composition and announcement format, not implementation against real code.

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none (no symptom class fires on this prompt alone)
- **Cross-vendor:** enabled for the milestone
- **Team:**
  - `lead-architect (claude:high)`
  - `codex-bridge[architect] (codex:high, mode=challenge)` — Co-Approval Rule with Lead
  - `codex-bridge[spec-to-test] (codex:mid)` — test author on opposite vendor from developer
  - `developer (claude:mid)` — implementer
  - `verification (claude:mid)` — single-vendor (no codex-verification shim in v0.7; pairing layer records `degraded: shim_unavailable` and falls back to anchor vendor)
  - `codex-bridge[code-reviewer] (codex:mid, mode=review-diff)` — opposite vendor from developer
  - `qa (claude:mid)` — single-vendor by choice (no codex-qa)
  - `doc-writer (claude:mid)` — single-vendor (no codex-doc-writer)
- **Order/notes:** Architecture-introducing hard floor fires (new public interface). Co-Approval Rule cited. Pairing summary in the announcement: "spec author (Codex) ≠ implementer (Claude); implementer (Claude) ≠ reviewer (Codex); verification single-vendor (no shim in v0.7); QA and docs single-vendor by choice."

## Pass criterion

Orchestrator's transparency announcement:

1. Names every dispatched agent with the `(vendor:tier)` annotation format.
2. Names the milestone-level setting `(Standard, cross-vendor enabled)` in the header.
3. Cites the Co-Approval Rule by name for the architect pair.
4. Cites the alternation rule's three active pairings (spec-author↔implementer, implementer↔reviewer, plus the architect Co-Approval).
5. Records `vendor_pairing.degraded: shim_unavailable` for the `verification` dispatch since `codex-verification` isn't shipped in v0.7.
6. Does NOT add both Claude-side and Codex-side reviewers in parallel — the rule is alternation, not doubling.

## Failure modes this catches

- Orchestrator dispatches everything on Claude despite the user's cross-vendor opt-in.
- Orchestrator runs Codex-side reviewers in parallel with Claude-side reviewers (doubling cost without the dialectic the rule is designed for).
- Orchestrator places spec-to-test and developer on the same vendor, defeating the test-author-≠-implementer pairing.
- Announcement uses the old `(anthropic:opus)` or `(anthropic:sonnet)` format instead of `(vendor:tier)`.
- Orchestrator silently falls back to single-vendor when a shim is missing without recording `pairing_degraded` in the dispatch log.
- Orchestrator forgets the Co-Approval Rule because the architect pair is now cross-vendor by default.
