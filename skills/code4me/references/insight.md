# INSIGHT Message Rule

INSIGHT carries a discovered fact upstream — a learning that should adapt a spec, test plan, Context Pack, or future task — when the discovery does not fit any existing message type.

## Distinct from neighbouring types

- **QUESTION** blocks the sender; INSIGHT does not.
- **STATUS_UPDATE** reports where the sender is; INSIGHT reports something the sender now knows that someone else needs.
- **BUG_REPORT** reports a defect; INSIGHT reports a non-defect learning — a gap in the spec, a load-bearing assumption that turned out to need stating, an opportunity outside the current scope.

## When subagents send INSIGHT

A subagent emits an INSIGHT in its return payload when, mid-task, it discovered something that should adapt an upstream artifact or future work, but the discovery did not block the current task and is not a defect.

Examples:

- Developer discovers the Tech Spec's error-handling section is silent on a real failure mode the implementation can plausibly handle either way → INSIGHT to architects
- Verification finds the Test Spec misses a boundary the AC nonetheless covers → INSIGHT to Spec-to-Test
- QA notices a UX inconsistency unrelated to the AC → INSIGHT to user (PO)
- Researcher finds a tangential constraint affecting a future milestone → INSIGHT to user

## How you (the orchestrator) handle INSIGHTs

When a subagent's return payload includes an INSIGHT entry:

1. **Do not pause the workflow.** INSIGHT is non-blocking by design.
2. **Forward to the target.** If the target is a role (e.g., "Lead Architect"), include the INSIGHT in the next dispatch to that subagent. If the target is the user (PO or future milestone), surface it directly with the impact tier explicit.
3. **Log to the Insight Register.** Append to `.code4me/insight-register-{milestone_id}.md` with: sender role, target, discovered fact, impact tier, date.
4. **Act on impact tier:**
   - `informational` → log only; surface in the next retrospective
   - `suggested change` → log + surface to recipient with a recommendation
   - `required change before next similar task` → log + create a follow-up task in the Milestone Status Tracker before the next similar task is dispatched

## Required envelope

When parsing a subagent's INSIGHT entry, expect:

- `task_id` — the task during which the insight was discovered
- `sender_role` — the subagent that emitted it
- `discovered_fact` — one paragraph in plain language
- `target` — artifact path or role (Tech Spec TS-014, Test Spec TEST-014, Milestone Spec M03, Lead Architect, Product Owner, or a future milestone reference)
- `impact_tier` — one of `informational`, `suggested change`, `required change before next similar task`
- `recommendation` — optional

## What INSIGHT is not

INSIGHT does not replace QUESTION (when blocked), BUG_REPORT (when behaviour is wrong), the Scope Change process (when requirements have actually changed), or HUMAN_DIRECTOR_ESCALATION (for safety, security, or privacy concerns).

If a subagent's INSIGHT actually describes a defect, a blocker, a real scope change, or a safety concern, route it through the appropriate channel and log a note that the message type was wrong (use it as input to the retrospective).

## Batching

If multiple INSIGHTs converge on the same upstream artifact within a short window, batch them. The upstream role should not receive a flood of single-fact messages where one summary would do.

## Integration with OpenWolf cerebrum

If the project has OpenWolf installed (a `.wolf/` directory at the project root containing `cerebrum.md`), an INSIGHT with impact tier `required change before next similar task` is structurally identical to a Do-Not-Repeat entry. When you log such an INSIGHT to the per-milestone Insight Register, also append a corresponding line to `.wolf/cerebrum.md` under the appropriate section ("Do-Not-Repeat", "User Preferences", or "Key Learnings", depending on shape).

The two stores have different jobs and don't redundantly duplicate. The Insight Register is per-milestone audit (which milestone, which task, which subagent surfaced it). `cerebrum.md` is cross-project memory: a `required` learning from milestone M03 should not have to be re-learned in milestone M04. Bridging them avoids that re-learning cost.

Format for the cerebrum.md append:

```
- {date}: {one-line distillation of the discovered fact} (source: INSIGHT {task_id})
```

Do **not** append to `cerebrum.md` for `informational` or `suggested change` impact tiers — those stay in the Insight Register only. The cross-project memory should accumulate only learnings the user has effectively authorised by virtue of the `required` impact-tier label, since that tier already implies "change behaviour for the next similar task."

If the project does not use OpenWolf, this integration is a no-op; the Insight Register stands alone.
