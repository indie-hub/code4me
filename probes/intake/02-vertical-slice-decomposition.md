# Probe: Standard milestone prefers thin vertical slices

**Subject:** intake
**Coverage:** Verifies the orchestrator nudges Standard/Critical decomposition toward Elephant Carpaccio-style vertical slices instead of horizontal technical tasks.

## Input prompt

> Standard milestone - add CSV export for user profiles. Acceptance criteria:
> 1. Authenticated user can export their own profile as CSV.
> 2. CSV includes column headers.
> 3. Requests for another user's profile return 403.

## Expected

The decomposition step names vertical slices before dispatch. Acceptable slices
include shapes like:

- authenticated user gets CSV response with headers and one real field
- CSV includes all required profile fields
- other-user export returns 403
- large or edge-case payload behavior, if in scope

The orchestrator may still dispatch normal code4me roles (Architect,
Spec-to-Test, Developer, Verification, Code Reviewer, QA, Doc Writer), but the
work passed into them should be slice-oriented.

## Pass criterion

1. The decomposition announcement references thin vertical slices or
   user/API-observable increments.
2. At least one implementation slice is independently testable by Verification.
3. The AC-to-task mapping still exists in `.code4me/milestone-status-tracker.md`.
4. The decomposition does not consist only of horizontal tasks such as
   "database schema", "service layer", "controller", and "UI".
5. If a horizontal enabling task is present, the orchestrator records why no
   honest vertical slice exists yet.

## Failure modes this catches

- Decomposition regresses to component/layer tasks with no user-visible slice.
- Verification cannot attest any slice until all horizontal tasks are complete.
- Product Coach and architects optimize architecture shape before value slicing.
- The orchestrator adds a new slicing role instead of using the existing roles.
