# Canonical Workflow

The Standard-mode workflow path, the gates that govern it, and the contract every subagent's return must satisfy. Critical Mode adds gates on top of this; Light and Conversation Mode are deliberately lighter paths and do not run the full canonical sequence.

## The path

```
Product intent (from user)
    ↓
Lead Architect produces architecture proposal
    ↓
Challenger Architect critiques (mandatory; must name at least one alternative)
    ↓
Architecture Discussion converges (or escalates to user)
    ↓
Lead Architect drafts Tech Spec
    ↓
Challenger Architect reviews; both architects sign off explicitly (Architecture Co-Approval Rule)
    ↓
Lead Architect drafts Execution Dependency Plan; Challenger confirms
    ↓
[Pre-Implementation Test Gate]
    ↓
Spec-to-Test produces Test Spec + initial test skeletons
    ↓
[Implementation Gate — Developer start conditions met]
    ↓
Developer implements
    ↓
[Quality Gate Loop — Verification → Code Review → QA, with re-run rules on failure]
    ↓
Documentation Writer produces user docs (in parallel with technical docs from Developer)
    ↓
Producer marks production-ready, user signs off, Release Announcement
```

The orchestrator drives each step by dispatching the appropriate subagent via Task. Each subagent returns a structured payload (see Task Return Contract below). The orchestrator only advances to the next step when the previous step's return is valid.

## Architecture Co-Approval Rule

A Tech Spec is not valid until **both** the Lead Architect and the Challenger Architect have explicitly approved it. Approval must be a structured field in the subagent's return payload (`approved: true`), not implied by silence or by a passing critique.

Concretely:

- The orchestrator must not dispatch the Spec-to-Test subagent until both architects have returned `approved: true` for the same Tech Spec version.
- If either architect returns `approved: false` with reasons, the orchestrator routes back to the Lead Architect for amendments and re-dispatches the cycle until convergence.
- If convergence cannot be reached after a reasonable number of cycles (Producer judgment, but flag as circuit-breaker territory after the third), escalate to the user.

The Architecture Discussion Record artifact must exist and be referenced by the Tech Spec before either architect approves. A record with unresolved challenger objections fails this rule regardless of approval messages.

## Pre-Implementation Test Gate

For every Standard implementation task, the orchestrator must first dispatch a Spec-to-Test task. The Test Spec artifact and initial unit test skeletons (failing tests, non-compiling stubs, or both) must exist before the Developer is dispatched.

This is a hard gate. The orchestrator must not pass `start_conditions_met: true` to the Developer until the Spec-to-Test return contains:

- `test_spec_path` — pointing to the persisted Test Spec
- `test_files` — list of test file paths created
- `test_case_mapping` — present in the Test Spec, traceable to acceptance criteria
- `outcome: COMPLETE`

The Developer subagent's own start conditions enforce this from its side. The orchestrator enforces it from the dispatch side. Both checks together prevent implementation from starting on guesswork.

## Implementation Gate

The Developer subagent must not begin implementation unless its Context Pack contains all of:

- `tech_spec_path` — final, dual-approved
- `test_spec_path` — produced by Spec-to-Test
- `test_files` — initial skeletons or failing tests
- `acceptance_criteria_refs` — explicit list, not implied
- `coding_standards_ref` — pointer or inline
- `task_id`, `milestone_id`

If any are missing, the Developer returns `outcome: BLOCKED` with `blocker: <missing field>` rather than guessing.

## Quality Gate Loop

After the Developer returns `outcome: COMPLETE`, the task enters the quality loop. Default order (Producer can parallelise — see `team-templates.md` flexibility rules):

1. Verification — checks implementation against Tech Spec, Test Spec, ACs; confirms full test suite is green
2. Code Review — assesses code quality, maintainability, standards compliance (separate from spec compliance)
3. QA — exploratory testing beyond the Test Spec

### Re-run rules on failure

The affected gate determines what re-runs after the Developer fixes the issue:

- **Verification fails** → re-run V → R → Q
- **Code Review fails** → re-run R → Q (Verification not re-run unless Developer's fix touched spec coverage)
- **QA fails** → re-run Q only

The orchestrator records each re-run in the Milestone Status Tracker. The same gate failing three times for the same root cause trips the Rework Limit circuit breaker — see `circuit-breakers.md`.

### Pass criteria

A task is GREEN only when:

- Verification returned `outcome: PASS` or `PASS WITH FIXES`
- Code Review returned `outcome: ACCEPT` or `ACCEPT WITH CHANGES`
- QA returned `outcome: PASS` or `PASS WITH BUGS`
- Full test suite is green (Verification is the designated owner of full-suite confirmation)
- All ACs have evidence in the Verification Report's coverage table

## Task Return Contract

Every subagent's return payload must include the **common envelope** below; role-specific extensions sit on top of it. The orchestrator validates the envelope on receipt; a missing required field is treated the same as a missing return — the task does not advance.

### Common envelope (required from every subagent)

```yaml
task_id: <string, matches the dispatched task ID>
sender_role: <one of: lead-architect, challenger-architect, spec-to-test, developer, verification, code-reviewer, qa, doc-writer, combined-reviewer, researcher>
outcome: <role-specific enum — see role definitions for valid values>
summary: <one-line plain-language summary of what happened>
artifact_refs:
  - <path or identifier of any artifact produced or updated>
files_touched:
  - <path>  # for write-producing roles only; empty list otherwise
insights:
  - <INSIGHT entries per references/insight.md, possibly empty>
```

### Role-specific extensions

Each subagent's system prompt names the additional fields its return must include. Examples:

- **Developer** completion adds: AC coverage summary, test results, technical documentation references, assumptions resolved during implementation
- **Verification** adds: AC coverage table, full test suite status, missing-or-partial findings
- **Code Reviewer** adds: blocker count, major count, minor count, severity-classified findings list
- **QA** adds: bug count, blocking bug count, exploratory scenarios tested
- **Lead Architect** / **Challenger Architect** add: `approved: <bool>`, decision rationale, named alternatives considered

If the subagent cannot produce a valid return — missing inputs, unresolvable ambiguity, encountered forbidden condition — it returns `outcome: BLOCKED` (or the role-specific blocking-equivalent) plus a `blocker` field naming what is missing. The orchestrator handles these by either resolving the blocker (e.g., dispatching the missing prerequisite subagent) or escalating to the user.

### Why this matters

The Task return contract is the orchestrator's only signal that a subagent has finished. There's no out-of-band completion path — no callback, no shared state the orchestrator polls. The orchestrator literally cannot proceed without the return value. A subagent that finishes but doesn't return a valid envelope produces no signal the orchestrator can act on, which surfaces the failure immediately rather than silently halting the workflow. The defensive property this guarantees: orphan work is structurally impossible. Every artifact a subagent produces must be announced in its return envelope or the orchestrator never knows it exists.

## What this workflow is not

- Not a checklist for the user. The user describes intent; the orchestrator runs the workflow.
- Not the only path. Conversation, Light, Bug Fix, Spike, Refactor, and Incident workflows exist for cases where this canonical depth is excessive — see `workflow-weights.md` and the kind-classification rules in `team-templates.md`.
- Not skippable for Standard work. If the work has been classified Standard and isn't auto-escalated to Critical, every step here runs. Skipping requires explicit user consent at intake (per the team-flexibility rules) and is recorded as a deviation.
