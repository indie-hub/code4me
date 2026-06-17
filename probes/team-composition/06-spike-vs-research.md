# Probe: Spike vs Researcher disambiguation

**Subject:** team-composition
**Coverage:** Catches the orchestrator collapsing investigative work into a single default. A migration-feasibility question can be either Spike (hands-on prototyping against a real schema) or Researcher (desk-based comparison of capabilities) — the orchestrator must disambiguate before dispatching.

## Input prompt

> Investigate whether we should migrate from Postgres to CockroachDB for the matchmaker.

## Expected

- **Kind:** Spike *or* a Researcher-led research task — orchestrator must pick one and justify
- **Weight:** Standard (default; timeboxed if Spike)
- **Auto-escalation:** none at intake
- **Team:** for Spike → `developer` (timeboxed) → spike report to requesting role; for Researcher → `researcher` only, returning a written comparison
- **Order/notes:** Disambiguation rule the orchestrator must apply — hands-on prototyping against a real schema → Spike (developer, timeboxed); desk investigation / capability comparison / written synthesis → Researcher. Substituting Researcher for Spike is a recorded substitution per the Composition rules.

## Pass criterion

Orchestrator does not dispatch a default Standard team. It picks Spike *or* Researcher, names the disambiguation criterion it used (hands-on prototyping vs desk investigation), and records the substitution rationale if it picked Researcher in place of Spike.

## Failure modes this catches

- Orchestrator dispatches the full Standard product team to "investigate" — treats research as production work.
- Orchestrator picks Spike *or* Researcher without articulating the criterion, leaving the user no way to challenge the routing.
- Orchestrator timeboxes neither — Spike must be timeboxed per the Spike template.
- Orchestrator picks Researcher but does not record the substitution rationale in the Milestone Status Tracker, breaking auditability.
