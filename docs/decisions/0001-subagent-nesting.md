# ADR 0001 — Subagent nesting and the Phase 2 audit orchestrator shape

**Status:** Accepted (provisional — confirm in Claude Code CLI before Phase 2 build)
**Date:** 2026-06-16
**Context:** audit4me design doc open question #4; gates Phase 2 (multi-vendor orchestrator).
**Probe:** `probes/audit4me/03-subagent-nesting.md`

## Question

The audit4me design imagined the per-file `code4me-audit-orchestrator` (itself a
Task-tool subagent dispatched by the `/audit4me-run` main loop) dispatching one
Claude subagent per audit category in parallel — two levels of Task nesting:

```
main session  →  per-file orchestrator (subagent)  →  per-category auditor (subagent)
```

Does the Claude Code / Agent SDK runtime support that second level? The answer
shapes the orchestrator's prompt, so it must be settled before Phase 2.

## Evidence

Tested empirically on 2026-06-16 in the Cowork / Agent-SDK harness: dispatched a
first-level `general-purpose` subagent and instructed it to spawn a nested subagent
that replies `PONG`.

Result: **the first-level subagent had no agent-spawning tool at all.** No `Task`
tool (with a `subagent_type` parameter), no `Agent` tool, nothing in its deferred
tool list that dispatches an agent. The similarly-named `TaskCreate`/`TaskList`/
`TaskStop` family is a to-do tracker + background-shell control, not agent dispatch.
The nested dispatch could not even be attempted — the capability is **absent at
depth ≥ 2**, not present-then-blocked-by-a-depth-limit.

This is consistent with documented Claude Code behaviour: subagents are not granted
the Task tool; only the top-level thread dispatches subagents. So the result is
expected to hold in the Claude Code CLI that audit4me runs in — but it should be
**confirmed there** via the probe before Phase 2 dispatch logic is finalised
(hence "provisional").

## Decision

**Do not rely on nested Claude subagents.** The Phase 2 orchestrator is designed for
a single level of subagent depth.

Concretely:

1. **Cross-vendor fan-out does NOT need nesting.** The per-file orchestrator runs the
   Claude pass inline (it *is* a Claude agent) and invokes OpenAI and DeepSeek via
   `codex-bridge` / `deepseek-bridge`, which are **subprocess calls** (`codex exec`,
   `reasonix run`) made with Bash — not nested subagents. A subagent can spawn
   subprocesses freely, so the three vendor passes still parallelise inside the
   orchestrator. This is the dominant time-saver and it is unaffected by the nesting
   limitation.

2. **Category fan-out, when it arrives (Phase 5), moves to the main loop — not inside
   the orchestrator.** Rather than `main → orchestrator → per-category subagent`
   (blocked), the `/audit4me-run` outer loop fans out **per-(file × category)** work
   items and dispatches one orchestrator per item, staying one level deep. The
   existing `concurrency_cap` then governs parallelism. Within a single orchestrator
   invocation, if multiple categories must be handled together, they run
   **sequentially in the orchestrator's own thread** (bounded, predictable).

3. **The orchestrator must not assume an inner Task tool exists.** Because the failure
   mode is "tool absent" (not "depth-limit error"), there is nothing to catch at
   runtime — the prompt simply must never instruct the orchestrator to dispatch a
   subagent. Phase 2's `code4me-audit-orchestrator.md` will state this explicitly.

## Consequences

- **Phase 2 is unblocked.** Multi-vendor agreement is achievable now: Claude inline +
  two bridge subprocesses, fanned out in parallel, aggregated within the orchestrator
  thread. No runtime dependency on a capability the platform doesn't provide.
- **Wall-clock model unchanged for vendors.** Per-file time is still
  `~max(vendor pass durations)` because the bridges run concurrently; only Claude-side
  *multi-category* work (Phase 5) is sequential within one orchestrator, and that is
  recovered by main-loop per-(file × category) fan-out if it matters.
- **Simpler failure surface.** One level of subagents means the resume/coverage model
  (ADR-adjacent: crash-safe persist order, atomic coverage) stays at the main loop,
  exactly where Phase 1 already put it.
- **Revisit if the platform changes.** If a future Claude Code grants subagents the
  Task tool, nested per-category Claude parallelism becomes available as an
  optimisation — but it is never required by this design. Re-run probe 03 to detect
  such a change.

## Follow-up

- [ ] Run `probes/audit4me/03-subagent-nesting.md` in the Claude Code CLI; record the
      confirmed outcome + date here and flip Status from "provisional" to "confirmed."
- [ ] When writing the Phase 2 `code4me-audit-orchestrator.md`, encode decisions 1–3
      (inline Claude + bridge subprocesses; no nested subagents; category fan-out at
      the main loop).
