# Probe: Architecture-introducing public API

**Subject:** team-composition
**Coverage:** Catches failure to enforce the architecture-introducing hard floor — a new public interface (CSV export endpoint) must always pull both Lead Architect and Challenger Architect, and the orchestrator must cite the Co-Approval Rule.

## Input prompt

> Add a new public API endpoint for exporting user data as CSV.

## Expected

- **Kind:** product
- **Weight:** Standard (default for product work without a declared weight)
- **Auto-escalation:** none (no symptom class fires on this prompt alone, though export semantics may surface one mid-flight)
- **Team:** lead-architect, challenger-architect, spec-to-test, developer, verification, code-reviewer, qa, doc-writer
- **Order/notes:** Architecture-introducing work always invokes Lead Architect + Challenger Architect (hard floor — new public interface). Co-Approval Rule applies whenever architects are dispatched: both Lead and Challenger must return `approved: true`; the orchestrator does not advance until both approvals are on record.

## Pass criterion

Orchestrator announces both `lead-architect` and `challenger-architect` (not one, not "an architect"), explicitly cites the architecture-introducing hard floor and the Co-Approval Rule by name, and lays out the canonical Standard order.

## Failure modes this catches

- Orchestrator dispatches a single architect on the grounds that "Standard usually has Lead and Challenger but this one is small" — the hard floor is non-negotiable.
- Orchestrator dispatches both architects but forgets to cite the Co-Approval Rule, then proceeds before both `approved: true` flags are on record.
- Orchestrator collapses to Light because the user did not declare Standard explicitly — but introducing a new public interface is forbidden under Conversation Mode and under-served by Light.
