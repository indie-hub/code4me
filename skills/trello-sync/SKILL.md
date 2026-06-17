---
name: trello-sync
description: One-way mirror from the code4me milestone-status-tracker to a Trello Kanban board. One card per acceptance criterion (v0.12+). The orchestrator invokes this skill at state transitions (intake-after-decomposition, dispatch, return, escalation) to project per-AC state to Trello cards for at-a-glance visibility. The `.code4me/milestone-status-tracker.md`'s `acceptance_criteria:` block is the source of truth; Trello is a projection. Targets the delorenj/mcp-server-trello tool surface (`add_card_to_list`, `update_card_details`, `move_card_to_list`, `archive_card`, etc.). Optional — when the Trello MCP is not configured (no `.code4me/trello-config.json`, no `mcp__trello__*` tools available), the skill silently no-ops. The milestone tracker continues unchanged either way.
---

# Trello Sync

The orchestrator invokes this skill inline from its own thread (no Task subagent spawn — Trello sync is bookkeeping, like appending to the dispatch log) at four state-transition moments to keep a Trello board in sync with the milestone-status-tracker's per-AC state.

**v0.12 change:** card unit is now the acceptance criterion (AC), not the task. One card per AC declared in the Milestone Spec. Cards aggregate the tasks touching each AC and move through `inbox → in_progress → in_review → done` according to per-AC state in the tracker. Conversation / Light / Trivial weight milestones (which have one AC by definition) produce one card per milestone.

## When to invoke

The orchestrator invokes `trello-sync` at exactly these four moments:

1. **After milestone decomposition** (operating-loop step 5 — Standard/Critical) — once the `acceptance_criteria:` block is written to the tracker, create one Trello card per AC in the **Inbox** list. Conversation/Light/Trivial: one card per milestone using the single-AC entry.
2. **At dispatch** — immediately before each `Task` call (or `codex-bridge` / `deepseek-bridge` invocation). For every AC the dispatched task is listed under (`tasks_touching`), if the AC card is currently in `Inbox`, move it to **In Progress**. Append the dispatch line to each affected AC card's description.
3. **At return** — after each subagent's structured return. Recompute per-AC state from the verification report's AC coverage table (or from the dispatch's outcome for non-verification dispatches). For each AC the returned task touches: update the card description; move to a new list if the AC's state transitioned (Verification PASS for this AC → **Done**; PARTIAL/FAIL → **Blocked**; gates still running → **In Review**).
4. **At escalation or circuit-breaker fire** — move all AC cards for the affected milestone (or the specific ACs the escalation cites) to **Blocked** or **Pending User** depending on the reason; append the escalation detail to each.

Outside these four moments, do not sync.

## Pre-flight

Before each invocation:

1. **Check the Trello MCP is reachable.** The orchestrator's MCP inventory should include at least one `mcp__trello__*` tool. If not → **silent no-op**.
2. **Check the project's `.code4me/trello-config.json` exists and parses.** If missing → silent no-op (user runs `/code4me-trello-init` once).
3. **Check the tracker's `acceptance_criteria:` block exists for the active milestone.** If missing for a Standard/Critical milestone → log a warning (this signals an orchestrator-side decomposition skip), then no-op. For Conversation/Light/Trivial weight, expect a single-AC entry; if missing, treat the milestone summary as the implicit single AC.

**Never block the milestone on Trello sync failures.** Trello is a projection. Failures go to `.code4me/trello-sync-errors.jsonl` (`{ts, op, error, milestone_id, ac_id}`) and surface in the next transparency announcement. Continue regardless.

## AC state → Trello list mapping

Default mapping from `references/columns.md`. Looked up from `.code4me/trello-config.json`'s `list_ids` block:

| Tracker AC state | Trello list | Trigger |
|---|---|---|
| `declared` | `inbox` | After decomposition |
| `in_progress` | `in_progress` | First touching task dispatches |
| `in_review` | `in_review` | All touching tasks returned, quality gates running |
| `blocked` | `blocked` | Verification PARTIAL/FAIL on this AC; circuit-breaker fires |
| Awaiting user decision | `pending_user` | NEEDS_DECISION / HUMAN_DIRECTOR_ESCALATION / Co-Approval / Conversation PROVISIONAL deadline approaches |
| `done` | `done` | Verification confirms PASS for this AC |

## Card lifecycle

- **Create** (after decomposition): for each AC entry in the tracker, `add_card_to_list` with `name = {milestone_id}-{ac_id}: {ac_summary}`, `desc = <body per references/card-shape.md>`, `idList = list_ids.inbox`, `labels = [weight label, kind label, vendor label(s)]`. Capture the returned `card_id` and write it back into the tracker's `acceptance_criteria.{ac_id}.trello_card_id` field.
- **Move + update** (at dispatch / return / escalation): look up `card_id` from the tracker's `acceptance_criteria.{ac_id}` block. `move_card_to_list` to the new `idList` (derived from current AC state). `update_card_details` to refresh `desc` (which lists tasks_touching, latest dispatches affecting this AC, latest verification status for this AC). If `card_id` is missing (unrecoverable from earlier failure), `add_card_to_list` to recreate and update the tracker.
- **Multi-AC dispatch fan-out:** when one task touches N ACs, the dispatch triggers N card updates (move + description refresh on each). This is intentional — the kanban view should show every AC the task advances.
- **Due dates**: when emitting a Conversation Mode `PROVISIONAL` tag with a promote-or-revert deadline, set the single AC card's `due` field to the deadline timestamp. On `/code4me-promote-or-revert`, clear the due date and move to `done` (promoted) or `archive_card` (reverted).
- **Archive** (optional): on `/code4me-promote-or-revert <task_id> revert`, archive the AC card rather than moving to `done`.

## MCP tool mapping

Targets delorenj/mcp-server-trello. Same as v0.11 — the tool name set is unchanged. The skill expects these tools (or their equivalents — actual names depend on the MCP server's exposed surface):

| Op | MCP tool | Required arguments |
|---|---|---|
| Create card | `mcp__trello__add_card_to_list` | `idList`, `name`, `desc`, `idLabels[]`, `due?` |
| Move card | `mcp__trello__move_card_to_list` (or `mcp__trello__update_card_details` with `idList`) | `id`, `idList` |
| Update card body | `mcp__trello__update_card_details` | `id`, `desc` (and optionally `due`, `idLabels`) |
| Archive card | `mcp__trello__archive_card` | `id` |
| List boards / lists / labels (one-time setup) | `mcp__trello__get_boards`, `mcp__trello__get_lists_by_board_id`, `mcp__trello__get_labels` | varies |

If the actual MCP server uses different tool names, edit `.code4me/trello-config.json`'s optional `tool_overrides` block to map the skill's expected op names to the actual MCP tool names.

## Failure modes

| Failure | Skill behaviour |
|---|---|
| Trello MCP not in dispatch's MCP inventory | Silent no-op. Logged once per session. |
| `.code4me/trello-config.json` missing | Silent no-op (run `/code4me-trello-init`). |
| `.code4me/trello-config.json` malformed JSON | Logged warning; no-op. |
| Tracker's `acceptance_criteria:` block missing for a Standard/Critical milestone | Logged warning naming `acceptance_criteria_block_missing`; no-op. The orchestrator should have decomposed at step 5; this is a workflow-violation signal. |
| MCP call returns auth error | Logged to `.code4me/trello-sync-errors.jsonl` with `{ts, op, error: "auth", ac_id}`. Skip; continue. |
| MCP call returns rate-limit / 429 | Logged; deferred to next state transition. |
| MCP call returns 5xx | Logged; deferred. |
| `card_id` missing in tracker for an update op | Recreate via `add_card_to_list`; update tracker. |
| Tracker has a `card_id` but Trello says it doesn't exist (404) | Recreate via `add_card_to_list`; update tracker. |
| State transition would move card to a non-existent list | Logged warning; card stays in current list. User re-runs `/code4me-trello-init` to refresh list IDs. |

The skill never blocks dispatch.

## Configuration

The orchestrator reads `.code4me/trello-config.json` at every invocation. Same shape as v0.11 — no schema change in v0.12. The board structure (6 lists) is unchanged; only the card unit shifts from task → AC.

```json
{
  "board_id": "<Trello board ID>",
  "list_ids": {
    "inbox": "<list ID>",
    "in_progress": "<list ID>",
    "in_review": "<list ID>",
    "blocked": "<list ID>",
    "pending_user": "<list ID>",
    "done": "<list ID>"
  },
  "label_ids": {
    "weight_conversation": "<label ID>",
    "weight_light": "<label ID>",
    "weight_standard": "<label ID>",
    "weight_critical": "<label ID>",
    "kind_product": "<label ID>",
    "kind_bug_fix": "<label ID>",
    "kind_tech_debt": "<label ID>",
    "kind_spike": "<label ID>",
    "kind_incident": "<label ID>",
    "kind_scope_change": "<label ID>",
    "vendor_claude": "<label ID>",
    "vendor_codex": "<label ID>",
    "vendor_deepseek": "<label ID>",
    "vendor_cross_vendor": "<label ID>"
  },
  "tool_overrides": {
    "add_card": "mcp__trello__add_card_to_list",
    "move_card": "mcp__trello__move_card_to_list",
    "update_card": "mcp__trello__update_card_details",
    "archive_card": "mcp__trello__archive_card"
  }
}
```

Populate via `/code4me-trello-init` (one-time).

## What this skill is NOT

- **Not a subagent.** The orchestrator invokes it inline from its own thread (similar to `codex-bridge` / `deepseek-bridge` — bookkeeping, not work execution).
- **Not bidirectional.** Drags on the Trello board do NOT change the milestone tracker. v1 is one-way (tracker → Trello).
- **Not a replacement for the milestone-status-tracker.** The tracker stays the source of truth: version-controlled, full history. Trello is a projection.
- **Not task-granular.** v0.12 moved card unit from task to AC. Internal task IDs appear in the card body's `tasks_touching` list but are not the unit of state on the board. If you want task-level tracking, use the dispatch log; the board reflects outcomes (ACs), not internal workflow steps.
- **Not opinionated about Trello board structure beyond the 6 lists.** Users can add custom lists / labels / power-ups on their board; the skill only touches the lists in `list_ids` and labels in `label_ids`.

## References

- `references/card-shape.md` — what goes in the card body (AC card description format)
- `references/columns.md` — the 6 default lists + label conventions + due-date rules
