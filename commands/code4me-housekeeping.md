---
description: Session-boundary checkpoint. Audits `.code4me/` for completeness, surfaces pending user actions, writes a handoff manifest the next session can read to resume context. Use this before `/clear` or closing the session — it confirms whether everything is bookkept and safe to walk away from. Read-only on project files; the only write is the handoff manifest under `.code4me/handoff-*.md`.
---

Produce a session-boundary housekeeping report at the project root. The user wants confirmation that everything dispatched in this session has been persisted and that a follow-up session can resume cleanly. **Do not dispatch any subagents.** **Do not modify project files.** The only file you create is the handoff manifest under `.code4me/handoff-{ISO8601}.md`.

Read `skills/code4me/references/housekeeping.md` for the full audit checklist and the handoff manifest schema before producing the report.

## Procedure

1. **Check `.code4me/` exists** at the project root. If not, surface *"No `.code4me/` directory — nothing to bookkeep. Run `/code4me-init` to scaffold one."* and stop.

2. **Run the audit checks** documented in `references/housekeeping.md` §"Audit checklist". For each:
   - **Dispatch log integrity** — read the last 20 lines of `.code4me/dispatch-log.jsonl`. For each entry without a matching return (in-flight dispatch), flag it.
   - **Milestone tracker freshness** — for each active milestone, confirm the tracker's `last_updated` is newer than (or equal to) the most recent dispatch's `ts` affecting that milestone.
   - **AC state currency (v0.12+)** — for Standard/Critical milestones, confirm every AC's `state` and `tasks_touching` reflect the latest verification report's coverage table.
   - **Artefact persistence** — every dispatched task referenced in the tracker has its corresponding artefact written (Tech Spec, Test Spec, Conversation Note as applicable).
   - **No orphan files** — every file under `.code4me/tech-specs/`, `test-specs/`, `conversation-notes/`, `milestone-specs/` is referenced from a tracker entry.
   - **Trello sync state** — if `.code4me/trello-config.json` exists, check `.code4me/trello-sync-errors.jsonl` for entries newer than the last successful sync. Note the last successful sync timestamp.
   - **OpenWolf flush** — if `.wolf/cerebrum.md` exists, scan the insight register for `impact: required` entries from this session and confirm they appear in cerebrum.
   - **Hook state files** — `.code4me/protected-tests.txt`, `forbidden-conditions.json`, `critical-allowlist.txt` exist if and only if a milestone in scope requires them.

3. **Surface pending user actions** — read the tracker and scan for:
   - Conversation Mode tasks with `PROVISIONAL` tag and a promote-or-revert deadline (any).
   - Tasks in state `BLOCKED` from circuit breakers (Rework Limit, Blocker Dwell, Scope Change).
   - Tasks in state `PENDING_USER` from `NEEDS_DECISION` / `HUMAN_DIRECTOR_ESCALATION` / Co-Approval disagreements.
   - INSIGHTs with `impact: required change before next similar task` that haven't been acknowledged.
   - For each: name the action the user must take (specific slash command, deadline, or decision).

4. **Compute the verdict**:
   - **READY** — all audit checks pass; no pending user actions. Safe to `/clear` or close the session without action.
   - **READY-WITH-NOTES** — audit checks pass; one or more pending user actions exist but nothing is in-flight or blocked. Session can be closed; resume to handle the notes when convenient.
   - **NOT-READY** — at least one in-flight dispatch hasn't returned, OR the tracker is stale relative to the dispatch log, OR a circuit breaker fired in this session and hasn't been acknowledged. Do NOT close yet; address the issues first.

5. **Write the handoff manifest** to `.code4me/handoff-{ISO8601}.md` per the schema in `references/housekeeping.md` §"Handoff manifest schema". This file is what the next session reads to restore context without re-reading the full dispatch log. Use a UTC ISO8601 timestamp with colons replaced by hyphens (e.g., `handoff-2026-06-02T14-35-00Z.md`).

6. **Emit the housekeeping report** as a single markdown block with the verdict prominent at the top, followed by:
   - Active milestones with AC state summary
   - Pending user actions (numbered)
   - Persistence audit results (each check with ✓ / ⚠ / ✗)
   - Trello sync status
   - Handoff manifest path
   - "To resume in next session" — the exact step(s) the user (or next-session orchestrator) should take

## Output shape (template)

```markdown
# Code4Me housekeeping — {ISO8601}

## Verdict: {READY | READY-WITH-NOTES | NOT-READY} {✓ | ⚠ | ✗}

{One-sentence summary tied to the verdict}

## Active milestones ({count})

{per-milestone block — id, summary, weight, AC states one-line each, last dispatch, suggested resume step}

## Pending user actions ({count})

{numbered list — each item names the specific action, deadline if applicable, slash command or decision needed}

## Persistence audit

- Dispatch log: {N} entries, {X} in-flight {✓ | ⚠}
- Milestone trackers: {N} active, {X} stale {✓ | ⚠}
- Artefacts: {N} written this session, {X} orphan {✓ | ⚠}
- INSIGHTs: {N} routed, {X} required-impact flushed to cerebrum {✓ | ⚠}
- Hook state files: {applicable list and status}

## Trello sync ({if configured})

- Last successful sync: {ts}
- Errors this session: {N}

## Handoff manifest

Written to `.code4me/handoff-{ISO8601}.md`.

## To resume in next session

{specific guidance — exact slash command, file to read, or decision to make first}
```

## Special cases

- **No active milestones, no dispatches** — emit a one-paragraph verdict: *"Nothing in flight; session is fully bookkept."* No handoff manifest written (nothing to hand off).
- **`.code4me/` is fully clean** but a Conversation Mode PROVISIONAL deadline is in N days from now — verdict is `READY-WITH-NOTES`; the action item is the deadline, no in-flight dispatch.
- **Verdict is NOT-READY** — do not write the handoff manifest. Instead, surface the in-flight dispatch and recommend either waiting for it to return or escalating to the user for explicit abort.

## Why this isn't a subagent dispatch

Housekeeping is bookkeeping — same category as the audit tool and Trello sync. The orchestrator runs it inline from its own thread (no Task call). It's READ-ONLY on project files; the only write is the handoff manifest, which is the orchestrator's own bookkeeping output under `.code4me/`.
