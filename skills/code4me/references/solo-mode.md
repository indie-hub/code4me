# Solo Execution Mode

Solo mode (v0.13+) is an **execution mode, not a weight**. The weight (Conversation, Light, Standard) keeps its full semantics — PROVISIONAL tags, promote-or-revert, decomposition, artifact requirements, auto-escalation. What changes is the executor: **the orchestrator implements inline** instead of dispatching a Developer subagent, and exactly **one fresh-context quality gate is always dispatched** to review the work.

Solo exists because for small-to-medium, well-understood tasks, the dispatch round-trip (Context Pack assembly, subagent spin-up, structured return) costs more than it returns — a single capable agent in a tight implement-test-fix loop is faster and loses nothing *except* the independent gates. Solo keeps the two gates that matter structurally: the fresh-context review (author ≠ reviewer) and the mechanical hook enforcement (protected tests, forbidden conditions), while dropping the handoff overhead.

This document is the load-bearing reference. Solo runs *only* when explicitly requested, never on the orchestrator's initiative.

## Entry gate (explicit only — mirror of the bridge gates)

Never run solo unless one of the following is true:

- (a) the user said **"solo"** at intake (e.g., "solo mode: add the CSV export", "do this one solo"), OR
- (b) the user passed the **`--solo` flag** on `/code4me-dispatch`, OR
- (c) the project's `AGENTS.md` or `CLAUDE.md` declares a **project-level solo default** (e.g., `code4me: solo default for Conversation/Light`) — in which case announce that the default applied and which weights it covers.

**Inferring solo from the task's size, the perceived dispatch overhead, time pressure, or the orchestrator's confidence is a workflow violation** — identical discipline to the codex-bridge and deepseek-bridge gates. If solo seems like a good fit, you may *suggest* it ("This looks like a good solo-mode candidate — want me to run it solo?") and wait for the answer. When uncertain, dispatch normally.

## Allowed weights

| Weight | Solo? | Retained gate |
|---|---|---|
| Trivial | n/a | Already inline by definition; `--solo` is a no-op |
| Conversation | ✅ | `combined-reviewer` (review-only pass on the diff) |
| Light | ✅ | `combined-reviewer` |
| Standard | ✅ | `verification` (suite-run + AC coverage table) |
| Critical | ❌ **never** | — |

**Critical Mode never runs solo.** The existing hard floor — "Critical Mode runs the full team. No subtractions, no substitutions on the core gates" — takes precedence over any solo request, flag, or project default. If the user requests solo Critical, refuse the solo part, explain the floor, and run Critical normally.

**The retained gate is not optional.** Solo with zero dispatch is not a mode this framework offers — that's just not using the framework. The gate is one cheap dispatch and it is the only fresh-context eyes on the diff. It also means every solo task still satisfies the hard success condition (≥1 Task call per classified task): solo is a carve-out from the *role boundary* (no production writes), not from the success condition.

## What the orchestrator may do in solo (carve-outs)

For the duration of a solo task — and only then:

- **`Edit` / `Write` on production source, tests, and configs** in the task's scope. This is the second carve-out (after Trivial) from the no-production-writes rule.
- **`Bash` to run tests, builds, linters, and type-checkers** for the task's verification loop. Outside solo, these belong to subagents.

Everything else is unchanged: bookkeeping under `.code4me/`, INSIGHT routing, transparency announcements, Trello projection, dispatch-log discipline.

## Mechanical enforcement still applies (this is the point)

The active client's PreToolUse hooks fire on the **orchestrator's own tool calls**. In solo mode this is the framework's structural answer to "the author can't be trusted to police itself":

- **Test protection.** `check-test-protection.sh` guards the orchestrator's own edits to paths in `.code4me/protected-tests.txt`. In Standard solo the orchestrator writes that manifest *before* implementing (see below) — binding its own hands mechanically, not on the honor system.
- **Forbidden conditions.** Conversation-solo writes `.code4me/forbidden-conditions.json` at task start exactly as dispatched Conversation Mode does; `check-forbidden-conditions.sh` gates the orchestrator's own file creation.
- **A hook guarding your own edit is an abort signal**, not an obstacle. Treat the gate as authoritative (ETHOS: fidelity); stop, surface what happened, and re-classify or re-scope.

## Per-weight procedure

### Conversation solo

1. Announce (transparency format below). Write the Conversation Note.
2. Write `.code4me/forbidden-conditions.json` (same globs as dispatched Conversation Mode).
3. Implement inline. Run the smoke test via Bash.
4. Dispatch **combined-reviewer** with the diff, the Conversation Note, and review-only instructions.
5. On `approved`: apply `PROVISIONAL` tag, schedule promote-or-revert — Conversation semantics unchanged. On findings: fix inline (one rework round), re-dispatch the reviewer. Two consecutive FAILs → abort solo (circuit-breaker discipline; see below).
6. Delete `forbidden-conditions.json` at close. Log per the shape below.

### Light solo

Same as Conversation solo. If the task warrants the architect-notify that Light Mode sometimes carries, send it as usual — it's a notification, not a dispatch, and solo doesn't change it.

### Standard solo

1. Announce. Milestone Spec and **decomposition are unchanged**: ≥1 task per acceptance criterion, AC↔task mapping recorded in the tracker before any work. Solo changes the executor, not the bookkeeping.
2. **Test gate first, self-binding.** Before touching production code, the orchestrator authors the Test Spec and initial test files (Given/When/Then discipline per `canonical-workflow.md`), then writes `.code4me/protected-tests.txt` covering them. From this point the test-protection hook gates the orchestrator's own hands. Implementing before the test gate exists is a workflow violation.
3. Implement per AC, updating per-AC state in the tracker (`declared` → `in_progress`) as each task starts. Run the suite via Bash as you go.
4. Dispatch **verification** (suite-run + ac-coverage modes) as the mandatory gate. Verification's coverage table drives AC states to `done`/`blocked` exactly as in dispatched Standard — the tracker and Trello state machines are unchanged.
5. Auto-escalation–mandated subagents (e.g., security-reviewer when an auth/sensitive-data/migration/new-dependency symptom fires) are **still dispatched**. Solo drops the default code-reviewer and QA, not the escalation floors.
6. Delete hook state files at close. Log per the shape below.

**Standard solo sizing rule:** if the milestone has more than 4 ACs, or the expected diff exceeds ~150 changed lines / ~5 files, surface `NEEDS_DECISION` recommending dispatched Standard instead. Solo work cannot be `/compact`ed away — it sits in the orchestrator's context permanently, and a large solo milestone will exhaust the context budget before it closes. This is the real cost of solo; respect it.

## Hard floors solo does NOT waive

- **Critical Mode never runs solo** (above).
- **Auto-escalation symptom classes still invoke their associated subagents.** A solo task that turns out to touch auth gets a security-reviewer dispatch, full stop.
- **Architecture-introducing work still invokes Lead + Challenger.** A new public interface, new data flow, or new cross-cutting concern triggers the architect dialectic *before* solo implementation begins; Co-Approval applies. Solo covers implementation, not architecture.
- **The retained gate dispatch** (combined-reviewer or verification) is non-negotiable.

## Transparency announcement

> Task `{task_id}` ({weight}, **solo**): orchestrator implements inline; retained gate: {combined-reviewer|verification} ({vendor}:{tier}). Solo requested via: {user keyword | --solo flag | project-instructions default}. {One-line scope statement.}

The `Solo requested via:` clause is mandatory — it is the auditable record that the entry gate was satisfied.

## Dispatch-log shape

Implementation work logs as:

```jsonl
{"ts": "...", "milestone": "...", "task": "...", "weight": "<Conversation|Light|Standard>",
 "subagent": "orchestrator-inline (solo)",
 "vendor": "anthropic", "model": "<orchestrator's session model>",
 "outcome": "<outcome>",
 "execution_mode": "solo",
 "solo_requested_via": "user-keyword|flag|project-instructions-default",
 "solo_justification": "<one-line scope statement, verbatim from the announcement>",
 "files_touched": ["..."]}
```

The retained-gate dispatch (and any escalation-mandated dispatch) logs as a normal Task entry with `execution_mode: "solo"` added, so the audit tool can group a solo task's full trail. Entries with `subagent: "orchestrator-inline (solo)"` missing `solo_requested_via` or `solo_justification` are malformed and flagged by the audit tool.

## Abort conditions

Abort solo — finish bookkeeping, announce, and dispatch the remainder normally — when any of these occur:

1. **Scope growth.** The "and I also need to…" signal (same as Trivial). More files, more ACs, or an unplanned subsystem → abort, re-scope, dispatch.
2. **Auto-escalation symptom discovered mid-implementation.** Stop immediately; the symptom's floor applies; dispatch the mandated team.
3. **A protection hook guards your own edit.** Treat it as authoritative. Do not bypass it.
4. **Two consecutive gate FAILs.** Mirrors the Rework circuit breaker: if the retained gate fails the same work twice, the author needs replacing — dispatch a fresh Developer with the gate's findings as input.
5. **Context budget pressure.** If the solo loop is visibly consuming the session's remaining context, checkpoint via `/code4me-housekeeping` and dispatch the remainder.

Aborts are logged as an INSIGHT (`impact: informational` unless a pattern emerges) and the abort reason recorded in the tracker.

## Anti-drift safeguards

1. **Explicit entry only**, audited via `solo_requested_via`. The probe suite (`probes/solo/`) verifies solo never fires uninvited.
2. **Audit-tool surveillance.** `bin/code4me-audit-dispatch-log` surfaces a "Solo execution surveillance" section: solo task count, share of dispatches, requested-via distribution, gate-outcome distribution, abort count, and malformed entries. There is no fixed "too much solo" threshold — solo is a legitimate user choice — but a rising solo share with a rising gate-FAIL rate is the drift signature to watch: it means work is going solo that needed a team.
3. **The retained gate is structural.** Even fully drifted, every solo diff still meets one fresh-context reviewer and the mechanical hooks.

## Composition with the rest of the framework

- **Cross-vendor pairing:** composes well, and is the recommended pairing for solo when enabled — run the retained gate on the *other* vendor (combined-reviewer or verification via codex-bridge / deepseek-bridge per `cross-vendor-policy.md`). Producer (orchestrator, Anthropic) and verifier (other vendor) land on opposite vendors, which is the alternation rule's intent. Same opt-in gate as always.
- **Trello sync:** unchanged. Cards move through the same states; solo implementation entries appear in card descriptions like any dispatch.
- **Basic Memory:** memory-first still applies before classifying or implementing when the MCP tools are available.
- **Trivial:** unchanged and unaffected. Trivial is "no dispatch at all, whitelist-bounded"; solo is "implementation inline, gate dispatched, weight semantics intact". When a request is Trivial-eligible, classify Trivial — don't run solo for what the whitelist already covers.

## When to recommend against solo

Suggest dispatched mode (and say why) when: the task spans unfamiliar subsystems; the milestone is large (>4 ACs / >~150 lines expected); the work is architecture-introducing (architects must run anyway, so the dispatch savings shrink); the session's context is already heavy; or the user's request hints at wanting the audit richness of a full team (compliance contexts). The user can still insist — solo is their call — but the recommendation must be on the record.
