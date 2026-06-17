---
description: One-time scaffold for Trello sync. Probes the Trello MCP server (delorenj/mcp-server-trello or compatible), lists available boards + lists + labels, helps you pick (or create) the six default lists and the weight/kind/vendor labels, and writes .code4me/trello-config.json. After this runs, the trello-sync skill auto-mirrors milestone state to Trello on every state transition.
argument-hint: [--board-id BOARD_ID] [--dry-run]
---

Scaffold the project's Trello integration. This is a one-time setup; subsequent state transitions use the saved config without re-prompting.

Procedure:

1. **Pre-flight.**
   - Confirm the Trello MCP server is reachable: at least one `mcp__trello__*` tool should appear in your available tool inventory. If not, surface this clearly: *"No `mcp__trello__*` tools available. Install the delorenj/mcp-server-trello (or compatible) MCP and confirm it's registered in `.mcp.json` or equivalent; re-run this command after."* Do NOT proceed.
   - Confirm `.code4me/` exists at the project root. If not, prompt to run `/code4me-init` first.
   - Confirm there isn't already a `.code4me/trello-config.json`. If there is, ask: *"Existing trello-config.json found. Overwrite (replaces all IDs), patch (only fill in missing fields), or abort?"* — wait for explicit user choice.

2. **Pick the board.**
   - If `--board-id` was passed, use it (skip the listing).
   - Otherwise, call the MCP's `get_boards` (or equivalent — list-all-boards tool) and present the available boards with `name` and `id`. Ask the user to pick one by number or by exact name. *Recommendation:* a dedicated `<project-name> — code4me` board is cleaner than reusing an existing project board.

3. **List or create the six required lists.**
   - Call `get_lists_by_board_id` for the chosen board. Map each existing list to one of the six required slots:
     - `inbox`, `in_progress`, `in_review`, `blocked`, `pending_user`, `done`
   - For each slot, ask: *"Map to existing list `<existing-list-name>`, create new list `<recommended-name>`, or skip?"* — recommended names: 📥 Inbox / 🏗 In Progress / 🧪 In Review / 🚧 Blocked / ⏳ Pending User / ✅ Done.
   - If the user chooses "create new", call `create_list_on_board` (or the equivalent MCP op); capture the returned `id`.
   - If they "skip" a slot, the skill will no-op for state transitions targeting that slot until the slot is mapped (the user can re-run `/code4me-trello-init --patch` later).

4. **List or create the labels.**
   - Call `get_labels_by_board_id`. Categories needed:
     - **Weight** (mutually exclusive): `weight: Conversation`, `weight: Light`, `weight: Standard`, `weight: Critical`
     - **Kind** (mutually exclusive): `kind: product`, `kind: bug-fix`, `kind: tech-debt`, `kind: spike`, `kind: incident`, `kind: scope-change`
     - **Vendor** (mutually exclusive): `vendor: claude`, `vendor: codex`, `vendor: cross-vendor`
   - For each, ask: *"Map to existing label `<name>`, create new (suggested colour: `<colour>`), or skip?"* Use the colour suggestions from `skills/trello-sync/references/columns.md`.

5. **Detect MCP tool names.**
   - The skill's defaults assume `mcp__trello__add_card_to_list`, `mcp__trello__move_card_to_list`, `mcp__trello__update_card_details`, `mcp__trello__archive_card`. If the user's MCP exposes different names, ask the user to confirm or override at the end of the wizard. Record any overrides in the `tool_overrides` block.

6. **Write the config.**
   - If `--dry-run` was passed, print the proposed JSON content and exit without writing.
   - Otherwise, write `.code4me/trello-config.json` with the collected `board_id`, `list_ids`, `label_ids`, and any `tool_overrides`. Use 2-space indentation. Don't add comments (JSON doesn't support them).

7. **Smoke test (optional).**
   - Ask the user: *"Create a smoke-test card now to verify the wiring? (yes/no)"*. If yes, `add_card_to_list` with `name: "[code4me smoke test — safe to archive]"` and `idList: list_ids.done`. Then `archive_card` immediately. If both succeed, the wiring works end-to-end. If either fails, surface the error and recommend re-running with `--dry-run` first.

8. **Summary.**
   - Print: board name and ID, the six list mappings, the label mappings, and the path of the saved config file. Note that subsequent `Task` / `codex-bridge` invocations will now auto-sync to Trello via the `trello-sync` skill.

**When NOT to run this:**

- If you don't want Trello integration at all — just don't run it. Without `.code4me/trello-config.json`, the trello-sync skill silently no-ops; nothing breaks.
- If you're trying to test the rest of the framework in isolation — the absence of the config file is the canonical "off switch."
- If the project is shared with team members who don't have Trello access — the config file is version-controllable, so committing it would make everyone need Trello. Consider gitignoring `.code4me/trello-config.json` (recommended), and have each team member run `/code4me-trello-init` against their own preferred board.

Arguments:

$ARGUMENTS
