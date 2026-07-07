# Public-release readiness audit — code4me-plugin

Generated against the current `code4me-plugin` working tree. Findings grouped by category. Each entry: `file:line — context`. CHANGELOG entries are flagged but mostly historical (append-only; cleanup optional).

---

## 1. Hardcoded Windows absolute paths

- .lsp.json:34:      "C:/Users/FVR/Documents/Share/code4me-plugin/clangd-didopen-proxy.mjs",

## 2. Hardcoded macOS / Linux absolute paths (other-user-shaped)

- .lsp.json:34:      "C:/Users/FVR/Documents/Share/code4me-plugin/clangd-didopen-proxy.mjs",

## 3. User identifier references (Bruno / FVR / personal email)

- .claude-plugin/plugin.json:6:    "name": "Bruno"
- .lsp.json:34:      "C:/Users/FVR/Documents/Share/code4me-plugin/clangd-didopen-proxy.mjs",

## 4. .agent/agents/ legacy lineage references

- CHANGELOG.md:1023:- Removed the harness migration item from the README's Current Scope and Roadmap. The legacy `.agent/agents/harness/` was designed for a context where prompt changes needed empirical falsification across a team; in single-developer iteration the live-test loop is providing equivalent signal at lower overhead. Decision is reversible — if the framework expands to multiple users later, a probe set can be added then.

## 5. Plugin assets in unexpected locations

Files at the plugin root that should probably be in `bin/` or moved:

- `clangd-didopen-proxy.mjs` — referenced by `.lsp.json`'s cpp entry. Should move to `bin/` so the .lsp.json can use `${CLAUDE_PLUGIN_ROOT}/bin/clangd-didopen-proxy.mjs` (or equivalent portable mechanism) instead of an absolute path.
- `code4me-v07-plan.html` — appears to be a plan deliverable, not plugin code. Consider moving to `docs/historical/` or removing for public release.

## 6. .lsp.json portability

Current `.lsp.json` has these portability issues:

- Line 34:      "C:/Users/FVR/Documents/Share/code4me-plugin/clangd-didopen-proxy.mjs",

Phase 1 action: ship `.lsp.json.example` (or per-platform `.lsp.json.{windows,macos,linux}.example`) with placeholder paths. Move the file from the repo root into `templates/project-starter/` since it's a template, not active config.

## 7. Hardcoded command paths in templates / settings examples

- templates/project-starter/.mcp-recommended.json:7:      "command": "npx",
- templates/project-starter/.mcp-recommended.json:21:      "command": "npx",

## 8. Examples assuming Bruno's stack

Probe / doc examples that lean specifically on C#/Swift/C++ (the three languages in your .lsp.json) without indicating they're examples not requirements:

- `.cs` / `cs` mentions: 32
- `.swift` / `swift` mentions: 9
- `.cpp` / `cpp` mentions: 10
- `.csharp` / `csharp` mentions: 3

_Many of these are legitimate (the structural-first hook tests use .cs/.swift/.cpp because those are the languages declared in the test .lsp.json). Worth reviewing the docs/howto-configure-lsp.md to confirm it presents the four shipped LSP configs (C#, Swift, C++, Python) as examples rather than the canonical set._

## 9. First-person voice in documentation

Phrases like 'my project', 'mine', 'I built', 'I use' that may need neutralizing for public release:


## 10. Missing public-release files

- Missing: `CONTRIBUTING.md`
- Missing: `CODE_OF_CONDUCT.md`
- Missing: `SECURITY.md`
- Missing: `.github/ISSUE_TEMPLATE/`
- Missing: `.github/workflows/`

## 11. CHANGELOG personal-shaped references (mostly historical, low priority)

- 1023:- Removed the harness migration item from the README's Current Scope and Roadmap. The legacy `.agent/agents/harness/` was designed for a context where prompt changes needed empirical falsification across a team; in single-developer iteration the live-test loop is providing equivalent signal at lower overhead. Decision is reversible — if the framework expands to multiple users later, a probe set can be added then.

_CHANGELOG is append-only by convention; these don't strictly need cleanup but you could neutralize on a clean-slate basis if going public._

## 12. References to specific external plugins / MCPs (verify they're presented as examples)

These tools / plugins are mentioned in the plugin's docs and skills; verify each is presented as an example or optional integration, not a hard requirement:

- `Basic Memory`: 33 mentions
- `context-mode`: 4 mentions
- `context-mode`: 4 mentions
- `trello-config`: 10 mentions
- `Reasonix`: 46 mentions
- `codex`: 221 mentions

## Summary — Phase 1 punch list (ordered by blocker severity)

1. **Fix .lsp.json portability** — single biggest blocker. Move out of repo root into `templates/project-starter/.lsp.json.example` (or per-platform variants). Replace absolute Windows paths with `${CLAUDE_PLUGIN_ROOT}` placeholders.
2. **Move clangd-didopen-proxy.mjs into `bin/`** — it's a plugin asset, not a project file.
3. **Scrub user identifier references** — `Bruno` / `FVR` in active (non-CHANGELOG) files.
4. **Move `code4me-v07-plan.html` out of repo root** — historical deliverable, doesn't belong in the plugin tree.
5. **Add CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md** — minimum public-release docs.
6. **Add .github/ISSUE_TEMPLATE/** — bug, feature, probe-failed templates.
7. **Add .github/workflows/probe.yml** — CI running the probe suite on Linux + macOS.
8. **Review docs first-person voice** — neutralize 'my', 'I', etc., to plugin-author-neutral framing.
9. **Write a fixture project** — a working example users can clone and run a milestone against.
10. **Rewrite README for newcomers** — currently structured for users who already understand code4me.
