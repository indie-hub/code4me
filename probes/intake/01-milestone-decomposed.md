# Probe: Standard/Critical milestone is decomposed into ≥1 task per AC (v0.12+)

**Subject:** intake
**Coverage:** Verifies the orchestrator's operating-loop step 5 — Standard and Critical milestones MUST be decomposed into tasks before the first dispatch. The `acceptance_criteria:` block in `.code4me/milestone-status-tracker.md` is populated with per-AC state and `tasks_touching` arrays. Collapsing a multi-AC milestone into one task is a workflow violation. Per `references/playbook.md` §"Milestone decomposition".

## Setup

Run this probe in a project with a clean `.code4me/` (no existing milestone-status-tracker, or one that doesn't have the milestone the probe creates). The Milestone Spec the probe creates will have three explicit ACs.

## Input prompt

> Standard milestone — ship CSV export for user profiles. Acceptance criteria:
> 1. User can request their own profile data as CSV via `GET /api/profile/export?format=csv`.
> 2. The CSV includes column headers in the first row (always).
> 3. Requests for other users' profiles return 403 Forbidden.
>
> Implementation in `src/profile/export.cs` with a paired `tests/profile/export.test.cs`. Standard weight, not Critical.

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none (no symptom class — read-only export, user's own data)
- **Milestone Spec** written to `.code4me/milestone-specs/M07.md` with the three ACs preserved verbatim.
- **Decomposition produces ≥3 tasks** — one per AC at minimum. Reasonable expected task list (the probe doesn't enforce exact task IDs, just the count and shape):
  - `M07-T01-ARCH` — architecture (one task spanning AC1+AC2+AC3 is acceptable; the architect addresses all three)
  - `M07-T02-S2T` — test spec (may produce tests covering all three ACs)
  - `M07-T03-DEV` — implementation
  - `M07-T04-VER` — verification (one verification pass typically covers all ACs)
  - `M07-T05-CR` — code review
  - `M07-T06-QA` — QA
  - `M07-T07-DOC` — doc-writer (user-visible behaviour change)
- **`acceptance_criteria:` block** in `.code4me/milestone-status-tracker.md` populated with three entries (`AC1`, `AC2`, `AC3`), each with:
  - `summary` — the AC statement verbatim
  - `source` — link to the milestone spec section
  - `state: declared`
  - `tasks_touching` — non-empty array (e.g., AC1 touched by `[M07-T03-DEV, M07-T04-VER, M07-T05-CR, M07-T06-QA]`)
  - `last_verification_status: null`
  - `last_updated` — ISO8601 timestamp
- **Trello-sync invocation** (if Trello MCP is configured) creates exactly **3 Trello cards** — one per AC — in the Inbox list.

## Pass criterion

1. The orchestrator does NOT dispatch a Task call until the `acceptance_criteria:` block exists in the tracker with all three AC entries populated.
2. The decomposition step is named explicitly in the transparency announcement (something like *"Decomposing M07 into tasks per AC: AC1 → T03/T04/T05/T06, AC2 → T03/T04/T05/T06, AC3 → T03/T04/T05/T06."*).
3. Every dispatched task is referenced in at least one AC's `tasks_touching` array.
4. The trello-sync invocation (if reachable) creates 3 cards, not 1.

## Failure modes this catches

- **Orchestrator collapses to one task.** The orchestrator treats "ship CSV export" as a single task with no AC granularity, dispatches one developer, the AC↔task mapping doesn't exist. Trello shows one card; verification has no per-AC table; users see milestone-level state instead of requirement-level state.
- **Orchestrator decomposes but skips the tracker write.** Tasks are created, dispatched, but the `acceptance_criteria:` block is missing from the tracker. trello-sync logs `acceptance_criteria_block_missing` and no-ops; verification later can't trace tasks to ACs.
- **Orchestrator writes the block but with empty `tasks_touching` arrays.** The decomposition is declarative only — no mapping from ACs to the actual dispatched tasks. Verification reports lack traceability.
- **Orchestrator dispatches tasks not in any AC's `tasks_touching` array.** Drift — a task ran but no AC associates with it. Verification will reject this in the AC coverage table.

## Audit-tool integration

After the milestone closes, run `/code4me-audit`. A new "Decomposition health" surveillance section (v0.12.x candidate) should show:

- Milestones with `acceptance_criteria:` block: count.
- Milestones missing the block (Standard/Critical only): 0 ideally; any nonzero is a workflow violation.
- Average ACs per milestone: a sanity check (should be ≥1, typically 1-5).
- Tasks not associated with any AC: 0 ideally; nonzero suggests orphan dispatches.

This surveillance section isn't shipped in v0.12.0 — it's deferred to v0.12.1. For v0.12.0 the probe is the sole check.

## Trivial / Conversation / Light weight exemption

This probe doesn't apply to Trivial, Conversation, or Light weight. Those produce one AC per milestone by definition and don't go through the multi-task decomposition step. The `acceptance_criteria:` block still exists for those milestones but with a single entry — verified by `probes/trello/01-ac-card-per-ac.md` instead.

## Edge cases worth knowing

- **One AC with multiple tasks** (typical) — AC1 might be touched by Tech Spec, Test Spec, implementation, verification, code review, QA, and doc-writer. All seven tasks appear in `AC1.tasks_touching`. The AC card moves to **In Progress** when any of these dispatches; moves to **Done** only when verification confirms PASS AND all other gates have accepted.
- **One task touching multiple ACs** (also common — verification typically touches all ACs in one pass) — the task ID appears in multiple ACs' `tasks_touching` arrays. The dispatch return triggers a fan-out: every AC the task touches gets a card update.
- **Mid-milestone scope change adds an AC** — the orchestrator detects a Scope Change circuit-breaker, the user decides to add AC4. The decomposition step re-runs with the expanded AC set; the tracker grows; a new Trello card is created in `Inbox`. The existing AC cards are unaffected.
- **Mid-milestone AC removal** — the user decides AC3 is out of scope. The card moves to **(archived)** rather than **Done**; the tracker marks `AC3.state: archived` (a new state value for v0.12). Verification ignores archived ACs in its coverage table.
