# Probe: Spec Kit interop consumes spec.md at intake (v0.9+)

**Subject:** classification
**Coverage:** Verifies the orchestrator detects `specs/<feature>/spec.md` at intake, consumes it as the Milestone Spec per `references/spec-kit-interop.md`, skips the Product Coach dispatch (the spec is already done), and surfaces the input provenance in the transparency announcement.

## Setup note

Run this probe in a project that contains:

```
specs/
  checkout-redesign/
    spec.md       — a Spec Kit specification (Markdown with frontmatter)
    plan.md       — a Spec Kit technical plan (optional for this probe; if present, also consumed as Lead Architect draft input)
```

The `spec.md` should declare a feature that warrants Standard weight (e.g., introduces a new public interface) so the architecture path engages. The `<feature>` slug should match what the user names in the input prompt below.

## Input prompt

> Standard milestone for the checkout-redesign feature. The spec and plan are already in `specs/checkout-redesign/`.

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none (unless the spec touches an auto-escalation symptom class — depends on `spec.md` content)
- **Spec Kit interop active:** yes
- **Team:**
  - `lead-architect (claude:high)` — receives `specs/checkout-redesign/plan.md` as the draft input (if plan.md exists)
  - `challenger-architect (claude:high)` — soundness review of the plan content
  - `spec-to-test (claude:mid)`
  - `developer (claude:mid)`
  - `verification (claude:mid)`
  - `code-reviewer (claude:mid)`
  - `qa (claude:mid)`
  - `doc-writer (claude:mid)`
- **Skipped:** Product Coach (the spec.md is the Milestone Spec; no intake refinement needed)
- **Order/notes:** Transparency announcement carries an `**Inputs**:` prefix line citing `specs/checkout-redesign/spec.md` (and `plan.md` if present). The Milestone Spec reference at `.code4me/milestone-specs/{milestone_id}-source.md` records provenance + Git blob SHA. Dispatch log entries carry `spec_kit_interop: true`.

## Pass criterion

Orchestrator's transparency announcement:

1. **Inputs line is present** before the team listing, citing the consumed Spec Kit files with their relative paths.
2. **Product Coach is not on the team** even though weight is Standard — the spec.md is the Milestone Spec, so the intake-refinement role is unnecessary.
3. **Lead Architect is dispatched normally** (not skipped) — the plan.md is the draft input, not a finished Tech Spec. Lead Architect produces the final Tech Spec; Challenger reviews; Co-Approval applies.
4. **Persisted provenance:** `.code4me/milestone-specs/{milestone_id}-source.md` references the Spec Kit file by path + SHA rather than copying the content.

## Failure modes this catches

- Orchestrator ignores the Spec Kit files and runs the original intake-from-scratch flow.
- Orchestrator consumes `spec.md` but also dispatches Product Coach to re-derive intake — defeats the interop's purpose.
- Orchestrator consumes `plan.md` and treats it as a final Tech Spec, skipping Lead Architect — but Lead Architect's role is the Architecture Discussion + Tech Spec authoring, which the Spec Kit plan doesn't replace.
- Orchestrator copies the Spec Kit content verbatim into `.code4me/milestone-specs/` rather than referencing by path + SHA — breaks the single-source-of-truth invariant.
- Transparency announcement omits the Inputs prefix line — Spec Kit's contribution is invisible in the audit trail.
- Dispatch log entries don't carry `spec_kit_interop: true` — the audit tool can't surface the interop's prevalence over time.

## Notes

This probe pairs naturally with `probes/team-composition/03-tech-debt-refactor.md` (without Spec Kit) — the same input prompt minus the Spec Kit files should produce a different team (Product Coach included). Running both as a pair tests both the interop-active path and the no-op-fallback path.
