# Trello card body format (v0.12+ — AC-level)

One Trello card per acceptance criterion. The card description (Trello's `desc` field) is auto-maintained by the orchestrator on each `trello-sync` invocation. Markdown.

## Card body template

```markdown
**Milestone:** {milestone_id} — {milestone_summary}
**AC:** {ac_id} — {ac_summary}
**Source:** [.code4me/milestone-specs/{milestone_id}.md#{ac_id}](.code4me/milestone-specs/{milestone_id}.md#{ac_id})
**Weight:** {weight} ({kind})
**Vendor mix:** {vendor_mix}{cross_vendor_note}

---

## Tasks touching this AC

{tasks_touching_block}

## Latest dispatches affecting this AC (last 3)

{ac_dispatch_history}

## Latest verification status for this AC

{latest_verification_status}

## Latest INSIGHTs touching this AC (last 2)

{ac_insight_history}

## Current state

{current_state}

## Next

{next_action}

---

_Synced from `.code4me/milestone-status-tracker.md` `acceptance_criteria.{ac_id}` at {sync_ts}._
_Edit on Trello is informational only — the tracker is the source of truth._
```

## Field semantics

### `{milestone_id}` and `{milestone_summary}`

The milestone identifier (e.g., `M07`) and its one-line summary from the Milestone Spec's title. Same value on every AC card belonging to the milestone — a label, a tag, or a Trello "Milestone" custom field could group them, but the body field makes the grouping explicit.

### `{ac_id}` and `{ac_summary}`

The AC identifier (e.g., `AC1`, `AC2`) and its one-line statement from the Milestone Spec. Used in the card title and as the second body field. AC IDs should be stable across the milestone's lifetime — don't renumber.

### `{vendor_mix}` and `{cross_vendor_note}`

- **Claude** — all tasks touching this AC dispatched through Claude subagents.
- **Codex** — at least one task touching this AC ran via codex-bridge.
- **DeepSeek** — at least one task touching this AC ran via deepseek-bridge.
- **Cross-vendor** — cross-vendor pairing is enabled for this milestone; the alternation rule applied.

`{cross_vendor_note}`: when vendor_mix is `Cross-vendor`, append a one-line summary of the pairing (e.g., "Lead: claude:high · Challenger: codex:high · Developer: claude:mid · Reviewer: deepseek:mid").

### `{tasks_touching_block}`

Bullet list of every task in `acceptance_criteria.{ac_id}.tasks_touching` with current dispatch outcome:

```markdown
- **M07-T03-DEV** (developer) → COMPLETE @ 14:35Z
- **M07-T04-VER** (verification) → PASS @ 14:42Z  ✓ AC1: PASS
- **M07-T05-CR** (code-reviewer) → ACCEPT WITH CHANGES @ 14:51Z
- **M07-T06-QA** (qa) → pending
```

The ✓/✗ markers on verification rows show this AC's verdict in that verification report (PASS / PARTIAL / FAIL / NOT VERIFIED). Code Reviewer and QA outcomes shown but don't carry per-AC verdicts (they're code-quality / runtime concerns, not requirement-attestation).

### `{ac_dispatch_history}`

Latest 3 dispatch-log entries where this AC was in `tasks_touching` of the dispatched task:

```markdown
- `2026-05-21T14:51:03Z` — **code-reviewer** (claude:mid) → ACCEPT WITH CHANGES
- `2026-05-21T14:42:09Z` — **verification** (claude:mid) → PASS  (AC1: PASS, AC2: PASS)
- `2026-05-21T14:35:12Z` — **developer** (claude:mid) → COMPLETE
```

If there are more than 3 affecting dispatches, the most recent 3 are shown and the line "_Full history in `.code4me/dispatch-log.jsonl`_" appears in the footer.

### `{latest_verification_status}`

One line stating the AC's verdict from the most recent verification report:

- `**PASS** — Verified by M07-T04-VER (2026-05-21T14:42:09Z). Evidence: tests/profile/test_csv_export.cs::test_basic_export_format passes.`
- `**PARTIAL** — Verified by M07-T04-VER (2026-05-21T14:42:09Z). Gap: test for malformed-row rejection missing.`
- `**FAIL** — Verified by M07-T04-VER (2026-05-21T14:42:09Z). Reason: test for AC2 missing in test suite.`
- `**NOT VERIFIED** — No verification report yet for this milestone.`

If multiple verifications have run (rework cycles), only the latest is shown.

### `{ac_insight_history}`

Latest 2 INSIGHTs from the milestone's insight register that name this AC (in `discovered_fact` or `target_role.payload.ac_id`):

```markdown
- `2026-05-21T14:35:12Z` [suggested change] **verification → spec-to-test**: AC1 had no failure-path test but spec said "reject empty input."
- `2026-05-21T14:42:09Z` [informational] **developer → user**: AC2 implementation required CSV-encoding library not in dependency manifest.
```

Format: timestamp + impact_tier + sender_role → target_role: discovered_fact (first ~120 chars).

### `{current_state}`

One paragraph describing this AC's status right now. Examples:

- "Declared. No task touching this AC has dispatched yet."
- "Implementation done (M07-T03-DEV COMPLETE). Quality Gate Loop running on touching tasks. Verification not yet started."
- "Verification PASS. Code Review in progress; QA pending."
- "Verification PARTIAL — gap: AC1's failure-path test missing. Rework dispatched to spec-to-test (M07-T07-S2T)."
- "PROVISIONAL — Conversation Mode promote-or-revert deadline 2026-05-28T00:00:00Z."

### `{next_action}`

One line describing what happens next FOR THIS AC. Examples:

- "Awaiting first touching-task dispatch."
- "Awaiting verification return — typical duration 3-8 minutes."
- "Awaiting QA return; verification already PASS."
- "Awaiting rework cycle (spec-to-test → developer → verification)."
- "Awaiting user `/code4me-promote-or-revert` (deadline 2026-05-28)."

### `{sync_ts}`

ISO8601 timestamp of when this card was last updated by the skill.

## Card title format

```
{milestone_id}-{ac_id}: {ac_summary}
```

Examples:

- `M07-AC1: User can export their profile as CSV`
- `M07-AC2: CSV includes column headers in the first row`
- `M07-AC3: Export endpoint rejects requests for other users with 403`
- `M03-CONV: Change homepage CTA colour from green to blue` (Conversation Mode — single AC implicit; `CONV` is the AC id)

Keep titles under ~80 characters (Trello truncates longer titles in the Kanban view). If the AC statement is too long, abbreviate it for the title but keep the full statement in the body's `**AC:**` field.

## What NOT to put in the card body

- **Full file contents.** Link to artefacts instead.
- **Full INSIGHT messages.** Truncate at ~120 chars; link to the insight register.
- **Full transcript or model reasoning.** Trello is a Kanban projection.
- **Per-task implementation detail.** That belongs in the Tech Spec / dispatch log. The card shows what AC outcomes are happening, not how the developer chose to structure their commits.
- **PII or secrets that the project's CLAUDE.md / hooks would otherwise gate.** Trello boards may be team-visible.

The card body should be readable in under 30 seconds. If you find yourself adding more, the milestone tracker (or a dedicated artefact) is the right place.

## Difference from v0.11 task-level cards

Three structural differences from the pre-v0.12 task-level card body:

1. **Card unit.** v0.11 had one card per task ID (e.g., `M07-T03-DEV: Add CSV export endpoint`). v0.12 has one card per AC (e.g., `M07-AC1: User can export their profile as CSV`). A milestone with 4 ACs and 8 tasks produces 4 cards in v0.12, not 8.
2. **Cross-task aggregation.** Each AC card aggregates ALL tasks that touch the AC. A single dispatch (e.g., a verification pass covering 4 ACs) updates 4 cards simultaneously. Conversely, a task touching 2 ACs appears in both cards' `tasks_touching` block.
3. **State semantics.** v0.11 task-level state was task-dispatch state (dispatched → returned → next-gate-running). v0.12 AC-level state is requirement-attestation state (declared → in-progress → in-review → done-once-verification-PASSes-this-AC). The board now shows requirement progress, not internal workflow lanes.

If you preferred v0.11's task-level view, the dispatch log (`.code4me/dispatch-log.jsonl`) is the per-task surface; the audit tool's "Dispatches per subagent" section gives the same task-granular breakdown without needing it on the kanban board.
