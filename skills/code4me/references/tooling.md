# Tooling Preferences

Canonical statement of the tooling preferences code4me subagents follow. The actual directives live in each subagent's system prompt — this file is the single source so changes propagate from one place.

## LSP first

Before reading a whole file, prefer LSP-style queries when available:

- **go-to-definition** for a symbol
- **find-references** for who uses what
- **hover / type info** for signatures and shapes
- **document-symbols** to enumerate what's in a file without reading it
- **workspace-symbols** for navigation
- **go-to-implementation** for interfaces and abstract methods
- **call-hierarchy** (`prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`) for who-calls-whom

LSP queries are token-efficient and surface only what you need. Whole-file reads should be a fallback, not a default. When you do need a whole file, briefly justify it to yourself — that hygiene check keeps your context tight over the run of a task.

This applies to: navigating the codebase to understand a change site, confirming an interface exists as specified, finding callers of a function you're modifying, checking type shapes, locating tests for a module.

## Configured LSP servers

The plugin ships a `.lsp.json` at the root that wires language servers for specific languages. Subagents using LSP-aware tooling will pick these up automatically when `ENABLE_LSP_TOOL=1` is set in `~/.claude/settings.json`.

| Language | Server | Extensions | Status |
|----------|--------|------------|--------|
| C# | `roslyn-language-server` (Microsoft, via `dotnet tool install --global roslyn-language-server --prerelease`) | `.cs`, `.csx`, `.cshtml` | configured |
| Swift | `xcrun sourcekit-lsp` (bundled with Xcode 11.4+ / Command Line Tools) | `.swift` | configured |
| C / C++ | `clangd` (LLVM project; install via `brew install llvm`, `apt install clangd`, etc.) | `.cpp`, `.cxx`, `.cc`, `.c++`, `.hpp`, `.hxx`, `.hh`, `.h++`, `.h`, `.c` | configured |

Setup steps and troubleshooting live in the project README's "LSP support" section. To add another language, add a sibling key to `.lsp.json` and document it in this table.

## MCPs (project-level)

Unlike LSPs (language-shape, plugin-shipped), MCPs are project-shape — a database MCP needs a specific connection string, a Unity MCP needs a specific project path. They live in the project's `.mcp.json`, not the plugin's.

The plugin states the **principle**: prefer MCPs over fallback tools when an MCP serves the task. The project states the **inventory**: which MCPs are available and when to use each (typically in the project's `CLAUDE.md`).

### When to use an MCP

When you (the subagent) start a task, scan the available tools in your context for `mcp__*` entries. If any of them serve the question you need to answer, prefer them over `Read`, `Grep`, or `Glob`. MCPs are structured queries — token-efficient, surfacing only what you need — for the same reason LSP-first applies.

### Examples by domain

- Project files in a Unity codebase → `mcp__unity__*` (scene structure, prefab queries, component lookups, asset references) before reading `.unity`, `.prefab`, or `.meta` files
- Database shape questions → `mcp__db__*` (query, schema, indexes) before searching migrations
- Ticket / issue context → `mcp__jira__*` or `mcp__github__*` before reading whole issue threads
- CI / deployment status → `mcp__ci__*` before reading log files
- Internal documentation → `mcp__notion__*` or `mcp__confluence__*` before crawling URLs

### What if no MCP is available

Fall back to `Read`, `Grep`, `Glob`, or LSP queries (per the LSP-first rule above). The principle doesn't penalise the absence of MCPs — it penalises *ignoring* configured MCPs in favour of more expensive fallback tools.

### Why this matters

A subagent that uses `Read`+`Grep` when a configured MCP could have answered the question in one structured call has not failed any rule, but has spent context wastefully. Same hygiene argument as LSP-first.

---

## OpenWolf — first stop when available

OpenWolf is invisible middleware for Claude Code — six hook scripts that fire on tool calls plus a `.wolf/` directory in the project root. You don't invoke OpenWolf directly; you consult its `.wolf/` files before doing things, and the hooks intercept your reads/writes to enforce learning and prevent repeated work.

When OpenWolf is configured, the `.wolf/` files are your **first stops**, in this order of usefulness:

1. **`.wolf/cerebrum.md`** — accumulated user preferences, past corrections, and "Do-Not-Repeat" patterns. **Read this before every meaningful decision** — before classifying weight, before writing code, before choosing a design, before producing tests. The cerebrum often pre-decides routing; ignoring an entry is a known failure mode the hooks try to catch. This is the single most valuable file in `.wolf/` because it carries cross-session, cross-milestone learning the user has already paid for once.
2. **`.wolf/anatomy.md`** — project file map. Every file has a one-line description and a token estimate. Read *before* opening any file; often the description is enough and you don't need to read the file at all. Whole-file reads should be a fallback, not a default.
3. **`.wolf/buglog.json`** — bug-fix memory keyed by error message. Before diagnosing an error, search this file. The same error has often been fixed before; the fix is recorded. **Do not read the whole file** — it grows to hundreds of entries (~90k+ tokens). Query it with the `bin/code4me-buglog` helper, which returns only the matching entries: `code4me-buglog search --error "<substring>"` (or `--tag`, `--file`, `--since`), `code4me-buglog get <bug-id>`, `code4me-buglog stats`. To record a fix, `code4me-buglog add --error … --file … --fix …` (dedup-aware: bumps `occurrences` on a recurrence) or `code4me-buglog update <bug-id> …`. The helper writes in OpenWolf's exact format, so it coexists with OpenWolf's own auto-logger. (`code4me-buglog doctor [--fix-ids]` reports/repairs integrity issues such as duplicate ids.) A PreToolUse hook (`check-buglog-helper.sh`, auto-wired) enforces this: a whole-file Read/Grep or a hand-edit of `.wolf/buglog.json` is ask-gated and redirected here, so the guidance holds even under drift. (It self-disables when the project has no `.wolf/buglog.json`.)
4. **`.wolf/memory.md`** — chronological action log of what's been done in recent sessions. Useful for understanding context if you need to know what changed earlier.

The hooks themselves are invisible — they fire automatically on your tool calls. Repeated reads of the same file in one session will be warned or blocked. After writes, `anatomy.md` auto-updates. You don't manage any of that.

`.wolf/OPENWOLF.md` carries auto-loaded session instructions; if you're a subagent, your context already has them — don't re-read.

### Why cerebrum specifically

The Insight Register (`.code4me/insight-register-{milestone_id}.md`) is per-milestone audit. Cerebrum is cross-project memory. They're related — `required` impact-tier INSIGHTs propagate from the register into cerebrum (see `references/insight.md`) — but cerebrum is what survives across sessions. Reading it first gives you everything the user has effectively pre-authorised about how this codebase should be handled.

A subagent that writes code without consulting cerebrum.md and ends up violating a Do-Not-Repeat entry has not failed a rule, but has wasted everyone's effort on something the user already corrected. Same hygiene argument as LSP-first, but with a stronger case: cerebrum is uniquely the user's voice from prior work.

## When neither applies

Fall back to standard file reads (`Read`, `Grep`, `Glob`), but stay narrow:

- read only the regions you need (use line offsets and limits when a file is large)
- prefer `Grep` for "where is this referenced" questions when LSP is unavailable
- prefer `Glob` for structural questions over reading every file

## Subagent-specific notes

| Role | Most-relevant tooling |
|------|------------------------|
| Developer | LSP (definitions, references, types); OpenWolf for module-level inspection |
| Combined Reviewer | LSP for change-site context (callers, callees); OpenWolf for spot-checking adjacent files |
| Spec-to-Test | LSP to confirm interfaces exist; Grep + OpenWolf to find existing test conventions |
| Verification | LSP for AC-to-implementation tracing; Grep for evidence; whole-file reads only when necessary |
| Code Reviewer | LSP for structural analysis; OpenWolf for fast cross-reference of the change |
| QA | OpenWolf for inspecting boundaries around the change; runtime tools as appropriate |
| Researcher | OpenW