# Auto-Escalation Override

The user-declared workflow weight does **not** override these symptom classes. When any apply, you must escalate the weight to at least Standard regardless of what the user declared.

## Symptom classes

Escalate to at least Standard when any of the following appear in the work:

- cross-user data leakage
- shared-state corruption
- session-isolation failures
- authorization boundary violations
- concurrency-correlated regressions
- changes to authentication, authorisation, or sensitive-data handling
- new external dependencies (third-party packages, services, APIs, libraries)
- changes that require data migration or feature-flagged rollout

## When to evaluate

Evaluate the symptom-class list at three points:

1. **At intake**, after the user has described the work and declared a weight. Use the description plus any code references the user provides.
2. **After Conversation Note or Milestone Spec creation**, before dispatching the first subagent.
3. **Mid-flight**, when a subagent reports something in its progress that suggests a symptom class applies. Subagents must surface this in their return payload — for the Developer subagent specifically, see its system prompt for the `forbidden_condition_encountered` field.

## Procedure when an auto-escalation triggers

You are not asking permission. You are correcting a routing instruction. Procedure:

1. **Pause the task.** If a subagent has already been dispatched, do not dispatch the next one.
2. **Reissue the Context Pack** at the new weight using the appropriate variant.
3. **Add `security-reviewer (mode=diff-focused)` to the team for this milestone**, cite the symptom class that triggered, and treat its outcome as a hard floor — Critical findings fail the gate. This is the agent that fills the space the escalation creates; without it the escalation is procedural-only.
4. **Notify the user** with a status message. Do not phrase it as a request. Frame it as: *"the work touches {symptom class}, so I'm escalating the weight from {declared} to Standard and adding `security-reviewer` to the team."*
5. **Record** the escalation, the trigger (which symptom class fired), and the date in the Milestone Status Tracker. Also record `security-reviewer` as added-by-auto-escalation in the team composition.
6. **Resume** at the new weight. Previously completed work is not re-gated unless the escalation reveals a defect.

If the user disputes the auto-escalation, route the dispute to the user as Human Director rather than de-escalating. The override is a circuit breaker, not a default.

## Why this is non-negotiable

The whole point of letting the user declare a lighter weight is to make everyday work fast without compromising on the work that genuinely matters. The auto-escalation override is the safety net that makes the lighter weights *safe to declare*. Without it, the lighter weights would have to be conservative; with it, the user can confidently declare Conversation knowing that anything truly load-bearing will be caught by the orchestrator.

This is not the user failing to classify — it is the system protecting the system. Frame it that way when you notify.
