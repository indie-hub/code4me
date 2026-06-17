# Circuit Breakers

Thresholds that, when crossed, halt routine workflow and force user escalation. These exist to surface stuck work before it consumes disproportionate effort. Absorbing repeated rework, indefinite blockers, or runaway scope changes silently is not acceptable — the circuit breakers turn those failure modes into visible escalations.

## Rework Limit

If a task enters REWORK three or more times for the same underlying issue, the orchestrator must pause the task and escalate to the user. The fourth rework attempt requires explicit user approval before dispatching.

The escalation must include:

- the task history (what failed at each attempt, what the Developer fixed, what failed again)
- the suspected root cause
- a recommended next step (one of: re-scope, re-architect, abandon, continue with extra scrutiny)

A pattern of "same gate fails repeatedly for the same root cause" is the signal. Different roots that happen to fail in sequence are not the same issue — the breaker is for *recurrence*, not raw count.

## Blocker Dwell Limit

If a task has been in BLOCKED state without resolution for longer than two follow-up cycles, the orchestrator must escalate to the user.

A "follow-up cycle" is one round of the orchestrator attempting to resolve the blocker — asking the relevant role for clarification, re-issuing the Context Pack, dispatching a research task. Two cycles without movement means the routine resolution path isn't working.

The escalation must include:

- the blocker description
- what was requested and from whom
- what has been tried to resolve it
- the impact on the milestone (other blocked tasks, deadline risk)
- a recommended next step

## Scope Change Limit

If more than two scope changes occur within a single milestone, the orchestrator must escalate to the user to assess whether the milestone definition is stable enough to continue.

A "scope change" is any post-Tech-Spec-approval modification to the requirements that triggers an Amendment or Re-scope path. Minor clarifications inside the existing scope don't count.

The escalation must include:

- the original Milestone Spec
- each scope change in order, with dates and classifications (Amendment vs. Re-scope)
- which tasks were re-planned, paused, or invalidated by each change
- a recommended next step (continue with current scope, freeze and ship what's done, abandon and re-scope from scratch)

## Auto-Escalation Override (related but distinct)

The auto-escalation symptom classes in `auto-escalation.md` are not circuit breakers in the stuck-work sense — they're routing instructions that fire on detection rather than on accumulated failure. But they share the framing: when a hard threshold is met, the orchestrator stops routine routing and forces a higher-touch path.

Specifically:
- Circuit breakers fire on **accumulated failure** (3 reworks, 2 stuck cycles, >2 scope changes)
- Auto-escalation fires on **symptom detection** (auth touched, sensitive data, cross-cutting concerns, etc.)

Both result in user notification, but the framing is different: circuit breakers ask the user to make a judgment about whether to continue; auto-escalation tells the user the framework already corrected a routing instruction.

## HUMAN_DIRECTOR_ESCALATION format

When the orchestrator escalates to the user (whether via circuit breaker or other escalation rule — architecture deadlock, safety/security concern, milestone at risk), the message follows this shape:

```
[ESCALATION] {milestone_id} — {one-line topic}

Why escalating:
  {one paragraph: which rule fired, what triggered it}

What's been tried:
  - {step}
  - {step}
  - {step}

Impact:
  {what's blocked, what's at risk, what deadline pressure exists}

Recommended next step:
  {one of the rule-specific options}

Decision needed from you:
  {explicit ask — the user's choice should be one of a small set}
```

The escalation is not a status update — it's a request for a decision. The orchestrator should pause the affected work until the user responds.

If the issue is an active incident (production is broken, data is leaking, etc.), any subagent may escalate directly to the user without going through the orchestrator's normal routing — speed matters more than chain of command during incidents.

## What circuit breakers are not

- Not a substitute for good classification at intake. If you're constantly hitting the Rework Limit on Standard tasks that should have been Light, the answer is fixing the classification, not raising the limit.
- Not punitive. The breaker firing isn't a mark against the team — it's a signal that the routine path isn't working for this particular task.
- Not silent. Every breaker firing produces a visible escalation; the user sees it. Internal absorption ("I'll just try one more rework") defeats the purpose.

## Recording

Every circuit breaker firing is logged to the Milestone Status Tracker:

- Which breaker (Rework / Blocker Dwell / Scope Change)
- When it fired
- What triggered it
- What the user decided
- Final outcome

These records feed the Post-Milestone Retrospective. Patterns of repeated breaker firings across milestones — same task type, same kind of blocker, same scope-change source — are the signal for tuning intake classification, the auto-escalation list, or the workflow weight tables.
