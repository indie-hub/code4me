# Trello list (column) layout — AC-level (v0.12+)

Six default Kanban lists, each corresponding to a phase in the canonical workflow as experienced from the requirement-attestation perspective. `/code4me-trello-init` creates these on first run; the IDs are stored in `.code4me/trello-config.json`'s `list_ids` block.

Cards are AC-shaped (v0.12+). One card per acceptance criterion. The list a card sits in reflects the AC's current attestation state, not any internal task workflow stage.

## The six lists

### 📥 Inbox

**What lands here:** ACs that have been declared (post-decomposition) but no task touching them has dispatched yet. State `declared` in the tracker.

**Stays here when:** The user runs `/code4me-classify` (preview-only, no dispatch); the user pauses after intake; the orchestrator is waiting on a `NEEDS_PRODUCT_CLARIFICATION` before dispatching the team.

**Leaves when:** The first task touching this AC dispatches → moves to **In Progress**.

### 🏗 In Progress

**What lands here:** At least one task touching this AC has dispatched and not all touching tasks have returned. State `in_progress` in the tracker.

**Stays here when:** Touching tasks are running. Multiple sequential dispatches (Lead → Challenger → Spec-to-Test → Developer) for tasks affecting this AC all happen with the card in this list — the card's `tasks_touching` block updates per dispatch; the list doesn't change.

**Leaves when:**
- All touching tasks return COMPLETE and the Quality Gate Loop begins → **In Review**.
- A circuit breaker fires → **Blocked**.
- A touching task returns `NEEDS_DECISION` / `HUMAN_DIRECTOR_ESCALATION` → **Pending User**.
- Conversation Mode developer returns COMPLETE on the single-AC milestone → directly to **Pending User** (awaiting promote-or-revert).

### 🧪 In Review

**What lands here:** Implementation tasks touching this AC are done; the Quality Gate Loop is running (Verification + Code Reviewer + QA, plus Security Reviewer if auto-escalation fired). State `in_review` in the tracker.

**Stays here when:** Any quality gate is still running, OR Verification returned PASS for this AC but other gates (Code Reviewer, QA) are still in flight, OR Verification returned PARTIAL/FAIL and rework is in progress within the Rework Limit.

**Leaves when:**
- Verification confirms PASS for this AC AND all other gates have returned acceptably AND (if applicable) Doc Writer completes → **Done**.
- Verification returns PARTIAL or FAIL for this AC AND rework can't resolve within the Rework Limit → **Blocked**.

### 🚧 Blocked

**What lands here:** Verification PARTIAL or FAIL for this AC after rework cycles exhausted, OR a circuit breaker fired naming this AC, OR an unrecoverable BLOCKED outcome from a touching task. State `blocked` in the tracker.

**Card description includes:** The verification report's reason for PARTIAL/FAIL (or the breaker that fired), what was tried, recommended next steps (per `references/circuit-breakers.md`'s `HUMAN_DIRECTOR_ESCALATION` format).

**Stays here until:** The user decides on a path forward (re-scope the AC, re-architect, accept-with-gap, abandon, continue with extra scrutiny) and the orchestrator dispatches accordingly → back to **In Progress** or **In Review**.

### ⏳ Pending User

**What lands here:** ACs awaiting an explicit user decision that isn't a circuit-breaker escalation:

- Conversation Mode `PROVISIONAL` AC (awaiting promote-or-revert).
- Co-Approval situations where one architect approved and one didn't on a task touching this AC, and the disagreement was escalated.
- `NEEDS_PRODUCT_CLARIFICATION` from Lead Architect or Spec-to-Test about how this AC should be interpreted, surfaced to the user.
- Auto-escalation triggered for this AC and orchestrator wants user acknowledgement before proceeding (less common — usually auto-escalation just runs the bigger team without asking).

**Due date:** For Conversation Mode `PROVISIONAL` ACs, the card's `due` field is the promote-or-revert deadline (typically intake + 7 days). Trello surfaces overdue cards visibly.

**Stays here until:** The user runs the corresponding action (`/code4me-promote-or-revert`, a clarification message, etc.) and the orchestrator advances → **Done**, **In Progress**, or **(archived)** depending on the decision.

### ✅ Done

**What lands here:** ACs whose verification has confirmed PASS and all touching tasks' downstream gates (Code Reviewer accept, QA pass) have closed acceptably. State `done` in the tracker.

**Stays here.** Cards in **Done** are historical; the orchestrator doesn't move them again.

**Optional:** Periodic archive sweeps. Once a month (or once per release), the user can manually archive cards from **Done** to keep the board clean. The skill doesn't auto-archive.

## Why the AC granularity changes what each list shows

Compared to the v0.11 task-level model, the AC-level model has subtle differences in how state transitions feel on the board:

- **One milestone with 4 ACs can show 4 cards each in DIFFERENT lists.** Verification might PASS AC1 and AC3 but PARTIAL on AC2 and FAIL on AC4. Result: AC1 and AC3 move to **Done**, AC2 stays in **In Review** for rework, AC4 moves to **Blocked**. The board shows partial progress at the requirement level rather than collapsing the whole milestone into one card's state.
- **A single dispatch updates multiple cards.** When a touching task returns COMPLETE, every AC card it touches gets its description refreshed and (if state transitioned) gets moved. Visually: a verification dispatch in a 4-AC milestone is a 4-card update fan-out.
- **Rework cycles are AC-localised.** If only AC2 fails verification, only AC2's card moves to **Blocked** while AC1/3/4 progress. Code Reviewer and QA on the implementation are still useful; rework is targeted at the specific AC.

## Label conventions

Three label categories. Cards get one of each (weight, kind, vendor mix).

### Weight labels (mutually exclusive)

| Label name | Trello colour suggestion |
|---|---|
| `weight: Conversation` | green |
| `weight: Light` | yellow |
| `weight: Standard` | orange |
| `weight: Critical` | red |
| `weight: Trivial` (v0.10.4+) | grey |

### Kind labels (mutually exclusive)

| Label name | Trello colour suggestion |
|---|---|
| `kind: product` | blue |
| `kind: bug-fix` | pink |
| `kind: tech-debt` | sky |
| `kind: spike` | lime |
| `kind: incident` | red (darker) |
| `kind: scope-change` | purple |

### Vendor labels (mutually exclusive)

| Label name | Trello colour suggestion |
|---|---|
| `vendor: claude` | black |
| `vendor: codex` | grey |
| `vendor: deepseek` (v0.11+) | dark blue |
| `vendor: cross-vendor` | rainbow (or any distinctive colour) |

The orchestrator applies one label per category. Vendor label reflects the dominant vendor of tasks touching this AC; if multiple vendors touched the AC, use `cross-vendor`. When weight changes (e.g., auto-escalation lifts Conversation to Standard), the orchestrator updates labels via `update_card_details`.

## Due dates

Set the card's `due` field in exactly two situations:

1. **Conversation Mode `PROVISIONAL` ACs** — `due` = the promote-or-revert deadline (intake_ts + 7 days, or whatever the project's Conversation Mode config specifies).
2. **Critical milestones with explicit user-set deadlines** — when the user states "this needs to ship by Friday," set `due` to that date on every AC card belonging to the milestone.

Don't set due dates speculatively.

## What the skill does NOT touch

- **Other lists/columns** the user adds to the board (e.g., "Triage backlog", "Ideas", "Out of scope"). The skill only operates on the six lists in `list_ids`.
- **Custom labels** outside the three categories above. The user can add team / area / area-of-code labels; the skill leaves them alone on existing cards.
- **Card comments.** The skill maintains the `desc` field but doesn't add comments.
- **Card members.** The skill doesn't assign cards to Trello members.
- **Trello checklists.** Not used; the card description already carries the structured content.

The principle: code4me state goes in code4me-controlled fields (`desc`, `idList`, `idLabels`, `due`). Everything else on Trello is the user's space.
