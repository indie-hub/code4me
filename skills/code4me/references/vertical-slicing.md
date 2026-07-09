# Vertical Slicing

Use this reference during Standard and Critical milestone decomposition.

The default decomposition bias is Elephant Carpaccio-style: prefer the thinnest
useful vertical slice of value over horizontal technical tasks.

## Slice Rule

A good slice is:

- user-observable or API-observable
- independently testable by Verification
- mapped to one or more acceptance criteria
- small enough to implement and review without hiding risk
- honest about deferred polish, scale, migration, or hardening

Prefer slice names like:

- "Authenticated user gets CSV with headers and one real field"
- "Other-user export returns 403"
- "Large export streams without loading the whole payload"

Avoid task names like:

- "Create database schema"
- "Implement service layer"
- "Build UI"
- "Wire controller"

Those horizontal tasks are allowed only when no honest user/API-observable slice
exists yet. In that case, classify it as a Spike, Architecture task, migration
step, or enabling task, and record why it cannot be sliced vertically.

## Slice Readiness Checklist

Before dispatching a slice, record or pass:

- outcome: what the user/API can observe after this slice
- acceptance check: test, probe, or manual verification
- touched layers: UI/API/domain/storage/etc. when applicable
- deferrals: polish, scale, edge cases, migration, hardening
- rollback/revert note

## Example

Acceptance criterion: user can export their profile as CSV.

Good slices:

1. Authenticated user receives a CSV response with headers and one real field.
2. CSV includes all required profile fields.
3. Requesting another user's profile returns 403.
4. Large profile payloads stream safely.
5. Audit logging and user documentation are added.

The first slice may be deliberately thin, but it should still be demonstrably
CSV export behavior, not just a controller stub or isolated helper.

## Role Fit

- Product Coach helps find value slices when the request is large or fuzzy.
- Lead Architect and Challenger Architect check whether slices cross the right
  boundaries without creating unsafe shortcuts.
- Spec-to-Test writes per-slice checks.
- Developer implements one or more slices.
- Verification reports slice-by-slice coverage.

Do not add a new role just for slicing. This is a decomposition rule inside the
existing workflow.
