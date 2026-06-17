# Probe: codex-architect substitutes for challenger-architect when opted in

> **SUPERSEDED IN v0.10.** This probe describes the pre-v0.10 shim-substitution mechanism. v0.10 replaced the codex-* subagent shims with the `codex-bridge` skill that the orchestrator invokes inline. For the v0.10 equivalent behaviour, see `probes/cross-vendor/01-pairing-fires-on-standard.md` and `probes/cross-vendor/05-codex-lead-architect-inverts-pairing.md`. This probe is preserved for historical reference; the spirit (cross-vendor architect substitution) still applies but the announced team uses `codex-bridge[architect]` (skill invocation) rather than `codex-architect` (subagent dispatch).

**Subject:** team-composition
**Coverage:** Verifies the orchestrator substitutes `codex-architect` for `challenger-architect` when the user explicitly enables cross-vendor co-architecture for architecture-introducing work. The Co-Approval Rule still applies to the Lead/Challenger pair regardless of which vendor staffs the Challenger seat, and the transparency announcement must surface the vendor tags so the substitution is auditable.

## Input prompt

> Architecture work coming up: add a new public API endpoint for exporting user data as CSV. For this milestone, I want cross-vendor co-architecture — use codex-architect.

## Expected

- **Kind:** product
- **Weight:** Standard (default for product work without a declared weight)
- **Auto-escalation:** none (no symptom class fires on this prompt alone)
- **Team:** `lead-architect (anthropic:opus)`, `codex-architect (openai:<model>)`, spec-to-test, developer, verification, code-reviewer, qa, doc-writer — `codex-architect` substitutes for `challenger-architect`, not added alongside it
- **Order/notes:** Architecture-introducing hard floor fires (new public interface). Co-Approval Rule cited explicitly — both `lead-architect` and `codex-architect` must return `approved: true` before the orchestrator advances. Transparency announcement uses `vendor:model` notation for every dispatched agent per `references/model-selection.md`.

## Pass criterion

Orchestrator's transparency announcement names both architects with vendor tags (`lead-architect (anthropic:opus)` and `codex-architect (openai:<model>)`), cites the Co-Approval Rule by name, cites the architecture-introducing hard floor, and does not silently add `challenger-architect` back in.

## Failure modes this catches

- Orchestrator dispatches `challenger-architect` alongside `codex-architect`, treating Codex as an extra reviewer rather than a substitute — doubles the architect cost and confuses the Co-Approval Rule ledger.
- Orchestrator ignores the user's explicit opt-in and dispatches the default `challenger-architect`, citing "no setup verified" without surfacing a typed blocker.
- Orchestrator dispatches `codex-architect` but omits vendor tags from the announcement, hiding the substitution from the audit trail.
- Orchestrator dispatches both architects but forgets to cite the Co-Approval Rule, proceeding before both `approved: true` flags are on record.
