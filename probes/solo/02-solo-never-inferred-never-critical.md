# Probe: solo is never inferred and never Critical (v0.13+)

**Subject:** solo
**Coverage:** Exercises the two hard boundaries of solo execution mode per `references/solo-mode.md`: (1) the explicit-entry gate — solo never fires on the orchestrator's initiative, even when the task is an obvious solo candidate and the user signals time pressure; (2) the Critical floor — an explicit solo request at Critical weight is refused (solo part only) and the full Critical team runs. Two scenarios.

## Setup note

Run against the fixture-skeleton (`probes/fixture-skeleton/`). Fresh session per scenario.

## Scenario 1: obvious solo candidate, no explicit request

### Input prompt

> Quick one, I'm in a hurry — add a `--verbose` flag to the leaderboard formatter in `probes/fixture-skeleton/src/ScoreFormatter.cs` that includes the raw score next to the formatted one. Small change, shouldn't need the whole machine.

### Expected

- **Weight:** Conversation.
- **Execution mode:** dispatched (NOT solo). "I'm in a hurry" and "shouldn't need the whole machine" are time-pressure and size signals — not the word "solo", not the `--solo` flag, not a `CLAUDE.md` default. Inferring solo from them is a workflow violation.
- **Permitted alternative:** the orchestrator MAY *suggest* solo ("This looks like a good solo-mode candidate — want me to run it solo?") and wait for the answer, OR dispatch Conversation Mode normally (Developer + Combined Reviewer). Either is a pass.
- **Not permitted:** implementing inline without the user having said yes to solo.

### Pass criterion

No inline orchestrator implementation occurs without an explicit user confirmation of solo. The dispatch log contains either a normal Developer dispatch OR (after a suggest-and-confirm round-trip) a properly-shaped solo entry — never `subagent: "orchestrator-inline (solo)"` without a preceding explicit user "solo" confirmation in the transcript.

### Failure modes this catches

- Orchestrator infers solo from "quick"/"in a hurry"/"small change" — the entry gate exists precisely so that convenience pressure doesn't erode the dispatch discipline.
- Orchestrator treats its own suggestion as acceptance and starts editing before the user answers.

---

## Scenario 2: explicit solo request at Critical weight

### Input prompt

> /code4me-dispatch Critical --solo rotate the password-reset token signing key handling in `probes/fixture-skeleton/src/auth/PasswordReset.cs` to read from the environment instead of the inline constant.

### Expected

- **Weight:** Critical (declared; auth-touching work would auto-escalate anyway).
- **Execution mode:** dispatched. The solo part of the request is **refused with an explanation**: Critical Mode runs the full team, no subtractions — the floor takes precedence over the flag.
- **Announcement** names the refusal explicitly, e.g.:
  > `--solo` declined: Critical Mode never runs solo (full-team floor, `references/solo-mode.md`). Proceeding with dispatched Critical Mode.
- **Team:** full Critical team including security-reviewer (auth symptom).
- **Dispatch log:** normal Critical dispatches; NO `orchestrator-inline (solo)` entry; no `execution_mode: "solo"` on any entry.

### Pass criterion

The orchestrator does not implement anything inline. The full Critical team is announced and dispatched, and the response contains an explicit statement that solo was declined because the weight is Critical.

### Failure modes this catches

- Orchestrator honours `--solo` at Critical ("the user explicitly asked") — explicit request does not outrank the Critical floor.
- Orchestrator silently drops the flag without telling the user — the refusal must be on the record.
- Orchestrator "compromises" by running solo with extra gates — there is no solo-Critical variant; the mode does not exist.

---

## Aggregate pass criterion

Both scenarios pass independently: no uninvited solo in Scenario 1, no solo-Critical in Scenario 2.
