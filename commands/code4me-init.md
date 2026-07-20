---
description: Scaffold client-appropriate project instructions and the .code4me working directory. Creates AGENTS.md for Codex or CLAUDE.md for Claude Code, never overwrites existing files, and leaves hooks, MCPs, and machine-local paths to the installers.
---

Scaffold the current project for code4me. **Never overwrite existing files.** Surface a dry-run preview and wait for confirmation before writing.

## Ownership boundary

`/code4me-init` owns project-authored scaffolding only:

- `.code4me/` runtime working directory, for every client
- `AGENTS.md` when Codex is the orchestrator
- `CLAUDE.md` when Claude Code is the orchestrator

It must **not** create `.mcp.json`, `.claude/settings.json`, `.codex/hooks.json`, or `.lsp.json`, and must not invoke `code4me-install`. Machine/client wiring belongs to:

- `bin/code4me-install-deps --configure-mcp codex|claude|all` for MCPs
- `bin/code4me-install` for Claude project hooks and optional legacy LSP
- the Codex plugin bundle for required Codex hooks; the user only reviews and trusts them with `/hooks`

## Procedure

1. **Discover the plugin directory.** Resolve it from the currently loaded code4me skill/plugin. Do not assume a `~/.claude/` path. Store it as `PLUGIN_DIR`; ask the user only if it cannot be determined.

2. **Detect the current orchestrator.** Use the runtime identity, not files already present in the project:
   - Codex -> `CLIENT=codex`
   - Claude Code -> `CLIENT=claude`
   - If genuinely unknown, ask which client is running.

3. **Build the client-appropriate target list:**
   - Always: `.code4me/` <- `<PLUGIN_DIR>/templates/.code4me-skeleton/`
   - Codex only: `AGENTS.md` <- `<PLUGIN_DIR>/templates/project-starter/AGENTS.md.example`
   - Claude only: `CLAUDE.md` <- `<PLUGIN_DIR>/templates/project-starter/CLAUDE.md.example`

4. **Print the preview:**

   ```text
   code4me init - dry-run preview (client: <codex|claude>, project root: <cwd>)

   Will create:
     - <path>  (from <template>)
   Will skip (already exists):
     - <path>

   Installer-owned (not touched by init):
     - hooks
     - MCP registrations
     - machine-local paths / optional LSP
   ```

5. **Pause for confirmation.** Do not write until the user confirms.

6. **Copy only missing targets.** Copy the convention template as-is. For `.code4me/`, create the directory and recursively copy the skeleton. If any copy fails, stop and report the partial state explicitly.

7. **Print the post-init summary:**
   - client detected
   - files/directories created
   - targets skipped because they already existed
   - placeholders remaining in the created convention file
   - installer checklist:
     - configure integrations: `bash <PLUGIN_DIR>/bin/code4me-install-deps --configure-mcp <client>`
     - Claude only, wire project hooks: `bash <PLUGIN_DIR>/bin/code4me-install --project <cwd>`
     - Codex only, review and trust the bundled code4me hooks with `/hooks`
     - initialize code indexes when installed: `codegraph init -i` and `ccc index`
     - run `/code4me-preflight`

If both `AGENTS.md` and `CLAUDE.md` already exist, never attempt to merge or synchronize them. The current client's native file is authoritative for that client.
