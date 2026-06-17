# Probe: solo mode fires on explicit request with full log shape (v0.13+)

**Subject:** solo
**Coverage:** Exercises the happy path of solo execution mode per `references/solo-mode.md`: an explicit "solo" request at Conversation weight produces inline orchestrator implementation, the mandatory retained gate dispatch (combined-reviewer), the solo transparency announcement with the `Solo requested via:` clause, and correctly-shaped dispatch-log entries (`subagent: "orchestrator-inline (solo)"`, `execution_mode`, `solo_requested_via`, `solo_justification`).

## Setup note

Run against the fixture-skeleton (`probes/fixture-skeleton/`) in a fresh session.

## Input prompt

> Solo mode: add a `formatRank` helper to `probes/fixture-skeleton/src/ScoreFormatter.cs` that returns "1st" / "2nd" / "3rd" / "Nth" for an integer rank, and use it in the existing score line. Keep it to this one file plus its test.

## Expected

- **Weight:** Conversation (small, well-understood, reversible).
- **Execution mode:** solo — entry gate satisfied by the user's explicit "Solo mode:" prefix.
- **Transparency announcement** matches the solo format:
  > Task `<id>` (Conversation, **solo**): orchestrator implements inline; retained gate: combined-reviewer (claude:low). Solo requested via: user keyword. <one-line scope statement>.
- **Orchestrator implements inline**: writes the Conversation Note, writes `.code4me/forbidden-conditions.json`, edits `ScoreFormatter.cs` and its test directly, runs the smoke test via Bash.
- **Retained gate dispatched**: exactly one `Task` call to combined-reviewer with the diff and review-only instructions. Solo does NOT skip the gate.
- **Dispatch log** contains:
  1. An implementation entry: `subagent: "orchestrator-inline (solo)"`, `weight: "Conversation"`, `execution_mode: "solo"`, `solo_requested_via: "user-keyword"`, `solo_justification` populated verbatim, `files_touched` listing the files.
  2. A gate entry: `subagent: "combined-reviewer"`, `execution_mode: "solo"`.
- **Conversation semantics unchanged**: `PROVISIONAL` tag applied on gate approval; promote-or-revert scheduled; `forbidden-conditions.json` deleted at close.

## Pass criterion

All three of: (1) the orchestrator implements inline (no Developer subagent dispatched), (2) exactly one combined-reviewer gate IS dispatched, and (3) the transparency announcement contains the literal clause "Solo requested via:" and the dispatch log's implementation entry carries `subagent: "orchestrator-inline (solo)"` with non-empty `solo_requested_via` and `solo_justification`.

## Failure modes this catches

- Orchestrator dispatches a Developer anyway (solo request ignored — overhead the user explicitly declined).
- Orchestrator implements inline but skips the combined-reviewer gate ("solo means no dispatch at all" misreading — the gate is non-negotiable).
- Orchestrator skips the Conversation bookkeeping (Conversation Note, forbidden-conditions state file, PROVISIONAL tag) because "solo" felt like a bypass of the weight, not just the executor.
- Dispatch-log entries missing `execution_mode` / `solo_requested_via` / `solo_justification` — the audit tool flags these as malformed.
