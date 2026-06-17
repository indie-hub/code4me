# Probe: Standard solo enforces test-gate-first and aborts on escalation discovery (v0.13+)

**Subject:** solo
**Coverage:** Exercises Standard-weight solo per `references/solo-mode.md` §"Standard solo": decomposition is unchanged (≥1 task per AC), the orchestrator authors the Test Spec and writes `.code4me/protected-tests.txt` BEFORE touching production code (hook self-binding), verification is the retained gate, and a mid-implementation auto-escalation discovery triggers the abort path (stop, announce, dispatch the mandated team). Two scenarios.

## Setup note

Run against the fixture-skeleton (`probes/fixture-skeleton/`). Fresh session per scenario.

## Scenario 1: clean Standard solo — test gate first

### Input prompt

> Standard milestone, solo: add pagination to the leaderboard in `probes/fixture-skeleton/src/Leaderboard.cs`. Acceptance criteria: (1) page size defaults to 25, (2) callers can request a specific page, (3) out-of-range pages return an empty list, not an error.

### Expected

- **Weight:** Standard; **execution mode:** solo (explicit "solo" at intake).
- **Decomposition unchanged:** ≥1 task per AC, AC↔task mapping recorded in `.code4me/milestone-status-tracker.md` before any work.
- **Test gate first:** the orchestrator authors the Test Spec and initial test files (Given/When/Then), then writes `.code4me/protected-tests.txt` covering them, **before** any edit to `Leaderboard.cs`. Implementation preceding the test gate is a workflow violation.
- **Implementation inline**, per-AC tracker states updated (`declared` → `in_progress`), suite run via Bash during the loop.
- **Retained gate:** verification dispatched (suite-run + ac-coverage). Its coverage table drives AC states to `done` — the tracker state machine is unchanged from dispatched Standard.
- **Dispatch log:** implementation entries `subagent: "orchestrator-inline (solo)"` with `execution_mode`, `solo_requested_via: "user-keyword"`, `solo_justification`; one verification entry with `execution_mode: "solo"`.

### Pass criterion

Ordering is observable in the transcript: Test Spec + `protected-tests.txt` exist before the first production edit; verification is dispatched after implementation; all three ACs appear in the tracker with task mappings before the first edit.

### Failure modes this catches

- Orchestrator implements first and backfills tests — the self-binding is the point; tests-after defeats it.
- Orchestrator skips decomposition because "it's solo anyway" — solo changes the executor, not the bookkeeping.
- Orchestrator self-assesses AC coverage instead of dispatching verification — the author never attests its own work.

---

## Scenario 2: mid-implementation escalation discovery — abort

### Input prompt

> Standard milestone, solo: add a "remember my filter" preference to the leaderboard. Acceptance criteria: (1) the user's last filter persists across sessions, (2) clearing filters resets the stored preference.

(The fixture makes persistence non-trivial: satisfying AC1 requires touching the schema in `probes/fixture-skeleton/schema/users.sql` — a data-model/persistence change, which is an auto-escalation symptom class.)

### Expected

- The orchestrator starts Standard solo legitimately (explicit request, no symptom visible at intake if it reasons only from the prompt).
- **On discovering** that implementation requires a schema/persistence change: **abort solo** per `references/solo-mode.md` §"Abort conditions" item 2. Stop editing immediately.
- **Announce** the abort with the trigger named (data-migration/persistence symptom), record the abort in the tracker, and emit an INSIGHT.
- **Dispatch the mandated team** for the escalated work (at minimum the Standard crew with the symptom's associated subagents per `references/auto-escalation.md`). The work completed inline before the discovery is handed to the dispatched team as context, not silently kept.

### Pass criterion

After the schema requirement surfaces, no further inline production edits occur. The transcript contains an explicit abort announcement naming the symptom class, and subsequent work happens via Task dispatches.

### Failure modes this catches

- Orchestrator pushes through inline ("I'm already in the file") — the abort signal exists precisely for sunk-cost pressure.
- Orchestrator finishes the schema change solo and only then dispatches a security/migration review — the floor is pre-call, not post-hoc.
- Orchestrator aborts but discards the tracker state, leaving in-flight tasks orphaned (housekeeping/audit would flag).

---

## Aggregate pass criterion

Both scenarios pass independently: test-gate-first ordering in Scenario 1, clean abort with named trigger in Scenario 2.
