# `.code4me/` Skeleton

This directory is the seed layout the code4me orchestrator copies into a project's root on first run when no `.code4me/` directory already exists. It establishes the canonical artifact locations referenced in `skills/code4me/references/canonical-artifacts.md` so subagents can persist their outputs at predictable paths.

Contents:

- `milestone-status-tracker.md` — template for the per-milestone status table. The orchestrator renames or duplicates it as `milestone-status-{milestone_id}.md` and updates it on every state change. Tracks task ID, dispatched subagent, concrete `vendor:model`, requested effort, status, timestamps, and notes.
- `insight-register-TEMPLATE.md` — template for the per-milestone INSIGHT register. The orchestrator renames it as `insight-register-{milestone_id}.md` and appends entries as subagents emit INSIGHTs in their return payloads. Envelope shape comes from `skills/code4me/references/insight.md`.
- `conversation-notes/` — destination for Conversation-weight `Conversation Note` artifacts. Populated by the orchestrator from `templates/conversation_note.md` per task.
- `milestone-specs/` — destination for Light / Standard / Critical Milestone Specs.
- `tech-specs/` — destination for Tech Specs authored by the Lead Architect and approved by the Challenger Architect.

The orchestrator copies this skeleton on first run when `.code4me/` doesn't exist at the project root. Subsequent runs leave the existing layout untouched.
