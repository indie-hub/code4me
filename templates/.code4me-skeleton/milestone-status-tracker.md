# Milestone Status Tracker — {milestone_id}

The canonical state-of-play table for this milestone. The orchestrator updates it on every dispatch, completion, blocker, and auto-escalation so the next session can resume from a known state without re-deriving context.

## Tasks

| task_id | subagent | vendor:model | status | started | completed | notes |
|---|---|---|---|---|---|---|
| {milestone_id}-T01-DEV | developer | anthropic:sonnet | COMPLETE | 2026-05-15T09:12Z | 2026-05-15T09:47Z | smoke test green; touched `src/ui/Welcome.cs` |
| {milestone_id}-T02-DEV | codex-developer | openai:gpt-5-codex | DISPATCHED | 2026-05-15T10:02Z |  | cross-vendor implementation; protected-tests list forwarded |

Valid `status` values: `PENDING`, `DISPATCHED`, `COMPLETE`, `BLOCKED`, `REWORK`, `ESCALATED`.

## Auto-escalation log

| date | task_id | from_weight | to_weight | symptom_class |
|---|---|---|---|---|

## Notes

- Update on every state change. Persist artifacts before declaring a task complete.
- `vendor:model` column uses the notation defined in `references/model-selection.md` (`anthropic:<tier>` for Claude-side dispatch, `openai:<codex_model>` for Codex-shim dispatch).
- When auto-escalation fires, record the trigger in the auto-escalation log per `references/auto-escalation.md`.
