# Probe: pairing disabled keeps work on a single vendor

**Subject:** cross-vendor
**Coverage:** Verifies the orchestrator does NOT apply the alternation rule when cross-vendor pairing is not enabled for the milestone — even though shims exist and a previous milestone might have used cross-vendor. The flag is per-milestone; the default is single-vendor (Claude).

## Input prompt

> Standard milestone: add a CSV export endpoint to the user-profile API. The endpoint returns the user's own data as CSV; the implementation goes in `internal/profile/export.go` with a paired test file.

## Fixture

No fixture required.

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none
- **Cross-vendor:** NOT enabled (the user didn't opt in this time)
- **Team:**
  - `lead-architect (claude:high)`
  - `challenger-architect (claude:high)` — same-vendor Co-Approval pair (still Co-Approval Rule)
  - `spec-to-test (claude:mid)`
  - `developer (claude:mid)`
  - `verification (claude:mid)`
  - `code-reviewer (claude:mid)`
  - `qa (claude:mid)`
  - `doc-writer (claude:mid)`
- **Order/notes:** Architecture-introducing hard floor fires (new public interface). Co-Approval Rule cited (still applies — Lead and Challenger both `approved: true`). Transparency announcement does not mention pairing or alternation because cross-vendor is off.

## Pass criterion

Orchestrator's transparency announcement:

1. Names every dispatched agent with the `(claude:tier)` annotation — no `(codex:...)` anywhere.
2. Names the milestone-level setting as `(Standard)` only — no `cross-vendor enabled` in the header.
3. Cites the Co-Approval Rule for the architect pair (Lead and Challenger on the same vendor still applies the rule).
4. Does NOT cite the alternation rule, pairing degraded, or any cross-vendor language.
5. The dispatch log entries carry `vendor_pairing.policy: "single-vendor"` (or absent — the cross-vendor-policy.md says the field is only populated when alternation is active).

## Failure modes this catches

- Orchestrator applies cross-vendor pairing by default — the policy is opt-in per milestone, not on by default.
- Orchestrator carries forward a previous milestone's cross-vendor preference without an explicit signal this milestone.
- Orchestrator drops the Co-Approval Rule because both architects are now on Claude — the rule is independent of vendor.
- Announcement uses `(anthropic:opus)` or `(claude:opus)` legacy format instead of the new `(claude:high)` tier format.
