# Insight Register — Milestone {milestone_id}

Per-milestone audit log of INSIGHT envelopes emitted by subagents. The orchestrator appends to this file whenever a subagent's return payload contains an `insights` entry. Envelope shape and routing rules come from `skills/code4me/references/insight.md`.

Entries are grouped by impact tier. Within each section, newest entries go at the bottom.

## Informational

- **task_id:** {milestone_id}-T01-DEV
  **sender_role:** developer
  **discovered_fact:** The Welcome screen module uses a string-table lookup for greetings, but the lookup helper is colocated with the view rather than the localization service. Tangential to the current change.
  **target:** Lead Architect
  **impact_tier:** informational
  **recommendation:** Consider relocating the helper during the next refactor pass; not blocking.

## Suggested changes

## Required changes before next similar task

---

**Notes:**

- INSIGHT does not block the workflow; the orchestrator forwards and logs without pausing.
- `required change before next similar task` entries also append a one-line distillation to `.wolf/cerebrum.md` when OpenWolf is configured (see `references/insight.md`).
- If a subagent's "INSIGHT" actually describes a defect, blocker, scope change, or safety concern, route it through the appropriate channel instead and note the mis-labelling for the retrospective.
