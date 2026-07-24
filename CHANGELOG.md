# Changelog

All notable changes to this plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.15.5-dev] — in progress

### Changed

- Structural-first source routing is now a non-blocking `additionalContext` nudge in Claude and Codex. It emits no permission decision, while the three state-backed write guards retain Claude `ask` and Codex `deny` behavior.
- `/code4me-init` is now client-aware and project-only: Codex gets `AGENTS.md`, Claude Code gets `CLAUDE.md`, and both get `.code4me/`. Init no longer duplicates installer ownership by creating MCP, hook, or LSP configuration.
- Codex hooks are now a required plugin-bundled surface instead of an optional project template. A Codex adapter checks every path in `apply_patch` payloads and maps unsupported `ask` gates to actionable denies; Claude keeps its existing approval prompts.
- Installation and hook documentation now provides one complete Claude/Codex setup flow, and the retired external specification workflow has been removed from guidance, probes, and history.

## [0.15.2-dev]

### Added

- `code4me-install-deps --configure-mcp codex|claude|all` idempotently registers Basic Memory and CocoIndex, delegates codegraph configuration to its installer, installs context-mode through each client's plugin marketplace, and prints a final user-action checklist. Preflight now recognizes current Claude and Codex context-mode installations instead of checking only the obsolete Claude directory layout.

## [0.15.1-dev]

### Fixed

- Windows Git Bash hook installation now writes LF-only `settings.json`, preflight strips native `jq.exe` CRLF record terminators before checking paths, and genuinely corrupted hook commands with a trailing carriage return receive an explicit reinstall diagnosis.

## [0.15.0-dev]

### Added

- Multi-vendor LLM-as-judge backends for probes and `/code4me-improve`: Anthropic API, subscription-backed `claude-p`, signed-in Codex CLI, and Reasonix. Backend selection is explicit, results record the resolved backend/provider/model/effort, and missing backends fail without fallback.

### Changed

- CLI judges run isolated from the project: `claude-p` receives no tools and an empty cwd, Codex uses an empty read-only sandbox, and Reasonix uses an empty `-dir`. Reasonix provider aliases are verified against their concrete model through `reasonix doctor --json`.
- Improve experiments now freeze and reuse the judge backend, provider, model, and supported effort across public/held-out baseline and candidate runs.

## [0.14.2-dev]

### Fixed

- Strip native Windows `jq` CRLF record terminators when reading held-out manifest paths and hashes, so verified probes run correctly under Git Bash.

- Windows Git Bash held-out probe manifests now preserve POSIX paths during `jq` serialization and normalize drive-letter paths through `cygpath`; symlink-capability tests skip platforms that emulate `ln -s` as a copy.

## [0.14.0-dev] — in progress

### Added

- `/code4me-improve`: supervised baseline-first improvement experiments in a clean temporary worktree, with frozen probe manifests, one approved candidate change, held-out isolation, and explicit keep/revert.
- Independent dispatch effort defaults and logging (`effort`, `default_effort`, deviation/source/application fields), including backward-compatible legacy tier fallback.
- Focused model-routing, improve-supervision, mapping, wrapper, audit, and probe-structure tests.

### Changed

- Current vendor mappings: Anthropic Haiku 4.5 / Sonnet 5 / Opus 4.8 (Fable 5 explicit-only), OpenAI GPT-5.6 Luna / Terra / Sol, DeepSeek V4 Flash / V4 Pro.
- Codex bridge now documents stdin prompts and `model_reasoning_effort`; Reasonix uses project-overrideable, doctor-verified provider aliases and honestly records unsupported effort as not applied. Former invalid `deepseek-v4-pro[1m]` overrides must migrate to `deepseek-v4-pro` or an exact custom model plus `reasonix_aliases` entry.
- Claude wrapper helper validates and forwards `--effort`.

## [0.13.4-dev]

### Added

- Vertical slicing guidance: Standard/Critical decomposition now prefers Elephant Carpaccio-style user/API-observable slices over horizontal technical task breakdowns.
- Bumped plugin manifests to avoid Codex reusing a cached `0.13.3-dev` install.

## [0.13.3-dev]

### Fixed

- Codex plugin install now accepts bundled hook config: removed non-schema metadata fields from `hooks/hooks.json` and the Codex hooks template.
- Bumped plugin manifests to avoid Codex reusing a cached `0.13.2-dev` install.

### Added

- Basic Memory map adoption protocol: on startup, code4me now searches for an existing memory map, proposes an adapter when project memory already exists, and only proposes the default map for empty memory stores.

## [0.13.2-dev]

### Added

- **`bin/code4me-install-deps`** — opt-in dependency checker/installer for macOS, Linux/WSL, and Windows Git Bash. Default mode is read-only status; `--install core|memory|indexes|agents|claude-wrapper|all` runs explicit package-manager commands only for the selected group.
- **Claude wrapper docs/preflight** — documents [indie-hub/claude-wrapper](https://github.com/indie-hub/claude-wrapper) as the optional `claude-p` backend for Codex-orchestrated local Claude Code consultation.
- **Codex-as-orchestrator prompt guidance** — code4me skill references now explain when a Codex Producer may route an Anthropic/Claude-side role through a configured local `claude-p` worker, and how to degrade/block when `claude-p` is unavailable.

- **Claude wrapper subprocess helper** — adds `bin/code4me-claude-wrapper-run` as the bounded Codex-to-`claude-p` invocation path.
- **Codex quickstart and hooks template** — adds `docs/howto-run-with-codex.md`, `docs/howto-use-codex-hooks.md`, and `templates/project-starter/codex-hooks.json.example`.

### Changed

- README and manifests now advertise `0.13.2-dev`.

- Recommended MCP defaults no longer include `sequential-thinking`.

## [0.13.1-dev] — in progress

**audit4me Phase 1** — the first real auditing. On top of Phase 0's committed data model and read-only surface, this ships a single-vendor (`anthropic`), single-category (`bugs`) audit sweep via `/audit4me-run`, validating the whole architecture end-to-end: deterministic outer loop (bash + `jq`) + per-file judgment (the `code4me-audit-orchestrator` subagent) + atomic, resume-safe persistence. No proposed fixes yet — findings are surfaced for review only (multi-vendor agreement is Phase 2, failing tests Phase 3, `/audit4me-apply` Phase 4).

Two open design questions from the design doc were resolved before building, both per their documented recommendation: **coverage granularity is file-level** (symbol-level deferred to Phase 5+ if re-audit noise becomes real), and **findings are invalidated on content-hash change** (a finding is pinned to a hash; when the hash moves, the finding goes stale rather than being mapped forward).

### Added — audit4me Phase 1

- **`commands/audit4me-run.md`** — the sweep entry point. Flags: `--paths`, `--changed-since`, `--max-files`, `--vendor anthropic`, `--category bugs`, `--force-audit`. Drives the outer loop, honours the cost/time/files boxes, takes a run lock, writes a run summary. Read-only on production source.
- **`skills/audit4me/subagents/code4me-audit-orchestrator.md`** — the per-file judgment unit, dispatched once per file via the Task tool. Phase 1 minimal: one vendor, one category, no aggregation. Defines the `{file_path, content_hash, coverage_entry, config, run_id, vendor, model, category}` → `{findings[], updated_coverage_entry, insight?}` contract that Phase 2 builds on.
- **`skills/audit4me/references/audit-prompt-bugs.md`** — the load-bearing artifact: second-person `bugs`-category audit instructions (precision over recall, only defects you can point to, no cross-file speculation, empty result is valid) and a strict JSON RETURN SCHEMA (`findings[]` with `severity`, `line_range`, `summary`, `evidence`, `reproduction_steps`, `affected_inputs`). `rules_version` baseline `v0.1.0`.
- **`bin/audit4me-helpers.sh`** — deterministic outer-loop bookkeeping (pure bash + `jq`, no python/node): `hash-file`, `resolve-scope`, `work-set` (with the five re-audit triggers: uncovered / vendor-uncovered / content-change / rules-version-change / category-uncovered / refresh-stale), `coverage-update` (atomic via tmp + `mv`), `event-append` (forced single-line JSONL), `alloc-finding-id` (per-day sequence), `new-run-id`.
- **`bin/audit4me-rebuild-coverage.sh`** — disaster recovery: reconstructs `audit-coverage.json` from the append-only `audit-events.jsonl` (the source of truth), recomputing per-vendor entries and `coverage_level`.
- **`probes/audit4me/01-single-vendor-run.md`** and **`02-resume-after-interruption.md`** — integration (run-and-inspect) probes covering the end-to-end sweep (findings + coverage + events, idempotent re-run, read-only invariant) and crash-safe resume (atomic coverage, no double-audit, stale-lock handling).

### Changed — audit4me Phase 1

- **`skills/audit4me/SKILL.md`** — scope note moved from Phase 0 to Phase 1; added the `/audit4me-run` operating-loop section (deterministic outer loop vs. per-file orchestrator split, the crash-safe persist order — findings → event → coverage-update-last, resume + rebuild semantics); file inventory updated to include the new subagent, prompt, and helpers.

### Notes

- **Crash-safety ordering.** Per-file persistence is **findings → event-append → coverage-update (last)**. Coverage is the resume marker, so a crash can only ever cause a file to be redone next run, never falsely marked audited.
- **Single-vendor coverage level.** In a 1-vendor deployment one audit yields `coverage_level: full-covered` (one vendor *is* the full dialectic surface); `single-vendor` only appears when `vendors_available ≥ 2`.

### Added — OpenWolf buglog tooling

- **`bin/code4me-buglog`** (Python, stdlib-only) — a token-cheap inspector/editor for OpenWolf's `.wolf/buglog.json`. OpenWolf's documented consult path is "read the whole file before fixing," but that file grows to hundreds of entries (~90k+ tokens). The helper replaces the whole-file read with targeted queries: `search` (by `--error`/`--tag`/`--file`/`--since`, oneline/full/count), `get <id>`, `stats`; plus dedup-aware `add` and `update <id>` (by bug number), and a `doctor [--fix-ids]` for integrity issues. Writes are byte-identical to OpenWolf's own writer (`JSON.stringify(data, null, 2)` — indent=2, UTF-8 literals, no trailing newline, `bug-NNN` ids, `occurrences`/`last_seen` recurrence bump), atomic (tmp + replace) with a rolling `.bak`, so it coexists with OpenWolf's auto-logger. `get`/`update` refuse on ambiguous (duplicate) ids; `doctor` found and can repair 6 pre-existing duplicate ids in the live log (an artifact of OpenWolf's `length+1` id scheme). `tests/buglog/test-buglog.sh` covers it in CI; `skills/code4me/references/tooling.md` documents it as the buglog consult path.

- **`hooks/check-buglog-helper.sh`** — PreToolUse enforcement for the above, mirroring the LSP-first hook: whole-file `Read`/`Grep`/raw-shell reads of `.wolf/buglog.json` are ask-gated and redirected to `code4me-buglog search|get|stats`; `Edit`/`Write`/shell-writes to `add|update`. Returns `ask` (never deny), exempts the helper's own Bash invocation, lets narrowed reads through, normalises Windows paths via `c4m-pathlib.sh`, and self-disables when there is no `.wolf/buglog.json`. Auto-wired in `hooks/hooks.json` (plugin-system installs); covered by `tests/buglog/test-buglog-hook.sh` and `probes/hooks/05-buglog-helper-redirects.md`.

- **Plugin hook wiring corrected.** Moved the plugin's PreToolUse registrations from `.claude-plugin/hooks.json` to the documented **`hooks/hooks.json`** (plugin root — `.claude-plugin/` is only for `plugin.json`); this is the location Claude Code auto-discovers on plugin-system installs. Separately: a plugin **referenced by absolute path** in a project's `.claude/settings.json` (rather than installed via the plugin system) does NOT auto-load `hooks/hooks.json` at all, so the LSP-first and buglog hooks have been added to `templates/project-starter/claude-settings.json.example` for path-referenced setups. Net: plugin-system installs get the hooks from `hooks/hooks.json`; path-referenced installs wire them in `.claude/settings.json`. Confirm what's loaded with the `/hooks` command.

- **`bin/code4me-install`** — self-locating, platform-aware installer that fixes the "hardcoded path that can't exist on this machine" problem. It writes the plugin's real absolute path into `.claude/settings.json` (merging the 5 hook entries idempotently — stale/placeholder `<PLUGIN_DIR>` paths are replaced, foreign hooks/settings preserved) and **regenerates `.lsp.json`** tailored to the platform and the LSP servers actually on PATH: `roslyn-language-server` vs `…​.cmd`, `xcrun sourcekit-lsp` (macOS) vs `sourcekit-lsp` (Linux/WSL), and clangd wrapped by the node didopen-proxy on Windows (bug #29501) but direct elsewhere. Only detected servers are written by default (so Claude Code never errors on a missing executable); `--lsp-all` scaffolds all three. Atomic writes with a `.bak`, `--dry-run`, and re-runnable (self-heals when the plugin moves). `/code4me-init` now calls it instead of hand-substituting `<PLUGIN_DIR>`. Covered by `tests/install/test-install.sh`.
- **`bin/code4me-preflight`** — two new checks: **Hook command paths** (flags unsubstituted `<PLUGIN_DIR>` or stale/missing hook script paths in settings.json) and **Project .lsp.json** (flags invalid JSON, leftover `<PLUGIN_DIR>`, or a clangd-proxy path that doesn't exist). Both point at `code4me-install` as the fix. These surface the malformed/`<PLUGIN_DIR>`-laden configs that previously failed silently at session start.

- **`hooks/check-session-wiring.sh`** — a read-only `SessionStart` detector (auto-wired in `hooks/hooks.json` for plugin-system installs; also wired into `.claude/settings.json` by `code4me-install` for path-referenced installs). At session start it checks whether the wired hook paths and `.lsp.json` resolve on this machine and, if not, surfaces a `SessionStart` `additionalContext` nudge pointing at `code4me-install`. It **never writes** and stays silent when wiring is correct or absent (so it doesn't nag plugin-system installs or fresh projects) — it only speaks up about config that exists but is broken. Auto-apply is deliberately NOT done: config mutation stays an explicit user action. Covered by `tests/install/test-session-wiring.sh`.

## [0.13.0-dev] — in progress

Three parallel tracks in this version: **audit4me Phase 0** (data-model commitment + read-only surface for the new sibling product), **codegraph integration** (a second structural-first path alongside LSP, detected automatically by the LSP-first hook), and **solo execution mode** (orchestrator-as-coder for Conversation/Light/Standard, with one retained quality gate).

### Solo execution mode

The framework's honest answer to "a good agent in a tight loop beats the dispatch pipeline on small work." Solo is an **execution mode, orthogonal to weight** — the weight's semantics (PROVISIONAL, promote-or-revert, decomposition, auto-escalation) are unchanged; the orchestrator implements inline instead of dispatching a Developer, and exactly one fresh-context gate is always dispatched: `combined-reviewer` for Conversation/Light, `verification` for Standard. Critical never runs solo (the full-team floor is non-negotiable).

Design principles: **explicit entry only** (the word "solo" at intake, the `--solo` flag on `/code4me-dispatch`, or a `CLAUDE.md` project default — inferring solo is a workflow violation, same discipline as the bridge gates); **the gate is structural, not optional** (author ≠ reviewer is the control a pure loop cannot give; it also means every solo task still satisfies the ≥1-Task-call hard success condition); **mechanical self-binding** (the PreToolUse hooks fire on the orchestrator's own edits — Standard solo writes the Test Spec and `protected-tests.txt` *before* implementing, so the test-protection hook ask-gates the author against weakening its own test gate); **floors never waived** (auto-escalation subagents and the architecture dialectic still dispatch).

### Added — solo execution mode

- **`skills/code4me/references/solo-mode.md`** — the canonical reference: explicit-entry gate, allowed weights (Conversation/Light/Standard; Critical excluded), retained gate per weight, the two toolbelt carve-outs (Edit/Write on production files, Bash for the task's test loop), per-weight procedure (Standard solo is test-gate-first with hook self-binding), sizing rule (>4 ACs or >~150 lines → recommend dispatched mode; solo work can't be `/compact`ed away), five abort conditions, dispatch-log shape (`subagent: "orchestrator-inline (solo)"`, `execution_mode`, `solo_requested_via`, `solo_justification`), anti-drift safeguards, and composition notes (solo + cross-vendor runs the retained gate on the opposite vendor).
- **`probes/solo/`** — three probes: solo fires on explicit request (and logs the full shape), solo is never inferred and never Critical, Standard solo enforces test-gate-first and aborts on mid-task auto-escalation discovery.
- **Audit-tool "Solo execution surveillance" section** in `bin/code4me-audit-dispatch-log` — solo count and share, requested-via distribution, gate-outcome distribution for solo tasks, abort visibility, malformed-entry detection (missing `solo_requested_via` / `solo_justification`). No fixed threshold (solo is a legitimate user choice); the drift signature is rising solo share with rising gate-FAIL rate.

### Changed — solo execution mode

- **`skills/code4me/SKILL.md`** — solo added as the second (and last) carve-out from the no-production-writes rule; solo execution gate added to operating-loop step 6 (mirrors the bridge gates' explicit-entry discipline); hard floors extended (Critical never solo; solo never waives a floor); Bash toolbelt exception for the solo test loop; reference list and dispatch command line updated.
- **`commands/code4me-dispatch.md`** — `--solo` flag: weight check (Critical refuses solo, announces, proceeds dispatched), auto-escalation interaction (escalation to Critical drops solo; to Standard keeps it at Standard semantics), `--solo --cross-vendor` composition.
- **`skills/code4me/references/workflow-weights.md`** — new §"Solo execution mode — orthogonal to weight".
- **`docs/reference.md`** — weights table gains the Trivial row (drift fix) and a solo paragraph; dispatch-log field provenance extended (v0.10.4 `trivial_justification`, v0.13 solo fields); slash-command list completed (drift fix: trello-init, housekeeping, audit4me pointer).
- **`docs/explanation.md`** — new §"Why solo mode, when the Producer pattern says 'coordinate, don't do'?" — the concession (handoffs lose information and burn tokens on small work) and the boundary (fresh-context gate + hook self-binding are the two controls a pure loop structurally cannot provide).
- **`README.md`** — solo mentioned in "Five things" item 1; dispatch cheat-sheet row updated.

### codegraph integration: structural-first, not LSP-first

The diagnostic problem this addresses: agents reach for whole-file `Read` and bare-identifier `Grep` instead of LSP because LSP's per-symbol round-trip ceremony doesn't match how they reason. The LSP-first hook nudges, but `permissionDecision: ask` lets agents proceed past the nudge — and they often do.

[codegraph](https://github.com/colbymchenry/codegraph) is a tree-sitter-based MCP server that pre-indexes the repo into a local SQLite knowledge graph (calls, imports, extends, implements, framework routes, cross-language bridges). Its MCP tools (`codegraph_explore`, `codegraph_callers`, `codegraph_callees`, `codegraph_impact`, `codegraph_search`) return rich, structural answers in one call — the response shape that models reason over best. Adding codegraph gives the agent a second structural path with a friendlier shape; the hypothesis is agents will reach for it more naturally than LSP.

This is an Option B integration (out of the three options the design discussion considered): codegraph is **detected, not required**. When `.codegraph/codegraph.db` exists at the project root (codegraph installed AND indexed for the project), the LSP-first hook lists codegraph alongside LSP in its redirect message. When the database is absent, the hook falls back to LSP-only — same behavior as v0.12 and earlier. No regression for non-adopters.

**Maturity caveat:** codegraph is pre-1.0 (v0.9.9 as of June 2026). The integration is detection-based, so removing codegraph is a one-command fallback (`rm -rf .codegraph/`) with zero code4me-side changes. We're trialing codegraph as a recommended-but-optional structural path; Option C (rename the hook, reorder defaults to put codegraph first) waits for codegraph to cross 1.0.

### Added — codegraph integration

- **`docs/howto-use-codegraph.md`** — Diataxis how-to recipe. Install codegraph (curl / PowerShell / npm), wire it into Claude Code (`codegraph install` auto-configures `~/.claude.json`), index the project (`codegraph init -i` → builds `.codegraph/codegraph.db`), what changes in code4me when codegraph is detected (hook surfaces both codegraph and LSP; events log records `codegraph_available`), when to use codegraph vs LSP (cross-file graph questions → codegraph; type-precise questions → LSP), removing codegraph, troubleshooting. Includes pre-1.0 maturity caveat.
- **`probes/hooks/04-lsp-first-surfaces-codegraph.md`** — four-scenario probe. (A) `.codegraph/codegraph.db` absent → hook surfaces LSP only, no codegraph leak. (B) `.codegraph/codegraph.db` present → hook surfaces BOTH codegraph and LSP. (C) Read with offset+limit passes through regardless of codegraph state. (D) Events log records `codegraph_available` correctly. Directly executable via bash; no Claude session needed.

### Changed — codegraph integration

- **`hooks/check-lsp-first-on-source.sh`** — header comment renamed from "LSP-first" to "structural-first" framing (file name unchanged to avoid breaking the auto-wire in `.claude-plugin/hooks.json`). New detection block: checks for `.codegraph/codegraph.db` at `$PROJECT_DIR`; sets `CODEGRAPH_AVAILABLE=1` when present. Redirect message is now two-branch — when codegraph is available, the message lists `codegraph_explore` / `codegraph_callers` / `codegraph_callees` / `codegraph_impact` / `codegraph_search` alongside LSP's `textDocument/*` methods, with a "Which to pick" note guiding cross-file vs type-precise questions. When codegraph is absent, the message is unchanged from v0.12. The audit-log event (`.code4me/lsp-first-events.jsonl`) gains a `codegraph_available: bool` field on every ask-gate, enabling downstream surveillance of whether agents shift toward structural tools post-adoption.
- **`skills/code4me/references/code-consultation-precedence.md`** — opening doc renamed from "LSP-first" to "structural-first (as of v0.13)". New §"Two structural tools, both valid" explaining the codegraph vs LSP split. Precedence section #1 expanded to cover both. "What to use instead" table updated — each row now lists the codegraph option first, LSP option second. Carve-outs section renamed to "When neither structural tool can answer" and refines the criteria (codegraph DOES handle some cross-language edges LSP can't; FTS5 search via `codegraph_search` extends the matching surface).
- **`docs/howto-configure-lsp.md`** — opening prose adds a v0.13+ note that LSP is one of two structural-first paths; cross-links to `howto-use-codegraph.md`.
- **`bin/code4me-preflight`** — new check 5c surfaces codegraph status: `ok` when `codegraph` CLI is on PATH AND `.codegraph/codegraph.db` exists; `warn` when CLI is installed but project not indexed; `warn` when CLI not installed (with install pointer). Optional integration — never blocking, never affects exit code.
- **`README.md`** — "Optional integrations" gets a codegraph entry. "How-to recipes" links to `docs/howto-use-codegraph.md`.

### Verification — codegraph integration

- Hook script smoke-tested across four scenarios: no-codegraph (LSP-only message), codegraph-present (both message), offset+limit pass-through (no ask), events log captures `codegraph_available`. All pass.
- Detection logic uses presence of `.codegraph/codegraph.db` only — no dependency on the codegraph CLI being on PATH at hook-execution time. The CLI presence is reported by preflight; the hook's behavior is data-driven.
- Falls back gracefully when codegraph is uninstalled: delete `.codegraph/codegraph.db` (or the whole `.codegraph/` directory) and the next hook fire returns to LSP-only output.

### Cross-vendor bridge post-validation (Layer C — diff scan)

Pre-v0.13, when the orchestrator dispatched to `codex exec` or `reasonix run`, the subprocess made its own internal tool calls (file edits, test invocations) and Claude Code's PreToolUse hooks never saw them. Protection was prompt-side rules + RETURN SCHEMA validation only — advisory. A vendor agent that ignored prompt rules AND lied about it in the response got past both checks.

Layer C closes the gap deterministically. After every bridge invocation returns, `bin/code4me-bridge-diff-scan.sh` inspects `git status --porcelain` and cross-references the changed paths against `.code4me/protected-tests.txt`, `.code4me/critical-allowlist.txt` (Critical-mode), and `.code4me/forbidden-conditions.json` (Conversation-mode). Violations surface as the same typed blockers Claude-side hooks produce. Vendor-agnostic; one helper, both bridges.

**Architectural framing.** The cross-vendor protection model is now three layers, with this version shipping Layer C only:

- **Layer A** — Claude-side PreToolUse hooks (existing). Pre-call interception on the orchestrator's own tool dispatches.
- **Layer B** — Vendor-side native PreToolUse hooks in codex and reasonix (ear-tagged for v0.14+). Pre-call interception inside the subprocess; limited by what each vendor's `PreToolUse` actually intercepts (codex is Bash-only currently). See `docs/roadmap.md` §"Vendor-side hooks (Layer B)" for the verified-vs-unknowns matrix.
- **Layer C** — Post-validation diff scan (THIS VERSION). Deterministic; can't be lied about. Catches violations after they touch disk, before the orchestrator advances.

### Added — Layer C

- **`bin/code4me-bridge-diff-scan.sh`** — vendor-agnostic helper. Args: `--project-dir <path> --weight <weight> --mode <read-only|read-write> --vendor <codex|deepseek>`. Output: JSON with `ok` boolean, `violations` array (each with `type` / `file` / `detail`), `files_changed` list. Skips gracefully (`ok: true, skipped: true`) when git unavailable or project isn't a git repo. Glob matching uses the regex polyfill unconditionally to handle `**/` zero-or-more directory components (the sister hooks' native `[[ == ]]` path doesn't — discovered during build; informally ear-tagged for the sister hooks).
- **`probes/cross-vendor/09-bridge-post-validation-catches-protected-test-edit.md`** — six-scenario probe, directly executable via bash. Covers: clean tree, test-protection violation, critical-allowlist violation, forbidden-conditions violation, read-only-mode unexpected modification, no-git graceful skip. Exercises the exact glob bug found during build (Scenario 4 — `tests/**/*new_test*` matching a file at depth 1).

### Changed — Layer C

- **`skills/codex-bridge/SKILL.md`** — new step 5 in "Invocation flow" calls the diff-scan helper. Step renumbering: old steps 5/6/7 become 6/7/8. Per-role `--mode` mapping documented (architect/code-reviewer/security-reviewer/verification-ac-coverage/lead-architect → read-only; developer/spec-to-test → read-write). Dispatch-log shape extended with `layer_c_status: clean|violation|skipped` and `layer_c_violations: [...]` fields.
- **`skills/deepseek-bridge/SKILL.md`** — symmetric to codex-bridge. Step 5 added; same `--mode` mapping; same dispatch-log fields. Cross-references codex-bridge SKILL.md for the shared semantics.
- **`docs/howto-enable-codex.md`** — new §"Cross-vendor protection: the three layers (v0.13+)". Walks through Layer A / B / C with the limitations of each. Explains the post-call vs pre-call trade-off explicitly.
- **`docs/howto-enable-deepseek.md`** — symmetric §"Cross-vendor protection: the three layers (v0.13+)". Notes that reasonix's `PreToolUse` coverage is unverified (Layer B prerequisite).
- **`docs/roadmap.md`** — Cross-vendor bridge post-validation moved from v0.12.x candidates to "Items that shipped". Layer B added as a new ear-tagged item with the verified codex/reasonix hook facts (5 events, JSON config, deny-only on codex, Bash-only intercept currently; reasonix coverage TBD).

### Verification — Layer C

- **Helper smoke-tested across all six probe scenarios in this session.** Scenarios 1, 2, 3, 5, 6 passed first try. Scenario 4 (forbidden new test file with `tests/**/*new_test*` glob against a file at depth 1) initially failed because bash's `[[ == ]]` doesn't handle `**/` as zero-or-more directory components — fixed by forcing the regex polyfill unconditionally.
- **Mount-sync caveat:** the bash sandbox in this session went stale after the polyfill fix, showing a truncated view of the helper script that triggered spurious "syntax error" reports. The Read tool confirmed the file is intact on disk at 308 lines. Users should run the probe locally against the helper to confirm Scenario 4 passes — the file content is correct, but I couldn't re-verify through the stale sandbox.
- **Layer C is opt-in by repo shape.** A project that isn't a git repo gets `skipped: true` — the bridge logs the skip and proceeds without Layer C. Layer A still covers what it can.

### Windows hook portability mitigations

The plugin's hooks and bin scripts are bash; native Windows (cmd.exe / PowerShell only) doesn't run them. The four mitigations from the v0.12.x ear-tagged item land here in v0.13.0-dev, formalizing the **Linux/macOS first-class, Windows-via-Git-Bash-or-WSL second-class** support story. Native Windows remains unsupported (would require rewriting hooks in Node/Python — substantial work deferred until empirical demand justifies it).

### Added — Windows mitigations

- **`.gitattributes`** — forces `eol=lf` on shell scripts (`*.sh`, `*.bash`), JSON / JSONL / YAML / TOML, Python / Node / Markdown / text. Prevents CRLF corruption on Windows clones, which would otherwise break `#!/usr/bin/env bash` shebangs. Binary types (`*.db`, images, archives) declared explicitly so they aren't touched.
- **`docs/howto-windows.md`** — Diataxis how-to recipe. Covers: pick WSL or Git Bash (with a "WSL recommended" rationale), install dependencies per Windows package manager (`winget` / `choco` / `scoop` for jq + Node), how to verify the environment via the new Platform preflight check, known quirks (CLAUDE_PROJECT_DIR path translation, CRLF on legacy clones, PowerShell launch issues, silently-not-firing hooks debug ladder), how to report Windows issues, when native Windows might happen.

### Changed — Windows mitigations

- **`bin/code4me-preflight`** — new check 0 (Platform). Detects OS via `uname -s` and identifies the environment: `Linux` (native or WSL — WSL detected via `WSL_DISTRO_NAME` or `/proc/version` containing "microsoft"), `macOS`, `Windows + Git Bash` (`MINGW*` / `MSYS*` / `CYGWIN*`), or `unknown`. Reported as the first preflight line; `Linux` and `macOS` are `ok`, `Windows + Git Bash` and `unknown` are `warn` (with pointer to `docs/howto-windows.md`). The check is informational — never affects exit code.
- **`CONTRIBUTING.md`** — new §"Windows manual-test checklist" before the Reviewing section. Four explicit checks for contributors who touch `hooks/`, `bin/`, or `.gitattributes`: line endings preserved as LF, shebang executes cleanly, preflight Platform line shows the correct environment, path-handling tested against `$CLAUDE_PROJECT_DIR`. Includes "request a Windows-using reviewer if you can't test locally" as the escalation.
- **`README.md`** — install section gets a Windows callout pointing at `docs/howto-windows.md`. How-to list includes the new doc.
- **`docs/roadmap.md`** — Windows hook portability mitigations entry retired from "v0.12.x candidates"; corresponding entry added to "Items that shipped and are no longer ear-tagged" with the four-item summary and the explicit note that path-translation remains deferred.

### Verification — Windows mitigations

- `.gitattributes` covers all known text file types in the repo. Hook scripts, bin scripts, JSON config, JSONL events log, markdown docs — all declared LF.
- Preflight Platform check tested against the sandbox environment (returns `Linux` — `Native Linux; bash hooks and bin scripts run natively. CI runs on ubuntu-latest.`). Other branches verified by reading the case statement; not yet exercised against real Windows + Git Bash, Windows + WSL, or macOS.
- CONTRIBUTING checklist is enforceable by reviewers; CI doesn't enforce it, by design (Windows CI is intentionally skipped per the roadmap rationale).
- Mount-sync caveat: the bash sandbox in this session went stale during the preflight edit; the Read tool confirmed the file is intact at 352 lines on disk. Users should run `bash bin/code4me-preflight` locally to confirm the new Platform check renders correctly.

### audit4me Phase 0

audit4me Phase 0 lands — the **data-model commitment and the read-only surface**, nothing more. No orchestrator, no actual auditing yet (Phase 1's scope). The point of Phase 0 is to validate the file shapes and slash-command UX *before* committing the per-file orchestrator pattern, while code4me v0.12 continues soaking against real milestones.

### Architectural decision: per-file orchestrator (not run-level)

`docs/audit4me-design.md` updated to commit to the per-file orchestrator pattern. The main session runs a deterministic outer loop (worklist computation, atomic coverage update, events log append) and dispatches a `code4me-audit-orchestrator` subagent per file via the Task tool for the judgment-heavy work (which categories apply, which vendors per category, within-file aggregation, partial-failure handling). The original design's "deterministic outer loop only" framing was too binary; the per-file orchestrator earns its tokens where the work is fuzzy without burning them across hundreds of files of mechanical bookkeeping.

Phase 0 ships none of the orchestrator yet — that's Phase 1. Phase 0 ships the *schemas* the orchestrator and outer loop will produce and consume.

### Added

- **`skills/audit4me/SKILL.md`** — Phase 0 skill scope: handles `/audit4me-config` and `/audit4me-status` only. Documents what's in Phase 0 vs. what's deferred to Phases 1–5. Loads on slash-command dispatch; does not auto-load from code4me's operating loop (audit4me runs detached from milestones).
- **`skills/audit4me/schemas/config.schema.json`** — JSON Schema (draft 2020-12) for `.code4me/audit4me-config.json`. Pins required fields (`vendors_available`, `default_categories`, `scope.include`, `rules_version`), enum-constrains vendor names and category names, declares all defaults. The 2-vendor minimum is a runtime constraint (single-vendor mode is find-only); single-vendor is a legal config.
- **`skills/audit4me/schemas/audit-coverage.schema.json`** — JSON Schema for `.code4me/audit4me/audit-coverage.json`. Per-file entries with `content_hash`, per-vendor audit state, `rules_version_at_audit`, computed `coverage_level` (uncovered / single-vendor / agreement-covered / full-covered).
- **`skills/audit4me/schemas/audit-event.schema.json`** — JSON Schema for each line of `.code4me/audit4me/audit-events.jsonl`. The append-only history that's the source of truth; the coverage projection derives from this. Includes `run_id` for grouping events from a single `/audit4me-run` invocation.
- **`skills/audit4me/schemas/finding-frontmatter.schema.json`** — JSON Schema for the YAML frontmatter at the top of each `findings/{id}.md`. Tooling (`/audit4me-status`, future `/audit4me-findings` and `/audit4me-apply`) reads the frontmatter without parsing the markdown body. `id` format: `F-{YYYY-MM-DD}-{NNNN}`; `status` enum: `open / applied / dismissed / stale`.
- **`skills/audit4me/references/config-format.md`** — prose explanation of each config field, the vendor floor (3-vendor / 2-vendor / 1-vendor), recommended exclude patterns, cost/time boxes, confidence thresholds, apply-integration, and gitignore policy.
- **`skills/audit4me/references/coverage-format.md`** — prose on the two-file model (coverage JSON + events JSONL), why they're split, re-audit triggers (content / rule-version / refresh / new-vendor / new-category), coverage levels, resume semantics, disaster-recovery rebuild, storage growth estimates.
- **`skills/audit4me/references/finding-template.md`** — the finding markdown shape: YAML frontmatter + body sections (`Summary`, `Evidence` with per-vendor verbatim quotes, `Confidence signals`, `Proposed fix`, `Failing test`, `Apply readiness`). Includes dismissal and stale-finding lifecycle.
- **`commands/audit4me-config.md`** — slash command for one-time project setup. Probes installed vendor CLIs (`claude`, `codex`, `reasonix`), asks the user to confirm `vendors_available` and `scope.include`, applies sensible defaults for everything else, writes `.code4me/audit4me-config.json`, scaffolds `.code4me/audit4me/findings/` directory. Supports `--overwrite`, `--patch`, `--dry-run`.
- **`commands/audit4me-status.md`** — slash command for the read-only coverage report. Parses config + coverage, enumerates scope files, computes per-coverage-level counts, surfaces stale/behind-rules-version counts, lists findings on disk by status, estimates next-run cost. In Phase 0 the coverage is always empty (no audits run yet); the report validates the wiring.

### Changed

- **`.claude-plugin/plugin.json`** — version bumped to `0.13.0-dev`.
- **`docs/audit4me-design.md`** — added §"Architecture: execution model" (skill-shaped not script-shaped, per-file orchestrator subagent, what-happens-on-`/audit4me-run` step-by-step, interactive vs scheduled paths, resume semantics, concurrency model). Phases 1 and 2 revised to include the orchestrator build (Phase 1 minimal, Phase 2 full). Subagent-nesting question added to Open design questions (most consequential — shapes the orchestrator's prompt; resolve before Phase 2). "Last updated" bumped to 2026-06-03.

### Verification

- All four JSON schemas are draft 2020-12 with `$id`, `$schema`, `title`, `description`, and either `additionalProperties: false` or explicit `additionalProperties` schemas. No `additionalProperties: true` permitted by accident.
- `skills/audit4me/SKILL.md` is explicit about Phase 0 scope (what's in, what's out) so future readers don't expect `/audit4me-run` to work yet.
- `commands/audit4me-config.md` and `commands/audit4me-status.md` reference the skill's SKILL.md and references/ for procedure detail (avoids duplicating logic across skill and command files).
- CHANGELOG entry calls out the per-file-orchestrator architectural decision (the meaningful design shift in this version) prominently, not buried in the file list.

### What's NOT in this version (deferred)

- `/audit4me-run` — Phase 1
- `subagents/code4me-audit-orchestrator.md` — Phase 1 minimal, Phase 2 full
- `references/audit-prompt-bugs.md` (and per-category prompts) — Phase 1 (bugs), Phase 5 (others)
- Multi-vendor agreement + within-file aggregation — Phase 2
- Failing-test generation — Phase 3
- `/audit4me-apply` integration with code4me Conversation Mode — Phase 4
- `/audit4me-findings`, `/audit4me-dismiss` — Phase 4
- Categories beyond `bugs` (security, performance, maintainability, test_gaps) — Phase 5
- `bin/code4me-audit-dispatch-log` extension for audit4me activity — Phase 5
- The `/code4me-audit` → `/code4me-dispatch-audit` rename — when Phase 4 ships

Phase 0's deliberate restraint: do nothing that depends on the orchestrator pattern that code4me v0.12 is still soaking. The Phase 1 trigger is "code4me v0.12 has 2 weeks of clean real-milestone usage" (per `docs/audit4me-design.md` §"Why this isn't urgent").

## [0.12.0-dev] — in progress

Milestone decomposition becomes an explicit operating-loop step, and Trello cards move from task-shaped to AC-shaped. Two related changes that together turn the Kanban board from "internal workflow status" into "requirement attestation status" — closer to how a real sprint board reads.

### The decomposition rule

Standard and Critical milestones MUST be decomposed into ≥1 task per acceptance criterion before the first dispatch. The minimum decomposition unit is *"one Verification can attest the AC is met"*. The decomposition produces an explicit AC↔task mapping recorded in `.code4me/milestone-status-tracker.md` under a new `acceptance_criteria:` block. Collapsing a multi-AC milestone into one task is a workflow violation. Conversation / Light / Trivial weight remain decomposition-exempt (single AC by definition).

### The AC-level Trello model

One card per acceptance criterion (not per task). Card title is `{milestone_id}-{ac_id}: {ac_summary}`. Cards aggregate the tasks touching each AC; a single verification dispatch with per-AC verdicts updates multiple cards in a fan-out. AC card state machine: `declared → in_progress → in_review → done` (or `blocked` on Verification PARTIAL/FAIL). The board now shows which requirements are progressing through which gates, instead of which internal workflow lanes are active.

Concrete shift: a milestone with 4 ACs and 8 tasks used to produce 8 cards (or, more often in practice, 1 collapsed card). It now produces 4 cards moving independently. Verification can PASS AC1 and AC3 while PARTIAL on AC2 — AC1 and AC3 advance to **Done** while AC2 stays in **In Review** for rework. Real kanban rhythm.

### Added

- **`probes/intake/01-milestone-decomposed.md`** — verifies Standard/Critical milestones decompose into ≥1 task per AC; `acceptance_criteria:` block populated before first dispatch; every dispatched task referenced in at least one AC's `tasks_touching`. Catches the common regression where the orchestrator collapses a milestone into a single task.

### Changed

- **`skills/code4me/SKILL.md`** — operating loop now has a step 5 "Decompose the milestone into tasks". Original steps 5/6/7/8 renumbered to 6/7/8/9. The decomposition step is mandatory for Standard/Critical, decomposition-exempt for Conversation/Light/Trivial. Trello sync moment references updated (step 5 for card creation, step 7 for dispatch updates, step 8 for escalation). The new step references `references/playbook.md` §"Milestone decomposition" for the rule.
- **`skills/code4me/references/playbook.md`** — new §"Milestone decomposition" section (~70 lines) defining: the decomposition rule, the minimum-decomposition heuristic, the `acceptance_criteria:` schema (with YAML example), the per-AC state machine, the four workflow-violation signals (`milestone_not_decomposed`, `acceptance_criteria_block_missing`, empty `tasks_touching`, task not in any AC), and the lighter-weight exemption.
- **`skills/trello-sync/SKILL.md`** — rewritten for AC-level cards. The four state-transition moments are now: after-decomposition (create N cards, one per AC), at-dispatch (move + update every AC card the task touches), at-return (recompute per-AC state from verification's coverage table, fan-out updates), at-escalation. Card unit, state model, and fan-out semantics all documented. No backwards-compat flag — task-level mode is gone.
- **`skills/trello-sync/references/card-shape.md`** — rewritten for AC card body. New fields: `Tasks touching this AC`, `Latest verification status for this AC` (PASS/PARTIAL/FAIL/NOT VERIFIED), `Latest INSIGHTs touching this AC`. Card title format changed from `{task_id}: {summary}` to `{milestone_id}-{ac_id}: {ac_summary}`. Added a "Difference from v0.11 task-level cards" section explaining the model shift.
- **`skills/trello-sync/references/columns.md`** — restated for AC-state transitions. Each of the six lists now describes what an AC card in that state means (not what a task card means). New section "Why the AC granularity changes what each list shows" explains the fan-out behaviour (one milestone showing different ACs in different lists). Vendor labels extended with `vendor: deepseek` (v0.11 carryover that was missing).
- **`probes/trello/01-sync-fires-on-state-transition.md`** — rewritten for AC-level expectations. Pass criteria now check card count = AC count (not 1, not task count), AC-shaped titles, AC-aligned state transitions, cross-task fan-out on verification returns.

### What this costs to migrate

- **Existing milestone-status-trackers** without an `acceptance_criteria:` block won't sync to Trello after upgrade. The skill logs `acceptance_criteria_block_missing` and no-ops on those milestones. Hand-write the block by inferring ACs from the Milestone Spec, OR start fresh on new milestones.
- **Existing Trello cards** from v0.11 task-level mode stay on the board with their old titles. The orchestrator never updates them (no matching task_id mapping). Archive them manually and the board starts clean.
- **The trello-config.json schema is unchanged** — `board_id`, `list_ids`, `label_ids`, `tool_overrides`. The six lists keep their semantics (Inbox / In Progress / In Review / Blocked / Pending User / Done), only the unit moving through them changed.

### Verification

- SKILL.md operating loop now has 9 steps (was 8); decomposition is explicit at step 5.
- `playbook.md` §"Milestone decomposition" present with schema + state machine + violation signals.
- trello-sync SKILL.md cites the AC-level model; no leftover task-level mentions.
- `card-shape.md` template uses `{ac_id}`, `{ac_summary}`, `tasks_touching_block` placeholders (not `{task_id}` and `dispatch_history`).
- `columns.md` describes per-AC state semantics for each list.
- Both probes (intake decomposition + trello AC card creation) written with explicit pass criteria.

### Consolidated roadmap doc

- **`docs/roadmap.md` (new)** — maintained consolidated view of all ear-tagged work, with the per-item template (Status / Target version / Scope / Trigger condition / CHANGELOG reference). Twelve items at landing time: four v0.11.x carryovers (DeepSeek audit surveillance, DeepSeek eval probes, cost rollup precision, env-var hook profiles), seven v0.12.x candidates (decomposition-health surveillance, milestone-grouping in Trello, scope-change AC probe, Windows portability mitigations, cross-vendor bridge post-validation, resume-from-handoff probe, handoff-health surveillance), and one conditional (CodeGraph). Each entry cross-links its origin CHANGELOG section so the roadmap stays the consolidated view rather than the source of truth. Includes a "How to add" / "How to ship" workflow so future ear-tags follow the same template. Linked from README's Documentation section.

### Session-boundary checkpoint (`/code4me-housekeeping`)

A new slash command that audits `.code4me/` state, surfaces pending user actions, and writes a handoff manifest the next session can read to resume context without re-walking the dispatch log. Designed for the moment you're about to `/clear` or close the session and want confirmation everything is bookkept.

- **`commands/code4me-housekeeping.md` (new)** — slash command file. Documents the audit procedure (9 checks: dispatch-log integrity, tracker freshness, AC state currency, artefact persistence, orphan files, Trello sync state, OpenWolf flush, hook state files, pending user actions), the three verdicts (READY / READY-WITH-NOTES / NOT-READY), the output template, and the special cases (no active milestones, NOT-READY blocks manifest write).
- **`skills/code4me/references/housekeeping.md` (new)** — load-bearing reference with full audit checklist, verdict computation rules, handoff manifest schema (versioned as `handoff-schema-v1`), resume protocol (operating-loop step 1 reads the most recent manifest on session start), failure modes the audit catches, and what the audit deliberately does NOT do (no subagent dispatch, no project-source modification, no auto-flush of cerebrum, no rollback on NOT-READY).
- **`skills/code4me/SKILL.md` updated** — operating-loop step 1 ("Consult cerebrum first") extended to also read the most recent `.code4me/handoff-*.md` if one exists. Step 9 ("Confirm and close") suggests `/code4me-housekeeping` when the session had ≥3 dispatches or any auto-escalation or any circuit-breaker fire.
- **`probes/housekeeping/01-handoff-manifest-written.md` (new)** — four scenarios: (A) READY clean close, (B) READY-WITH-NOTES with pending actions, (C) NOT-READY in-flight dispatch, (D) NOT-READY stale tracker. Pass criteria cover read-only invariant, manifest write rules, verdict correctness, and filesystem-safe ISO8601 filename.
- **README cheat-sheet** updated with the new slash command.

### How resume works

When a new session opens against a project with handoff manifests, the orchestrator's operating-loop step 1 reads the most recent `handoff-*.md` (newest ISO8601). The manifest's pre-digested sections (Active milestones with AC state, Pending user actions, Recent dispatches, Persistence state) become the resumed context. The orchestrator doesn't need to re-read the full dispatch log to orient — the manifest is a few hundred tokens vs. thousands for the log. Reading the log remains available for specific historical detail.

### What this enables in practice

The user can confidently `/clear` mid-milestone, knowing the next session will pick up where they left off. The verdict surfaces in-flight dispatches that haven't returned (NOT-READY), pending PROVISIONAL deadlines (READY-WITH-NOTES), and clean-close conditions (READY). The handoff manifest acts as the bridge between sessions — replacing "wait, where was I?" with a pre-written orientation.

### Public-release infrastructure (Phase 2)

Community-facing files and CI scaffolding added so external contributors have a clear on-ramp and the repository passes GitHub's standard "community profile" checks. None of this changes plugin behaviour; it's pure infrastructure.

- **`CONTRIBUTING.md`** — patterns for adding subagents (`context_queries:` frontmatter requirement), bridges (STRICT BRIDGE PROTOCOL + dispatch gate), PreToolUse hooks (ask-never-deny convention; silent pass-through), and probes (Pass criterion + Failure modes structure). PR checklist. Versioning policy (semantic versioning, every change logged under `-dev`, minor bumps for new capabilities). Run-probes-locally instructions and a Co-Approval Rule reminder for architectural changes.
- **`CODE_OF_CONDUCT.md`** — short pointer to [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Includes reporting instructions and maintainer responsibility. Notes that forks publishing under a different name should replace the file with the full canonical Covenant text.
- **`SECURITY.md`** — private vulnerability reporting procedure (GitHub's private advisory + email). In-scope surface enumerated: PreToolUse hooks, bridge subprocesses, dispatch log writes, orchestrator-managed state files, Trello sync API calls, auto-wired `hooks.json`. Out-of-scope: third-party CLIs/MCPs, user-induced misconfigurations. Acknowledgement and fix SLAs (7-day ack, 30-day for high-severity).
- **`.github/ISSUE_TEMPLATE/bug_report.md`** — structured bug template with reproduction steps, environment table, dispatch log paste field, hook events paste field, and probe-coverage checkbox.
- **`.github/ISSUE_TEMPLATE/feature_request.md`** — what-problem / proposed-shape / fits-architecture / alternatives / adoption / effort / willing-to-PR sections.
- **`.github/ISSUE_TEMPLATE/probe_failed.md`** — regression-specific template with failing probe path, last-known-passing version, observed vs. expected, suspected change, severity classification.
- **`.github/ISSUE_TEMPLATE/config.yml`** — disables blank issues; routes "how do I" questions to Discussions, docs questions to the docs/ tree, security issues to private advisory.
- **`.github/PULL_REQUEST_TEMPLATE.md`** — PR checklist covering type-of-change, convention checklist (CHANGELOG entry, no hardcoded paths, no first-person voice, agent/bridge/hook conventions), probe coverage, verification steps (preflight, probe-run, audit), documentation, cross-platform testing, breaking changes.
- **`.github/workflows/probe.yml`** — GitHub Actions running on push + PR. Two jobs: `static-checks` (Linux) does JSON/YAML validation, shellcheck on hooks and bin/*, bash syntax checks, and a probe-structure check verifying every probe has required sections; `static-checks-macos` runs the same on macOS. Windows CI intentionally skipped (Git Bash CI fragility documented in the workflow); manual Windows runs documented in CONTRIBUTING.md.
- **README.md** rewritten for newcomers. Lead with "what it does, concretely" — one-paragraph elevator pitch + a 6-step example showing the orchestrator's behaviour. Removed internal-facing framing. Five-bullet "what makes code4me different" section. Optional integrations clearly marked as optional. Diataxis docs split linked prominently. Slash commands cheat sheet retained. Version arc through v0.12 noted. Contributing / CoC / Security links at the bottom.

### Public-release portability (Phase 1)

Surface-level cleanup to make the plugin installable by another developer on any OS. Doesn't change behaviour for existing users; the active `.lsp.json` at the plugin root remains in place and untouched. The shipped template is at `templates/project-starter/.lsp.json.example`.

- **`bin/clangd-didopen-proxy.mjs` (new)** — the Node shim that wraps clangd to work around Claude Code CLI bug #29501. Copied from the plugin root into `bin/` so it has a stable, portable path under the plugin tree. The repo-root copy is preserved temporarily so existing setups keep working; will be removed in v1.0 once all known users have migrated their `.lsp.json` to reference `bin/clangd-didopen-proxy.mjs`.
- **`templates/project-starter/.lsp.json.example` (new)** — portable template using `<PLUGIN_DIR>` placeholder for the cpp.args path. C# and Swift entries auto-resolve via PATH (no manual edit). Per-platform notes (`_notes_per_platform`) cover Windows path quirks, macOS `xcrun` behaviour, and Linux `sourcekit-lsp` direct invocation. New users copy this to their project root, replace `<PLUGIN_DIR>`, and are running.
- **`docs/historical/code4me-v07-plan.html` (relocated)** — historical planning artifact moved out of the repo root into `docs/historical/`. Doesn't belong on the plugin's main surface; useful for project-history readers who want to see how v0.7 was scoped.
- **`docs/howto-configure-lsp.md` updated** — new "Setting up .lsp.json" section explains the template-copy workflow and the `<PLUGIN_DIR>` substitution. Per-OS install paths for the typical Claude Code plugin cache location documented.

### Open questions deferred to v0.12.x

- **Audit-tool decomposition-health surveillance.** A "Decomposition health" section that counts milestones with/without `acceptance_criteria:`, average ACs per milestone, and orphan dispatches (tasks not in any AC's `tasks_touching`). Mirror of the existing Trivial and LSP-first surveillance sections. Candidate for v0.12.1.
- **Milestone-level grouping in Trello** (epic→story). Currently AC cards belong to a milestone via the body's `Milestone:` field but there's no parent card or labelled grouping. A milestone-level card with checklist items for each AC would give the board both AC-progression rhythm AND milestone-rollup visibility. Candidate for v0.12.x.
- **Scope-change AC additions mid-milestone.** The probe's edge-case section mentions "user decides to add AC4 mid-milestone". The trello-sync and tracker both support this (just append to the block) but there's no probe verifying the behaviour. Add a dedicated probe in v0.12.x.

---

## [0.11.0-dev] — in progress

Two concurrent threads ship in this version: **DeepSeek as a third vendor** (the larger architectural extension), and **the v0.10.5 LSP-first hook follow-up** (a tighter, broader, auto-wired version of the hook to address its zero-fire problem and matcher gap discovered in v0.10.5 soak). The two are independent and compose freely.

### LSP-first hook v2 (follow-up to v0.10.5)

The v0.10.5 cut shipped the hook but left two gaps that the user observed in real-session soak:

1. **The events log never appeared.** Root cause: v0.10.5 wired the hook through `templates/project-starter/claude-settings.json.example` only — a template file the user has to manually copy into their real `.claude/settings.json`. Users on existing installs never picked it up, so the hook silently never registered.

2. **The matcher was too narrow.** v0.10.5 covered only context-mode's `ctx_execute` family. In practice, agents reach for the built-in `Read` and `Grep` tools first for code consultation — those went uncovered, and drift continued invisibly under the v0.10.5 framing.

Both fixed in this cut:

- **`.claude-plugin/hooks.json` (new)** — registers the LSP-first hook automatically when the plugin is installed. The matcher string covers `Read|Grep|mcp__plugin_context-mode_context-mode__ctx_execute|mcp__plugin_context-mode_context-mode__ctx_execute_file|mcp__plugin_context-mode_context-mode__ctx_batch_execute`. The hook still auto-no-ops when `.lsp.json` is absent at the project root, so this is safe to wire unconditionally. **Existing installs need to restart Claude Code once for the new hooks.json to be picked up.** No manual `.claude/settings.json` edit required.

  The other three hooks (test-protection, forbidden-conditions, critical-write-allowlist) stay opt-in via the user's settings.json because they tie to orchestrator-written state files (`.code4me/protected-tests.txt`, `.code4me/forbidden-conditions.json`, `.code4me/critical-allowlist.txt`) that the user may not always want written.

- **`hooks/check-lsp-first-on-source.sh` extended (v0.11)** — handles five tools now (added Read and Grep). New matching rules:

  - **Read on a source-extension file WITHOUT `offset` or `limit`** → ask-gate. Strong signal the agent doesn't know what region they want yet, so LSP would help locate it structurally. A Read **with** offset+limit (i.e., narrowed) passes through silently.
  - **Grep with a bare-identifier pattern (matching `^[a-zA-Z_][a-zA-Z0-9_]{2,}$` after stripping word-boundary markers) AND a source-file target** → ask-gate. The "source-file target" check uses four signals in priority order: explicit `glob` matching a source extension; `type` matching an LSP-declared language; explicit `path` to a source file; or no glob/type/path specified (workspace-wide grep in a project with `.lsp.json` declared = guaranteed to touch source). Genuine regex patterns (containing `.*`, `[...]`, `|`, `(...)`, etc.) pass through unchanged.
  - **ctx_execute family** continues to match the same three shapes as v0.10.5 (grep/rg on source, ctx_execute_file with symbol-search verbs, cat/head/sed with class/function regex).

  Events log entries now include the tool name in the `tool` field — `Read`, `Grep`, or the context-mode tool ID — so the audit-tool surveillance section's per-tool breakdown picks up the new tools automatically without a code change.

- **`skills/code4me/references/code-consultation-precedence.md` extended** — the pattern surface table grows from three rows to five, with new sections explicitly documenting the Read offset+limit carve-out, the Grep bare-identifier carve-out, and the legitimate proceed cases (whole-file refactor reads, small-file reads, literal-string searches that happen to look like identifiers, etc.). Subagents reading this reference at dispatch time get the carve-outs in advance, so they can issue `Read(file_path, offset, limit)` directly without triggering the gate when they've already narrowed the question.

- **Starter template (`templates/project-starter/claude-settings.json.example`)** — the v0.10.5 LSP-first PreToolUse entry that lived here has been removed; the plugin's `.claude-plugin/hooks.json` is now the source of truth for that hook. The starter template retains the three opt-in Edit/Write-gating hooks.

### What changes for existing v0.10.5 users on upgrade

- **Restart Claude Code once** so the new `.claude-plugin/hooks.json` registers.
- **(Optional)** Remove any manually-copied `check-lsp-first-on-source.sh` entry from your `.claude/settings.json` — keeping it produces duplicate hook fires (cheap but noisy in the events log). Leaving it in place is harmless; the duplicate just costs a few extra `bash` invocations per matched tool call.
- **Confirm the hook is firing** by triggering a whole-file Read of a source file in your project, then checking `.code4me/lsp-first-events.jsonl` — a new line should appear.

### Verification (LSP follow-up)

15 hook test cases pass:

- Read .cs no offset/limit → **ask** (T1)
- Read .cs with offset+limit → pass (T2)
- Read .md non-source → pass (T3)
- Read .cpp no offset → **ask** (T4)
- Grep `PasswordReset` glob=*.cs → **ask** (T5)
- Grep `log.*Error` (regex) → pass (T6)
- Grep `PasswordReset` glob=*.md → pass (T7)
- Grep `PasswordReset` type=cs → **ask** (T8)
- Grep `PasswordReset` no glob/type/path → **ask** (T9, workspace-wide)
- Grep `PR` type=cs → pass (T10, pattern too short)
- ctx_execute grep on .cs → **ask** (T11, regression)
- ctx_execute dotnet test → pass (T12)
- Read .cs without .lsp.json → pass (T13, auto-opt-out)
- Edit on .cs → pass (T14, not in matcher)
- Glob → pass (T15, not in matcher)

Events log accumulates 6 entries matching the 6 ask-gate cases.

---

## [0.11.0-dev] — DeepSeek bridge (continued below)

DeepSeek joins as a third supported vendor alongside Anthropic and OpenAI. A new `deepseek-bridge` skill mirrors the existing `codex-bridge`, exposing the same seven roles (architect, developer, code-reviewer, spec-to-test, security-reviewer, verification, lead-architect) with the same modes and return schemas. The bridge invokes the **Reasonix CLI** (`reasonix run`) — a DeepSeek-native agentic coding agent purpose-built around DeepSeek's prefix-cache stability (the project reports ~99.8% cache hit rates, roughly 5x lower per-token cost than naive API use). Reasonix is DeepSeek's analog to OpenAI's Codex CLI: a dedicated agentic substrate the bridge spawns as a subprocess, just like codex-bridge spawns `codex exec`. The cross-vendor policy generalises to three-vendor alternation with the same closest-pair-wins rule and an alphabetical tiebreaker for ambiguous cases.

**Architectural note — Reasonix vs. earlier prototype.** An interim v0.11 prototype used `claude --print` against DeepSeek's Anthropic-compatible endpoint (`https://api.deepseek.com/anthropic`), with `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` pointed at DeepSeek. That worked mechanically but had three drawbacks: (1) recursion-prevention complexity (a nested Claude Code instance could load the code4me plugin and try to be another orchestrator); (2) no prefix-cache stability (Claude Code's prompt construction is optimized for Anthropic's tool-use format, not DeepSeek's prefix cache); (3) subtle tool-call format mismatches through the Anthropic-compatible shim. The shipped version uses Reasonix instead, gaining DeepSeek-native prefix-cache optimization (the 5x cost reduction is the headline benefit), native DeepSeek tool-call format, and structural symmetry with codex-bridge (both bridges spawn vendor-native CLI subprocesses; no Claude-Code-in-Claude-Code nesting).

Minor version bump (not a patch) because the third vendor is a meaningful architectural extension that affects team-composition decisions, dispatch-log shape (`vendor: deepseek` now valid), and the cross-vendor policy's resolution algorithm. No breaking changes — existing single-vendor and two-vendor (Anthropic + OpenAI) workflows continue unchanged; DeepSeek is purely additive and opt-in.

### Added

- **`skills/deepseek-bridge/SKILL.md`** + 7 per-role references (`architect.md`, `developer.md`, `code-reviewer.md`, `spec-to-test.md`, `security-reviewer.md`, `verification.md`, `lead-architect.md`). Mirrors `skills/codex-bridge/` structure:
  - Same dispatch protocol (load reference → assemble prompt → invoke → parse → use inline → log).
  - Same seven roles with same modes (challenge/consult/review-spec for architect, etc.).
  - Same RETURN SCHEMA per role-mode (field names, blocker_type values, outcome enums all identical).
  - Same STRICT BRIDGE PROTOCOL discipline (carved into each role reference).
  - Same context discipline (large-field trimming, /compact between phases).
  - The mechanical difference: invocation is `reasonix run --model {id} --effort {level} --no-config --transcript {path} "<task>"` rather than `codex exec`. The role references' "Invocation" sections show the full per-role command with role-appropriate timeout (architect-class 300s; developer 600s; verification 360s; lead-architect 360s). The model + effort are resolved by tier: low→(v4-flash, medium); mid→(v4-pro, high); high→(v4-pro[1m], max).
  - **No recursion-prevention needed:** Reasonix is not Claude Code, so there's no risk of the bridge subprocess loading code4me and trying to be another orchestrator. (This was a concern in the interim v0.11 prototype that used `claude --print` against DeepSeek's Anthropic-compatible endpoint; switching to Reasonix removed the entire failure mode.)
- **`probes/cross-vendor/06-deepseek-pairing-three-vendor.md`** — exercises the three-vendor team composition with DeepSeek as the challenger architect. Pass criteria cover announcement format, dispatch-log fields, and the `(vendor:tier)` annotation.
- **`probes/cross-vendor/07-deepseek-unavailable-degrades.md`** — exercises the `$DEEPSEEK_API_KEY` missing failure mode. Verifies graceful degradation: orchestrator falls back to anchor vendor, records `pairing_degraded: deepseek_unavailable`, surfaces the remediation hint, does NOT block the milestone.
- **`probes/cross-vendor/08-deepseek-single-role-opt-in.md`** — exercises Path 1's single-role opt-in (user names "deepseek-security-reviewer" without enabling milestone-wide cross-vendor). Verifies the orchestrator dispatches exactly one DeepSeek invocation and does not generalise to three-vendor uninvited.
- **`docs/howto-enable-deepseek.md`** — user-facing setup guide mirroring `howto-enable-codex.md`. Covers the seven bridge roles, Reasonix installation (`npm install -g reasonix`), model + effort tier mapping (low=v4-flash/medium, mid=v4-pro/high, high=v4-pro[1m]/max), the two paths (single-role opt-in vs three-vendor milestone-wide), combining DeepSeek with Codex and Anthropic, the Reasonix-specific flags the bridge uses, and a troubleshooting table.

### Changed

- **`skills/code4me/references/vendor-models.yaml`** — added a `deepseek` block:
  ```yaml
  deepseek:
    low:  deepseek-v4-flash
    mid:  deepseek-v4-pro
    high: "deepseek-v4-pro[1m]"
  ```
  The `[1m]` suffix denotes DeepSeek's 1-million-context variant (higher per-token cost than plain v4-pro), reserved for the `high` tier where roles need maximum capability.
- **`skills/code4me/references/cross-vendor-policy.md`** — added a "Three-vendor pairing (v0.11+)" section. Documents the generalised alternation rule (producer ≠ verifier, with vendor selection between two non-anchor options using closest-pair-wins + alphabetical tiebreaker), a vendor-mechanism table (`anthropic`=Task subagent, `openai`=codex-bridge, `deepseek`=deepseek-bridge), an updated transparency-announcement format showing all three vendors interleaved, the "user names DeepSeek" single-role opt-in pattern, and the `deepseek_unavailable` failure mode (parallel to `codex_unavailable`).
- **`skills/code4me/SKILL.md`** — four updates:
  1. STRICT ORCHESTRATOR PROTOCOL block now lists `codex-bridge` and `deepseek-bridge` as the two cross-vendor skills.
  2. Toolbelt entry adds `deepseek-bridge skill (v0.11+)`.
  3. Hard success condition allows `deepseek-bridge` invocation as a valid dispatch alongside Task and codex-bridge.
  4. New **DeepSeek bridge dispatch gate** added below the existing Codex bridge gate, with parallel discipline: never invoke deepseek-bridge unilaterally; require user signal (single-role naming OR explicit three-vendor pairing with DeepSeek listed). Documents the Reasonix invocation mechanism.
- **`agents/{developer,code-reviewer,verification,challenger-architect,lead-architect,security-reviewer,spec-to-test}.md`** — each gets a "v0.11+: DeepSeek joins as a third vendor" comment block appended to its existing v0.10+ cross_vendor_pair_with note. The `cross_vendor_pair_with:` frontmatter itself does NOT change — it still lists roles, not vendors. The vendor decision remains dynamic, made by the orchestrator at team-composition time.
- **`bin/code4me-preflight`** — added a new "check 5b: DeepSeek bridging (optional)" that verifies `command -v reasonix` and checks for at least one auth source (`$DEEPSEEK_API_KEY` env var OR `~/.reasonix/config.json` `apiKey` field). The bridge does NOT pre-check auth at dispatch time — the env-var-or-config-file check exists in preflight purely as a friendly heads-up. Soft warning regardless — same posture as the existing check 5 for Codex (which doesn't pre-check `OPENAI_API_KEY` because `codex login` OAuth may be in use). Reasonix install hint included in the warning text.

### Auth posture for deepseek-bridge

The bridge does NOT require `$DEEPSEEK_API_KEY` at pre-flight. Reasonix accepts the API key from EITHER source:

- `$DEEPSEEK_API_KEY` env var (set by `export`)
- `~/.reasonix/config.json` `apiKey` field (populated by Reasonix's first-run wizard when the user runs `reasonix code` for the first time, or hand-edited)

Auth failures (neither source configured) surface at bridge invocation as `deepseek_subprocess_error` with the auth-error stderr tail in `blocker_detail`. This mirrors codex-bridge's posture exactly: codex-bridge doesn't pre-check `OPENAI_API_KEY` because the user may have authenticated via `codex login` OAuth instead. Pre-flight is CLI-presence only; auth is the CLI's problem.

Reason for the change: an interim v0.11 cut required `$DEEPSEEK_API_KEY` as a hard pre-flight, which broke users who'd authenticated Reasonix via its first-run wizard (the wizard stores the key in the config file, not env). The shipped bridge accepts either source. The `--no-config` flag that earlier prototypes passed for "deterministic per-dispatch settings" was also dropped — the explicit `--model` and `--effort` flags override config-file values for the things that affect bridge correctness, so the determinism cost was illusory while the user-config-breakage cost was real.

### Why Reasonix

Reasonix is DeepSeek's analog to OpenAI's Codex CLI: a dedicated, vendor-native agentic coding agent designed specifically for the model it talks to. The bridge architecture mirrors codex-bridge cleanly — same dispatch flow, same prompt-file pattern, same parse-validate loop, just a different CLI subprocess.

Key Reasonix advantages over the interim "nested Claude Code against DeepSeek's Anthropic-compatible endpoint" prototype:

1. **Prefix-cache native.** Reasonix orders prompts for DeepSeek's prefix-cache stability — the project reports 99.8% cache hit rates in real sessions, producing ~5x lower cost than naive API use. Claude Code's prompt construction is Anthropic-format-optimized and breaks DeepSeek's cache on minor changes.
2. **Native tool-call format.** DeepSeek's tool-call wire format differs subtly from Anthropic's. Reasonix uses DeepSeek's format directly; the Anthropic-compatible shim occasionally produced format errors when Claude Code talked to it.
3. **No recursion-prevention complexity.** A nested Claude Code instance might load the code4me plugin and try to be another orchestrator. Reasonix isn't Claude Code, so this failure mode doesn't exist.
4. **Symmetry with codex-bridge.** Both bridges spawn vendor-native CLI subprocesses. The orchestrator's reasoning at team-composition time treats DeepSeek as a clean peer of OpenAI rather than a nested-substrate special case.

### Cross-bridge symmetry

The two bridges are intentionally parallel, not branched:

- Same role set (7 roles), same modes per role, same return schemas, same blocker_type names.
- Same dispatch protocol shape (pre-flight → load reference → assemble prompt → invoke → parse → log).
- Same opt-in discipline (the dispatch gate's intake patterns are isomorphic — "user named codex-architect" maps directly to "user named deepseek-architect").
- Same audit-tool integration: dispatch log entries differ only in `vendor` and the model identifier; vendor split, vendor × tier rollup, weight × outcome heatmap, and pairing-degradation surveillance all work uniformly across the three vendors.

This symmetry is deliberate. A user who knows codex-bridge can use deepseek-bridge with no additional learning curve, and the orchestrator's reasoning at team-composition time treats DeepSeek as a peer of OpenAI rather than a special case.

### Migration / no breaking changes

The bridge is additive. Existing single-vendor and two-vendor (Anthropic + OpenAI) workflows continue to work as before. To opt in: set `$DEEPSEEK_API_KEY`, run `/code4me-preflight` to verify, then either name a specific DeepSeek role at intake (Path 1) or enable three-vendor cross-vendor pairing (Path 2). Probes 06-08 exercise both paths and the failure mode.

### Verification

- Bridge SKILL.md syntactically clean; 7 per-role references generated and verified for vendor-naming consistency (`vendor: deepseek` everywhere).
- `vendor-models.yaml` parses as valid YAML with the new `deepseek` block.
- `cross-vendor-policy.md` extension internally consistent (alternation rule generalised; three-vendor tiebreaker documented; failure mode mirrors `codex_unavailable`).
- Orchestrator SKILL.md dispatch gate added in the same place as the Codex gate; toolbelt and success conditions updated.
- All 7 agent files carry the v0.11+ comment block.
- Preflight check 5b added with both `claude` and `$DEEPSEEK_API_KEY` checks.
- Probes 06-08 written with explicit pass criteria and failure modes.
- `howto-enable-deepseek.md` mirrors `howto-enable-codex.md` for user-facing setup.

### Open questions deferred to v0.11.x

- **Audit-tool DeepSeek surveillance section.** The audit tool currently has Trivial surveillance (v0.10.4) and LSP-first surveillance (v0.10.5). A "Cross-vendor health" section that breaks down ask-gate rate, pairing degradation rate, and per-vendor outcome distribution would be useful but is not in scope for v0.11.0. Candidate for v0.11.1.
- **DeepSeek-specific tool-use evaluation.** DeepSeek's response quality on tool-using prompts (read file, run test, iterate) hasn't been measured against Claude or Codex on this plugin's role prompts. Probes 06-08 verify the orchestrator's behaviour; they don't measure DeepSeek's competence. A separate eval probe under `probes/evals/` covering "DeepSeek developer mode implement quality" would be useful — deferred to v0.11.x.
- **Cost rollup precision.** The dispatch log records the model identifier and tier; it doesn't sum input/output tokens. Reconcile against DeepSeek's billing portal for precise per-milestone cost numbers. Out of scope for the v0.11.0 cut.
- **Hook runtime gating via env vars** (idea source: `affaan-m/ECC`'s `ECC_HOOK_PROFILE` and `ECC_DISABLED_HOOKS`). Today the four PreToolUse hooks are all-or-nothing per install. Add `CODE4ME_HOOK_PROFILE=minimal|standard|strict` plus `CODE4ME_DISABLED_HOOKS="check-lsp-first-on-source,check-test-protection,..."` so a user can flip any hook off for a single session without uninstalling. Scope: ~3-line patch to each of the four hooks (early-exit based on env), one paragraph in `docs/howto-configure-lsp.md` and the other relevant howtos, optional audit-tool line showing the active profile. Low-urgency — only ship when ask-gate noise becomes a real complaint. Candidate for v0.11.1.
- **Windows hook portability mitigations.** Four small fixes to harden the bash hooks on Windows + Git Bash / WSL: (1) `.gitattributes` with `*.sh / *.json / *.yaml text eol=lf` to prevent CRLF corruption on clone, (2) `bin/code4me-preflight` gets a `command -v bash` check with Windows install hint, (3) new `docs/howto-windows.md` covering Git Bash / WSL requirement, jq install paths per package manager, known quirks, (4) CONTRIBUTING.md gets a Windows manual-test checklist. Defers the path-translation edge-case fix (`\` → `/` normalization in `$CLAUDE_PROJECT_DIR`) until real Windows soak surfaces it. Total scope ~1 hour. Candidate for v0.12.x.
- **Cross-vendor bridge post-validation (Option A — diff scan).** The PreToolUse hooks don't fire on `codex exec` or `reasonix run` subprocesses; bridge protection today is prompt-side rules + RETURN SCHEMA validation. Close the gap deterministically by extending each bridge's "Validation" step to run `git diff --name-only` after the return, cross-reference against `.code4me/protected-tests.txt`, `forbidden-conditions.json`, `critical-allowlist.txt`. Violations surface as the existing typed blockers (`test_protection_violation`, `out_of_scope_target`, `forbidden_condition_violation`). New probe `probes/cross-vendor/09-bridge-post-validation-catches-protected-test-edit.md`. Documents the layered defense in `docs/howto-enable-codex.md` and `docs/howto-enable-deepseek.md`. Doesn't add Codex-side hooks (Option B) — that's a separate optional advanced topic. Total scope ~2-3 hours. Candidate for v0.12.x.
- **CodeGraph as a code-knowledge surface alongside LSP** (idea source: `colbymchenry/codegraph`). Pre-indexed cross-language knowledge graph (tree-sitter → SQLite + FTS5) with MCP tools: `codegraph_context(task)` packages entry points + related symbols + code snippets in one call (the headline "94% fewer tool calls" benefit); `codegraph_impact(symbol)` analyzes blast radius (NEW capability — LSP has no equivalent); `codegraph_callers` / `codegraph_callees` for cross-language call traversal; `codegraph_affected` finds tests touched by a diff. Complementary to LSP, not a replacement (LSP keeps live diagnostics, completion, full type inference). **Trigger condition for revisiting:** if the LSP-first hook's ask-gate rate stays above ~30% of dispatch volume after a month of soak, that's evidence agents are asking task-shaped questions LSP doesn't answer well — codegraph_context is the stronger redirect target. Costs to adopt: another dependency (Node + npm + per-project `.codegraph/` SQLite), a third "code-knowledge" surface (alongside LSP and context-mode) requiring updated precedence rules in `code-consultation-precedence.md`, and the codegraph project's maturity risk (552 stars, 0 releases, 237 commits — active but young). Candidate for v0.12 IF the trigger condition fires.

---

## [0.10.5-dev] — in progress

LSP-first redirection for source-code consultation. A new opt-out PreToolUse hook (`check-lsp-first-on-source.sh`) intercepts symbol-shaped `ctx_execute` / `ctx_execute_file` / `ctx_batch_execute` invocations against languages declared in `.lsp.json` and ask-gates them with a redirect to LSP capabilities (definition, references, hover, documentSymbol, workspace_symbol, diagnostics). The hook auto-disables on projects without `.lsp.json`, so it's safe to wire unconditionally — and the starter `claude-settings.json` now does. Companion piece: `references/code-consultation-precedence.md` declares the full LSP-first ordering and the carve-outs (regex-in-comments, cross-language symbols, fuzzy search) where ctx_execute legitimately wins. Audit-tool extended with LSP-first surveillance reporting ask-gate counts, shape breakdown, and per-tool counts; >20% of dispatch volume is the drift threshold.

### Added

- **`hooks/check-lsp-first-on-source.sh`** — fourth runtime hook in the plugin's hook family. Auto-opt-out semantics: silent pass-through when `.lsp.json` is absent at the project root; activates when present. Matches three symbol-lookup shapes:
  - **(a)** `grep|rg|ag|ack` against files whose extension is declared in `.lsp.json` (e.g., `rg PasswordResetService src/`).
  - **(b)** `ctx_execute_file` whose `path` is a source file AND whose `code` contains a symbol-search verb (find / locate / where is / definition of / references to / declaration of / all functions / etc.).
  - **(c)** `cat|head|tail|less|sed -n` of a source file paired with a function/class/method/interface/struct/enum regex in the surrounding code.
  - Builds the source-extension regex dynamically from `.lsp.json`'s `extensionToLanguage` maps — adding a language to `.lsp.json` automatically extends the hook's coverage, no hook code change needed.
  - Returns `permissionDecision: ask` (never deny) with the message listing the LSP capabilities to consider first and pointing at `references/code-consultation-precedence.md`. Agent can type "yes" to proceed if the query is a genuine LSP carve-out.
  - Logs each ask-gate to `.code4me/lsp-first-events.jsonl` (one JSONL line: ts, tool, reason, haystack_head, event) for audit-tool surveillance.
  - Defensive behaviour matches the existing three hooks: missing jq, missing input, malformed input, missing `.lsp.json` → pass through silently.
- **`skills/code4me/references/code-consultation-precedence.md`** — declares the LSP-first ordering shared between developer / code-reviewer / verification subagents and the orchestrator's inline-edit path:
  1. **LSP** for "where defined / who calls / what type / what symbols / what's wrong" — definition, references, hover, documentSymbol, workspace_symbol, implementation, diagnostics, callHierarchy.
  2. **Read** (with `offset` + `limit`) for "show me this whole region" once LSP has narrowed it down.
  3. **ctx_execute_file** for non-symbolic analysis over a whole module — count occurrences, extract metrics, derive structural summary.
  4. **ctx_search** for non-source surfaces — indexed external docs, build outputs, log files.
  5. **ctx_execute with grep/rg/ag/ack** last resort for non-source files, regex-in-comments, or fuzzy text searches LSP cannot help with.
  Documents the runtime hook's pattern surface, the LSP-can't-answer carve-outs (regex inside strings/comments, generated/build artifacts, cross-language symbols, fuzzy/stemmed searches), and the auditability of proceeded ask-gates.

### Changed

- **`templates/project-starter/claude-settings.json.example`** — added a second `PreToolUse` entry wiring `check-lsp-first-on-source.sh` against the three context-mode matchers (`ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`). Auto-no-op on `.lsp.json` absence means it's safe to wire unconditionally — no separate "if you use LSP" opt-in needed. Updated `_notes` to document the four-hook family and the new lsp_first_hook entry.
- **`agents/developer.md`, `agents/code-reviewer.md`, `agents/verification.md`** — each adds `kind: dispatch-reminder, content: code-consultation-precedence` to its `context_queries:` block. The orchestrator emits a one-line pointer to `references/code-consultation-precedence.md` at every dispatch of these three subagents, surfacing the LSP-first rule at the moment of dispatch (not just in the steady-state reference). ~80 tokens per dispatch, paid back many times over by avoided full-file analysis passes.
- **`skills/code4me/references/context-queries-schema.md`** — extends the `dispatch-reminder` content enum from `tooling-hierarchy | language-injection | model-explicit` to add `code-consultation-precedence`. Documents that subagents consulting existing source code declare this content type to surface the LSP-first ordering at dispatch time, and that the runtime hook references the same file.
- **`bin/code4me-audit-dispatch-log`** — adds an **LSP-first surveillance** section that reads `.code4me/lsp-first-events.jsonl` when present. Reports: total ask-gate count, ratio to dispatch volume, drift warning when ratio > 20%, per-shape breakdown (which of the three matchers fired most), per-tool breakdown (ctx_execute vs ctx_execute_file vs ctx_batch_execute), and the last 5 ask-gate samples. Companion to the v0.10.4 Trivial surveillance; together they form the orchestrator-side audit surface for drift detection.
- **`docs/howto-configure-lsp.md`** — adds a "Runtime enforcement: the LSP-first hook (v0.10.5+)" section explaining auto-detection on `.lsp.json`, what the hook ask-gates, and how the per-language coverage extends automatically when you add a language to `.lsp.json`.

### Auto-enable semantics

The v0.10.5 hook breaks the v0.5+ "all hooks opt-in" invariant deliberately: the user picked **opt-out when `.lsp.json` is present** in the design conversation. Rationale: a project with `.lsp.json` declared has LSP wired and benefits from the redirect; a project without it has no redirect target, so the hook's auto-no-op makes it inert. There's no scenario where wiring the hook in the starter template harms a project; the worst case is "no `.lsp.json` → hook returns `{}` instantly". The opt-in convention is preserved for the three Edit/Write-gating hooks (test-protection, forbidden-conditions, critical-write-allowlist) because those tie to orchestrator state files (`.code4me/protected-tests.txt`, etc.) the user might not want to write.

### Why this matters in practice

Even with `.lsp.json` declared and ENABLE_LSP_TOOL=1, subagents reflexively reach for `ctx_execute` to do symbol queries — the output is text, and text is the shape models are most comfortable working with. A full-file `ctx_execute_file` pass to find a function declaration is several hundred tokens minimum; an LSP `textDocument/definition` returns the precise span in <50 tokens with the full signature attached. Multiplied across a Standard or Critical dispatch chain, the reflexive choice burns several thousand tokens of avoidable noise per milestone. The redirect surfaces this drift at the moment it happens, so the agent can choose correctly without the cost having to compound silently.

### Migration / no breaking changes

The hook is additive. Existing projects continue to work as before; if their `.lsp.json` is absent, the hook silently passes through and the existing context-mode flow is unchanged. To opt in: copy or merge the new `PreToolUse` entry from `templates/project-starter/claude-settings.json.example` into your project's `.claude/settings.json` (or just take the entire file fresh). The hook's events log lives at `.code4me/lsp-first-events.jsonl` and is created on first ask-gate — no setup required.

### Verification

- Hook handles 8 test cases: ask-gate on rg-on-source, ask-gate on ctx_execute_file with find-verb, ask-gate on cat-on-source-with-class-regex, ask-gate on ctx_batch_execute with mixed commands; pass-through on `dotnet test`, pass-through on no-`.lsp.json`, pass-through on log-file grep, pass-through on non-context-mode tool name (e.g., Bash).
- Hook auto-extends to new languages added to `.lsp.json` without code change.
- Events log accumulates correctly across multiple ask-gates; pass-throughs don't pollute the log.
- Audit-tool surveillance section renders with breakdowns and threshold warning when ratio > 20%.
- `claude-settings.json.example` validates as JSON; new entry slots cleanly alongside the existing Edit/Write hooks.

---

## [0.10.4-dev] — in progress

A fifth workflow weight — **Trivial** — and its supporting policy. Carves out a narrow exception to the v0.10.2 STRICT ORCHESTRATOR PROTOCOL for genuinely tiny edits (typos, version bumps, single-line value swaps, comment fixes, single imports, formatting, feature-flag toggles) where Conversation Mode's ~3–5K-token dispatch overhead structurally exceeds the change's value. The orchestrator does the edit inline, gated by a hard whitelist and a mandatory one-line justification recorded in both the transparency announcement and the dispatch log.

### Added

- **`skills/code4me/references/trivial-classification.md`** — the load-bearing reference for the Trivial weight. Covers:
  - **The whitelist** (7 items): single-file string value change, comment/docstring edit, typo in user-facing text, version/date bump, single import add/remove, whitespace/formatting/lint-fix, feature-flag toggle (config-only).
  - **What does NOT count** (8 categories): any behaviour change, any multi-file change, any new function/type/class, any test change, any schema/migration, any auth/sensitive-data touch, any new external dependency, any CI/deployment/infra change. Auto-escalation override applies normally.
  - **The justification requirement**: mandatory one-line `Justification:` in the transparency announcement, citing the specific whitelist item AND the concrete change (path, line, before→after). Vague justifications ("simple change", "small refactor") are a workflow violation; escalate to Conversation.
  - **Orchestrator behaviour in Trivial mode**: announce → direct Edit → dispatch-log entry with `subagent: "orchestrator-inline (trivial)"` + `trivial_justification` field → tracker update → no `PROVISIONAL` tag, no smoke test, no Combined Reviewer → report to user with explicit "verify visually" disclaimer.
  - **Abort conditions**: if mid-edit the orchestrator finds itself thinking *"and I also need to..."*, that's the abort signal — escalate to Conversation. Auto-escalation symptoms (auth, sensitive-data, migration, new dep) override Trivial unconditionally.
  - **Anti-drift safeguards**: (1) whitelist is short and concrete; (2) justification mandatory and audit-tool-surveilled; (3) probe 10 exercises edge cases.
  - **Composition** with auto-escalation, hooks, OpenWolf cerebrum, cross-vendor pairing (N/A), and Trello sync (applies normally).
  - **When NOT to use Trivial**: if 30%+ of work is Trivial by the rules, you have a tooling gap (linter, version bumper, template) — automate the underlying need rather than route systematic small changes through code4me.
- **`probes/classification/10-trivial-vs-conversation.md`** — five-scenario probe exercising the Trivial/Conversation boundary:
  1. Clear Trivial — typo fix → expect Trivial classification.
  2. Looks Trivial but is Conversation — function rename in one file → expect Conversation (Trivial whitelist excludes function renames).
  3. Looks Trivial but auto-escalates — JWT_SECRET value change → expect Standard with Security Reviewer (auth/sensitive-data symptom).
  4. User-facing string with behaviour implication — CTA copy change → expect Conversation (user-facing copy is observable behaviour).
  5. Genuine version bump — `package.json` 1.4.2 → 1.4.3 → expect Trivial.
  Each scenario documents its pass criterion + failure modes. Aggregate expectation: 2 Trivial, 2 Conversation, 1 auto-escalated Standard.

### Changed

- **`skills/code4me/references/workflow-weights.md`** — table extended from 4 weights to 5 (Trivial first). New paragraph explains Trivial's structural difference: no subagent dispatch, bounded whitelist, mandatory justification, bypasses Quality Gate Loop / PROVISIONAL / smoke test / Combined Reviewer. Order-of-evaluation step list gains step 5 "match the Trivial whitelist?" before product-work classification.
- **`skills/code4me/SKILL.md` STRICT ORCHESTRATOR PROTOCOL**:
  - **Toolbelt entry for `Write`/`Edit`** gains the "Trivial-classification exception" — production-file writes are permitted when classification is Trivial AND a valid one-line justification is recorded.
  - **Hard success condition** updates from "any classified task (Conversation/Light/Standard/Critical) MUST result in at least one Task call or codex-bridge invocation" to "any classified task EXCEPT Trivial MUST result in at least one Task call or codex-bridge invocation. Trivial classification (v0.10.4+) is the only exception."
  - **Operating loop step 3 (Classify)** lists the five weights including Trivial; references `trivial-classification.md`; instructs "when in doubt between Trivial and Conversation, escalate to Conversation."
  - Available reference files list adds `references/trivial-classification.md`.
- **`skills/code4me/references/playbook.md`** transparency-announcement section gains a Trivial example: *"Task `M07-T05-TRIV`: Classified Trivial — inline edit. Justification: typo fix in user-facing text. ..."* Explains the fixed shape: classification label + whitelist item + concrete one-line description.
- **`skills/code4me/references/model-selection.yaml`** gets a comment block explaining that Trivial doesn't appear in the tier defaults table — no subagent dispatch means no tier resolution; the orchestrator uses its own session model for the inline edit. Recorded in dispatch log as `subagent: "orchestrator-inline (trivial)"`.
- **`bin/code4me-audit-dispatch-log`** gains a **Trivial dispatch surveillance** section (v0.10.4+):
  - Reports total Trivial dispatches as count + percentage of all dispatches.
  - Threshold check: > 20% triggers a "possible classification drift" warning explaining the two likely causes (Conversation work mis-classified as Trivial; tooling gap that should automate the work).
  - Surfaces malformed entries (Trivial subagent value but missing `trivial_justification` field) as a "Malformed Trivial entries" subsection — these violate the dispatch-log contract.
  - Lists the last 10 Trivial justifications inline so the user can spot vague justifications at a glance.
- **`.claude-plugin/plugin.json`** version bumped to `0.10.4-dev`.

### Why

The v0.10.2 STRICT ORCHESTRATOR PROTOCOL closed a real drift problem (orchestrator doing subagent work inline, burning tokens and skipping gates). But it created a new tension: Conversation Mode's dispatch overhead is structurally excessive for changes where the entire diff is < 5 lines and the blast radius is zero. A 2-line typo fix that triggers a Developer subagent + Combined Reviewer + smoke test + `PROVISIONAL` tag costs ~3-5K tokens. For one-shot trivial edits this is bad cost-benefit and creates pressure to drift back to inline work — exactly what STRICT was meant to prevent.

The Trivial carve-out resolves the tension structurally: explicit fifth weight, narrow whitelist, mandatory justification, audit-tool surveillance for drift. The orchestrator gets a clean path for trivial edits without abandoning the discipline for everything else. Anti-drift is enforced through three layers: prompt (the whitelist is concrete and the rules say "when in doubt, escalate"), audit (the > 20% threshold and malformed-entry detection), and probe (probe 10 exercises edge cases).

Where the carve-out is deliberately narrow:
- Multi-file changes never qualify (even if each file's change individually would).
- Function renames, new code surface, test changes are all out.
- Auto-escalation symptoms override Trivial unconditionally — JWT secret changes aren't Trivial just because they're one line.
- "Looks like a string swap but user-facing" (CTA copy, error messages) defaults to Conversation, not Trivial.

The carve-out is a release valve, not a routine workflow. Sustained high Trivial volume signals a tooling gap (use a linter on save, a dependency-version bumper, a code generator) rather than a workflow that should accommodate it. The 20% threshold in the audit tool surfaces that signal explicitly.

### Verified

Audit tool smoke test against a synthetic Trivial-heavy log (3 of 4 dispatches Trivial = 75%):
- Drift warning fired correctly (over 20% threshold).
- Recent justifications listed inline with the vague "simple change" entry visible for user review.
- Malformed-entry detection works (entries missing `trivial_justification` would be surfaced if any).

---

## [0.10.3-dev] — in progress

Optional Kanban projection. The milestone-status-tracker remains the source of truth; the new `trello-sync` skill projects state to a Trello board (one-way, best-effort) at the four state-transition moments (intake, dispatch, return, escalation). When the Trello MCP isn't configured, the skill silently no-ops — the framework runs identically with or without Trello.

### Added

- **`skills/trello-sync/SKILL.md`** + `references/card-shape.md` + `references/columns.md` — the new skill the orchestrator invokes inline at state transitions. Targets the delorenj/mcp-server-trello tool surface (`mcp__trello__add_card_to_list`, `move_card_to_list`, `update_card_details`, `archive_card`). Six-column Kanban layout (Inbox / In Progress / In Review / Blocked / Pending User / Done). Three label categories per card: weight (Conversation / Light / Standard / Critical), kind (product / bug-fix / tech-debt / spike / incident / scope-change), vendor mix (claude / codex / cross-vendor). Card body auto-maintained with task ID, weight, kind, vendor mix, artefact links, latest 5 dispatches, latest 3 INSIGHTs, current state, next action. Conversation Mode `PROVISIONAL` tasks get the promote-or-revert deadline as the card's due date.
- **`commands/code4me-trello-init.md`** — one-time scaffold slash command. Probes the Trello MCP, lists available boards / lists / labels, helps the user pick or create the six default lists and the 13 labels, detects MCP tool-name conventions, writes `.code4me/trello-config.json`. Supports `--dry-run` (preview without writing) and `--board-id BOARD_ID` (skip the listing). Includes an optional end-to-end smoke test (create + archive a smoke card) to verify the wiring.
- **`templates/project-starter/trello-config.json.example`** — populated example config with placeholder IDs and inline comments explaining what each field means. Recommended to gitignore the real `.code4me/trello-config.json` since each team member typically has their own Trello board.
- **`probes/trello/01-sync-fires-on-state-transition.md`** — probe verifying the orchestrator invokes `trello-sync` at the four documented moments (intake, dispatch, return, escalation), NOT for read-only commands, NOT from inside subagents. Pass criterion: for a Standard milestone with N dispatched subagents, expect 1 + N + N + 1 trello-sync invocations.

### Changed

- **`skills/code4me/SKILL.md`** — operating loop step 8 ("Confirm and close") gains a "Trello sync (v0.10.3+, optional)" subsection describing the four invocation moments. STRICT PROTOCOL toolbelt gains a new bullet: *"MCP tool calls for bookkeeping projections — `mcp__trello__*` via the `trello-sync` skill at state transitions, when configured."* Available reference files list adds `skills/trello-sync/SKILL.md`.
- **`bin/code4me-preflight`** — new check 7b "Trello sync (optional)". Reports whether `.code4me/trello-config.json` exists, whether the `board_id` is set (not the placeholder), and whether all six `list_ids` are populated. Doesn't probe the Trello MCP directly (no clean way from a shell script); the actual MCP availability is checked at skill invocation time. Marked `warn` rather than `fail` on all degraded states — Trello sync is optional.
- **`.claude-plugin/plugin.json`** version bumped to `0.10.3-dev`.

### Why

The orchestrator already maintains state in `.code4me/milestone-status-tracker.md` — fine for reading inside Claude Code, but invisible from the user's phone, from the rest of the team, from a Trello-trained eye glancing at a wall display. The Kanban projection costs ~6 MCP tool calls per milestone (mostly `move_card_to_list` + `update_card_details`) and gives:

- **At-a-glance visibility.** Where is M07-T03 right now? Look at the column.
- **Mobile / web access.** The Trello mobile app is the projection's UX; the user doesn't need to be at their dev machine.
- **Stakeholder transparency.** Non-technical people can see Kanban; they can't read the markdown tracker file.
- **Conversation Mode deadline pressure.** `PROVISIONAL` cards have due dates; Trello surfaces overdue cards visibly.

The design discipline: **one-way sync, tracker as source of truth.** Drags on the Trello board don't change the milestone tracker (v1 limitation). If the user moves a card manually, the next state transition will overwrite the position. v2 with bidirectional sync + conflict resolution is possible later; not in v0.10.3.

The skill is opt-in by config presence: no `.code4me/trello-config.json`, no Trello sync. The orchestrator's announcement still mentions sync invocations (so the audit trail records the intent) but the skill no-ops the actual MCP calls. Zero footprint on projects that don't use Trello.

This composes cleanly with the v0.10 codex-bridge pattern: skill encapsulates the mechanism (Trello MCP calls); orchestrator owns the decision (when to sync, with what payload). Same shape as `codex-bridge`; same `STRICT PROTOCOL` allowlist treatment (the orchestrator invokes both inline from its own thread as bookkeeping).

### Deferred

- **`probes/trello/02-no-sync-when-mcp-missing.md`** — explicit no-op verification (same Standard milestone in a project without trello-config.json; expect zero `mcp__trello__*` calls). v0.10.4.
- **Bidirectional sync.** Drag-on-Trello-changes-state is genuinely useful but adds: a session-start "pull from Trello" step, conflict-resolution rules, an out-of-band "orchestrator and user disagree" escalation. v0.11 candidate; not in v0.10.x.
- **Multi-user / shared board patterns.** Currently the config is per-project, per-user (each team member runs `/code4me-trello-init` against their preferred board). A shared-board mode where all team members see the same Kanban view would need card-ownership conventions and per-user filtering. v0.11+ candidate.

---

## [0.10.2-dev] — in progress

Prompt-engineering fix for orchestrator drift. The orchestrator (the user's Claude session running the `code4me` skill) was occasionally doing subagent work itself — composing code edits, drafting specs, running quality checks inline — instead of dispatching. The costs are real: tokens (the orchestrator running on Opus does work a Sonnet developer subagent could do cheaper), audit trail (no `Task` entry in the dispatch log, no structured return, no INSIGHT routing), context (inline work can't be `/compact`ed away), and quality gates (no Verification / Code Review / QA / Co-Approval runs on inline work).

Same structural pattern as the v0.9.2 STRICT BRIDGE PROTOCOL fix for Codex shims — a Claude with full tools reading a skill file that describes a role sometimes drifts into doing the role's work instead of dispatching/bridging. The fix is identical: a STRICT block at the top of the file naming what the role is NOT, restricting the toolbelt explicitly, and adding a hard success condition.

### Added

- **`STRICT ORCHESTRATOR PROTOCOL` section at the top of `skills/code4me/SKILL.md`** — inserted right after the opening paragraph and the "This file is the contract" preamble, before any other section. Five substantive parts:
  1. **Explicit role prohibition.** Names every subagent role the orchestrator is NOT (developer, architect, verifier, code reviewer, QA, security reviewer, doc writer, researcher, product coach).
  2. **Toolbelt restriction.** Spells out which tools the orchestrator may use and for what:
     - `Task` — dispatch subagents; the primary action.
     - `codex-bridge` skill — cross-vendor execution.
     - `Read` — consult artefacts; "every file you read sits in your context permanently."
     - `Bash` — only for pre-flight, audit-log, `openwolf` commands, `bin/code4me-preflight`, etc. **Never** to run tests / builds / linters / type-checkers.
     - `Write` / `Edit` — only under `.code4me/` (own bookkeeping) and `.wolf/` (cerebrum updates on required-change INSIGHTs). **Never** to production code / tests / configs / docs.
  3. **Hard success condition.** Any classified task (Conversation / Light / Standard / Critical) MUST result in at least one `Task` call OR `codex-bridge` skill invocation. Failing this is a workflow violation; the orchestrator should stop, re-emit the transparency announcement, and dispatch.
  4. **Exemption list for read-only commands.** `/code4me-classify`, `/code4me-status`, `/code4me-audit`, `/code4me-preflight`, the decision part of `/code4me-promote-or-revert`, ad-hoc state questions. These don't dispatch by design.
  5. **"Why this matters" rationale.** Spells out the costs of inline work — destroyed audit trail, burnt context, skipped Quality Gate Loop, impossible Co-Approval, silent weight downgrade to "worse than Conversation Mode." Concludes with the key reframe: *"when the request maps to a subagent's role, dispatch — even if you have all the context to do it yourself; ESPECIALLY if you have all the context to do it yourself."*

### Changed

- **`.claude-plugin/plugin.json`** version bumped to `0.10.2-dev`.

### Why

The existing "Role boundaries you must respect" section in SKILL.md was correct but **buried in the middle of the file** (after the operating loop). The orchestrator routinely skimmed past it once classification was done. The STRICT block puts the prohibition at the **top** of the file — the first thing the orchestrator reads after the title and contract preamble — with a hard success condition that makes inline work an explicit workflow violation rather than a soft "should avoid."

The hard success condition is the load-bearing addition: previous prose said "you don't do that"; the new framing says **"if you do that, you have failed; stop and dispatch."** Failure framing changes the model's calibration — drift becomes self-correcting rather than soft-deprecated.

This is a prompt-level fix. It does not structurally prevent the orchestrator from editing production files at runtime — for that, see the deferred Option B below.

### Deferred (to v0.10.3 if drift persists)

- **Option B — runtime hook (`check-orchestrator-no-edit.sh`).** Ask-gates `Edit` / `Write` / `MultiEdit` from the orchestrator when the target is outside the allowlist (`.code4me/**` and `.wolf/**` by default; project-extendable via `.code4me/orchestrator-write-allowlist.txt`). Subagent edits pass through (the hook discriminates by Claude Code's `subagent_name` field in the hook payload). Soak Option A first; if the STRICT block plus the hard success condition fully eliminates drift, Option B is unnecessary. If drift persists in observed dispatches, the hook is the next escalation.

---

## [0.10.1-dev] — in progress

Preflight extensions surfaced by the user wanting visibility on more environmental signals: OpenWolf presence, the `context-mode` plugin, and a deeper LSP check that verifies each language server actually responds to an LSP `initialize` request rather than just checking the env var.

### Added

- **`bin/code4me-lsp-check`** — Python helper that performs an LSP handshake-lite against each language entry in `.lsp.json`. For each language: locates the binary on PATH; spawns the server; sends a minimal `initialize` JSON-RPC request via stdio; waits up to `--timeout` seconds for a response; inspects whether the response contains `Content-Length:` framing and JSON-RPC-shaped content. Reports per-language status (`ok` / `warn`) with detail. Supports `--json` (machine-readable) and `--timeout SECONDS` flags. Exits 0 even on per-language warnings — warnings are advisory, not failures. The "handshake-lite" framing (don't fully parse `InitializeResult`, just confirm LSP-shaped response) keeps the check robust across heterogeneous LSP implementations.

### Changed

- **`bin/code4me-preflight` gains three new checks:**
  1. **Per-language LSP handshake** (check 4b) — calls `bin/code4me-lsp-check --json` and surfaces each language as its own preflight row (`LSP handshake: cpp`, `LSP handshake: csharp`, etc.). Replaces the v0.9-era single `LSP enabled` env-var check with a real verification that each declared server is reachable and speaks LSP. The env-var check (check 3) is preserved as a separate row for visibility.
  2. **OpenWolf (optional)** (check 7) — looks for `.wolf/` at the project root and reports which knowledge files (`cerebrum.md`, `anatomy.md`, `buglog.json`) are present. Optional — marked `warn` rather than `fail` when absent.
  3. **context-mode plugin (optional)** (check 8) — looks for `~/.claude/plugins/context-mode/.claude-plugin/plugin.json`; if present, parses and surfaces the plugin's version. Optional — marked `warn` rather than `fail` when absent.
- **Codex CLI check message updated** to reference the v0.10 codex-bridge skill instead of the deprecated codex-* shims. The CLI-on-PATH check itself is unchanged; only the warn-text describing failure consequences was stale.

### Why

The v0.9 preflight handled `.code4me/`, hooks, LSP-env-var, plugin `.lsp.json`, Codex CLI, and `jq`. Three real signals were absent:

- **Deeper LSP verification.** Knowing `ENABLE_LSP_TOOL=1` is set is necessary but not sufficient — the actual language servers can still be missing from PATH (`pyright-langserver` not installed, `clangd` not built) or misconfigured (`compile_commands.json` missing for C++). The handshake check confirms each server is reachable AND speaks LSP at the protocol level. Per-language reporting means a broken C# setup doesn't drown out a working Python setup.
- **OpenWolf presence.** The plugin integrates with OpenWolf when present (cerebrum-first decision pre-deciding, anatomy-driven file reads, buglog-aware Lead Architect proposals). Preflight didn't expose whether OpenWolf was actually wired up — users would deploy the plugin into a project without `.wolf/` and silently miss the integration's benefits. The new check surfaces presence and lists which knowledge files exist.
- **context-mode plugin presence.** User-specific plugin integration the user flagged. Optional; surfaced because the user wants visibility.

All three new checks are **advisory** (warn, not fail). None block dispatch — the framework runs fully without OpenWolf, without context-mode, and even with broken individual LSP servers (other Claude tooling still works; LSP-enabled subagents fall back to Read/Grep). The point is visibility.

### Verification

Tested against the plugin's own folder (where most language servers aren't installed). Output correctly reports 3 LSP languages with appropriate warnings, OpenWolf absent, context-mode absent, Codex absent. No FAILs — preflight exits 0 with 8 warnings.

---

## [0.10.0-dev] — in progress

Architectural shift: the seven `codex-*` subagent shims are **gone**, replaced by a single `codex-bridge` skill that the orchestrator invokes inline from its own thread. Same roles, same modes, same prompts, same validation, same return contracts — but no more Claude-wrapper-around-Codex tax, and the v0.6–v0.9 identity-drift failure mode is eliminated structurally rather than papered over with prompt warnings.

### Added

- **`skills/codex-bridge/SKILL.md`** — the orchestrator-thread bridge to OpenAI Codex CLI. Top-level skill with frontmatter description, "when to invoke" gate (must be cross-vendor enabled OR user-named role — same gate as v0.9.1, just the action it gates has changed), pre-flight (only `command -v codex` — no `OPENAI_API_KEY` requirement since modern Codex supports `codex login`), invocation flow (read role reference → assemble prompt via Write → invoke `codex exec` via Bash → Read response → validate → use inline → log dispatch), tier resolution mapping (bridge role → Claude-side role for tier lookup), failure-mode catalogue, and context-discipline guidance (Codex responses can be large; orchestrator may /compact between phases).
- **`skills/codex-bridge/references/`** — seven per-role reference files distilled from the deleted shim content:
  - `architect.md` — challenge / consult / review-spec modes
  - `developer.md` — implement / review-diff / spike modes
  - `code-reviewer.md` — review-diff / review-files / review-spec-fit modes
  - `spec-to-test.md` — generate / review-test-spec modes (generate writes test files + protected-tests manifest)
  - `security-reviewer.md` — diff-focused / comprehensive modes
  - `verification.md` — suite-run / ac-coverage modes
  - `lead-architect.md` — propose / amend modes (Codex-led architecture; inverse pairing)

  Each reference carries the modes table, per-mode inputs, the literal Codex prompt template (the string the orchestrator writes to `/tmp/codex-{slug}-{task_id}.txt`), the invocation command + timeout, per-mode validation rules + typed `blocker_type` values, and the return shape that goes back into the orchestrator's working data.

### Removed

- **All 7 codex-* agent files** in `agents/`: `codex-architect.md`, `codex-developer.md`, `codex-code-reviewer.md`, `codex-spec-to-test.md`, `codex-security-reviewer.md`, `codex-verification.md`, `codex-lead-architect.md`. The subagent contracts that lived in them have moved to the skill references; the bridging behaviour is now the orchestrator's responsibility.

### Changed

- **`skills/code4me/SKILL.md`** — the v0.9.1 "Codex shim dispatch gate" is now the "Codex bridge dispatch gate" with the same opt-in conditions and the same workflow-violation framing, but the action it gates is "invoke the codex-bridge skill" rather than "dispatch a codex-* shim." Available-subagents section lost the codex-* entries; a new "Cross-vendor execution (v0.10+)" subsection describes the bridge and lists the seven role references.
- **`skills/code4me/references/cross-vendor-policy.md`** — the alternation rule still applies but the resolution algorithm describes the new mechanism: "Check Codex bridge availability" (single `command -v codex` check, no API-key pre-check). Failure mode renamed: `pairing_degraded: shim_unavailable` → `pairing_degraded: codex_unavailable`. Audit-tool integration note updated: codex-bridge invocations appear in the dispatch log with `subagent: "codex-{role} (skill-bridge)"`.
- **`skills/code4me/references/model-selection.yaml`** — codex-* entries removed; comment block explains that tier lookup goes through the underlying role name (e.g., `architect` bridge role uses `challenger-architect` tier defaults). The bridge SKILL.md's "Tier resolution" section spells out the mapping explicitly.
- **`skills/code4me/references/playbook.md`** — transparency announcement example updated from `codex-architect (codex:high)` to `codex-bridge[architect] (codex:high)` notation.
- **9 agent files** with `cross_vendor_pair_with` frontmatter — codex-* role entries removed; the lists now contain only Claude-side role names. The mechanism (Claude subagent vs codex-bridge skill) is a vendor decision the orchestrator makes at dispatch time per `cross-vendor-policy.md`, not a per-role declaration.
- **Probes `cross-vendor/01`, `03`, `04`, `05`** — Expected blocks updated to use the new `codex-bridge[role] (codex:tier)` notation in team announcements; `pairing_degraded` reason renamed in probe 03.
- **Probes `external-agents/01–05`** — marked **SUPERSEDED IN v0.10** with a banner at the top of each, pointing at the new `probes/cross-vendor/*` set. The probes are preserved for historical reference; the spirit of each (substitution, failure-mapping, mode dispatch, mode-defaulting) still applies but the announced team uses skill invocations rather than subagent dispatches.
- **`README.md`** — version-history line updated to mention the v0.10 conversion.
- **`.claude-plugin/plugin.json`** version bumped to `0.10.0-dev`.

### Why

The user identified two compounding costs of the subagent-shim approach:

1. **Token cost.** Every Codex invocation paid double — a Claude subagent setup + the Codex tokens. The Claude subagent was doing essentially mechanical bridging (write file, run bash, parse response) that didn't need a model. The skill approach pays only the Codex tokens.

2. **Identity drift.** The shim files contained verbatim Codex prompt templates (addressed to Codex in second person: "ROLE: You are the Challenger Architect...") that read as instructions to whoever was reading. The fresh Claude subagent spawned to bridge would often respond to the template's content as its own instructions and start doing the architect's substantive work inline instead of invoking `codex exec`. v0.9.1 and v0.9.2 tried to fix this with prompt-engineering fences and explicit "you are NOT the role" framings, but the structural fix is to not spawn a separate Claude in the first place. The orchestrator is clearly the orchestrator; it doesn't get confused about whether it should be doing the work itself.

The skill conversion is opinionated: the orchestrator's thread does more work per Codex dispatch (read role reference, write prompt file, invoke Bash, parse response, validate). The trade-off is real but the cost-benefit favours the bridge for this specific case where the subagent was doing mechanical wrapping rather than substantive Claude work.

### Trade-offs to know

- **Codex responses live in the orchestrator's context.** A `verification (mode=suite-run)` response can be substantial. The reference's validation step trims large fields (e.g., `test_runner_output_excerpt` limited to last 50 lines), but on Critical milestones with 4–5 cross-vendor invocations the orchestrator's context can accumulate. Mitigation: orchestrator can `/compact` between phases; the structured outcomes survive compaction.
- **Dispatch-log accounting:** the `subagent` field is now a slight misnomer for bridge invocations. The convention is `"codex-{role} (skill-bridge)"` so audit-tool analytics still group by role name; the suffix distinguishes them from legacy subagent dispatches in pre-v0.10 logs.
- **Cross-vendor pairing semantics are unchanged** — same Co-Approval Rule, same alternation matrix, same hard floors. Only the mechanism on the Codex side changed.

### Deferred to v0.10.1

- **Shell portability** still hardcodes `/tmp/`, `timeout`, and POSIX commands. The v0.9.1 changelog noted this; v0.10 didn't fix it. On Windows with Git Bash this typically works because Git Bash provides `/tmp/` and POSIX shims; on plain PowerShell environments it won't. Mitigation today: `docs/howto-enable-codex.md` must document that Codex needs to be on the PATH of the same shell Claude Code's Bash tool uses.
- **External-agents probes** are marked superseded rather than rewritten or deleted. v0.10.1 may add probes that explicitly verify the v0.10 skill-bridge behaviour (e.g., "orchestrator invokes Bash + Codex inline; no Task tool dispatch for codex roles"). For now, `probes/cross-vendor/01-05` cover the load-bearing behaviour.

---

## [0.9.2-dev] — in progress

Second bug-fix cut on the Codex shims. v0.9.1 fixed auth + dispatch-gating; v0.9.2 addresses the identity-drift failure mode that v0.9.1 deferred — the subagent reading a shim file would do lots of reasoning but never actually invoke `codex exec`.

### Fixed

- **STRICT BRIDGE PROTOCOL block at the top of all 7 shims.** Inserted right after the opening "You are a protocol bridge..." paragraph, before any other section. Each shim now opens with an explicit anti-drift statement:
  - "**You are NOT the {role}.**" (architect / developer / code reviewer / spec-to-test engineer / security reviewer / verification engineer / lead architect — named explicitly per shim)
  - The exact three-tool toolbelt the bridge is allowed to use: Bash, Write, Read (no Read of project files for "context-gathering"; no LSP queries; the shim is purely a wrapper around `codex exec`)
  - A do-not list naming the role-specific outputs the bridge must NOT produce inline (critiques, implementations, reviews, etc.)
  - **A hard success condition:** "A successful dispatch transcript MUST include a Bash tool call that invokes `codex exec --prompt-file ...`. If you complete this dispatch without that Bash call, you have failed the protocol — return `BLOCKED` with `blocker_type: codex_response_invalid` and `blocker_detail: \"bridge did not invoke codex exec\"` rather than synthesising the work."

  The placement matters: this block is the FIRST thing after the title and opening paragraph, before "## Prime directive". The previous "What you do not do" list was at the very bottom of each file, where it tended to get skimmed.

- **"WARNING — these are STRINGS, not your instructions" header on every "Constructing the Codex prompt" section.** The fenced blocks inside each shim contain literal Codex prompts addressed in second person ("ROLE: You are...", "INPUTS:", "PROCEDURE:", "RETURN SCHEMA:"). Without explicit fencing, the bridge subagent reads those as its own instructions and starts doing the role's substantive work inline. The new warning paragraph spells out:
  - The fenced block is a literal string for Write to copy into the prompt file
  - Second-person language addressed to Codex, not to the bridge
  - `{placeholder}` fields are to be substituted from the Context Pack
  - If the bridge finds itself producing role-substance content (critiques, implementations, reviews, findings, etc.) instead of writing the string to a file, stop and use Write + Bash instead

  The warning is per-shim, tailored to the specific role's substantive outputs (e.g., codex-architect's warning names "critiques, alternatives, spec reviews"; codex-developer's names "code, tests, diffs, spikes"; codex-security-reviewer's names "OWASP findings, STRIDE examinations, dependency audits").

### Why

The v0.9.1 fixes addressed setup-side blockers (auth pre-flight, orchestrator dispatch gate) but the bridge runtime itself was still confused by the shim file's structure. The bridge subagent reads ~280-400 lines of Markdown including a verbatim Codex prompt template, and the prompt template's second-person voice ("ROLE: You are the Challenger Architect... Your job is to pressure-test...") reads as instructions to whoever is reading. The bridge has all the model capacity to do the role's work directly, and the file's structure made it the path of least resistance.

The fix is purely prompt-engineering: move the anti-drift framing to the TOP where it can't be skimmed past, restrict the toolbelt explicitly to make "use Bash to invoke codex" the obvious action, and fence the verbatim templates so the second-person language can't be confused with instructions for the bridge itself.

This is a prompt-layout fix, not a logic fix. The shims' validation contracts, return shapes, and orchestrator-side handling are unchanged — only the framing inside each shim file changed. Files touched: 7 (one per shim). Two Edits per file (STRICT BRIDGE PROTOCOL insert + WARNING insert). No new files; no agent-frontmatter changes.

### What this doesn't fix

Per the v0.9.1 changelog's "Known remaining shim issues" list, one item remains: **shell portability**. The shims still hard-code `/tmp/`, `timeout`, and POSIX commands. On Windows with Git Bash this typically works because Git Bash provides `/tmp/` and POSIX shims, but `codex` reachability can break if Codex is installed for PowerShell but not for the bash environment Claude Code invokes. Defer to v0.9.3 or absorb into v1.0 prep — the simplest mitigation today is documenting in `docs/howto-enable-codex.md` that Codex must be on the PATH of the same shell Claude Code's Bash tool uses (typically Git Bash on Windows).

---

## [0.9.1-dev] — in progress

Bug-fix cut surfaced by the first real attempt to use the Codex shims. Two issues, two fixes:

### Fixed

- **Removed the `OPENAI_API_KEY` pre-flight check from all 7 Codex shims.** Modern Codex CLI authenticates via `codex login` (OAuth, credentials stored under `~/.codex/`) OR via the env var — either works. The shim's previous behaviour was to BLOCK with `codex_auth_missing` whenever the env var wasn't set, which broke every dispatch for users who'd authenticated via login instead. The shim now only checks `command -v codex` at pre-flight; authentication failures (if any) surface as `codex_error` on a non-zero exit from `codex exec`, with the stderr tail in `blocker_detail`. The `codex_auth_missing` blocker_type is removed from every shim's failure enum.

  Files touched: `agents/codex-architect.md`, `agents/codex-developer.md`, `agents/codex-code-reviewer.md`, `agents/codex-spec-to-test.md`, `agents/codex-security-reviewer.md`, `agents/codex-verification.md`, `agents/codex-lead-architect.md` — pre-flight section + failure enum + description "Opt-in only:" text in each.

- **Added a Codex shim dispatch gate to `SKILL.md`'s operating loop step 5.** The orchestrator was dispatching `codex-*` shims when it shouldn't — inferring cross-vendor from the work's nature, the team-template pairing column, or the perceived benefit of dialectic, when the user hadn't actually opted in. The new gate states: never include a `codex-*` shim in the announced team unless (a) the user named the specific shim, OR (b) the user explicitly enabled cross-vendor pairing (the words "cross-vendor" / "alternation" / `--cross-vendor` flag, or a project-level default in CLAUDE.md). When uncertain, surface as `NEEDS_DECISION` and ask — don't dispatch optimistically. Each shim's description frontmatter now points at this gate.

### Why

Two failure modes the user surfaced from the first attempted Codex run:

1. **Pre-flight rejecting valid setups.** The OPENAI_API_KEY check predates the modern Codex CLI's OAuth login flow. Users who `codex login` instead of exporting an env var saw every shim BLOCK at pre-flight despite having a working Codex install. The fix is to delegate auth-detection to Codex itself — it knows whether it's authenticated; the shim doesn't need to second-guess.

2. **Orchestrator over-eager about cross-vendor.** The shims read as "available" to the orchestrator because they're listed alongside Claude-side subagents in `SKILL.md` and `references/team-templates.md`. Without the gate, the orchestrator was treating them as substitute roles to pick when the work seemed to warrant cross-vendor dialectic — but cross-vendor is opt-in per milestone, not an orchestrator-side judgment call. The gate makes that explicit: codex shims require an explicit user signal, full stop.

Both are structural issues in v0.6-v0.9 that surfaced only when a real user tried to use Codex with a non-API-key auth method and watched the orchestrator misfire. Worth surfacing because they were silently making the cross-vendor pairing infrastructure unusable.

### Known remaining shim issues (deferred)

Per the same diagnosis pass, two more shim bugs were identified but deferred to a later cut at user's discretion:

- **Identity drift.** Each shim file has a long verbatim Codex prompt template (`ROLE: You are the Challenger Architect ...`) that Claude is supposed to write to /tmp for Codex to consume — but Claude can confuse this with its own role and start doing the architecture work itself instead of bridging. The fix would restructure each shim with clearer demarcation between "instructions to the bridge" and "prompt string for Codex."
- **Shell portability.** The shims hard-code `/tmp/`, `timeout`, and POSIX commands. On Windows with Git Bash this typically works because Git Bash provides `/tmp/` and POSIX shims, but `codex` reachability can break if Codex is installed for PowerShell but not for the bash environment Claude Code invokes.

Both are real bugs but lower-priority than the auth + dispatch-gate fixes. Will land in v0.9.2 or absorbed into v1.0 prep.

---

## [0.9.0-dev] — in progress

Two cuts so far:

1. **Gap-closing + cleanup** — closes the v0.8 codex-developer allowlist asymmetry; softens Playwright to disabled-by-default in the recommended MCP starter.
2. **Workflow integrations + Diataxis docs split** — pre-flight sanity-check script + slash command, the 430-line monolithic README split into Diataxis quadrants under `docs/`, plus discipline docs for probe-baselines and trace-review.

### Added

- **Codex-developer allowlist pre-screening** in `agents/codex-developer.md` (implement mode). Closes the Critical-mode safety asymmetry explicitly flagged in v0.8's Safety cut. Three changes compose to make the protection symmetric across vendors:
  - `context_queries:` gains a new `protected-list` entry for `.code4me/critical-allowlist.txt` (active in implement mode), so the orchestrator resolves the allowlist contents into the Context Pack alongside the existing protected-tests manifest.
  - The Codex prompt for implement mode now includes a **CRITICAL-MODE ALLOWLIST RULE** section that tells Codex: if a file you need to modify is not covered by any allowlist entry, stop and return `outcome: OUT_OF_SCOPE_TARGET` with the gated path and the patterns it failed to match. The allowlist content is forwarded verbatim so Codex sees the scope.
  - The shim's implement-mode validation step gains a **Critical-Mode allowlist pre-screen** check that runs after parsing Codex's response: for every path in `files_touched`, verify it matches at least one allowlist entry using the same glob semantics as `hooks/check-critical-write-allowlist.sh` (`**`, `*`, `?`; relative paths resolved to project root). Any path with zero matches → `BLOCKED` with `blocker_type: out_of_scope_target` and the structured `out_of_scope_target: {path, allowlist_patterns_not_matched}` detail. Codex's edits don't pass through Claude Code's hook system, so this post-hoc shim-side check is what makes the allowlist symmetric — a Codex-side dispatch in Critical mode now respects the milestone scope just like a Claude-side dispatch.
  - New typed `blocker_type: out_of_scope_target` added to codex-developer's failure enum.
  - "What you do not do" section gains the line "Allow `files_touched` to contain paths outside the Critical-mode allowlist when one is active."

### Changed

- **`templates/project-starter/.mcp-recommended.json`** — Playwright moved from enabled-by-default to disabled-by-default with the same `_disabled_by_default` annotation pattern used for `filesystem`, `sentry`, and `postgres`. Comments make explicit that it's a web/UI work tool: "If your project is server-only, library code, native desktop, or anything without a browser surface, leave this disabled." The `_subagent_preferences` block annotations for Developer / Verification / QA now tag Playwright with "(web projects only)" so the recommendation is conditional rather than default.
- **`.claude-plugin/plugin.json`** version bumped to `0.9.0-dev`; description condensed to remove the v0.7/v0.8 narrative and instead spell out the current feature set (tiers, pairing, three hooks with symmetric enforcement as of v0.9).

### Why

The v0.8 Safety cut explicitly named the codex-developer asymmetry as a known gap — the Claude-side hook (`check-critical-write-allowlist.sh`) catches Edit/Write tool calls before they execute, but Codex runs in a subprocess whose tool calls never pass through Claude Code's hook system. That meant a `codex-developer (mode=implement)` dispatch in Critical mode could silently edit out-of-scope files; the structural protection only applied to Claude-side dispatches. v0.9 closes that with the post-hoc validation: Codex still has its own sandbox, but the shim refuses to mark a dispatch COMPLETE when its `files_touched` lists out-of-scope paths. Same outcome shape as the Claude-side gate (`OUT_OF_SCOPE_TARGET`); orchestrator handles the scope-expansion request identically.

The Playwright softening is straightforward: the v0.7 starter shipped with Playwright enabled-by-default because the field guide treated visual verification as a high-leverage practice — but for projects without a browser surface (server-only, library, native desktop, anything not web), Playwright is dead weight and the unconditional recommendation is misleading. Disabled-by-default with a clear "web projects only" annotation matches the actual leverage curve.

---

### Added (workflow + docs cut)

- **Pre-flight sanity checks (F2)** — `bin/code4me-preflight` runs eight checks: `.code4me/` working directory present and writable; hooks installed in `.claude/settings.json` (all three hook scripts referenced); LSP enabled via `ENABLE_LSP_TOOL=1`; plugin `.lsp.json` present; Codex CLI on PATH (optional, warns if missing); `jq` on PATH (required by audit + probe tools); `--critical` flag enables extra checks for critical-allowlist content and hook-script executability. Output is a markdown report with per-check verdict (✓ ok / ⚠ warn / ✗ FAIL); exit non-zero only on FAIL (warnings advisory). Wrapped by `/code4me-preflight [--critical] [--quiet]` slash command. SKILL.md updated to list it in the slash-commands section.
- **Diataxis docs split (C1)** — the 430-line monolithic README has been split into four-quadrant Diataxis structure under `docs/`:
  - `docs/tutorial.md` — 10-minute "first milestone" walkthrough
  - `docs/howto-install-hooks.md` — installing the three opt-in PreToolUse hooks
  - `docs/howto-configure-lsp.md` — enabling LSP for C# / Swift / C++ / Python + adding another language
  - `docs/howto-enable-codex.md` — Codex CLI setup, the seven shims, per-use-case mode reference, failure modes
  - `docs/howto-enable-cross-vendor.md` — opt-in alternation rule (v0.7+) walkthrough
  - `docs/reference.md` — workflow weights, Standard Mode flow, all 15 subagents, slash commands, model tiers, cross-vendor pairing, runtime hooks, audit/analytics, context-queries schema, dispatch log JSONL shape, full folder layout
  - `docs/explanation.md` — design-decision rationale: why four weights, why auto-escalation override, why Co-Approval, why Producer-as-orchestrator, why declarative context_queries, why slim SKILL+playbook+references, why Test Protection Rule, why opt-in cross-vendor, why hooks ask not deny, why probes instead of unit tests, why no codex-qa or codex-researcher, why orchestrator on Opus, what ETHOS provides, why the framework still ships at 0.x
  - **New ~80-line root `README.md`** that points at the four quadrants instead of trying to be all four at once
- **Probe baselines discipline doc (C3)** — `docs/probe-baselines.md` covers when to capture a new baseline (after intentional framework changes verified clean; after judge-model upgrade; at major version bumps), when NOT to (don't silence a regression by re-baselining), how flip detection works in the runner, how to interpret the output, how to tune the `max_flips` budget, the CI integration story (and its current limitation: probes are interactive, so CI is `--no-budget` only until headless invocation lands). `probes/README.md` "Baselines" section updated to point at this doc.
- **Trace-review discipline doc (B4)** — `docs/trace-review.md` operationalises Hamel Husain's 30-minute trace-reading practice against the v0.8 audit-tool extensions. Tier 1 / Tier 2 / Tier 3 checklist of what to look for; how to use `/code4me-audit` and `jq` queries to find traces worth reading; what to do with what you find (cerebrum updates, INSIGHT register entries, framework changes); anti-patterns to avoid.

### Changed (workflow + docs cut)

- **`skills/code4me/SKILL.md`** — slash-commands section lists `/code4me-preflight`.
- **`probes/README.md`** — "Baselines" section rewritten to cover the v0.8 programmatic runner workflow alongside the original manual approach; pointers to `docs/probe-baselines.md` for the full discipline.

### Why (workflow + docs cut)

Three independent improvements grouped for momentum:

- **Pre-flight sanity checks** make Critical milestones safer to invoke. The `--critical` flag's extra checks (allowlist content, hook scripts on disk) catch the most common "I forgot to configure X before dispatching Critical work" cases. The slash command makes it user-invokable; the orchestrator's playbook gains a recommendation to run it before Critical dispatches. Failure modes are now visible up front rather than mid-dispatch.
- **The Diataxis split** is the single most-cited improvement from the original v0.7 plan. The 430-line monolithic README was correct content but wrong shape: it tried to be reference + tutorial + how-to + explanation simultaneously. Each Diataxis quadrant serves a distinct mode of reading — tutorials for learning, how-tos for doing, reference for looking up, explanation for understanding. The new ~80-line root README is the table of contents; the docs/ files are each focused on one mode. External readers can now find what they need; the internal author (you) can update one quadrant without rippling through the others.

Pluss the two discipline docs (probe-baselines and trace-review) are the missing pieces of the v0.8 observability story. The regression budget and the audit-tool extensions ship the capability; these docs ship the practice. Without them, the v0.8 features were "available" but not "actionable."

This essentially closes the v0.9 plan. Remaining backlog items:

- **A3** — measuring SKILL.md description activation precision before tightening trigger phrasing. Soft priority; the description currently activates reliably enough.
- **D3** — AGENTS.md emission for cross-agent toolchain portability. Only worth doing if you actually run multi-agent setups; otherwise dead weight.
- **v0.9.1+** — headless probe execution so CI can run the suite end-to-end without interactive paste (`probes/README.md` currently says `--no-budget` in CI only).

And — same as always, for the fifth version in a row — **live-testing**. v0.6.1 through v0.9.0-dev is now roughly 60 files of theoretical framework with zero dispatches against real work. The framework is now structurally complete enough that the empirical signal is the only thing standing between it and 1.0.

---

## [0.8.0-dev] — in progress

Two items remain on the v0.9 plan after this cut:

1. **Doc polish** — C1 Diataxis README split, C3 probe-baseline note (documents how to capture baselines for the v0.8 regression budget), B4 trace-review discipline doc (operationalises Hamel Husain's 30-minute trace-reading practice against the v0.8 audit-tool extensions).
2. **Workflow integrations** — F2 pre-flight sanity probes (run before Critical dispatch; checks `.code4me/`, hooks installed, LSP reachable, Codex CLI present if codex-* shims will fire).

Tier-3 shims (codex-qa, codex-researcher) are explicitly closed as of this cut: the user has chosen to keep QA and Researcher Claude-only, and the deferred-list framing those as "pending live-test signal" no longer applies.

And, for the fourth version in a row: **the live-test step is still un-done.** v0.6.1 through v0.9.0-dev has accumulated ~50 files of theoretical framework with zero dispatches against real work. The next Standard milestone you run through it remains the single highest-leverage activity ahead.

---

## [0.8.0-dev] — in progress

Three cuts so far:

1. **Tier-2 shims** — completes cross-vendor pairing coverage with `codex-verification` (closes the verifier-alternation gap that degraded in v0.7 probe 01) and `codex-lead-architect` (inverts the architect pairing direction so Codex can lead with a Claude challenger).
2. **Observability** — regression budget on probe runs (B2), dispatch-log analytics extensions (B3), context-query provenance schema (D1).
3. **Safety hardening** — Critical-write-allowlist hook (F1) closes the highest-stakes blast-radius gap by ask-gating any Edit/Write outside the Tech Spec's declared scope during Critical milestones.

### Added

- **`agents/codex-verification.md`** — Tier-2 shim of the Verification role with two modes:
  - `suite-run` (default) — Codex runs the project's test command via shell, parses results (passed / failed / skipped counts, failing test names), performs AC coverage assessment per AC against the Tech Spec, performs test integrity check against the protected-tests manifest (flags removed / weakened / value-changed / skip-added / unauthorised tests), returns a full structured Verification Report. Enforces the Test Suite Rule (RED anywhere in the repo → FAIL) and the Test Integrity Rule (any integrity finding → FAIL) at validation time.
  - `ac-coverage` — read-only AC traceability pass; no test execution; for fast pre-checks before the full verification gate.
  - Both modes: `files_touched` must be empty; outcome consistency enforced (RED → FAIL, integrity findings → FAIL); shim BLOCKs with typed `blocker_type` (`suite_status_outcome_mismatch`, `ac_coverage_incomplete`, `test_integrity_outcome_mismatch`, etc.) on validation failure. Outcomes PASS / PASS_WITH_FIXES / FAIL / BLOCKED match canonical `verification`.
- **`agents/codex-lead-architect.md`** — Tier-2 shim of the Lead Architect role with two modes:
  - `propose` (default) — produces an architecture proposal covering system components / module responsibilities / data flow / external dependencies / key interfaces / performance considerations / error-handling strategy, with **mandatory ≥ 2 named alternatives** (or `convergence_notes` explicitly citing which classes were ruled out). The shim BLOCKs with `mandatory_alternatives_violation` if Codex returns a proposal without the alternative space — same discipline the existing `challenger-architect`/`codex-architect` enforce on critique. Outcomes PROPOSED / NEEDS_PRODUCT_CLARIFICATION / BLOCKED.
  - `amend` — integrates Challenger amendments into an existing Tech Spec draft. Updates `updated_tech_spec_content` with the integrated changes; lists `changes_integrated` / `items_disputed` / `items_for_user_escalation` separately. Enforces the Co-Approval Rule at validation time: `approved: true` is only valid when both `items_disputed` and `items_for_user_escalation` are empty; shim BLOCKs with `co_approval_violation` otherwise. Outcomes REWORK / APPROVED / BLOCKED.
  - Inverts the v0.7 architect pairing: `codex-lead-architect (codex:high)` + `challenger-architect (claude:high)` composes normally under Co-Approval, just with the vendors flipped from v0.7's default.
- **Probes 04–05 under `probes/cross-vendor/`:**
  - `04-codex-verification-completes-alternation.md` — re-runs v0.7 probe 01's scenario; expects no `pairing_degraded` on the verification dispatch in v0.8+. Side-by-side regression check across the v0.7→v0.8 version bump.
  - `05-codex-lead-architect-inverts-pairing.md` — Standard milestone with `codex-lead-architect` driving the design and `challenger-architect` (Claude) pressure-testing. Tests the symmetry of the alternation rule and the mandatory-alternatives check.

### Changed

- **`cross_vendor_pair_with` frontmatter additions** on existing agents:
  - `developer.md` and `codex-developer.md` each gain `codex-verification` in their pair list (relation: `verified-by`).
  - `challenger-architect.md` and `codex-architect.md` each gain `codex-lead-architect` in their pair list (relation: `critic-of`).
  - `security-reviewer.md` gains a clarification note that it operates on code (diff / surface), not architecture artifacts — the architect pairings live entirely on `lead-architect ↔ challenger-architect / codex-architect / codex-lead-architect`.
- **`references/model-selection.yaml`** — `codex-verification` and `codex-lead-architect` registered in the `defaults:` block with the same tier defaults as the roles they shim (verification: standard mid / critical mid; lead-architect: standard high / critical high). Hard floors and deviation rules apply unchanged.
- **`references/model-selection.md`** — "Per-shim guidance" section gains entries for both new shims with mode descriptions and when-to-use guidance.
- **`SKILL.md` "Available subagents"** lists `codex-verification` and `codex-lead-architect` with mode summaries and pairing notes.
- **`.claude-plugin/plugin.json`** version bumped to `0.8.0-dev`; description updated to mention the v0.8 Tier-2 additions explicitly.

### Why

The Tier-2 cut closes the two most visible gaps from the v0.7 Foundation:

1. **The verification alternation gap.** v0.7 probe 01 explicitly recorded `pairing_degraded: shim_unavailable` on the verification dispatch because `codex-verification` did not exist. Every cross-vendor Standard / Critical milestone in v0.7 had a Claude-side verifier checking Claude-side implementation — same-distribution blind spots on the most important gate. v0.8's `codex-verification` closes that. Pairs naturally: Codex authors tests → Claude implements → Codex verifies + reviews + security-reviews. End-to-end different-distribution coverage on Critical work.

2. **The architect-pairing direction asymmetry.** v0.7 supported one direction (Claude-Lead + Codex-Challenger). Some milestones — particularly those where Codex's training distribution is a better fit for the problem domain — benefit from the inverse direction. `codex-lead-architect` makes the alternation rule symmetric; the Co-Approval Rule still applies regardless of which vendor is on which side.

Both shims enforce mandatory rules at the shim level so they fail loudly when violated: `codex-verification` cannot return PASS with a RED test suite; `codex-lead-architect` cannot return a proposal without named alternatives or approve while disputes remain. Same discipline pattern as the existing Tier-1 shims; same `BLOCKED` + typed `blocker_type` failure shape so circuit breakers handle them uniformly.

Deferred to v0.9: Tier-3 shims (`codex-qa`, `codex-researcher`) pending live-test signal on whether they're worth shimming, plus the `codex-developer` allowlist pre-screening asymmetry noted in the Safety cut below. (B2, B3, D1, F1 originally listed here all landed in v0.8.)

Still un-done: **live-testing** at least one cross-vendor Standard milestone (v0.7 deferred item) and one Critical milestone with full pairing (v0.8 deferred item). The dispatch log is empty across both versions; the tier defaults are theory; the alternation degrade-fallback hasn't been exercised under load. Treat v0.8.0-dev as code-complete but unvalidated until that happens.

---

### Added (observability cut)

- **`probes/budget.toml`** — regression budget configuration for the probe suite. Sets `max_flips` (default `3`), `count_skips` / `count_errors` (default `false`), and the baseline file path (default `probes/baseline.jsonl`). Tunable per the eval-discipline argument: a non-zero budget absorbs LLM-as-judge variance, but a budget that never trips is too generous.
- **Regression-budget logic in `bin/code4me-probe-run`** — after the main probe loop, the runner reads the configured baseline JSONL, computes per-probe outcome flips (current outcome vs. baseline outcome, matched by `probe` field), prints a flip summary with diff detail (`baseline → current` per flipped probe; `+ (new)` for probes not in baseline), and exits non-zero if flips exceed the budget. New CLI flags: `--max-flips=N` (overrides budget.toml), `--baseline=PATH`, `--update-baseline` (promote current results to baseline; skipped if any probe errored), `--no-budget` (skip the flip check entirely), `--judge-model=MODEL`. Existing usage without budget.toml continues to work — the runner falls back to a built-in `max_flips=3` default.
- **Dispatch-log analytics extensions in `bin/code4me-audit-dispatch-log`:**
  - **Tier distribution** — distribution_table row for `.model_tier` alongside subagent / weight / vendor / outcome.
  - **Vendor × tier rollup** — new section cross-tabbing `(vendor, tier)` pairs with counts and percentages; intended to pair with billing data for cost rollups.
  - **Weight × outcome heatmap** — awk-built table cross-tabbing weight against outcome; surfaces FAIL/REWORK clusters at specific weights that indicate gate tuning or intake-classification issues.
  - **Tier deviation pattern detection** — for every `(subagent, weight)` combo whose `tier_deviated_from_default: true` rate exceeds 50% across dispatches, surfaces the combo with default→actual tier pair and a recommendation to update `model-selection.yaml` rather than deviating on every dispatch.
  - **Cross-vendor pairing summary** — when `vendor_pairing` is present, surfaces pairing degradation count + reasons, plus pair-role distribution. Highlights persistent `shim_unavailable` patterns.
  - Legacy `deviated_from_default` (pre-v0.7) is still reported under a "Legacy model deviation" subsection for backward compatibility with old dispatch logs.
- **`context_provenance` field** in the dispatch-log JSONL line per `references/context-queries-schema.md` §Resolution provenance (new section). Each resolved query records its `query_kind`, `query_descriptor`, `resolved_artifact` path, `resolved_sha` (content blob SHA when the artifact is in git; null for plugin-shipped content versioned through `plugin.json`), optional `size_bytes` / `truncated` flags, and `skipped` / `skip_reason` for queries that evaluated but resolved to no content (e.g., OpenWolf not configured). Enables three diagnostic uses: post-mortem on a wrong dispatch ("was the Context Pack stale?"), Context Pack assembly audits ("did every Critical dispatch include security-conventions cerebrum?"), and token-budget tuning via persistent truncation surfacing.

### Changed (observability cut)

- **`skills/code4me/SKILL.md` "Artifact persistence"** — the dispatch-log JSONL shape is now spelled out as a fenced block including all the v0.7 fields (`model_tier`, `default_tier`, `tier_deviated_from_default`, `vendor_pairing`) and the new v0.8 `context_provenance` field. Includes a one-line field-provenance note for each version's additions.
- **`references/playbook.md` "Dispatch protocol detail"** — gains an explicit step (now step 4 of the resolution sequence) for recording provenance; the universal-items step renumbered to step 5; the skipped-queries step renumbered to step 6 and updated to note that skips appear in `context_provenance` with `skipped: true` as well as in the transparency announcement.

### Why (observability cut)

The Foundation and Tier-2 cuts produced a framework that makes a lot of choices on every dispatch — vendor, tier, pairing direction, which artifacts to load, when to degrade. Without observability, those choices are invisible until something goes wrong and you're reading transcripts. The Observability cut closes that gap:

- **B2 makes probe runs catch regressions automatically.** Paste-and-eye-compare worked for one author; a CI-integratable runner with a budget threshold scales to "did my v0.7→v0.8 bump move anything?" without manual inspection. The Husain-style discipline: a budget that's never tripped is too generous; a budget that trips every run is too tight; one that trips on real changes is the sweet spot.
- **B3 turns the dispatch log into a tunable signal.** The new tier-deviation detector surfaces "this combo always deviates" automatically — exactly the case where `model-selection.yaml` defaults need updating instead of deviating per dispatch. The weight × outcome heatmap turns "Critical FAIL rates" from anecdote into data. The pairing-degradation summary flags persistent `shim_unavailable` so you don't run for months on cross-vendor pairing that's silently degrading every milestone.
- **D1 makes Context Pack assembly auditable.** "Why did the developer not see the latest amendment?" is now a one-line jq query against the dispatch log, not a transcript dig.

All three items pay off on the *next* dispatch — they instrument decisions that v0.7/v0.8 already make. They're zero-runtime-cost for the orchestrator (the audit and probe tooling reads the log; the orchestrator just writes one more JSON field per dispatch).

---

### Added (safety cut)

- **`hooks/check-critical-write-allowlist.sh`** — third PreToolUse hook, parallel to the v0.6 `check-test-protection.sh` and `check-forbidden-conditions.sh`. Reads `.code4me/critical-allowlist.txt` (one path or glob per line; `#` comments; blank lines ignored) and ask-gates any `Edit`, `Write`, or `MultiEdit` whose target does NOT match any allowlist entry. Inverted logic vs. test-protection: test-protection is a deny-list (gate on match); critical-allowlist is an allow-list (gate on no-match). Reuses the same glob-to-regex polyfill so `**`, `*`, `?` all work uniformly across bash 3.2 and 4+. Defensive behaviour identical to the sister hooks: missing file → silent pass-through; non-Edit/Write tools (Read, Grep, etc.) → silent pass-through; never returns `deny`, only `ask`. Tested across five behaviours: in-scope pass-through, out-of-scope ask-gate with full reason text including the gated path and non-matching patterns, no-allowlist pass-through, non-write-tool pass-through, glob matching via `**`.
- **Orchestrator state-file convention:** at Critical-mode dispatch, the orchestrator writes `.code4me/critical-allowlist.txt` containing the in-scope paths derived from the Tech Spec's modules-in-scope and the Test Spec's test paths. Delete at task close so it does not leak across dispatches. Documented in `SKILL.md` "Hook state files" as the third entry alongside `forbidden-conditions.json` and `protected-tests.txt`.
- **New developer outcome `OUT_OF_SCOPE_TARGET`** in `agents/developer.md` and `agents/codex-developer.md`. When the critical-write-allowlist hook ask-gates an Edit/Write, the developer recognises the gate as authoritative and returns the structured outcome:

  ```yaml
  outcome: OUT_OF_SCOPE_TARGET
  out_of_scope_target:
    path: <gated path>
    allowlist_patterns_not_matched: [<pattern>, ...]
  ```

  The orchestrator surfaces this to the user as a scope-expansion request with two explicit options: re-scope the milestone (route to Lead Architect for a Tech Spec amendment that includes the new path; update the allowlist on disk; increment the Scope Change Limit counter) or reject the edit (route back to the developer to find an in-scope solution).
- **`probes/hooks/03-critical-write-allowlist-hook-fires.md`** — probe verifying the hook fires on an out-of-scope Edit during a Critical milestone, the developer maps the gate to `OUT_OF_SCOPE_TARGET`, and the orchestrator surfaces the re-scope-vs-reject choice to the user without auto-routing.

### Changed (safety cut)

- **`README.md` "Hook protections"** — the install snippet adds the third hook entry; the "When NOT to use them" section gains a fourth bullet noting that the hook is a no-op without `.code4me/critical-allowlist.txt`; the "Verifying" section references the third probe.
- **`templates/project-starter/claude-settings.json.example`** — the third hook entry is included in the pre-wired hooks list so `/code4me-init` scaffolds the full v0.8 hook set.
- **`agents/developer.md` and `agents/codex-developer.md`** — `outcome` enums gain `OUT_OF_SCOPE_TARGET`; the detail-field list gains `out_of_scope_target` with the `{path, allowlist_patterns_not_matched}` shape; the hook-handling guidance enumerates all three hooks and their respective outcome mappings (TEST_QUESTION / FORBIDDEN_CONDITION_ENCOUNTERED / OUT_OF_SCOPE_TARGET).
- **`skills/code4me/SKILL.md` "Hook state files"** restructured into a bulleted list of three entries (Conversation Mode forbidden-conditions, Standard/Critical protected-tests, Critical-mode write-allowlist) so the hierarchy of when-each-fires is explicit.

### Why (safety cut)

Critical Mode is the highest-stakes weight tier, but until v0.8 the only runtime protections on Critical work were the two v0.6 hooks (protected tests and Conversation-Mode forbidden conditions — neither of which actually fires during Critical). The blast radius was unbounded by anything stronger than the subagent's prompt-level discipline. F1 closes that with the inverted hook pattern (allow-list, not deny-list) and the new `OUT_OF_SCOPE_TARGET` outcome.

The design choice that matters: re-scope is a *user decision*, not an orchestrator decision. When the developer needs a file outside the declared scope, the orchestrator must surface the choice — re-scope (which updates the allowlist and counts toward the Scope Change Limit) or reject. Auto-routing to Lead Architect would mask the scope-mutation event from the Scope Change Limit circuit breaker, defeating the purpose of having that breaker.

Known asymmetry: the hook protects the Claude-side developer's tool calls (Edit/Write go through Claude Code's hook system). The `codex-developer` shim runs Codex in a subprocess; Codex's edits don't pass through Claude Code's hooks. v0.9 plan: the codex-developer shim's implement-mode validation will pre-screen `files_touched` against `.code4me/critical-allowlist.txt` after parsing Codex's response and BLOCK with `blocker_type: out_of_scope_target` for any mismatch, closing the asymmetry. Not done in v0.8 because the cleanest implementation requires touching the shim's prompt as well as its validation step, and the v0.8 safety cut deliberately stays small to keep the scope focused on the hook itself.

This closes the v0.8 plan. All four originally-deferred items (B2, B3, D1, F1) shipped. Tier-3 shims and the codex-developer asymmetry are explicit v0.9 backlog items. **Still un-done: live-testing** — at least one Standard milestone with cross-vendor enabled (v0.7's deferred item) and one Critical milestone with the allowlist hook installed and full pairing (v0.8's deferred item). The dispatch log is empty across all three versions; everything in v0.6→v0.8 is theory until those two runs happen.

---

## [0.7.0-dev] — in progress

Two cuts so far:

1. **Foundation** — vendor-aware model tiers, a cross-vendor pairing policy, and three Tier-1 Codex shims so the dialectic the framework already runs at the architect tier extends to every producer/verifier boundary that benefits from it.
2. **Ergonomics** — slash commands, starter templates, programmatic probe runner, OpenWolf intro, removed the v0.5 fallback path.

### Added

- **Vendor-aware model tiers.** Two new YAML files codify model selection in a vendor-agnostic way:
  - `references/vendor-models.yaml` — vendor → tier (`low` / `mid` / `high`) → concrete model identifier (Haiku/Sonnet/Opus on Anthropic; GPT-5.4-mini/GPT-5.4/GPT-5.5 on OpenAI Codex). The single edit-point when a vendor ships a new model in a tier.
  - `references/model-selection.yaml` — machine-readable per-(subagent, weight) tier defaults extracted from the existing prose in `model-selection.md`, plus hard floors and deviation rules. The orchestrator resolves a tier from this file at dispatch time and looks up the concrete model from `vendor-models.yaml`.
- **`references/cross-vendor-policy.md`** — the alternation rule, pair definitions (architect Co-Approval is one pair; new pairs cover spec-to-test ↔ developer, developer ↔ code-reviewer / verification / security-reviewer), the resolution algorithm (gate → anchor vendor → opposite vendor for each pair → conflict resolution → shim availability check → tier resolution), failure-mode handling (`shim_unavailable`, `user_override`, conflict resolution), and updated transparency announcement format `(vendor:tier)`.
- **Three Tier-1 Codex shims** at `agents/codex-code-reviewer.md`, `agents/codex-spec-to-test.md`, `agents/codex-security-reviewer.md`. Each follows the existing shim pattern (mode dispatch, `/tmp/codex-*-{task_id}.txt` prompt files, JSON-validated returns, typed `blocker_type` on failure):
  - `codex-code-reviewer` — three modes: `review-diff` (default), `review-files`, `review-spec-fit`. Read-only; severity-tagged findings (BLOCKER/MAJOR/MINOR/NIT); outcomes ACCEPT / ACCEPT WITH CHANGES / REWORK REQUIRED. Pairs with developer / codex-developer.
  - `codex-spec-to-test` — two modes: `generate` (default — produces Test Spec + protected tests + protected-tests manifest), `review-test-spec`. Enforces Gate Scope Rule (1 happy-path per AC, failure tests only when AC names the behaviour) and Given/When/Then naming. Pairs with developer / codex-developer.
  - `codex-security-reviewer` — two modes: `diff-focused` (default), `comprehensive`. OWASP Top 10 + STRIDE + secrets archaeology + supply chain. Critical-fail gate. Pairs with developer / codex-developer on Critical / auto-escalated work.
- **`cross_vendor_pair_with:` agent frontmatter** on nine agents (`lead-architect`, `challenger-architect`, `spec-to-test`, `developer`, `code-reviewer`, `verification`, `security-reviewer`, plus the existing `codex-architect` and `codex-developer`). Declares which roles each agent should be on the opposite vendor from when cross-vendor pairing is active; the orchestrator uses this for team composition at dispatch time. Includes `applies-when:` conditions for weight-gated pairings (e.g., `security-reviewer ↔ developer` only on Critical / auto-escalated work).
- **Three new probes under `probes/cross-vendor/`** exercise the pairing logic:
  - `01-pairing-fires-on-standard.md` — Standard milestone with cross-vendor enabled; alternation applies; `codex-verification` absence triggers graceful degrade.
  - `02-pairing-disabled-keeps-single-vendor.md` — same Standard work without cross-vendor opt-in; everything stays on Claude.
  - `03-pairing-degrades-when-shim-missing.md` — cross-vendor enabled but Codex CLI unavailable; pairings degrade with typed reason; milestone proceeds; INSIGHT recommends setup.

### Changed

- **Dispatch contract additions** in `SKILL.md` and `references/playbook.md` — every Task call now carries explicit `vendor` (`anthropic` | `openai`), `model_tier` (`low` | `mid` | `high`), and the resolved concrete `model` identifier. When cross-vendor pairing is active, dispatches additionally carry a `vendor_pairing` block (`policy`, `pair_role`, `alternates_with`, `degraded`). The dispatch log JSONL gains `model_tier`, `tier_deviated_from_default`, `default_tier`, and `vendor_pairing` fields.
- **Transparency announcement format** updated to `(vendor:tier)` — e.g., `developer (claude:mid)` and `codex-code-reviewer (codex:mid)`. Concrete model identifiers live in the dispatch log; the announcement stays compact and decision-relevant. Old `(anthropic:opus)` format is no longer used. Examples in `playbook.md` cover both single-vendor and cross-vendor-enabled milestones.
- **`references/model-selection.md` restructured** to use tier vocabulary throughout. The prose remains the human-facing explanation; `model-selection.yaml` is the authoritative machine-readable form. New section on the vendor dimension distinguishes individual-shim use from the per-milestone cross-vendor pairing opt-in. Per-shim guidance covers all five shims (the existing two plus the three Tier-1 additions).
- **`SKILL.md` "Available subagents"** lists the three new Tier-1 shims with their modes and pairing notes. "Available reference files" lists the two new YAML files and `cross-vendor-policy.md`.
- **`.claude-plugin/plugin.json`** version bumped to `0.7.0-dev`; description updated to mention the tier system and cross-vendor pairing; `cross-vendor` added to the keywords list.

### Why

The cross-vendor dialectic at the architect tier (existing `codex-architect` Co-Approval Rule) was empirically the strongest pressure-testing signal in v0.6. Two structural gaps were limiting it: (1) the orchestrator could only pick Claude models per dispatch — Codex shims had a single user-configured default that the shim passed via `--model`; (2) the cross-vendor pattern stopped at the architect pair, leaving the rest of the producer/verifier boundaries vulnerable to same-distribution blind spots.

v0.7 closes both gaps with one coherent layer. The tier abstraction (`low` / `mid` / `high`) makes model selection vendor-agnostic: the orchestrator picks a tier per (subagent, weight) the same way for both vendors and resolves to a concrete model through `vendor-models.yaml`. The cross-vendor pairing policy generalises Co-Approval into an alternation rule applied across the canonical producer/verifier pairs.

The three Tier-1 shims (`codex-code-reviewer`, `codex-spec-to-test`, `codex-security-reviewer`) cover the boundaries where the dialectic pays off most — same-vendor spec-to-test plus developer can match test-shape biases unconsciously; same-distribution reviewers share blind spots; OWASP category recall varies measurably by training distribution. Tier-2 shims (`codex-verification`, `codex-lead-architect`) are planned for v0.8; Tier-3 (`codex-qa`, `codex-researcher`) is deferred pending live-test signal.

Foundation phase posture: ergonomics (slash commands, starter templates, programmatic probe runner) and the v0.5 fallback-path removal land in subsequent cuts so the architectural backbone can be live-tested first. Cross-vendor pairing is **opt-in per milestone** — the cost surface is real and per-milestone control beats project-wide on/off for a discipline this new.

---

### Added (ergonomics cut)

- **Seven slash commands** under `commands/`:
  - `/code4me-classify <task>` — runs intake + classification only; produces the team transparency announcement; never dispatches. Useful for sanity-checking how the orchestrator would frame a request.
  - `/code4me-dispatch <weight> [--cross-vendor] <task>` — explicit weight declaration, skipping intake clarification. Auto-escalation override still applies; the `--cross-vendor` flag enables the alternation policy for this milestone.
  - `/code4me-status [milestone_id]` — read-only snapshot of `.code4me/`: active milestones, in-flight tasks, recent dispatch-log entries, pending INSIGHTs, approaching Conversation-Mode deadlines.
  - `/code4me-init` — scaffolds a new project. Dry-run preview first; never overwrites existing files. Copies `CLAUDE.md.example`, `.mcp-recommended.json`, `claude-settings.json.example`, and the `.code4me/` runtime skeleton. Substitutes `<PLUGIN_DIR>` in the settings example.
  - `/code4me-probe-run [subdir|path]` — wraps `bin/code4me-probe-run`. Interactive: prints input prompts, captures pasted responses, runs LLM-as-judge.
  - `/code4me-audit [path]` — wraps `bin/code4me-audit-dispatch-log`.
  - `/code4me-promote-or-revert <task_id>` — closes the Conversation Mode loop. Always interactive: surfaces the Conversation Note + smoke test + deadline, asks for promote / revert / extend / abandon, then executes.
- **`bin/code4me-probe-run`** — interactive programmatic probe runner. Bash + jq + curl. For each probe under `probes/`, parses the `## Input prompt` and `## Expected` sections; prints the input for the user to paste into a fresh Claude Code session; captures the orchestrator's response on stdin (terminated by `EOF`); runs an LLM-as-judge call against the Expected block on three axes (kind, weight, team); writes `probes/results-{YYYY-MM-DDTHHMMSS}.jsonl` with one verdict per probe. Requires `ANTHROPIC_API_KEY`. Exit code non-zero if any probe fails or errors — wires into CI cleanly.
- **Project-starter templates** under `templates/project-starter/`:
  - `CLAUDE.md.example` — annotated starter for the project's CLAUDE.md, with placeholders for stack / run-build-test / layout / conventions / boundaries / gotchas / MCPs / multi-language layout / cross-vendor preference.
  - `.mcp-recommended.json` — opinionated starter MCP configuration: `sequential-thinking`, `github`, `playwright` enabled; `filesystem`, `sentry`, `postgres` documented but disabled-by-default with `_` prefixes. Includes a `_subagent_preferences` block documenting which subagent should prefer which MCP.
  - `claude-settings.json.example` — example `.claude/settings.json` with `ENABLE_LSP_TOOL=1` and both PreToolUse hooks pre-wired with a `<PLUGIN_DIR>` placeholder.
  - `README.md` — how to use the starter, manual flow, what's NOT in the templates.
- **OpenWolf intro at the top of the main README.** A two-sentence note explaining that OpenWolf is an external persistent-knowledge layer the plugin integrates with when present and works fully without. Outside readers can now follow the `.wolf/*` references throughout the docs without confusion.

### Changed (ergonomics cut)

- **`references/playbook.md`** — the v0.5 imperative-list fallback path has been removed. Every shipped agent declares `context_queries:` in v0.7; an agent without that frontmatter is a bug. The orchestrator now surfaces a missing-frontmatter agent as `BLOCKED` with `blocker_type: agent_definition_invalid` rather than silently falling back.
- **`SKILL.md`** — gains a "Slash commands" section listing all seven commands and their argument shapes.
- **`README.md` "Folder layout"** — updated to include `commands/`, the new `bin/code4me-probe-run`, the three new reference YAML files, the three Tier-1 shim agents (`codex-code-reviewer`, `codex-spec-to-test`, `codex-security-reviewer`), the `templates/project-starter/` directory, and the new `probes/cross-vendor/` directory. The OpenWolf intro is at the very top of the README.

### Why (ergonomics cut)

The Foundation cut shipped a powerful but opaque architectural layer — the orchestrator silently picks vendor + tier + pairing decisions on every dispatch. Without ergonomics, the user has no handle on those decisions short of reading the dispatch log after the fact.

Slash commands give explicit handles: `/code4me-classify` previews a classification without committing; `/code4me-dispatch --cross-vendor` is the explicit cross-vendor opt-in; `/code4me-status` snapshots the runtime state without dispatch; `/code4me-init` removes the "where do I copy what" question on new projects.

The programmatic probe runner closes Hamel Husain's eval loop: the probes were already an executable spec, but paste-and-eye-compare doesn't scale to "did v0.7-dev move anything?" The LLM-as-judge call evaluates each probe on three axes against a recorded Expected block; the JSONL output feeds future regression-budget tooling (planned for v0.8) cleanly.

Dropping the v0.5 fallback path is small but important: it removes a code path the orchestrator should never take in v0.7. Surfacing a missing-frontmatter agent as `BLOCKED` makes a real bug visible rather than papering over it.

The OpenWolf intro is one paragraph but unblocks any future reader who isn't the author — they were three sections in before they could parse what `.wolf/cerebrum.md` actually is.

Still deferred: live-testing against a real Standard milestone with cross-vendor enabled. That's the single most important remaining v0.7 roadmap item; it will direct what v0.8 should prioritise.

## [0.6.1] — 2026-05-15

### Added

- **Python language reference** at `skills/code4me/references/languages/python.md`. Generic-opinionated Python guidance covering the Pythonic mindset, the modern toolchain baseline (`ruff format`/`ruff check`/`pyright`/`pytest`/`uv` or `poetry`), PEP 8 naming with the standard Pythonic exceptions, type-hint discipline (where they earn their keep), data-shape preferences (frozen dataclasses → Pydantic → dicts), EAFP error handling, the three concurrency patterns (asyncio / ThreadPoolExecutor / ProcessPoolExecutor) with GIL caveats, common traps (mutable defaults, late-binding closures, `is` vs `==`, falsy edge cases, import cycles, generator exhaustion), pytest patterns, `src/` project layout, and dependency-pinning conventions. As with the other language references, project `CLAUDE.md` authoritatively overrides.
- **Pyright LSP entry** in `.lsp.json` for `.py` and `.pyi`. Uses the `pyright-langserver --stdio` invocation. Pyright is the recommended default — fastest type-inference, Microsoft-maintained, MIT-licensed. README "LSP support" gains a "Python (Pyright)" subsection with install routes (`npm install -g pyright`, `pip install pyright`, `brew install pyright`) and a note on enabling strict mode via `pyrightconfig.json` or `[tool.pyright]`.

### Changed

- `SKILL.md` language-guidance injection table gains `.py` / `.pyi` → `references/languages/python.md`. Code-touching subagents dispatched against Python files now receive the Python reference in their Context Pack.
- README "Current scope" gains an explicit "Language references for ..." line so the four shipped language references are listed alongside the four LSP configurations. "Folder layout" gets `python.md` under `references/languages/`.

### Why

The other three language references (`csharp.md`, `swift.md`, `cpp.md`) reflect specific project conventions (Unity, Apple-platform Swift, strict C++20). Python had a gap: any future Python work would have fallen back to the project's `CLAUDE.md` alone, with no plugin-shipped baseline. This patch closes the gap with a generic-opinionated reference that the user can later adjust to their actual Python flavour (Django, FastAPI, data science, CLI) — or leave generic if Python use stays incidental.

Pyright over `python-lsp-server`: faster type inference, better support for modern typing constructs (PEP 695 generics, `Protocol`, structural typing), single-binary install, fewer plugin moving parts. `python-lsp-server` is still viable if your project already uses it; switch the `command` field in `.lsp.json` accordingly.

## [0.6.0] — 2026-05-15

### Added

- **`context_queries:` declarative schema** for per-agent Context Pack assembly. New reference file at `skills/code4me/references/context-queries-schema.md` defines six query kinds (`artifact`, `openwolf`, `protected-list`, `forbidden-conditions`, `project-info`, `dispatch-reminder`) with optional `when:` conditions for mode-aware (Codex shim) and weight-aware queries. All 14 agent files now declare a `context_queries:` block in their YAML frontmatter — each agent's block enumerates what *it* needs in the Context Pack, instead of the orchestrator following one imperative list for every dispatch.
- **`bin/code4me-audit-dispatch-log`** — bash script that reads `.code4me/dispatch-log.jsonl` (the v0.5 append-only dispatch log) and emits a markdown summary: dispatches per subagent, weight distribution, vendor split (Anthropic vs OpenAI), outcome distribution, model deviation patterns, and auto-escalation triggers. Requires `jq`. Run as `bin/code4me-audit-dispatch-log` from the project root.
- **Probe fixture skeleton** at `probes/fixture-skeleton/` — minimal mock project with placeholder source files for `Homepage.tsx`, `ScoreFormatter.cs`, `Leaderboard.cs`, `auth/PasswordReset.cs`, `schema/users.sql`, plus a CLAUDE.md and tests/ marker. The action-on-existing-code probes (01, 03, 05, 07) gained a `## Fixture` section between Input prompt and Expected, pointing at the specific skeleton files they require. Without the skeleton, the orchestrator correctly refuses to act ("no homepage in this directory") — but that short-circuits the classification + dispatch we're trying to measure. Copy the skeleton into your probe fixture folder before running these probes.

### Changed

- **`references/playbook.md` dispatch-protocol section rewritten** to describe the resolution flow: (1) read the dispatched agent's `context_queries:`, (2) evaluate `when:` clauses against weight/mode, (3) resolve each query, (4) assemble Context Pack, (5) append universal items (task ID, model, completion expectations, transparency announcement), (6) note skipped queries in the transparency announcement. The v0.5 imperative list is kept as a documented fallback path for agents that don't yet declare `context_queries:`.
- **`SKILL.md` "Available reference files"** gains `references/context-queries-schema.md`.

### Why

Three motivations driving 0.6.0:

1. **Context Pack assembly was imperatively coded into prose, not declaratively wired.** `references/playbook.md` said "every dispatch must include X, Y, Z" — same shape for every subagent, even when only some agents need a Tech Spec and others only need a Conversation Note. The orchestrator had no per-agent customisation surface short of editing the playbook. Declarative `context_queries` in agent frontmatter make each agent's needs explicit and self-documenting; adding a new subagent no longer requires touching the playbook.
2. **Mode-aware Context Packs were doubly coded.** Codex shim agents (`codex-architect`, `codex-developer`) document mode-specific inputs in their bodies, and the orchestrator had to consult the body to know what to include per mode. The `when:` clause on `context_queries` makes the mode-dependency machine-readable.
3. **The dispatch log needed a consumer.** v0.5 added `.code4me/dispatch-log.jsonl` as an audit trail but shipped without a tool to read it. The audit script closes that loop — patterns of model deviation, auto-escalation frequency, and cross-vendor cost rollups are now visible without writing one-off jq incantations.

The `context_queries` resolution is **orchestrator-side** in v0.6 — the Producer reasons about each query rather than executing a deterministic resolver. v0.7 may add small resolver scripts in `bin/` so the same `context_queries` produce the same Context Pack regardless of orchestrator instance. Inspired by [gstack](https://github.com/garrytan/gstack)'s `gbrain.context_queries` pattern, which uses shell-based deterministic resolvers; the v0.6 release commits to the *schema*, not yet the resolver.

### Notes

The v0.5 imperative Context Pack list survives as a fallback in `playbook.md`. Custom agents added by users outside the plugin distribution work without declaring `context_queries:`. The fallback is expected to be deprecated by v0.7 once all shipped agents have been exercised against real milestones at the new schema.

The fixture skeleton + per-probe `## Fixture` blocks resolve a real probe-design gap surfaced during 0.5's first probe run: an empty fixture folder is *too* empty — the orchestrator's correct refusal to hallucinate a target short-circuits the dispatch decision the probe was measuring. With the skeleton, action-on-code probes have something to act on; classification-only probes (02, 04, 06, 08, 09–15) still work in an empty folder.

## [0.5.0] — 2026-05-15

### Added

- **PreToolUse hooks** at `hooks/check-test-protection.sh` and `hooks/check-forbidden-conditions.sh`. Both are opt-in (installed by the user into their `.claude/settings.json`) and both return `permissionDecision: ask` (never `deny`) — a misconfigured hook degrades to a warning, never a hard block. Defensive throughout: missing data files, malformed JSON, or unavailable `jq` all pass through silently.
  - **`check-test-protection.sh`** reads `.code4me/protected-tests.txt` (written by Spec-to-Test) and ask-gates any `Edit`/`Write`/`MultiEdit` whose target matches a listed path or glob. Designed as defence-in-depth for the Test Protection Rule that previously lived only in the Developer prompt.
  - **`check-forbidden-conditions.sh`** reads `.code4me/forbidden-conditions.json` (written by the orchestrator at Conversation Mode dispatch, deleted at task close) and ask-gates any `Write` of a new file matching a forbidden glob (migrations, schemas, feature flags, secrets, env files, etc.). Existing-file Edits are not gated — the trigger is new-artifact creation.
- **README "Hook protections" section** documenting the two hooks, the install snippet for `.claude/settings.json`, the when-NOT-to-use cases, and pointers to the two verification probes.
- **`references/conversation-mode.md` "Glob patterns for the forbidden-conditions hook" section** — canonical mapping from the abstract forbidden-conditions list (new schema, data migration, feature flag, sensitive-data handling, etc.) to file-pattern globs that go into `.code4me/forbidden-conditions.json`. Project-specific tuning expected; the user can edit the JSON file directly.
- **`SKILL.md` operating-loop "Hook state files" paragraph** — orchestrator writes `.code4me/forbidden-conditions.json` at Conversation Mode dispatch, deletes it at task close. The Spec-to-Test subagent writes `.code4me/protected-tests.txt` during canonical workflows.
- **`agents/spec-to-test.md` "Protected-tests manifest" section** — Spec-to-Test now also writes the protected-test manifest at `.code4me/protected-tests.txt`. Overwrite-each-dispatch, not accumulate. The manifest is what *activates* runtime enforcement; failing to write it does not break the workflow.
- **Hook-awareness paragraphs** added to `agents/developer.md` and `agents/codex-developer.md` tooling-preferences sections. Developer maps gated outcomes to `TEST_QUESTION` or `FORBIDDEN_CONDITION_ENCOUNTERED` rather than approving past the gate; Codex Developer maps Codex-session gate signals to `BLOCKED` with `blocker_type: hook_gated`.
- **Two new probes** at `probes/hooks/01-test-protection-hook-fires.md` and `probes/hooks/02-forbidden-conditions-hook-fires-conversation-mode.md`. The first verifies a protected-test Edit ask-gates and routes to `TEST_QUESTION` (not silent modification); the second verifies a forbidden-glob Write ask-gates, the developer returns `FORBIDDEN_CONDITION_ENCOUNTERED`, the orchestrator escalates the weight to Standard, and `security-reviewer` is added to the team per the v0.4 hard-floor wiring.

### Changed

- README "Current scope" bumped to 0.5.0 with the hooks entry and the hook-firing probes mentioned in the probe-suite bullet.
- README "Folder layout" gains `hooks/` at the plugin root and `probes/hooks/` inside the probes tree.
- `.code4me/` working directory documented in SKILL.md now includes `forbidden-conditions.json` (orchestrator-managed, ephemeral) alongside the existing `protected-tests.txt` (Spec-to-Test-managed, persistent for the milestone).

### Why

Two motivations driving 0.5.0:

1. **Test Protection and Conversation-Mode forbidden conditions were prompt-only enforcement.** Both rules live as text in agent prompts — the Developer is *told* not to modify protected tests, *told* to return `FORBIDDEN_CONDITION_ENCOUNTERED` if a Conversation-Mode change introduces a forbidden artifact. That works when prompts work, but the cost of being wrong is real: a protected test silently weakened, or a migration file written in a Conversation Mode dispatch that should have been Standard. Hooks move both protections to the tool boundary — runtime mechanism, not just prompt language. Inspired by [gstack](https://github.com/garrytan/gstack)'s `/careful`, `/freeze`, and `/guard` skills, which encode their behaviour almost entirely as PreToolUse hooks.
2. **Defence-in-depth across the vendor surface.** A Claude-side Developer might respect the prompt; a Codex-side shim's protocol bridge might not catch every malformed Codex response. The hook fires regardless of which subagent attempted the Edit/Write, so the protection is uniform across vendors. The Codex Developer shim now maps a hook-gated tool call to `blocker_type: hook_gated`, surfacing the gate to the orchestrator's circuit breakers cleanly.

The hooks are opt-in by design. The plugin doesn't auto-install them into `.claude/settings.json` — installation is a deliberate user action documented in the README. Reasoning: shared-repo teams may have multiple hook configurations to coordinate, and forcing an install would conflict with project-specific hooks already in place. Two `claude/settings.json` blocks merging cleanly is a documentation concern, not a plugin concern.

### Notes

The hooks default to `ask` rather than `deny` deliberately. A malformed pattern in `protected-tests.txt` or a typo in `forbidden-conditions.json` produces a noisy session, not a blocked one — the user can fix the data file and continue. Future versions may add a `--strict` mode that elevates `ask` to `deny`, but only after the ask-mode has soaked through enough real milestones to demonstrate the rules are calibrated.

`v0.6` is parked. The next planned phase is declarative `context_queries` in agent frontmatter (the gstack `gbrain.context_queries` pattern, adapted to code4me's dispatch model). That refactor will touch every agent file's frontmatter and should wait until v0.5's hook wiring has been exercised against a real Standard milestone.

## [0.4.0] — 2026-05-15

### Added

- **`ETHOS.md`** at `skills/code4me/ETHOS.md` — shared operating principles inherited by the orchestrator and every subagent. Covers pacing, simplicity, role boundaries, context (OpenWolf cerebrum first), fidelity to protocol, project guidance precedence, user authority, and INSIGHT emission. Roughly 40 lines; replaces ~150 lines of duplicated prose across SKILL.md and the 14 agent files.
- **`security-reviewer` subagent** (`agents/security-reviewer.md`) — OWASP Top 10 + STRIDE security pass with two modes (`diff-focused` and `comprehensive`). Findings are severity-tagged (Critical | High | Medium | Low | Informational); Critical fails the gate. Fires *automatically* whenever auto-escalation cites authentication / sensitive-data / new-external-dependency / data-migration / cross-user-leakage / authorization-boundary / concurrency-regression / session-isolation symptom classes. Fills the gap the auto-escalation created: previously, escalation routed the weight up but no agent ran the actual audit.
- **Multi-mode Codex shims.** `codex-architect` now supports `challenge` (default; Mandatory Critique + Named Alternative for Co-Approval Rule), `consult` (direct architecture question, prose answer + named tradeoffs, no approval gate), and `review-spec` (Tech Spec soundness check, returns approved + amendments without proposing alternatives). `codex-developer` now supports `implement` (default; current behaviour with Test Protection + Conversation-Mode forbidden conditions), `review-diff` (read-only review, `files_touched` must be empty), and `spike` (throwaway prototype with explicit timebox, ≥ 2 options required, output marked `PROTOTYPE_NOT_FOR_MERGE`, not routed through V/R/QA gates). Each mode has its own prompt template, return schema, and validation rules.
- **Dispatch log** (`.code4me/dispatch-log.jsonl`) — orchestrator appends one JSONL line per Task-tool dispatch: timestamp, milestone, task, weight, subagent, vendor, model, mode, outcome, deviation flag, escalation trigger. Local audit trail for model-deviation patterns and cross-vendor cost rollups. Not part of the plugin distribution.
- **External-agents probes** (`probes/external-agents/03-codex-architect-consult-mode.md`, `04-codex-developer-spike-mode.md`, `05-codex-mode-defaulting.md`) exercise the new mode-dispatch paths and the defaulting behaviour when `mode` is unset.

### Changed

- **De-duplicated `## Prime directive` across all 14 agent files plus SKILL.md.** Each file's prime directive section now starts with a pointer to `ETHOS.md` for shared operating principles, followed by the role-specific essence (one sentence). Earlier the section repeated ~3-5 lines of shared prose across every file. Net ~120 lines removed; role-specific essence preserved in every case.
- **`references/team-templates.md`** "What's currently built" updated from 13 entries to 14 (adding `security-reviewer`). New "Security pass on auto-escalation" subsection explains the hard-floor wiring.
- **`references/auto-escalation.md`** procedure step now explicitly invokes `security-reviewer (mode=diff-focused)` as part of the escalation response, with the gate failing on Critical findings. Treats the security pass as the agent that fills the space the escalation creates, not procedural-only.
- **`SKILL.md` "Available subagents"** updated with `security-reviewer` and the modes available on each Codex shim. Operating loop's "Artifact persistence" section gains the dispatch-log append rule.
- **Codex shim agent files** restructured around mode-dispatched sections: `## Available modes` table at the top, mode-specific prompt templates under `## Constructing the Codex prompt`, mode-dispatched validation under `## Parsing and validating the response`, mode-specific payload fields under `## Return contract`. Common envelope (task_id, sender_role, vendor, model, mode, outcome, raw_response_path) is uniform across modes.

### Why

Two motivations driving 0.4.0:

1. **Auto-escalation routed weight without filling responsibility.** The override correctly caught symptom-class triggers (auth, sensitive-data, new external dependency, data migration) and bumped the weight to Standard, but the Standard team has no dedicated security reviewer — Lead Architect, Code Reviewer, and QA cover quality and correctness, not OWASP/STRIDE-style audit. The escalation was procedurally complete but functionally hollow. `security-reviewer` fills that gap as a hard-floor invocation tied to the symptom classes.
2. **Codex shims were single-use for an expensive integration.** Same translation surface, same pre-flight, same error mapping — but locked to one mode each. Three modes per shim turns the same infrastructure into useful tools for adjacent jobs: `consult` for architecture questions, `review-spec` for Tech Spec checks, `review-diff` for read-only code review, `spike` for throwaway prototypes. The orchestrator's gate semantics are unchanged because the return shapes match the Claude-side equivalents.

The `ETHOS.md` consolidation is hygiene — continuing the de-duplication work 0.3.0 started with the tooling-preferences block. The shared principles existed across 14 files in subtly different wording; one canonical source ensures every role inherits the same operating context. Inspired by the [gstack](https://github.com/garrytan/gstack) plugin's `ETHOS.md` pattern, which is injected into every skill's preamble.

### Notes

The probe set grew by three. Run all probes after this release: the multi-mode dispatch paths and the auto-escalation→security-reviewer wiring are both new behaviour worth eyeballing in a fresh session.

The dispatch log is opt-in by virtue of being local: the orchestrator writes to `.code4me/dispatch-log.jsonl` if `.code4me/` exists. After a few milestones, audit it for patterns of model deviation that signal the defaults in `references/model-selection.md` need tuning.

## [0.3.0] — 2026-05-15

### Added

- **Producer Playbook** (`skills/code4me/references/playbook.md`) — decision-time elaboration extracted from `SKILL.md`. The orchestrator reads the playbook only when a decision point isn't pre-decided in the contract, rather than preloading it on every wake.
- **Codex shim subagents** (`agents/codex-architect.md`, `agents/codex-developer.md`) — external-vendor implementations of the Challenger Architect and Developer roles via the OpenAI Codex CLI. Opt-in only; setup documented in README "External agents (Codex)". Each shim is a protocol bridge: it validates the Context Pack, runs pre-flight checks (`command -v codex`, `$OPENAI_API_KEY`), constructs a self-contained Codex prompt with the role's protocol rules embedded (Mandatory Critique + Named Alternative for architect; Test Protection + Conversation-Mode forbidden conditions for developer), invokes `codex exec` via Bash with a timeout, parses and validates the response against the same return schema as the Claude-side equivalent, and returns `BLOCKED` with a typed `blocker_type` (e.g. `codex_cli_not_installed`, `codex_timeout`, `codex_response_invalid`, `test_protection_violation`) on any failure so the orchestrator's circuit breakers fire correctly across vendors.
- **Vendor dimension** in model selection (`references/model-selection.md`). The `model` parameter notation extends to `vendor:model` (e.g., `anthropic:opus`, `openai:gpt-5-codex`). Transparency announcements now include the vendor for each dispatch. The Milestone Status Tracker template grows a `vendor` column for cross-vendor cost rollups.
- **`templates/.code4me-skeleton/`** — first-run skeleton the orchestrator copies when `.code4me/` doesn't exist at the project root. Includes Milestone Status Tracker template (with `vendor` column), Insight Register template, and folder markers for `conversation-notes/`, `milestone-specs/`, `tech-specs/`. New SKILL.md operating-loop step references the scaffold.
- **`probes/` directory** — executable spec of expected orchestrator behaviour, with subdirectories for `classification/`, `team-composition/`, `auto-escalation/`, and `external-agents/`. Probes are markdown scenarios a human pastes into a fresh Claude Code session; the user eyeballs the orchestrator's announcement against an Expected block. Used for regression detection after changes to `SKILL.md`, references, or agent files. Eight initial probes cover Conversation cosmetic vs Critical payment-provider, Tech Debt vs architecture-introducing, Bug Fix reproduce-first, Spike vs Researcher disambiguation, and two auto-escalation cases (auth, data migration); two additional probes exercise Codex shim substitution and BLOCKED-mapping.
- **Standard Mode sequence diagram** in README — ASCII visual of the canonical workflow (Producer → Architects [Co-Approval] → Spec-to-Test → Developer → V/R/QA Quality Gate Loop → Doc Writer → Release).
- **Cross-vendor shims section** in `references/team-templates.md` describing when to substitute `codex-architect` for `challenger-architect` and `codex-developer` for `developer`, with Co-Approval Rule guidance and vendor:model announcement format.

### Changed

- **`SKILL.md` slimmed from 186 lines to ~110.** Operating loop, role boundaries, return-shape contract, hard floors, and one-line reference/subagent lists kept in the contract; full dispatch protocol, model deviation rules, team composition reasoning, transparency format, and OpenWolf detail moved to the new playbook. The orchestrator reads the playbook on demand rather than preloading it on every wake.
- **De-duplicated `## Tooling preferences` block across all 11 existing agent files.** Each agent's tooling section was ~10 lines of near-identical content; replaced with a tight two-paragraph form pointing at `references/tooling.md`. Role-specific notes preserved on 6 agents (`challenger-architect`: buglog.json for pressure-testing; `product-coach`: product-level scope; `qa`: runtime MCPs; `researcher`: external web search; `spec-to-test`: test-runner/fixture discovery MCPs; `verification`: CI/coverage MCPs). Net ~100 lines removed across agent files; drift risk eliminated.
- **`references/team-templates.md`** "What's currently built" updated from 11 entries to 13 (adding the two Codex shims). The "All eleven subagents are implemented" copy adjusted to match.

### Why

Two motivations driving 0.3.0:

1. The orchestrator's standing context was growing. `SKILL.md` enumerated ~12 references at decision time, and every agent file duplicated ~10 lines of tooling-preference prose. Both added up to context tax the orchestrator paid on every wake without consulting most of it. The split into contract + playbook, plus the agent-file de-duplication, shifts content from *always-preloaded* to *read-on-demand*. The `references/tooling.md` file became the canonical home for tool hierarchy guidance; agent files point there.

2. Same-vendor co-architecture was a weaker dialectic than the framework deserves. The Co-Approval Rule's whole point is *independent* pressure-testing, and two Claude-family architects share a distribution. Adding Codex as a substitute for the Challenger role (and optionally the Developer role for pattern-following work) gives the user a genuinely cross-vendor option without changing the orchestrator's gate semantics — the shim returns the same `approved` / `outcome` / `blocker_type` shape as the Claude-side equivalent.

The probe suite formalises the "live-test loop" mentioned in 0.2.5 as something repeatable across changes. Probes don't replace soak-testing; they catch the silent failure modes (missed escalation, wrong team composition, dropped hard floor) that long-soak tests would eventually notice but probes catch immediately.

### Notes

The Codex shims are designed to be soaked through several Standard milestones before they should be used on Critical work. The shim re-encodes Test Protection and Conversation-Mode forbidden conditions in the Codex prompt, but adds a translation surface that hasn't yet been exercised at depth.

Probes are run by hand, not by any CI infrastructure: paste the input prompt into a fresh Claude Code session with the plugin enabled, compare the orchestrator's announcement to the Expected block. The intended cadence is one run after every change to `SKILL.md`, `references/`, or `agents/*.md`. Baselines are recorded locally by the user; they are not part of the plugin distribution.

## [0.2.7] — 2026-05-07

### Changed

- **Reworked all three language references** (`csharp.md`, `swift.md`, `cpp.md`) to reflect the user's actual project conventions, drawing from their attached CLAUDE.md / Unity.md / C++.md / SwiftEngineer.md drafts. Workflow MANDATORY sections (scratchpad, TODO, commit-before-finish, etc.) dropped from the language references — those overlap with Code4Me's own machinery and don't belong in language guidance. Coding-principles refresher (SOLID, Clean Code, composition over inheritance) lifted to the top of each file because subagent context may not include the full project-level CLAUDE.md.
- **csharp.md** is now Unity-flavoured: `m_` prefix on private fields, no `var`, always braces, the Unity null trap (never `??`/`?.`/`is null` with `UnityEngine.Object`), POCO-first / MonoBehaviours as adapters, URP-first, ScriptableObjects for data, asset naming conventions, Edit Mode + Play Mode testing strategy, Quest performance budgets sense.
- **cpp.md** is now strict C++20: always braces, **always angle-bracket includes** (quoted includes prohibited), always initialise fields, prefer brace initialisation, `const`/`constexpr`/`consteval`/`noexcept` whenever possible, `std::array` over C-style arrays, Rule of Zero, `std::expected` vs exceptions chosen per project (don't mix), `std::jthread`/`std::stop_token` for concurrency, `compile_commands.json` for clangd. Reflects the user's strong preferences from C++.md.
- **swift.md** leads with the mindset (clarity over cleverness, safety over shortcuts), priority-ordered principles (correctness → clarity → simplicity → testability → performance), and SOLID applied to Swift. Value types default, optionals discipline (no `!` in production), Apple API Design Guidelines as canonical naming reference, layered architecture with dependency direction inward, Swift Concurrency by default with `@MainActor` explicit and structured-over-unstructured, Swift Testing where supported with XCTest where established. Drawn from both SwiftEngineer.md and the macOS CLAUDE.md drafts.

Each file ends with a "When in doubt" closer pointing at project conventions and the INSIGHT mechanism for surfacing conflicts. Each explicitly states that project-specific guidance authoritatively overrides plugin guidance — the plugin baseline lives, the project's voice wins.

## [0.2.6] — 2026-05-07

### Added

- **Plugin-shipped language guidance** under `skills/code4me/references/languages/` — `csharp.md`, `swift.md`, `cpp.md`. Each is generic, framework-agnostic guidance covering modern-language features, idioms, common pitfalls, and naming conventions. Each explicitly defers to the project's own `CLAUDE.md` for project-specific conventions; the plugin guidance is a baseline, not a contract.
- **Language-guidance injection** added to the orchestrator's dispatch checklist in `SKILL.md`. At dispatch time the orchestrator inspects the task's file types, maps each extension to the appropriate language file, and injects the file's full content into the Context Pack. Multi-language tasks get multiple files. Announce in the dispatch transparency line which language guidance was loaded for which subagent.
- README now documents the recommended multi-language project layout (root `CLAUDE.md` for common concerns plus per-language subdirectory `CLAUDE.md` files for project-specific overlays). Folder layout updated to show the new `references/languages/` directory.

### Why

The user pointed out that heterogeneous projects (multiple languages in one repo) need language-specific guidance the plugin can ship regardless of how the project organises its `CLAUDE.md`. Relying on the project's hierarchy alone is fragile — projects vary widely in layout, and subagent-context propagation of CLAUDE.md across the Task-tool boundary isn't guaranteed. Plugin-shipped baseline guidance plus orchestrator-side injection at dispatch makes the language coverage reliable; the project's own CLAUDE.md hierarchy authoritatively overrides for project-specific conventions.

## [0.2.5] — 2026-05-07

### Changed

- Removed the harness migration item from the README's Current Scope and Roadmap. The legacy `.agent/agents/harness/` was designed for a context where prompt changes needed empirical falsification across a team; in single-developer iteration the live-test loop is providing equivalent signal at lower overhead. Decision is reversible — if the framework expands to multiple users later, a probe set can be added then.

## [0.2.4] — 2026-05-07

### Added

- **Researcher subagent** (`agents/researcher.md`) — desk-based investigation, comparison, synthesis for Research tasks and optional team augmentation. Distinguishes itself from spikes (which require running code); routes back to the orchestrator with `outcome: ROUTE_TO_SPIKE` if investigation reveals the question can't be answered without hands-on prototyping. Produces research briefs with explicit findings, options, recommendations, and risks. Surfaces significant discoveries via `escalation_required: true` in the return rather than burying them.
- **Product Coach subagent** (`agents/product-coach.md`) — optional systematic-intake helper for Standard/Critical work. Operates in four modes: intake-and-spec (drafts a Milestone Spec from informal intent), intake-only (generates clarifying questions without drafting), insight-triage (recommends action levels for accumulated INSIGHTs), scope-change-shaping (classifies amendment vs. re-scope and surfaces tradeoffs). Acts as scribe and advisor — never as decision-maker. The user remains the final word on intent.
- `team-templates.md`, `README.md`, and `SKILL.md` updated to reflect that all eleven subagents are now implemented; "Subagents not yet implemented" section in `team-templates.md` removed since it's empty.

### Notes

The Product Coach is optional in the workflow by design. The user, as Product Owner, can always do intake themselves. The Coach exists for cases where systematic interview saves effort or surfaces gaps informal intake would miss — Standard and Critical work where missed scope is expensive, or any task where the user explicitly asks for help shaping the request. For Conversation-weight work the Coach generally doesn't fire; the Conversation Note is small enough that systematic intake is overkill.

The Researcher is the canonical complement to the Spike workflow. Research is desk-based; Spike is hands-on. Both are timeboxed in spirit (Researcher self-stops when findings are decision-useful; Spike has an explicit timebox), and both produce artifacts the requesting role uses to inform a decision rather than making the decision themselves.

## [0.2.3] — 2026-05-07

### Added

- **C / C++ LSP support** via `clangd` (LLVM project). New `cpp` entry in `.lsp.json` covering all common C and C++ source/header extensions (`.cpp`, `.cxx`, `.cc`, `.c++`, `.hpp`, `.hxx`, `.hh`, `.h++`, `.h`, `.c`). Default args `--background-index --clang-tidy` for persistent symbol indexing and inline clang-tidy diagnostics. README extended with per-platform install routes (brew/apt/dnf/winget/choco) and a note about `compile_commands.json` for non-trivial projects. `references/tooling.md` per-language table updated.

## [0.2.2] — 2026-05-07

### Added

- **Swift LSP support** via `xcrun sourcekit-lsp` (bundled with Xcode 11.4+ and the Command Line Tools — no separate install). New `swift` entry in `.lsp.json` covering `.swift` files. Note in README about extending to Objective-C / C++ via SourceKit-LSP's clangd integration if mixed-language project support is needed.
- README and `references/tooling.md` updated with Swift setup details and the per-language LSP table extended.

## [0.2.1] — 2026-05-07

### Changed

- **Reframed the orchestrator's operating loop and team composition** to lead with active judgment rather than canonical-sequence following. Step 1 is now "consult `.wolf/cerebrum.md`" before anything else; team selection is now framed as *"what does this task actually need?"* with templates as informative starting references rather than prescriptive defaults. Hard floors tightened to genuinely-non-negotiable items: Critical Mode runs the full team; auto-escalation symptom classes always invoke their subagents; architecture-introducing work always invokes Lead + Challenger; Co-Approval Rule applies whenever architects are dispatched. Otherwise the orchestrator chooses the subagents the task actually needs (with rationale recorded), without requiring user consent for each non-floor subtraction.
- **Reframed `references/team-templates.md`** from prescriptive defaults to informative compositions. The tables document common shapes drawn from prior practice; the orchestrator's job is active judgment about *this* task, not template execution. Producer-flexibility table updated: "skip with explicit user consent" replaced with "choose not to invoke (orchestrator judgment, unless a hard floor applies, with recorded rationale)."
- **Reordered tooling preferences across the orchestrator and all nine subagents** to foreground `.wolf/cerebrum.md` as the *first stop*, not an afterthought. Cerebrum carries the user's voice from prior work — accumulated preferences and Do-Not-Repeat patterns — and consulting it before classifying, designing, writing, reviewing, or testing prevents re-litigating decisions the user already made. The OpenWolf section in `references/tooling.md` is rewritten as "first stop when available" with cerebrum as the most valuable file in `.wolf/`.

### Why

Two observations from live design review:

1. The 0.2.0 release imported too much canonical-sequence ceremony as default. Opus's judgment about what each task actually needs was technically allowed to flex but not actively encouraged — the prompts steered toward full-crew dispatch even when smaller teams would have been correct. Hard floors are kept where genuinely non-negotiable; the rest is now Opus's call.
2. The plugin was relying more on its own `Insight Register` than on OpenWolf's `cerebrum.md`. The integration documented in `references/insight.md` was one-way and reactive (`required` INSIGHTs propagate to cerebrum after the fact); the missing piece was the proactive direction — consulting cerebrum *before* decisions to prevent waste in the first place. That's now foregrounded across the orchestrator and every subagent's tooling preferences.

## [0.2.0] — 2026-05-07

### Added

- **Lead Architect subagent** (`agents/lead-architect.md`) — produces architecture proposals, drafts Tech Specs, authors Execution Dependency Plans, integrates Challenger amendments, enforces Co-Approval Rule via explicit `approved: true` return field
- **Challenger Architect subagent** (`agents/challenger-architect.md`) — pressure-tests with the Mandatory Critique Rule (five areas examined) and Named Alternative Rule (≥1 concrete alternative per critique), enforces Convergence Rule for Architecture Discussion Records
- **Spec-to-Test subagent** (`agents/spec-to-test.md`) — produces Test Spec + initial test files with Given/When/Then structure, enforces Gate Scope Rule (one happy-path per AC, failure tests only when AC explicitly names them), enforces Test Protection Rule
- **Verification subagent** (`agents/verification.md`) — designated owner of full test suite confirmation, AC Coverage Rule with traceable evidence, Test Integrity Check, Coverage Gap Priority, QA-optional veto right
- **Code Reviewer subagent** (`agents/code-reviewer.md`) — Standard-mode quality-only reviewer (distinct from `combined-reviewer`), four-tier severity classification (BLOCKER/MAJOR/MINOR/NIT), four review areas (correctness-adjacent quality, maintainability, standards, architectural alignment) plus test quality
- **QA subagent** (`agents/qa.md`) — exploratory testing beyond the Test Spec, Workflow Anomaly Rule (test suite must be green at start), three-decision return (PASS/PASS WITH BUGS/FAIL), Bug Fix reproduction mode, Critical-mode Post-Release QA Note
- **Documentation Writer subagent** (`agents/doc-writer.md`) — user-facing docs, audience and tone enforcement from Context Pack, division-of-responsibility with Developer's technical docs
- **canonical-workflow reference** (`references/canonical-workflow.md`) — Standard path end-to-end, Architecture Co-Approval Rule, Pre-Implementation Test Gate, Implementation Gate, Quality Gate Loop with re-run rules, Task Return Contract (the plugin-shape replacement for the legacy Completion Message Rule)
- **canonical-artifacts reference** (`references/canonical-artifacts.md`) — required content for Tech Spec, Test Spec, Execution Dependency Plan, Architecture Discussion Record, Context Pack, Verification Report, Code Review Report, QA Report
- **release reference** (`references/release.md`) — Zero Failing Tests Rule, Documentation Rule, Release Rule with Critical-Mode addition (post-release shadow QA + Human Director sign-off)
- **circuit-breakers reference** (`references/circuit-breakers.md`) — Rework Limit (3+ same-root-cause), Blocker Dwell Limit (2+ follow-up cycles), Scope Change Limit (>2 in milestone), HUMAN_DIRECTOR_ESCALATION format

### Changed

- Version bumped to 0.2.0 reflecting that Standard and Critical workflows are now end-to-end implementable
- `references/team-templates.md` "What's currently built" section updated to mark all nine subagents as implemented; remaining gaps narrowed to Researcher and the optional Product Coach
- README updated: current scope now reflects Conversation, Light, Standard, and Critical all implementable; folder layout updated with new files; roadmap shifted from "implement heavier workflows" to "live-test, migrate harness probes, add Researcher and Product Coach"

### Notes

This release is the largest content delta since 0.1.0 — seven new subagents plus four new references. The plugin is now self-contained for Conversation through Critical workflows; the legacy `.agent/agents/` framework is no longer referenced by any operational plugin file. References to it in README/CHANGELOG prose remain as design provenance (the plugin distilled from it) but do not constitute runtime dependencies.

The eleven new files were written in plugin-shape rather than ported from the legacy framework — the Task return contract replaces the mail-received Completion Message Rule, dispatch-time team transparency replaces silent template execution, and per-task model selection plus tooling preferences (LSP / MCPs / OpenWolf) are baked into every subagent system prompt.

## [0.1.0] — 2026-05-07

### Added

- Plugin scaffold with manifest, README, and folder structure
- Orchestrator skill (`skills/code4me/SKILL.md`) implementing the Producer-as-orchestrator brain — classification, team selection, dispatch, persistence, escalation
- Reference files for the orchestrator: workflow weights, Conversation Mode path, team templates, INSIGHT message rule, auto-escalation override, tooling preferences (LSP-first / OpenWolf-when-configured), and model selection heuristic
- Tooling preferences sections in the Developer and Combined Reviewer subagent system prompts, plus a one-line tooling reminder in the orchestrator's dispatch checklist
- Model selection heuristic with per-(subagent, weight) defaults, deviation rules, and an orchestrator-on-Opus recommendation; the orchestrator passes an explicit `model` to every Task dispatch
- Developer subagent (`agents/developer.md`)
- Combined Reviewer subagent (`agents/combined-reviewer.md`) — reviews spec compliance, code quality, and runtime behaviour for Conversation- and Light-weight work; named `combined-reviewer` to disambiguate from the Standard-mode `code-reviewer` subagent that will be added in a later version
- Conversation Note template (`templates/conversation_note.md`)
- `.lsp.json` at the plugin root configuring `roslyn-language-server` for C# (`.cs`, `.csx`, `.cshtml`) with `--stdio`, `--autoLoadProjects`, `--logLevel Information`, and `--extensionLogDirectory .code4me/lsp-logs` arguments; setup steps and per-language extension guidance documented in the README and `references/tooling.md`
- "MCP support" section in the README covering the project / plugin / user layering, a Recommended MCPs table by subagent role, and the enforcement pattern (project `CLAUDE.md` declares the inventory, plugin enforces the prefer-over-fallback principle)
- "MCPs (project-level)" section in `references/tooling.md` documenting the principle; matching one-line additions to the Developer and Combined Reviewer subagent system prompts; orchestrator's dispatch checklist now includes a relayed MCP inventory drawn from the project's `CLAUDE.md`

### Changed

- Reframed `references/team-templates.md` from rigid prescriptions to defaults-with-rules. Templates are now floors: the Producer can add specialists freely, skip subagents only with explicit user consent, reorder for parallelism, and substitute roles based on the task's actual shape. Hard floors preserved (Critical Mode keeps the full team; auto-escalation symptom classes always run their subagents; no architect below Sonnet). Added a Team transparency rule requiring the Producer to announce and justify the team composition at every dispatch, before the first Task call — making team selection a visible audit trail rather than a silent template lookup.
- Added a "Team composition" section to the orchestrator's `SKILL.md` summarising the flexibility rules and the transparency requirement. Sits alongside Model selection in the dispatch checklist so both decisions are explicit per task.
- Rewrote the orchestrator skill description in `skills/code4me/SKILL.md` frontmatter for better description-based triggering. Previous version led with internal vocabulary ("Producer-orchestrator", "workflow weight"), buried trigger phrases at the end, and lacked an explicit skip clause. New version follows the Anthropic skill pattern: outcome-shaped lead sentence naming concrete artifacts the workflow produces (Conversation Notes, smoke tests, PROVISIONAL tags, INSIGHT routing), trigger phrases promoted near the front, and an explicit "Skip for…" clause to prevent over-firing on one-line cosmetic edits and read-only questions.
- Rewrote the OpenWolf framing across `references/tooling.md`, both subagent system prompts, and the orchestrator's `SKILL.md` to reflect what OpenWolf actually does (invisible Claude Code middleware via hooks + `.wolf/` directory) rather than the earlier vaguer "use OpenWolf for codebase queries" framing. Subagents are now instructed to consult `.wolf/anatomy.md` before opening files, `.wolf/cerebrum.md` before writes, and `.wolf/buglog.json` before diagnosing errors, with an explicit note that the hooks operate invisibly and trust the layer.
- Added a new "Integration with OpenWolf cerebrum" section to `references/insight.md` describing how INSIGHTs with impact tier `required change before next similar task` should also be appended to `.wolf/cerebrum.md` when OpenWolf is present, so cross-project memory accumulates instead of relearning the same lesson per milestone.
- Added a paragraph to the orchestrator's "Artifact and state persistence" section instructing it to ensure new `.code4me/` artifacts are reflected in `.wolf/anatomy.md` when OpenWolf is installed, so the orchestrator's own state files do not cost full token reads on every check.

### Notes

This release is a scaffold. Conversation Mode is the only fully working end-to-end path. Light, Standard, and Critical modes are defined but their specialist subagents are not yet implemented.

The framework is distilled from the legacy `.agent/agents/` files. Validated rules (Workflow Weight tiers, INSIGHT message type, auto-escalation symptom classes, Conversation Mode forbidden conditions, Conversation Note structure) are preserved. The wiring shifts from mail-received coordination to Task-tool dispatch with file-persisted artifacts.
