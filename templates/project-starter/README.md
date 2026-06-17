# Project Starter Templates

Scaffold files for a new code4me project. Copied by `/code4me-init` (or copy manually).

## What's in here

- **`CLAUDE.md.example`** — annotated starter for your project's `CLAUDE.md` (the project-conventions file that layers on top of the plugin's baseline). Placeholders marked `PLACEHOLDER` or `<...>` should be edited or removed.
- **`.mcp-recommended.json`** — opinionated starter MCP configuration. Several servers are commented out by default (keys prefixed with `_`) — uncomment per project shape. See the project CLAUDE.md's "Available MCPs" section for documenting preferences.
- **`claude-settings.json.example`** — example file with the two opt-in PreToolUse hooks pre-wired. Destination is `<project-root>/.claude/settings.json` (note the leading dot). Replace `<PLUGIN_DIR>` with the absolute path to your code4me plugin checkout.

## How to use

If you have `/code4me-init` available (Claude Code with the code4me plugin enabled), run that in the project root and it will:

1. Copy `CLAUDE.md.example` → `<project-root>/CLAUDE.md` (only if the file does not already exist — `/code4me-init` will never overwrite a CLAUDE.md you've already written).
2. Copy `.mcp-recommended.json` → `<project-root>/.mcp.json` (only if the file does not already exist).
3. Copy `claude-settings.json.example` → `<project-root>/.claude/settings.json` (only if the file does not already exist), substituting `<PLUGIN_DIR>` with the absolute path to the plugin.
4. Also copy the runtime `.code4me/` skeleton (separately) from `templates/.code4me-skeleton/` to `<project-root>/.code4me/` — this is the working directory for milestone artifacts, separate from these project-conventions files.

Manual flow (if you'd rather):

```bash
# from your project root
cp <PLUGIN_DIR>/templates/project-starter/CLAUDE.md.example         CLAUDE.md
cp <PLUGIN_DIR>/templates/project-starter/.mcp-recommended.json     .mcp.json
mkdir -p .claude
cp <PLUGIN_DIR>/templates/project-starter/claude-settings.json.example .claude/settings.json

# then edit each file: replace placeholders, set PLUGIN_DIR, configure MCPs
```

## What's NOT in here

- **`.lsp.json`** — language-server configuration is plugin-shipped, not project-scoped. The plugin's root `.lsp.json` applies; you don't need a per-project copy. Add a language by adding a sibling key to the plugin's `.lsp.json` per README "LSP support → Adding another language."
- **MCP credentials** — the recommended config references environment variables (e.g., `GITHUB_PERSONAL_ACCESS_TOKEN`); set them in your shell, not in version-controlled files.
- **`.code4me/` runtime artifacts** — these live in a separate skeleton at `templates/.code4me-skeleton/`. The orchestrator copies them on first dispatch if `.code4me/` does not exist; `/code4me-init` also handles this.
