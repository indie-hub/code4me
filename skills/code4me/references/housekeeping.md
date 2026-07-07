# Housekeeping (session-boundary checkpoint)

The `/code4me-housekeeping` slash command invokes a session-boundary audit + handoff. This document is the load-bearing reference: it lists every audit check the orchestrator runs, the handoff manifest's schema, the resume protocol the next session follows when a handoff exists, and the failure modes the audit catches.

Read this when invoking the housekeeping command — the operating loop and the command file both reference it.

## When to invoke

The user invokes `/code4me-housekeeping` when they're about to:

- Close the Claude Code session
- Run `/clear` to reset context
- Walk away from a milestone for several hours / days
- Hand off to another user / themselves on another machine

The command is also safe to invoke any time as a sanity check on the project's `.code4me/` state. It's read-only on project files (the only write is the handoff manifest under `.code4me/handoff-*.md`).

## Audit checklist

For each milestone in `.code4me/milestone-status-tracker.md` with `state ≠ closed`, the orchestrator runs the following checks. Each produces ✓ / ⚠ / ✗ in the report.

### 1. Dispatch log integrity

- Read the last N (default 50) lines of `.code4me/dispatch-log.jsonl`.
- For each entry, parse the JSON. Lines that fail to parse → ✗ with the offending line number.
- For each subagent dispatch entry (`subagent ≠ "orchestrator-inline (trivial)"`), check there's a corresponding return either in the same entry (some dispatches log return inline) or in a subsequent entry referencing the same `task` field. Entries without a return → ⚠ "in-flight dispatch".
- The result determines the verdict's NOT-READY condition: **any in-flight dispatch → NOT-READY**.

### 2. Milestone tracker freshness

- For each active milestone in the tracker, find the most recent dispatch-log entry mentioning that milestone (by `milestone` field).
- Compare against the tracker's `last_updated` timestamp for that milestone.
- If the tracker is older than the most recent dispatch → ⚠ "tracker stale".
- Persistent staleness → ✗ "tracker not bookkept" — recommend re-reading the dispatch log and writing the latest state.

### 3. AC state currency (v0.12+, Standard/Critical only)

- For each Standard/Critical milestone, read the `acceptance_criteria:` block from the tracker.
- For each AC, find the most recent verification report touching this milestone (`subagent: verification`, mode `suite-run` or `ac-coverage`). If found, compare the verification's AC coverage table against the AC's `state` and `last_verification_status` in the tracker.
- If verification says `PASS` but tracker says `in_progress` → ⚠ "AC state lagging behind verification".
- If verification says `FAIL` but tracker says `done` → ✗ "AC state incorrectly advanced".

### 4. Artefact persistence

- For each task in the tracker, check the expected artefact exists:
  - Conversation Mode → `.code4me/conversation-notes/{task_id}.md`
  - Standard/Critical → `.code4me/tech-specs/{task_id}.md` AND `.code4me/test-specs/{task_id}.md`
  - Verification dispatched → look for a verification-report artefact reference in the dispatch return.
- Missing artefact for a dispatched task → ⚠ "artefact not persisted".

### 5. Orphan files

- List every file under `.code4me/tech-specs/`, `test-specs/`, `conversation-notes/`, `milestone-specs/`.
- Cross-reference against the tracker's known task and milestone IDs.
- Files not referenced from any tracker entry → ⚠ "orphan artefact" with the file path.

### 6. Trello sync state

- If `.code4me/trello-config.json` exists:
  - Read `.code4me/trello-sync-errors.jsonl` (if exists). Count entries from this session (since the last successful trello-sync log line).
  - Note the timestamp of the most recent successful sync (if visible in the dispatch log's `trello_sync_op` events).
  - Errors in this session → ⚠ "trello sync errors"; the manifest names the affected milestones.
- If no `.code4me/trello-config.json` → skip (no Trello configured).

### 7. Basic Memory flush

- If Basic Memory MCP tools are available:
  - Read the milestone's insight register for `impact: required change before next similar task` entries from this session.
  - For each, search Basic Memory for the insight's text or topic.
  - Required-impact INSIGHTs not in Basic Memory -> "memory not flushed"; recommend writing a durable note before close.
- If Basic Memory is unavailable -> skip.

### 8. Hook state files

- `.code4me/protected-tests.txt` should exist for any Standard/Critical milestone with Spec-to-Test dispatched.
- `.code4me/forbidden-conditions.json` should exist if and only if a Conversation Mode task is active and the orchestrator dispatched the Developer.
- `.code4me/critical-allowlist.txt` should exist if and only if a Critical milestone is active.
- Discrepancies → ⚠ with the specific mismatch.

### 9. Pending user actions

Not strictly an audit check — surfaces work the user must address. Scan for:

- Conversation Mode tasks with `state: PROVISIONAL` and any promote-or-revert deadline (not just approaching/overdue — list all PROVISIONAL with their deadlines).
- Tasks in state `BLOCKED` from circuit breakers (Rework Limit, Blocker Dwell, Scope Change).
- Tasks in state `PENDING_USER` from `NEEDS_DECISION` / `HUMAN_DIRECTOR_ESCALATION` / Co-Approval disagreements.
- INSIGHTs with `impact: required change before next similar task` not yet acknowledged.

Each pending action becomes one numbered item in the report with the specific slash command or decision the user must invoke.

## Verdict computation

After running all checks:

- **READY** — every check ✓; zero pending user actions.
- **READY-WITH-NOTES** — every check ✓; one or more pending user actions exist but nothing in-flight, blocked, or stale.
- **NOT-READY** — at least one ✗ OR at least one ⚠ in-flight dispatch.

NOT-READY blocks the handoff manifest write — the session has unresolved state that the next session would inherit incorrectly. Recommend resolving (wait for return, dispatch missing artefact persist, decide on the BLOCKED escalation) before re-running `/code4me-housekeeping`.

## Handoff manifest schema

Written to `.code4me/handoff-{ISO8601}.md` when the verdict is READY or READY-WITH-NOTES. Markdown with structured sections.

### Schema

```markdown
# Code4Me handoff — {ISO8601}

## Session summary

**Generated:** {ISO8601}
**Verdict at generation:** {READY | READY-WITH-NOTES}
**Active milestones at generation:** {count}
**Dispatches this session:** {count}
**Pending user actions:** {count}

## Active milestones

For each active milestone:

### {milestone_id}: {summary}

- **Weight:** {Conversation | Light | Standard | Critical}
- **Kind:** {product | bug-fix | tech-debt | spike | incident | scope-change}
- **Opened:** {ISO8601}
- **State:** {classified | dispatched | in-review | blocked | pending-user | provisional}
- **Acceptance criteria** (Standard/Critical):
  - `{ac_id}` — {state} — {tasks_touching list}
  - ...
- **Last dispatch affecting this milestone:** {ts, subagent, outcome}
- **Suggested resume step:** {specific slash command or next dispatch}

## Pending user actions

For each pending action:

### Action {N}: {one-line summary}

- **Task ID:** {task_id} (if applicable)
- **Why:** {circuit breaker / PROVISIONAL deadline / NEEDS_DECISION reason}
- **Deadline:** {ISO8601 if applicable, "none" otherwise}
- **What to do:** {exact slash command OR a description of the decision required}

## Recent dispatches (last 10)

```jsonl
{ts} — {subagent} ({vendor:tier}) → {outcome} — {milestone}-{task}
...
```

## Recent INSIGHTs (last 5)

- `{ts}` [{impact}] **{sender_role} → {target_role}**: {discovered_fact_excerpt}

## Persistence state at generation

- Dispatch log entries: {count}
- Milestone trackers updated: {count}
- Artefacts written this session: {count}
- INSIGHTs routed this session: {count}
- Required-impact INSIGHTs flushed to Basic Memory: {count}
- Trello sync last successful: {ISO8601 or "N/A"}

## Resume guidance

Specific to the verdict at generation:

- If READY: any session can resume work; the orchestrator should consult Basic Memory first (as always) and then proceed.
- If READY-WITH-NOTES: address the pending actions before dispatching new work, OR explicitly defer them.

## File version

`handoff-schema-v1` — for future-proofing if the schema changes.
```

### Naming convention

`.code4me/handoff-{ISO8601}.md` where the ISO8601 uses hyphens for colons (filesystem-safe), e.g., `handoff-2026-06-02T14-35-00Z.md`.

Multiple handoff manifests accumulate over time. Recommend periodic cleanup (manually or via a future `--prune` flag) of files older than 30 days. The most recent is the canonical one for resume.

## Resume protocol

When a new Claude Code session opens against a project containing handoff manifests, the orchestrator's operating-loop step 1 ("Consult Basic Memory first") extends to:

1. If Basic Memory MCP tools are available, search them for current project context.
2. List `.code4me/handoff-*.md` files. If any exist, read the **most recent one by ISO8601 timestamp**.
3. The manifest's "Active milestones" and "Pending user actions" sections become the resumed context.
4. The orchestrator does NOT need to re-read the full dispatch log to understand current state — the manifest pre-digests it.
5. The orchestrator can still read `.code4me/dispatch-log.jsonl` for specific historical detail, but the manifest is the canonical "where things stand right now" reference.

This is the resume mechanism. The handoff manifest is the load-bearing piece — it lets the next session orient itself in a few hundred tokens of read rather than thousands of dispatch-log lines.

## Failure modes the audit catches

- **Mid-session crash leaves an in-flight dispatch.** Verdict NOT-READY; the user knows not to assume the milestone closed.
- **Tracker drift** — orchestrator dispatched but forgot to update the tracker. AC state currency check flags it; the user sees a specific AC whose status is stale.
- **Orphan artefacts** — a Tech Spec exists for a task the tracker doesn't know about (e.g., user manually wrote a file). Surfaces so the user can either delete the orphan or wire it into the tracker.
- **Basic Memory drift** — a `required-impact` INSIGHT landed but the orchestrator forgot to flush to Basic Memory. Caught at audit; Basic Memory gets the note before close.
- **PROVISIONAL deadline approaching, no in-flight work** — the user might have forgotten about a Conversation Mode task awaiting promote-or-revert. Surfaced explicitly with the deadline timestamp.
- **Trello drift** — Trello cards out of sync with the tracker (sync errors logged but ignored). Surfaced; user can re-run `/code4me-trello-init` or manually reconcile.

## What the audit deliberately does NOT do

- **Does not modify project source.** Read-only on the project. The only write is the handoff manifest under `.code4me/`.
- **Does not dispatch any subagent.** The audit is the orchestrator's own bookkeeping; subagents would be expensive and unnecessary.
- **Does not roll back state on NOT-READY.** It just refuses to write the manifest. The user resolves the issues by dispatching the missing work or explicitly aborting (with `/code4me-status` to see the full state, or manual edits to the tracker).
- **Does not modify Trello cards.** If Trello sync errors are surfaced, the user re-triggers sync via the next state-transition dispatch — not via housekeeping directly.
- **Does not auto-flush Basic Memory.** If a `required-impact` INSIGHT hasn't landed in Basic Memory, housekeeping surfaces it but doesn't write memory automatically. That's a user decision (some INSIGHTs may not need durable memory scope; the orchestrator shouldn't assume).

## Integration with the operating loop

The housekeeping command is invoked explicitly by the user; the orchestrator does NOT auto-trigger it. However, the operating loop's step 9 "Confirm and close" can recommend `/code4me-housekeeping` if multiple state transitions happened in this session — the user can take that suggestion or skip.

Step 1 "Consult Basic Memory first" is extended (per the resume protocol above) to also consult the most recent handoff manifest if one exists.

## Audit-tool integration (v0.12.x candidate, deferred)

A future audit-tool extension could read all handoff manifests in `.code4me/` and surveille:

- How often verdicts are READY vs. READY-WITH-NOTES vs. NOT-READY.
- Persistent NOT-READY patterns (suggests in-flight dispatches not getting tracked properly).
- Basic Memory flush lag (how often `required-impact` INSIGHTs are flagged but not yet flushed).

Out of scope for v0.12.0 — ear-tagged for v0.12.x.
