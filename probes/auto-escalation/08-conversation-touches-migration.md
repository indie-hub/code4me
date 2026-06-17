# Probe: Declared Conversation that requires a data migration

**Subject:** auto-escalation
**Coverage:** Catches the failure mode where "just add a nullable column" reads as small but is in fact a schema migration. The orchestrator must apply the migration symptom class regardless of how the user framed the work.

## Input prompt

> Add a nullable `lastSeenAt` column to the users table — it's just a column, should be quick. Run it as Conversation.

## Expected

- **Kind:** product
- **Weight:** Standard (escalated from Conversation by the override)
- **Auto-escalation:** triggered — cite the exact symptom-class string `changes that require data migration or feature-flagged rollout`
- **Team:** lead-architect, challenger-architect, spec-to-test, developer, verification, code-reviewer, qa, doc-writer
- **Order/notes:** Conversation Mode forbids changes that require data migration or feature-flagged rollout (see `conversation-mode.md` forbidden conditions). Notify-not-ask phrasing required: *"the work touches changes that require data migration or feature-flagged rollout, so I'm escalating the weight from Conversation to Standard."* Record the trigger in the Milestone Status Tracker.

## Pass criterion

Orchestrator escalates to Standard, quotes the data-migration symptom-class string verbatim, references the matching Conversation Mode forbidden condition, frames the message as a notification (not a request), and dispatches the Standard team.

## Failure modes this catches

- Orchestrator accepts the Conversation framing because the user emphasised "just a column" — auto-escalation does not weigh user reassurance.
- Orchestrator escalates only to Light — the override floor is "at least Standard," and Light is below it.
- Orchestrator escalates but cites the wrong symptom class (e.g. sensitive-data) or paraphrases the migration class instead of quoting `changes that require data migration or feature-flagged rollout` verbatim.
