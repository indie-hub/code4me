# Probe: trello-sync creates one card per AC and fires at state transitions (v0.12+)

**Subject:** trello-sync
**Coverage:** Verifies (1) the orchestrator invokes the `trello-sync` skill at the four documented state-transition moments (after-decomposition, dispatch, return, escalation) — not before, not after, not for read-only commands; (2) the skill creates one Trello card per AC declared in the Milestone Spec, not one card per task. The skill itself is best-effort and silently no-ops when the MCP isn't configured; this probe doesn't care whether the actual Trello calls succeed, only that the orchestrator made the right invocation attempts.

## Setup

Run this probe in a project where:

1. `.code4me/trello-config.json` exists at the project root (populated, not the placeholder content — run `/code4me-trello-init` first).
2. The Trello MCP is reachable (verify via `/code4me-preflight` — the "Trello sync (optional)" check should be ✓ ok).
3. A clean `.code4me/dispatch-log.jsonl` so you can see the new entries from this run.

If either (1) or (2) is missing, the orchestrator should still announce trello-sync invocations in the transparency line but the skill will no-op silently — the probe's pass criterion is the orchestrator's announced behaviour, not the MCP outcome.

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
- **Auto-escalation:** none
- **Decomposition runs first** (per `probes/intake/01-milestone-decomposed.md`) — the tracker's `acceptance_criteria:` block ends up with `AC1`, `AC2`, `AC3`.

### Orchestrator behaviour through the milestone

The orchestrator's transparency announcements and tool calls should show `trello-sync` invocations at these moments, in this order:

1. **After decomposition (step 5)** — the orchestrator says *"Creating Trello cards for M07's 3 ACs in Inbox."* Then invokes `trello-sync`, which creates 3 cards:
   - `M07-AC1: User can request their own profile data as CSV via GET /api/profile/export?format=csv`
   - `M07-AC2: The CSV includes column headers in the first row (always)`
   - `M07-AC3: Requests for other users' profiles return 403 Forbidden`

2. **At each dispatch (step 7)** — before each `Task` call:
   - First dispatch (e.g., `M07-T01-ARCH` touching all 3 ACs) → trello-sync moves all 3 cards from **Inbox** to **In Progress**; appends the dispatch to each card's description.
   - Subsequent dispatches touching specific ACs (e.g., `M07-T03-DEV` touches all 3, `M07-T05-CR` touches all 3) update each card's description.

3. **At each subagent return** — the orchestrator recomputes per-AC state. Examples:
   - Developer returns COMPLETE → AC cards stay in **In Progress** until Quality Gates start.
   - Verification returns PASS with `AC1: PASS, AC2: PASS, AC3: PARTIAL` → AC1 and AC2 move to **In Review** (other gates still running); AC3 moves to **Blocked** (or stays in **In Review** if rework is dispatched).
   - All gates pass on AC1 and AC2 → those cards move to **Done**. AC3 stays in **Blocked** until rework completes.

4. **At escalation / circuit-breaker fire** — if a Rework Limit fires on AC3, the AC3 card moves to **Blocked** (already there from PARTIAL verification, so this is a description update). If a Scope Change circuit breaker fires for the milestone, all 3 cards may move to **Pending User** depending on the circuit-breaker's escalation shape.

## Pass criterion

1. **Card count = AC count.** The probe creates a milestone with 3 ACs; trello-sync creates exactly 3 cards. Not 1, not 5, not 7 (number of tasks).
2. **Card titles are AC-shaped**, matching `{milestone_id}-{ac_id}: {ac_summary}` from `references/card-shape.md`. They are NOT task-shaped (no `M07-T03-DEV: ...`).
3. **Each card's description** includes the `Tasks touching this AC` block with the dispatched task IDs.
4. **State transitions follow the AC lifecycle**, not task lifecycle. A verification PARTIAL on one AC moves only that AC's card to a different state; the other ACs continue independently.
5. **Cross-task fan-out fires correctly** — when verification (one Task call) returns with per-AC verdicts in its AC coverage table, the orchestrator updates all 3 AC cards in a single trello-sync invocation, not one per task.
6. **Conversation/Light/Trivial milestones in the same project still produce one card per milestone** (single-AC), confirming the AC-level model gracefully handles the lighter weights.

## Failure modes this catches

- **Orchestrator collapses to one card.** Most common regression — trello-sync mirrors task IDs instead of AC IDs; result is one card per milestone titled with a task ID like `M07-T03-DEV: ...`. Probe fails on criterion 1.
- **Orchestrator creates one card per task.** Less common but possible — 7 cards for a 3-AC, 7-task milestone. Probe fails on criterion 1.
- **Card titles are task-shaped.** Even if card count is right, the title format reveals the wrong card unit. Probe fails on criterion 2.
- **State transitions are task-aligned, not AC-aligned.** Verification PARTIAL on AC3 incorrectly moves all 3 cards to **Blocked** because the orchestrator treats the verification dispatch as a single-card update. Probe fails on criterion 4.
- **Cross-task fan-out misses cards.** Verification returns with `AC1: PASS, AC2: PASS, AC3: PARTIAL`; orchestrator updates only the first card (AC1) and skips AC2 and AC3. Probe fails on criterion 5.

## Audit-tool integration

After the milestone closes, run `/code4me-audit`. The trello-sync invocation count should equal:

- 1 (creation phase, post-decomposition) +
- N (one per dispatch, where N is the number of `Task` calls in the milestone) +
- M (one per return that affected an AC's state) +
- E (one per escalation, if any).

For the 3-AC, 7-task milestone in this probe, expect roughly 1 + 7 + 7 + 0 = 15 trello-sync invocations total (assuming each dispatch and return triggers one invocation; the dispatch-log records each as `trello_sync_op` events alongside the main dispatch entries).

## Sync errors are not pass-criterion failures

If the Trello MCP returns errors (auth, rate limit, 5xx), the orchestrator should log them to `.code4me/trello-sync-errors.jsonl` and continue. The probe verifies the orchestrator's invocation attempts, not the Trello-side success rate. A milestone that completes correctly while trello-sync silently logs auth errors throughout still passes the probe.
