---
description: Read-only snapshot of the .code4me/ working directory. Shows active milestones, in-flight tasks, recent dispatch log entries, open INSIGHTs, and any pending Conversation-Mode promote-or-revert deadlines. Optional argument restricts to a specific milestone ID.
argument-hint: [milestone_id]
---

Produce a read-only status snapshot of the code4me working directory at the project root. **Do not modify any files. Do not dispatch any subagents.**

If a milestone_id argument is provided, filter the report to that milestone. Otherwise report on all active milestones.

Procedure:

1. Check that `.code4me/` exists at the project root. If not, surface: *"No `.code4me/` directory found — run `/code4me-init` to scaffold one, or this project hasn't dispatched any code4me work yet."* and stop.
2. Read `.code4me/milestone-status-tracker.md`. List active milestones (filter to the argument if given).
3. For each active milestone, read `.code4me/insight-register-{milestone_id}.md` if present. Surface any INSIGHTs with impact tier `suggested change` or `required change before next similar task` (informational tier is summarised by count only).
4. Read the last 20 lines of `.code4me/dispatch-log.jsonl` if present. Summarise: which subagent, which weight, vendor/tier, outcome.
5. Scan `.code4me/conversation-notes/` for Conversation Mode notes with pending promote-or-revert deadlines. List any approaching or overdue.
6. If OpenWolf is configured (`.wolf/` exists), surface the last 3 `cerebrum.md` entries added since the most recent milestone open.

Output as a single markdown block:

```
# code4me status — {timestamp}

## Active milestones
[table: milestone_id, opened, weight, current task, current state]

## INSIGHTs requiring attention
[list of suggested-change and required-change INSIGHTs]

## Recent dispatches (last 20)
[table: ts, milestone, subagent, vendor:tier, outcome]

## Conversation Mode deadlines
[list of pending promote-or-revert deadlines]

## OpenWolf cerebrum (recent additions, if configured)
[brief list]
```

If any read fails, note it in the report but continue with what's available.

Argument:

$ARGUMENTS
