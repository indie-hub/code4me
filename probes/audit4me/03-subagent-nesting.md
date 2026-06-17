# Probe: subagent-nesting capability (Phase 2 gating decision)

**Subject:** audit4me
**Coverage:** Determines, in *your* Claude Code environment, whether a Task-tool
subagent can itself dispatch a nested Task-tool subagent (main session → per-file
orchestrator → per-category auditor). This is design-doc open question #4 and the
gating decision for the Phase 2 orchestrator's shape: if two-level nesting works,
the per-file orchestrator can parallel-dispatch per-category Claude auditors; if
not, Claude-side category work runs sequentially in the orchestrator's own thread
(cross-vendor passes via `codex-bridge` / `deepseek-bridge` parallelise regardless,
because they are inline subprocess calls, not nested subagents).

> **Probe type:** capability determination (run-and-record), not LLM-as-judge and
> not pass/fail on plugin behaviour. The point is to get a definitive yes/no and
> record it in `docs/decisions/0001-subagent-nesting.md`. A provisional answer from
> the Cowork / Agent-SDK harness is already recorded there; this probe confirms it
> in the Claude Code CLI environment audit4me actually runs in.

## Setup

A normal Claude Code session (CLI) in any project. No audit4me config required —
this probes the harness, not audit4me.

## Input prompt

> Using the Task tool, dispatch one subagent (subagent_type general-purpose) whose
> entire instruction is: "Report which agent-spawning tools you have. Then, if you
> have one, use it to dispatch a nested subagent whose only task is to reply with
> exactly the word PONG, and report verbatim what it returned. If you have no
> agent-spawning tool, say so plainly." Then tell me exactly what the first-level
> subagent reported: did it have a Task/Agent tool, did the nested dispatch
> succeed, error, or was the tool simply absent?

## Expected

Exactly one of two outcomes. Record which one in the ADR:

- **(A) Nesting works.** The first-level subagent had a Task/Agent tool, invoked it,
  and the nested subagent returned `PONG`. → The Phase 2 orchestrator *may* dispatch
  per-category Claude auditors in parallel from inside the per-file orchestrator.
- **(B) Nesting does not work.** The first-level subagent reported it had **no**
  agent-spawning tool (or the call errored / was refused). → The orchestrator must
  **not** rely on nested Claude subagents. Claude-side categories run sequentially
  in the orchestrator thread, or category fan-out moves to the main loop as
  per-(file × category) work items (one level deep). Cross-vendor bridges still
  parallelise.

Provisional result (Cowork / Agent-SDK harness, 2026-06-16): **(B)** — a first-level
subagent is given no agent-spawning tool; nesting is absent rather than blocked.
Consistent with documented Claude Code behaviour that subagents lack the Task tool.

## Pass criterion

1. The run yields a definitive (A) or (B) determination for the Claude Code CLI.
2. The outcome — and its date/environment — is recorded in
   `docs/decisions/0001-subagent-nesting.md`, superseding or confirming the
   provisional Cowork result.
3. The Phase 2 orchestrator design in `subagents/code4me-audit-orchestrator.md`
   reflects the confirmed outcome before Phase 2 dispatch logic is built.

## Failure modes this catches

- Building the Phase 2 orchestrator to parallel-dispatch nested Claude subagents on
  the assumption nesting works, then discovering at runtime that the inner Task tool
  is absent — every per-category dispatch silently degrades or errors.
- Conversely, serialising everything defensively when nesting actually works, losing
  the cleanest within-file parallelism for no reason.
- Conflating cross-vendor parallelism (subprocess bridges — always available from a
  subagent) with nested-subagent parallelism (gated by this probe). They are
  different mechanisms; only the latter is in question here.

## Notes

The mechanism matters for the decision: in the harness tested so far, the dispatch
tool is **withheld** from sub-level agents (the tool is simply not in the
subagent's tool list) rather than present-but-depth-limited. That means the failure
mode is "tool absent," which a Phase 2 orchestrator must detect by *not assuming the
tool exists*, not by catching a depth-limit error. See
`docs/decisions/0001-subagent-nesting.md` for the resulting architecture (vendor
fan-out via inline bridges; category fan-out at the main-loop level, not nested).
