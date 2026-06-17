---
description: Scaffold a new project for code4me. Creates the project-conventions files (CLAUDE.md, .mcp.json, .claude/settings.json) from the templates if they don't already exist, and creates the runtime .code4me/ working directory from the skeleton. Never overwrites existing files — surfaces what would be skipped before doing anything.
---

Scaffold the current project to work with code4me. **Never overwrite existing files** — if a target file already exists, skip it and report. Surface a dry-run preview before writing anything; only proceed after confirming.

Procedure:

1. **Discover the plugin's checkout directory.** The code4me plugin is installed somewhere known to Claude Code; find that path (typically under `~/.claude/plugins/code4me/` or wherever it was cloned). Store as `PLUGIN_DIR`. If you cannot determine it, ask the user to provide the absolute path.

2. **Run the dry-run preview.** For each of these target files, check whether it already exists in the project root:
   - `CLAUDE.md` ← `<PLUGIN_DIR>/templates/project-starter/CLAUDE.md.example`
   - `.mcp.json` ← `<PLUGIN_DIR>/templates/project-starter/.mcp-recommended.json`
   - `.claude/settings.json` ← `<PLUGIN_DIR>/templates/project-starter/claude-settings.json.example`
   - `.code4me/` directory ← `<PLUGIN_DIR>/templates/.code4me-skeleton/`

3. **Print the preview.** Format:

   ```
   code4me init — dry-run preview (project root: <cwd>)

   Will create:
     - <path>  (from <template>)
     - <path>  (from <template>)
   Will skip (already exists):
     - <path>
   ```

4. **Pause for confirmation.** Ask the user to confirm before proceeding. Do not write anything until they confirm.

5. **On confirmation, copy each non-existing target.** For `.code4me/` skeleton, create the directory and copy the contents recursively. For `CLAUDE.md` and `.mcp.json`, copy as-is.

   **Do NOT hand-substitute `<PLUGIN_DIR>` in `.claude/settings.json` or `.lsp.json`.** Instead, after copying, run the installer — it self-locates the plugin and writes the correct machine-local absolute paths, probing which LSP servers are actually present and tailoring `.lsp.json` to this platform (e.g. `roslyn-language-server.cmd` on Windows vs `roslyn-language-server` elsewhere; the clangd didopen-proxy only on Windows):

   ```bash
   bash <PLUGIN_DIR>/bin/code4me-install --project <cwd>
   ```

   (Use `--dry-run` first to preview. The installer is idempotent and backs up any file it changes to `<file>.bak`.) This is what wires the PreToolUse hooks into `.claude/settings.json` with real paths and generates a valid `.lsp.json`.

6. **Post-init summary.** Print:
   - Files created (paths)
   - Files skipped (paths + reason "already exists")
   - What `code4me-install` wired: hooks in `.claude/settings.json`, LSP servers detected/written to `.lsp.json`, and any servers it skipped (with install hints).
   - Next steps: edit the `PLACEHOLDER`/`<...>` sections of `CLAUDE.md`; uncomment any `_disabled_by_default` MCP entries in `.mcp.json` you want to use; set any required env vars (`GITHUB_PERSONAL_ACCESS_TOKEN`, etc.); run `/code4me-preflight` to confirm the wiring resolves; in Claude Code, `/hooks` shows the registered hooks.
   - Note: `code4me-install` configures LSP *clients* but does not *install* the language-server binaries — see README "LSP support" for install routes per language you use. Re-run `code4me-install` after installing a server to pick it up.

If any step fails (permission, missing template, etc.), stop and surface the error clearly. Do not partially scaffold.
