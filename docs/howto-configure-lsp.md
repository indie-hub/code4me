# How to configure LSP for code4me

The plugin ships a `.lsp.json.example` at `templates/project-starter/` that wires language servers for the languages it's pre-configured for: C# (Roslyn), Swift (SourceKit-LSP), C++ (clangd), and Python (Pyright). LSP-aware subagents get go-to-definition, find-references, hover, document-symbols, workspace-symbols, and call hierarchy without burning context on whole-file reads.

> **Note (v0.13+):** LSP is one of two structural-first paths code4me recognizes. The other is [codegraph](howto-use-codegraph.md), a tree-sitter-based MCP server that pre-indexes the repo into a local SQLite graph. Both are optional, both are detected by the LSP-first hook, and either is sufficient — they're complementary, not redundant. LSP excels at type precision and language-specific diagnostics; codegraph excels at cross-file graph traversal and a one-call rich response. See `skills/code4me/references/code-consultation-precedence.md` for the precedence and `docs/howto-use-codegraph.md` for the codegraph setup.

## Setting up .lsp.json

Copy the template to your project root and edit it:

```bash
cp <PLUGIN_DIR>/templates/project-starter/.lsp.json.example .lsp.json
```

The C# and Swift entries auto-resolve via PATH and need no edits — just have the respective LSP servers installed (per the per-language sections below).

The **C++ entry** is the only one needing a manual edit. It uses a Node-based shim (`bin/clangd-didopen-proxy.mjs`) to work around Claude Code CLI bug [anthropics/claude-code#29501](https://github.com/anthropics/claude-code/issues/29501) where AST-requiring LSP requests get dispatched without a prior `textDocument/didOpen`. Replace `<PLUGIN_DIR>` in `cpp.args[0]` with the absolute path to your code4me plugin checkout. On a default Claude Code plugin install, the path is typically:

- **macOS / Linux:** `~/.claude/plugins/cache/code4me/<version>/`
- **Windows:** `%USERPROFILE%\.claude\plugins\cache\code4me\<version>\` (use forward slashes in the JSON, Node accepts them on Windows too)

Check `~/.claude/plugins/installed_plugins.json` for the exact `installPath` if unsure.

If you don't use C++, you can delete the `cpp` block from your `.lsp.json` entirely.

## Enabling the LSP tool

Add this to `~/.claude/settings.json` (or your project's `.claude/settings.json`):

```json
{ "env": { "ENABLE_LSP_TOOL": "1" } }
```

Required regardless of which language servers you use. With `ENABLE_LSP_TOOL=0` or absent, subagents fall back to Read/Grep (more context-expensive).

`/code4me-preflight` checks this and warns if it's not set.

## Per-language setup

### C# (Roslyn)

Install as a global .NET tool:

```
dotnet tool install --global roslyn-language-server --prerelease
```

This places the binary in `~/.dotnet/tools/`. Make sure that folder is on your `PATH` so `roslyn-language-server` resolves; otherwise edit the `command` field in `.lsp.json` to use an absolute path.

The default `args` are `--stdio --autoLoadProjects --logLevel Information --extensionLogDirectory .code4me/lsp-logs`. The first two are canonical flags for stdio communication and project auto-discovery; the latter two are required by Microsoft.CodeAnalysis.LanguageServer and write logs to `.code4me/lsp-logs/`. Adjust if you want logs elsewhere.

### Swift (SourceKit-LSP)

SourceKit-LSP is bundled with Xcode (11.4+) and the Command Line Tools — no separate install. The plugin invokes it via `xcrun sourcekit-lsp`, which resolves the active Xcode toolchain automatically. Verify with: `xcrun -f sourcekit-lsp` should print a path under `Xcode.app/Contents/Developer/Toolchains/...` or `/Library/Developer/CommandLineTools/...`.

If you're on a system without Xcode and only have the Command Line Tools, ensure they're properly selected (`xcode-select -p`). `xcrun` will route to whichever toolchain is active.

SourceKit-LSP also supports C-family languages (C, C++, Objective-C, Objective-C++) via its clangd integration, but the plugin's `swift` entry is Swift-only. For C++ the plugin uses standalone `clangd`. For Objective-C / Objective-C++ in mixed Apple projects, extend the Swift entry's `extensionToLanguage` map to include `.m`, `.mm`, etc.

### C++ / C (clangd)

`clangd` is the LLVM-project language server for C-family code (C, C++, Objective-C, Objective-C++). The plugin defaults to using `clangd` via `PATH` resolution.

Install:

- **macOS**: `brew install llvm` (then ensure `$(brew --prefix llvm)/bin` is on your `PATH`), or use the version bundled with Xcode via `xcrun -f clangd`
- **Linux**: `apt install clangd` (Debian/Ubuntu), `dnf install clang-tools-extra` (Fedora), or download from [LLVM releases](https://releases.llvm.org/)
- **Windows**: `winget install LLVM.LLVM` or `choco install llvm`, or an LLVM installer

Verify with: `clangd --version` should print a version like `clangd version 17.0.6`.

The default `args` are `--background-index --clang-tidy`. Background indexing builds a persistent project-wide symbol index in `.clangd/index/` (and `~/.clangd/index/` for shared header indexes like the STL); first build can take a minute on large projects, then subsequent sessions are instant. `--clang-tidy` enables clang-tidy diagnostics inline; useful for the Code Reviewer subagent's quality work, drop it if your project uses different lint tooling.

For non-trivial projects you want a `compile_commands.json` at the project root or in `build/` so clangd knows the actual compile flags. CMake produces this with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`; for other build systems see [clangd installation docs](https://clangd.llvm.org/installation).

The plugin's default `extensionToLanguage` covers `.cpp`, `.cxx`, `.cc`, `.c++` (C++ source); `.hpp`, `.hxx`, `.hh`, `.h++`, `.h` (headers); and `.c` (plain C). `.h` is ambiguous — clangd handles it correctly when `compile_commands.json` is present.

### Python (Pyright)

`pyright` is Microsoft's static type checker for Python. Its LSP-mode binary `pyright-langserver` provides type inference, go-to-definition, find-references, and inline diagnostics with strong support for `typing`, dataclasses, Pydantic, and protocol classes.

Install:

- **macOS / Linux / Windows (via Node)**: `npm install -g pyright` — canonical install route
- **macOS / Linux (via pip)**: `pip install pyright` — convenient if you don't want Node, but couples the install to one Python
- **macOS (via Homebrew)**: `brew install pyright`

Verify with: `pyright --version` should print `pyright 1.1.x`. The LSP-mode entry point is `pyright-langserver` (separate binary; same install).

The default `args` are `--stdio` — the canonical flag for stdio communication. No additional flags needed; pyright auto-discovers project configuration from `pyrightconfig.json` or the `[tool.pyright]` block in `pyproject.toml`.

For strict-mode type checking on new code, add to your `pyproject.toml`:

```toml
[tool.pyright]
typeCheckingMode = "strict"
include = ["src"]
```

Or use the per-file pragma `# pyright: strict` at the top of individual modules. Strict mode is the recommended default for new Python; gradually-typed legacy code can stay at `"basic"`.

The plugin's `extensionToLanguage` covers `.py` and `.pyi`. Skip `.ipynb` (Jupyter notebooks need separate tooling — Jupyter LSP, ipykernel) and `.pyx` (Cython is a different language).

## Adding another language

Add a sibling key to `.lsp.json` — e.g.:

```json
"go": {
  "command": "gopls",
  "args": ["serve"],
  "extensionToLanguage": { ".go": "go", ".mod": "go.mod", ".sum": "go.sum" }
}
```

The per-language tooling table in `skills/code4me/references/tooling.md` is where to document the recommendation alongside the new entry.

## What this gives the subagents

LSP-aware subagents (Developer, Spec-to-Test, Verification, Code Reviewer, QA, Combined Reviewer, and the Codex shims) prefer LSP queries over Read/Grep for code-symbol navigation per `references/tooling.md`. Concretely:

- Looking up a function definition is one LSP call, not a full-file Read + grep.
- Find-references across a project is a single query, not a recursive grep.
- Document-symbols give the subagent a module's shape in one call.
- Workspace-symbols answer "where's the auth code?" without exploration.

The orchestrator's Context Pack includes a tooling-hierarchy reminder per dispatch (LSP → MCP → Read/Grep/Glob), so subagents are nudged toward LSP at every wake. The savings compound: on a multi-subagent dispatch chain, LSP can cut total tokens by 30-50% versus Read-heavy fallback.

## Runtime enforcement: the LSP-first hook (v0.10.5+)

The starter `claude-settings.json` wires `hooks/check-lsp-first-on-source.sh` against context-mode's `ctx_execute` / `ctx_execute_file` / `ctx_batch_execute`. The hook auto-detects whether `.lsp.json` exists at the project root — if it does, the hook activates and ask-gates symbol-shaped queries (grep/rg/ag/ack on source files, ctx_execute_file with symbol-search verbs, cat/head/sed reading source paired with class/function regex). If `.lsp.json` is absent, the hook silently passes through.

The hook's purpose: when a subagent reflexively reaches for `ctx_execute` to do a symbol lookup that LSP could answer in one call, the hook surfaces a redirect message with the relevant LSP capabilities (definition / references / hover / documentSymbol / workspace_symbol / diagnostics). The agent can proceed with `yes` if the query is a genuine LSP carve-out (regex inside comments, cross-language search, fuzzy match) — those proceeds are auditable via `bin/code4me-audit-dispatch-log`'s LSP-first surveillance section.

Adding a new language to `.lsp.json` automatically extends the hook's coverage — no hook code change needed. The hook reads `.lsp.json` at every invocation, builds the source-file extension regex from the union of declared extensions, and matches against the tool input.

See `skills/code4me/references/code-consultation-precedence.md` for the full precedence ordering (LSP → Read → ctx_execute_file analysis → ctx_search → ctx_execute grep) and the documented carve-outs.
