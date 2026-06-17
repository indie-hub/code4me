# How to use codegraph with code4me

[codegraph](https://github.com/colbymchenry/codegraph) is an MCP server that pre-indexes a repository into a local SQLite knowledge graph (symbols + edges: calls, imports, extends, implements, framework routes, cross-language bridges) via tree-sitter. Its MCP tools (`codegraph_explore`, `codegraph_callers`, `codegraph_callees`, `codegraph_impact`, `codegraph_search`) give the agent rich, structural answers to "what calls X?", "where is Y defined?", and "if I change Z, what breaks?" in a single tool call.

As of v0.13.0-dev, code4me recognizes codegraph as a **structural-first alternative to LSP**. When the project is indexed (i.e., `.codegraph/codegraph.db` exists at the project root), the LSP-first hook (`check-lsp-first-on-source.sh`) lists both codegraph and LSP in its redirect message. The agent picks whichever fits the question; neither is required.

This is an **optional integration** — the plugin works fully without it. The reason to consider adopting codegraph: many models reach for whole-file `Read` and bare-identifier `Grep` instead of LSP because LSP's per-symbol round-trip ceremony doesn't match how they reason. codegraph's response shape — rich text in one MCP call — does. Adding codegraph gives the agent a second structural path with a friendlier shape, which (based on the reasoning in `docs/explanation.md`) should meaningfully reduce "agent avoids LSP, falls back to Read/Grep" patterns.

## Status and maturity caveat

codegraph is **pre-1.0** (latest v0.9.9 as of June 2026). It's actively developed (43k stars, 411 commits, regular releases), but you're integrating with a project that may ship breaking changes before 1.0. code4me's hook integration is **detection-based** (presence of `.codegraph/codegraph.db`) — if you uninstall codegraph, the hook falls back to LSP-only with zero code changes.

## Install codegraph

Three options:

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh

# Windows (PowerShell)
irm https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1 | iex

# Via npm (any platform with Node)
npm i -g @colbymchenry/codegraph
```

Verify:

```bash
codegraph --version
```

## Wire codegraph into Claude Code

```bash
codegraph install
```

This auto-detects Claude Code (and other supported agents) and writes the MCP server entry into `~/.claude.json` under `mcpServers.codegraph`. The wired command is `codegraph serve --mcp` (stdio MCP server).

If you prefer manual setup, add to your `~/.claude.json`:

```json
{
  "mcpServers": {
    "codegraph": {
      "command": "codegraph",
      "args": ["serve", "--mcp"]
    }
  }
}
```

Restart Claude Code. The `codegraph_*` MCP tools should now appear in your tool inventory.

## Index your project

```bash
cd /path/to/your/project
codegraph init -i
```

This builds `.codegraph/codegraph.db` at the project root. The first index takes a minute or two for a small project, longer for a large one. A file watcher (native OS events: FSEvents / inotify / ReadDirectoryChangesW) keeps the database in sync as files change — you don't need to re-run init manually.

Verify the database exists:

```bash
ls -la .codegraph/codegraph.db
```

That file is what the code4me hook detects.

## What changes in code4me when codegraph is detected

Two things, both automatic:

1. **The LSP-first hook's redirect message lists codegraph first.** When the agent does a whole-file `Read` on a source file (or a bare-identifier `Grep`, or a symbol-shaped `ctx_execute_file` query, etc.), the hook returns `permissionDecision: ask` with a message that now lists `codegraph_explore`, `codegraph_callers`, `codegraph_callees`, `codegraph_impact`, `codegraph_search` alongside the LSP textDocument/* methods. Both are presented as valid structural paths.
2. **The ask-gate event log records `codegraph_available: true`.** Entries in `.code4me/lsp-first-events.jsonl` include this field, so the audit tool can later report on whether agents shifted toward structural tools after codegraph adoption.

When `.codegraph/codegraph.db` doesn't exist, the hook falls back to LSP-only — same behavior as v0.12 and earlier. No regression for non-adopters.

## Confirm the integration is live

```bash
bin/code4me-preflight
```

The output should include a line like:

```
✓ codegraph (optional)  codegraph CLI on PATH; .codegraph/codegraph.db indexed for this project
```

If codegraph is installed but the project isn't indexed yet, you'll see a warn-level note pointing you at `codegraph init -i`.

## When to use codegraph vs LSP

Both are structural; pick by question shape:

- **Use codegraph first for cross-file and graph-shaped questions.** "Who calls this function across the repo?" (`codegraph_callers`). "If I change this class, what breaks downstream?" (`codegraph_impact`). "Tell me about this symbol including its cross-language neighbors" (`codegraph_explore`).
- **Use LSP first for type-precise and language-specific questions.** "What's the exact signature of this method?" (`textDocument/hover`). "What's wrong with this file?" (`textDocument/diagnostics`). "What implementations does this interface have?" (`textDocument/implementation`).

When in doubt, codegraph's one-call rich response is usually faster to digest than LSP's per-symbol round-trips, and the agent will reach for it more naturally because the tool name (`codegraph_explore`) reads as obviously useful where `mcp__plugin_context-mode_context-mode__ctx_execute` does not.

## Removing codegraph

If you decide it's not for you:

1. Uninstall the CLI: `npm uninstall -g @colbymchenry/codegraph` (or the install script's removal step).
2. Remove the MCP server entry from `~/.claude.json` (delete the `codegraph` key under `mcpServers`).
3. Delete `.codegraph/` at the project root if you want to reclaim disk: `rm -rf .codegraph/`.

The code4me hook automatically falls back to LSP-only as soon as `.codegraph/codegraph.db` is gone. No code4me-side configuration change needed.

## Troubleshooting

**Hook still suggests only LSP even though codegraph is installed.** Check that `.codegraph/codegraph.db` exists at the project root (not a subdirectory). If you ran `codegraph init` in a subdirectory, the hook won't detect it.

**Agent ignores both codegraph and LSP and uses `Read` anyway.** The hook is `permissionDecision: ask`, not `deny` — agents can proceed past the ask. If this happens consistently, scan `.code4me/lsp-first-events.jsonl` to count ask-gate fires; if proceed-anyway is the norm, the issue isn't tool availability, it's prompt-side discipline. See `skills/code4me/references/code-consultation-precedence.md` §"When the ask-gate is 'wrong' — legitimate proceed cases" for the design rationale.

**codegraph claims to support a language but the database is empty for those files.** Check codegraph's docs for the language's status (some are marked "Partial support"). For unsupported languages, fall back to LSP if `.lsp.json` covers them.

**codegraph's file watcher misses changes.** Re-index manually: `codegraph init -i`. The watcher is OS-event-based and can miss updates from atomic-rename tools (some editors).

## Pointers

- [codegraph repo](https://github.com/colbymchenry/codegraph) — install, MCP tool reference, language support matrix.
- `hooks/check-lsp-first-on-source.sh` — the hook that detects codegraph and surfaces it in the redirect message.
- `skills/code4me/references/code-consultation-precedence.md` — the precedence rules: when to reach for codegraph vs LSP vs Read vs Grep.
- `docs/howto-configure-lsp.md` — companion how-to for LSP setup; complementary to this doc.
