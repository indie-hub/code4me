# Project Starter Templates

Scaffold files for a new code4me project. Copied by `/code4me-init` (or copy manually).

## What's in here

- **`CLAUDE.md.example`** — Claude Code project-instructions starter.
- **`AGENTS.md.example`** — Codex project-instructions starter.
- **`.mcp-recommended.json`** — optional reference for project-specific MCPs. `/code4me-init` does not copy it; use `bin/code4me-install-deps --configure-mcp` for code4me's standard integrations.
- **`claude-settings.json.example`** — example file with the two opt-in PreToolUse hooks pre-wired. Destination is `<project-root>/.claude/settings.json` (note the leading dot). Replace `<PLUGIN_DIR>` with the absolute path to your code4me plugin checkout.

## How to use

Run `/code4me-init` in the project root and it will:

1. Copy `AGENTS.md.example` to `AGENTS.md` for Codex, or `CLAUDE.md.example` to `CLAUDE.md` for Claude Code, only when the target does not exist.
2. Copy the runtime `.code4me/` skeleton to `<project-root>/.code4me/` when it does not exist.
3. Leave hooks, MCP registrations, and machine-local paths to the installer scripts.

Manual flow (if you'd rather):

```bash
# from your project root
cp <PLUGIN_DIR>/templates/project-starter/CLAUDE.md.example         CLAUDE.md
# Codex instead:
cp <PLUGIN_DIR>/templates/project-starter/AGENTS.md.example          AGENTS.md

# then edit the placeholders and run the relevant installer commands
```

## What's NOT in here

- **`.lsp.json`** — legacy optional and owned by `bin/code4me-install --with-lsp`, not init.
- **Hook and MCP configuration** — Claude hooks are owned by `bin/code4me-install`, Codex hooks are bundled with the plugin, and MCPs are owned by `bin/code4me-install-deps`; init does not duplicate them.
- **MCP credentials** — the recommended config references environment variables (e.g., `GITHUB_PERSONAL_ACCESS_TOKEN`); set them in your shell, not in version-controlled files.
- **`.code4me/` runtime artifacts in this directory** — they live in the separate `templates/.code4me-skeleton/`; `/code4me-init` copies that skeleton.
