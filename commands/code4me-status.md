---
description: Read-only snapshot of the .code4me/ working directory. Shows active milestones, in-flight tasks, recent dispatch log entries, open INSIGHTs, and pending Conversation-Mode promote-or-revert deadlines. Optional argument restricts output to a specific milestone ID.
argument-hint: [milestone_id]
---

Produce a read-only status snapshot of the code4me working directory at the
project root. **Do not modify any files. Do not dispatch any subagents.**

If a `milestone_id` argument is provided, filter the report to that milestone.
Otherwise report on all active milestones.

Procedure:

1. Check whether `.code4me/` exists at the project root. If not, surface:
   *"No `.code4me/` directory found - run `/code4me-init` to scaffold one; this
   project has not dispatched any code4me work yet."* Then stop.
2. Read `.code4me/milestone-status-tracker.md`. List active milestones, filtered
   to the argument if one was provided.
3. For each active milestone, read `.code4me/insight-register-{milestone_id}.md`
   if present. Surface INSIGHTs with impact tier `suggested change` or
   `required change before next similar task`; summarize informational INSIGHTs
   as a count only.
4. Read the last 20 lines of `.code4me/dispatch-log.jsonl` if present. Summarize
   timestamp, milestone, subagent, vendor/tier, and outcome.
5. Scan `.code4me/conversation-notes/` for Conversation Mode notes with pending
   promote-or-revert deadlines. List any approaching or overdue deadlines.
6. If Basic Memory MCP tools are available, surface up to three recent relevant
   durable notes for the active milestone or project. Skip silently if Basic
   Memory is not configured.

Output one markdown block:

```markdown
# code4me status - {timestamp}

## Active milestones

[table: milestone_id, opened, weight, current task, current state]

## INSIGHTs requiring attention

[list suggested-change and required-change INSIGHTs]

## Recent dispatches (last 20)

[table: ts, milestone, subagent, vendor:tier, outcome]

## Conversation Mode deadlines

[list pending promote-or-revert deadlines]

## Basic Memory

[recent relevant notes, if configured]
```

If any read fails, note it in the report and continue with the information that
is available.

Argument:

$ARGUMENTS
