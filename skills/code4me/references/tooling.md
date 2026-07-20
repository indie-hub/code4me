# Tooling Preferences

Canonical tooling preferences for code4me subagents. Subagent prompts point here
so the order stays consistent across roles.

## Persistent Memory

Use **Basic Memory** when it is available through MCP. It replaces the old
project-local memory path for cross-session project knowledge.

Consult Basic Memory before decisions that benefit from prior context:

- architecture decisions and "do not repeat" preferences
- prior fixes and recurring failure modes
- project conventions that are not obvious from the current diff
- notes that the user or prior agents explicitly saved for future sessions

Preferred Basic Memory tools:

- `search_notes` or `search` to find prior decisions and fixes
- `read_note`, `read_content`, or `build_context` for a specific memory URL
- `write_note` or `edit_note` to persist durable decisions, postmortems, and
  reusable project guidance

On startup, follow `memory-map.md`: search for a project memory map/index note,
adapt to existing Basic Memory structure when present, and ask before writing a
new map. Do not create empty bucket notes up front; use atomic tagged notes.

Do not use memory as a substitute for source inspection. Memory answers "what
have we learned before?" Code indexes answer "what does the repo do now?"

## Source-Code Lookup

Use source-code indexes before `Read`, `Grep`, or context-mode for source-code
consultation.

### 1. codegraph

Use codegraph first for exact structural questions when the repo has
`.codegraph/codegraph.db`:

- "tell me about this symbol"
- "who calls this"
- "what does this call"
- "what is the downstream impact"
- "show neighboring definitions and call paths"

### 2. CocoIndex Code

Use CocoIndex Code for semantic or fuzzy source discovery when `ccc` or the
`cocoindex-code` MCP server is available:

- "where do we embed documents"
- "find the auth flow"
- "find code related to CSV export"
- "search implementations without knowing the exact symbol name"

Run `ccc index` once at the project root when the repo has not been indexed.
Via MCP, prefer the `search(query, limit, paths, languages)` tool.

### 3. LSP

LSP is legacy optional. Use it when a project still has `.lsp.json` and the
question needs language-server precision:

- exact type/signature hover
- diagnostics
- refactoring-grade single-language references
- implementation/definition in a language where LSP is known to be more precise

Standard installs do not generate `.lsp.json` by default. Use
`bin/code4me-install --with-lsp` only for projects that still want this path.

## MCPs

Prefer project-specific MCPs over fallback file reads when an MCP directly
serves the question:

- database shape questions -> database MCP
- PR or issue context -> GitHub/Jira MCP
- UI verification -> Playwright/browser MCP
- Trello status projection -> Trello MCP

MCPs are project-specific. The orchestrator should include the available MCP
inventory in each dispatch context pack with one-line preference notes.

## Local Agent Backends

`claude-p` from [indie-hub/claude-wrapper](https://github.com/indie-hub/claude-wrapper)
is an optional agent backend, not a memory or source-lookup tool. Use it only
when Codex is the orchestrator and a Claude/local-Claude consult was explicitly
requested or selected by cross-vendor policy.

Prefer a configured MCP worker/tool that wraps `claude-p`. If you must call it
from Codex directly, use the code4me helper so cwd, timeout, and JSON output are
explicit:

```bash
bin/code4me-claude-wrapper-run --prompt-file prompt.md --cwd "$PWD" --timeout-sec 300
```

Do not pass provider API environment variables to this path. The point is to use
the local Claude Code login state, with normal account and rate limits intact.

## context-mode

Use context-mode after the source-code indexes for:

- derived analysis over a known file or narrowed region
- logs, build output, generated reports, and large non-source text
- counting, filtering, aggregation, and transformation where raw bytes should
  stay out of the conversation

Do not use context-mode as the first step for "where is symbol X?", "who calls
Y?", or "what does this module do?" when codegraph or CocoIndex can answer.
The structural-first hook guards common context-mode source-search shapes. Claude asks for approval; Codex denies the call with fallback guidance.

## Fallback Tools

Use `Read`, `Grep`, and `Glob` when no structured surface applies, or when the
query is genuinely text-shaped:

- regex inside comments or string literals
- generated/build artifacts not indexed by code tools
- short direct reads after a code index already returned a file and line range
- non-source config or markdown searches

Keep fallback reads narrow. Prefer line ranges over whole-file reads once the
target area is known.

## Role Notes

| Role | Most-relevant tooling |
|---|---|
| Developer | Basic Memory for prior decisions; codegraph/CocoIndex for source navigation; context-mode for derived analysis |
| Combined Reviewer | codegraph/CocoIndex for change-site context; Basic Memory for prior bug patterns |
| Spec-to-Test | Basic Memory for test conventions; codegraph/CocoIndex to confirm interfaces |
| Verification | codegraph/CocoIndex for AC-to-implementation tracing; context-mode for evidence aggregation |
| Code Reviewer | codegraph for blast radius; CocoIndex for semantic adjacent-code discovery |
| QA | Basic Memory for prior incidents; project MCPs and browser tools as appropriate |
| Researcher | Basic Memory for saved project knowledge; external sources only when current facts are required |
