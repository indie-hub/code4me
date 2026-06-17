# Probe: /code4me-housekeeping writes a handoff manifest and produces the correct verdict (v0.12+)

**Subject:** housekeeping
**Coverage:** Verifies the `/code4me-housekeeping` slash command (1) runs the audit checklist from `references/housekeeping.md`, (2) computes the correct verdict (READY / READY-WITH-NOTES / NOT-READY), (3) writes a handoff manifest at `.code4me/handoff-{ISO8601}.md` when the verdict is READY or READY-WITH-NOTES, (4) emits the housekeeping report in the documented shape, and (5) does NOT dispatch any subagent or modify project source.

## Scenarios

### Scenario A — READY (clean close)

#### Fixture

`.code4me/` contains:
- `milestone-status-tracker.md` with one closed milestone (`state: closed`), no active milestones
- `dispatch-log.jsonl` with 5 entries, all with return outcomes
- Nothing in `pending` state, no PROVISIONAL Conversation Mode tasks, no BLOCKED entries
- No Trello config

#### Input prompt

> `/code4me-housekeeping`

#### Expected

- Verdict: **READY ✓** at the top of the report
- All audit checks return ✓
- Pending user actions: 0
- Handoff manifest written to `.code4me/handoff-{ISO8601}.md`
- Manifest contains: session summary block, "Active milestones: none" or empty list, recent dispatches (last 5), persistence-state summary, "Resume guidance" section noting READY status
- Report ends with "To resume in next session" naming the manifest path

### Scenario B — READY-WITH-NOTES (pending actions, nothing in-flight)

#### Fixture

`.code4me/` contains:
- One active milestone with all dispatches returned
- One Conversation Mode task in `state: PROVISIONAL` with promote-or-revert deadline 3 days from now
- One INSIGHT with `impact: required change before next similar task` flushed to `.wolf/cerebrum.md`

#### Expected

- Verdict: **READY-WITH-NOTES ⚠**
- Audit checks all ✓
- Pending user actions: 1 (the PROVISIONAL task with its deadline)
- Action entry names the specific slash command: `/code4me-promote-or-revert <task_id> promote` (or `revert`)
- Handoff manifest IS written (READY-WITH-NOTES still permits the write)
- The manifest's "Pending user actions" section lists the PROVISIONAL task

### Scenario C — NOT-READY (in-flight dispatch)

#### Fixture

`.code4me/` contains:
- One active milestone with an in-flight dispatch (a `subagent` log entry with no matching return)

#### Expected

- Verdict: **NOT-READY ✗**
- Dispatch log integrity check flags the in-flight dispatch by task ID
- Handoff manifest is NOT written
- Report ends with "Resolve the in-flight dispatch before re-running `/code4me-housekeeping`" guidance

### Scenario D — NOT-READY (tracker stale relative to dispatch log)

#### Fixture

`.code4me/` contains:
- One active milestone whose tracker `last_updated` is older than the most recent dispatch-log entry affecting it (orchestrator dispatched but forgot to update the tracker)

#### Expected

- Verdict: **NOT-READY ✗**
- Milestone tracker freshness check flags the staleness
- Handoff manifest is NOT written
- Report names the specific milestone and the tracker's stale timestamp vs. the dispatch's newer timestamp

## Pass criterion (across all scenarios)

1. The command does NOT dispatch any subagent (no `Task` calls; no codex-bridge or deepseek-bridge invocations).
2. The command does NOT modify project source. The only write is the handoff manifest.
3. The verdict reflects the audit checks correctly per `references/housekeeping.md` §"Verdict computation".
4. NOT-READY scenarios do NOT produce a handoff manifest.
5. READY and READY-WITH-NOTES scenarios DO produce a handoff manifest, with the documented schema (file version `handoff-schema-v1`, all required sections present).
6. The report's "Pending user actions" section is empty in Scenario A and lists at least one action in Scenario B.
7. The handoff manifest filename uses filesystem-safe ISO8601 (hyphens for colons): `handoff-2026-06-02T14-35-00Z.md`.

## Failure modes this catches

- Orchestrator dispatches a subagent (e.g., calls a Verification subagent to "audit the milestone") — workflow violation; housekeeping is read-only orchestrator bookkeeping.
- Orchestrator modifies tracker / artefacts during housekeeping — write-side-effects must not happen except the handoff manifest.
- Orchestrator writes a handoff manifest under NOT-READY — defeats the verdict's purpose.
- Orchestrator computes verdict READY despite an in-flight dispatch — audit check missed.
- Orchestrator computes verdict NOT-READY despite all checks ✓ — false alarm; user can't close cleanly.
- Manifest is missing required sections (Session summary / Active milestones / Pending actions / Recent dispatches / Persistence state) — partial write, breaks the resume protocol.
- Manifest filename uses colons (`handoff-2026-06-02T14:35:00Z.md`) — fails on filesystems that disallow colons in filenames (Windows + some Linux setups).

## Resume-protocol companion check

After Scenario A or B writes a handoff manifest, opening a fresh Claude Code session in the project should result in the orchestrator's operating-loop step 1 reading the manifest (per `references/housekeeping.md` §"Resume protocol"). This sub-test isn't part of `01-handoff-manifest-written.md` per se; it's covered by `probes/housekeeping/02-resume-from-handoff.md` (deferred to v0.12.x).

## Audit-tool integration

Not yet — handoff manifests don't surface in the audit tool today. v0.12.x candidate: an "Handoff health" section counting READY / READY-WITH-NOTES / NOT-READY verdicts across the project's manifest history, surfacing patterns (e.g., persistent NOT-READY suggests dispatches aren't getting tracked properly).
