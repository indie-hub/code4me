# Roadmap

This document lists ear-tagged work that's been considered, scoped, and intentionally deferred. Each item names what it is, why it's not shipping now, the target version, and (where applicable) a trigger condition for revisiting.

The canonical record is still the CHANGELOG (each item has a deferred-items section under its origin version). This roadmap is a maintained consolidated view — useful when planning the next cut.

When an item ships, move it out of this doc and into the version's CHANGELOG entry. When a new item is ear-tagged, add it here AND in the appropriate CHANGELOG deferred section.

---

## How to read this doc

Each item has:

- **Status:** `ear-tagged` (proposed and deferred), `in-progress` (someone's working on it for the next cut), or `revisiting` (the trigger condition fired; about to evaluate).
- **Target version:** the version it would land in IF shipped.
- **Scope estimate:** rough effort.
- **Trigger condition (when present):** what would prompt revisiting. Items without a trigger are pure prioritisation calls.
- **CHANGELOG reference:** where the item was originally ear-tagged.

Items are ordered by target version, then by adoption value within that version.

---

## Carryovers from v0.11.x

These were ear-tagged during the v0.11 cycle and didn't make the cut. Could ship as part of v0.12.x or a later v0.11.y patch.

### Audit-tool DeepSeek surveillance section

**Status:** ear-tagged  
**Target version:** v0.11.1 or v0.12.x  
**Scope:** ~30 lines in `bin/code4me-audit-dispatch-log`

A "Cross-vendor health" section breaking down per-vendor ask-gate rate, pairing degradation rate, and outcome distribution. Mirrors the existing Trivial and LSP-first surveillance sections.

CHANGELOG reference: v0.11.0-dev "Open questions deferred to v0.11.x".

### DeepSeek tool-use eval probe

**Status:** ear-tagged  
**Target version:** v0.11.x  
**Scope:** ~half-day of probe authorship + a soak pass

DeepSeek's response quality on tool-using prompts (read file, run test, iterate) hasn't been measured against Claude or Codex on the plugin's role prompts. Probes 06-08 verify orchestrator behaviour; they don't measure DeepSeek's competence. Add a `probes/evals/` directory with quality-comparison probes.

CHANGELOG reference: v0.11.0-dev "Open questions deferred to v0.11.x".

### Cost rollup precision

**Status:** ear-tagged  
**Target version:** v0.11.x or later  
**Scope:** a few hours

The dispatch log records model identifier and tier; it doesn't sum input/output tokens. Reconcile against vendor billing portals (DeepSeek, OpenAI) for precise per-milestone $$. Out of scope for v0.11.0 by intent.

CHANGELOG reference: v0.11.0-dev "Open questions deferred to v0.11.x".

### Hook runtime gating via env vars

**Status:** ear-tagged  
**Target version:** v0.11.1  
**Scope:** ~3-line patch per hook + one paragraph in each `docs/howto-*.md`  
**Idea source:** `affaan-m/ECC`'s `ECC_HOOK_PROFILE` and `ECC_DISABLED_HOOKS`

`CODE4ME_HOOK_PROFILE=minimal|standard|strict` + `CODE4ME_DISABLED_HOOKS="check-lsp-first-on-source,..."` so a user can flip any hook off for a single session without uninstalling. **Trigger condition:** ask-gate noise becomes a real complaint during soak.

CHANGELOG reference: v0.11.0-dev "Open questions deferred to v0.11.x".

---

## v0.12.x candidates

These were ear-tagged during the v0.12 cycle. Most are observability or polish; the cross-vendor post-validation is the only behavioural change.

### Audit-tool decomposition-health surveillance

**Status:** ear-tagged  
**Target version:** v0.12.1  
**Scope:** ~30 lines in the audit tool

Counts milestones with/without `acceptance_criteria:` block, average ACs per milestone, orphan dispatches (tasks not in any AC's `tasks_touching` array). Mirror of Trivial + LSP-first surveillance sections.

CHANGELOG reference: v0.12.0-dev "Open questions deferred to v0.12.x".

### Milestone-level grouping in Trello (epic → story)

**Status:** ear-tagged  
**Target version:** v0.12.x  
**Scope:** ~50 lines in trello-sync SKILL.md + one new column behavior

Currently AC cards reference their milestone via the body's `Milestone:` field. Add a milestone-level parent card with checklist items per AC. Gives the board both AC-progression rhythm AND milestone-rollup visibility.

CHANGELOG reference: v0.12.0-dev "Open questions deferred to v0.12.x".

### Scope-change AC additions probe

**Status:** ear-tagged  
**Target version:** v0.12.x  
**Scope:** new probe file (~80 lines)

The edge case where the user adds AC4 mid-milestone. Both trello-sync and the tracker support it (just append to `acceptance_criteria:`); no probe currently verifies the behaviour end-to-end.

CHANGELOG reference: v0.12.0-dev probe-06's edge-cases section.

### Vendor-side hooks (Layer B) — codex and reasonix native PreToolUse

**Status:** ear-tagged
**Target version:** v0.14+
**Scope:** ~6-10 hours total (codex ~3h, reasonix investigation ~half-day, reasonix wiring ~3h)

Layer C (post-validation diff scan) landed in v0.13.0-dev and catches all on-disk violations regardless of vendor — but it's **post-call**, so the violation already touched the disk by the time we surface it. Layer B closes the rest of the gap with **native pre-call interception** inside the vendor subprocess.

Verified facts about the vendor hook systems:

- **Codex CLI has lifecycle hooks** at `~/.codex/hooks.json` (and `<repo>/.codex/hooks.json`). Five events: `SessionStart`, `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`. Enabled via `[features] codex_hooks = true` in `config.toml`. Hooks receive JSON on stdin (shape near-identical to Claude Code); can return `permissionDecision: "deny"` to block. **Critical limitations:**
  - `PreToolUse` currently fires only for the `Bash` tool. Doesn't intercept file writes (`Write`), MCP, or `WebSearch`. Codex docs: *"useful guardrail rather than a complete enforcement boundary."*
  - Only `deny` is supported. `allow`, `ask`, `updatedInput`, `additionalContext` parse but fail open.
  - Experimental. Windows currently disabled.

- **Reasonix has lifecycle hooks** at `<project>/.reasonix/` (per-project) and `~/.reasonix/config.json` (global). Four events confirmed from README: `PreToolUse` (gating), `PostToolUse`, `UserPromptSubmit`, `Stop`. **Coverage unknown** — what reasonix's `PreToolUse` actually intercepts (Bash-only like codex? all tools? a specific subset?) needs verification from the bundled docs (`<install>/REASONIX.md` or `<install>/docs/`) before wiring.

The build:

1. **Verify reasonix `PreToolUse` coverage.** Read `REASONIX.md` and `<install>/docs/`. Confirm which tools `PreToolUse` intercepts and what `permissionDecision` values are supported. ~half day depending on doc clarity.
2. **Build codex-side hooks** (`hooks/codex/check-test-protection-on-bash.sh`, `hooks/codex/check-critical-write-on-bash.sh`, `hooks/codex/check-forbidden-conditions-on-bash.sh`). Each parses the Bash command, greps for paths matching protected/allowlist/forbidden patterns, returns `deny` on violation. Mirrors Claude-side logic but operates on shell-command strings rather than tool-call JSON.
3. **Ship `templates/codex-hooks.json.example`** wiring all three hooks under `PreToolUse` matcher `Bash`. Document the manual install step (no auto-wire — codex hooks are user-configured, not project-shipped, to respect codex's hook-tier semantics).
4. **Build reasonix-side hooks** if and only if step 1 confirms reasonix's `PreToolUse` intercepts something useful. Same shape; vendor-specific config format.
5. **Probes**: `probes/cross-vendor/10-codex-side-hooks-fire-on-bash-violation.md`, plus reasonix-side probe if applicable.
6. **Preflight checks**: detect whether codex hooks are wired (`[features] codex_hooks = true` AND a hooks.json file exists), surface as warn-level when not.

**Decision pending before build:** opt-in (user manually copies hooks.json.example) vs auto-wire (extend `/code4me-init` to scaffold codex hooks if codex CLI is detected). Roadmap default: opt-in (less invasive). Defer the call until v0.14 build starts.

**Why this is meaningfully more work than Layer C was:** codex hooks require a feature flag, a separate config file format (TOML for the flag + JSON for the hooks), and Bash-command parsing rather than file-path matching. Reasonix is a separate ecosystem on top of that. Layer C's helper script is vendor-agnostic; Layer B has to be vendor-specific.

**Why it's worth doing eventually:** pre-call interception is strictly better than post-call detection where it covers. A protected test that codex would `rm` via Bash gets `deny`ed before the `rm` runs, rather than after. Layer C catches it either way (deterministically); Layer B catches it earlier (probabilistically — bounded by what each vendor's PreToolUse actually intercepts).

CHANGELOG reference: v0.13.0-dev "Layer B ear-tagged with verified vendor hook info".

### Resume-from-handoff probe

**Status:** ear-tagged  
**Target version:** v0.12.x  
**Scope:** new probe file

`probes/housekeeping/02-resume-from-handoff.md`. Verifies the operating-loop step 1 actually reads the most recent handoff manifest on session start (not just that step 1 documents doing so).

Referenced in `skills/code4me/references/housekeeping.md` §"Resume-protocol companion check".

### Audit-tool handoff-health surveillance

**Status:** ear-tagged  
**Target version:** v0.12.x  
**Scope:** ~30 lines in the audit tool

Counts READY / READY-WITH-NOTES / NOT-READY verdicts across the project's manifest history; surfaces persistent NOT-READY patterns (e.g., dispatches not getting tracked properly). Mirror of Trivial + LSP-first + (future) decomposition-health + (future) cross-vendor-health surveillance sections.

Referenced in `skills/code4me/references/housekeeping.md` §"Audit-tool integration".

---

## Conditional / future

Items with explicit trigger conditions — they only get built if a measurable signal fires.

### audit4me (sibling product — batch codebase auditor)

**Status:** designed (v0.1 design doc landed), not built  
**Target version:** v0.13+ (separate ship cycle)  
**Scope:** 3-5 days of focused work for Phase 1; ~2 weeks for Phases 1-5  
**Design doc:** [audit4me-design.md](audit4me-design.md)

A batch, ambient, cross-vendor codebase auditor. Runs after normal hours (or any time on demand); audits the codebase across ≥2 LLM vendors; produces a morning report with findings labelled by multi-vendor agreement confidence. High-confidence findings come with proposed fixes the user can apply via `/audit4me-apply <id>` — which dispatches a code4me Conversation Mode workflow to actually make the change (audit4me proposes; code4me applies).

Key design decisions captured in the design doc:

- **≥2 vendors required.** Single-vendor mode exists but can't auto-propose fixes. The 2-vendor case (typical corporate constraint: Anthropic + OpenAI, or Anthropic + DeepSeek) is the design floor, not an edge case.
- **Coverage tracking is first-class.** `.code4me/audit4me/audit-coverage.json` tracks per-file per-vendor audit state by content hash. `/audit4me-status` reports what's audited and what isn't. Re-audit triggers: content change, rules-version change, periodic refresh.
- **Five audit categories.** Bugs, security, performance, maintainability, test gaps. Each has its own RETURN SCHEMA.
- **Composite confidence.** Multi-vendor agreement + reproducibility (failing test written) + LSP/linter cross-check + test coverage. All-vendors-agreed + failing-test + severity≥MAJOR + no-protected-test-touched is the propose-fix threshold.
- **Five-phase build.** Coverage tracking → multi-vendor agreement → failing-test generation → `/audit4me-apply` integration → additional categories.

**Trigger condition for starting Phase 1 build:** code4me v0.12.0 has 2 weeks of clean real-milestone usage. Building audit4me before code4me is soaked risks both — audit4me's value depends on code4me's `/audit4me-apply` integration working reliably.

**Naming consequence at ship time:** `/code4me-audit` (dispatch-log analytics) gets renamed to `/code4me-dispatch-audit` to disambiguate from the new `/audit4me-*` commands. The `audit` namespace transfers to the new product.

### CodeGraph as a code-knowledge surface alongside LSP

**Status:** ear-tagged, conditional  
**Target version:** v0.12.x or later, IF the trigger fires  
**Idea source:** `colbymchenry/codegraph`

Pre-indexed cross-language knowledge graph (tree-sitter → SQLite + FTS5) with MCP tools:

- `codegraph_context(task)` — packages entry points + related symbols + code snippets in one call (the "94% fewer tool calls" benefit).
- `codegraph_impact(symbol)` — blast-radius analysis. NEW capability — LSP has no equivalent.
- `codegraph_callers` / `codegraph_callees` — cross-language call traversal.
- `codegraph_affected <files>` — finds tests touched by a diff.

Complementary to LSP, not a replacement (LSP keeps live diagnostics, completion, full type inference).

**Trigger condition for revisiting:** if the LSP-first hook's ask-gate rate stays above ~30% of dispatch volume after a month of soak. That signals agents are asking task-shaped questions LSP doesn't answer well — `codegraph_context` is the stronger redirect target.

**Costs to adopt:** another dependency (Node + npm + per-project `.codegraph/` SQLite), a third "code-knowledge" surface (alongside LSP and context-mode) requiring updated precedence rules in `references/code-consultation-precedence.md`, and the codegraph project's maturity risk (552 stars, 0 releases, 237 commits — active but young).

CHANGELOG reference: v0.12.0-dev "Open questions deferred to v0.12.x".

---

## Patterns worth knowing

A few observations across the current ear-tag set:

1. **Six of the twelve items are audit-tool surveillance sections.** `bin/code4me-audit-dispatch-log` is becoming the second-most-important file in the plugin (after `skills/code4me/SKILL.md`). When the audit tool reaches four or five surveillance sections, consider refactoring each section into a sourced file (`bin/audit-sections/decomposition-health.sh`, `cross-vendor-health.sh`, `handoff-health.sh`, etc.). Avoids the file growing past ~1000 lines.
2. **Four items are probes.** Healthy ratio — probes are the spec; new behaviour should always have a probe.
3. **Only one item is a behavioural orchestrator change** (the cross-vendor bridge post-validation). The rest are observability, portability, or community-infra. That's a sign the orchestrator core is in a stable shape; remaining work is polish.
4. **No vendor additions are ear-tagged.** Three vendors (Anthropic, OpenAI via codex-bridge, DeepSeek via deepseek-bridge) is the right number for now. A fourth would be high-leverage only if it differs qualitatively from the three — a privacy-focused local-only inference vendor would qualify; another OpenAI-compatible API wouldn't.
5. **Two items have explicit trigger conditions.** CodeGraph (LSP-first ask-gate rate >30% for a month) and Hook runtime gating (ask-gate noise becomes a complaint). The rest are pure prioritisation — they ship when someone has the appetite to ship them. The trigger-gated items are the most resistant to scope creep because the condition is measurable.

---

## How to add an item to this list

1. Decide it's not shipping now. Common reasons: requires soak data we don't have; scope creep on the current cut; depends on something else landing first.
2. Add a section above with the same template (Status / Target / Scope / Trigger condition if applicable / CHANGELOG reference).
3. Add the same item to the CHANGELOG's "Open questions deferred to vX.Y.x" section under the current dev version.
4. If the item has a trigger condition, note it both here and in the CHANGELOG entry. Triggers are how we avoid "we'll get to it" purgatory.

## How to ship an item from this list

1. Move the section out of this doc and into the version's CHANGELOG entry as a real "Added" or "Changed" item.
2. Update any cross-references (this doc shrinks; the CHANGELOG gains the detail).
3. Write the probe(s). The ear-tag mentioned probe paths — those become real files.
4. If the item had a trigger condition, note in the CHANGELOG that the trigger fired (or that the item shipped despite the trigger not firing, because the user decided it was time).

---

## Items that shipped and are no longer ear-tagged

A history of items that started life on this list and shipped. Useful for showing the deferral discipline works (items don't sit forever).

### Cross-vendor bridge post-validation (Layer C — diff scan) — shipped in v0.13.0-dev

**Shipped:** 2026-06-08.
**Originally ear-tagged for:** v0.12.x.
**Original scope:** ~2-3 hours (held; actual was ~3 hours including the polyfill bugfix found in Scenario 4).

The PreToolUse hooks don't fire on `codex exec` or `reasonix run` subprocesses; pre-v0.13 bridge protection was prompt-side rules + RETURN SCHEMA validation only (advisory; a vendor agent that ignored prompt rules AND lied about it in the response got past both checks). Layer C closes the gap deterministically — after every `codex exec` / `reasonix run` return, `bin/code4me-bridge-diff-scan.sh` inspects `git status --porcelain` and cross-references the changed paths against `.code4me/protected-tests.txt`, `.code4me/critical-allowlist.txt` (Critical-mode), and `.code4me/forbidden-conditions.json` (Conversation-mode). Violations surface as the same typed blockers Claude-side hooks produce (`test_protection_violation`, `out_of_scope_target`, `forbidden_condition_violation`, plus a new `unexpected_modification` for read-only roles). Vendor-agnostic; the helper script is identical across both bridges.

Trade-off: violations are caught **after** the subprocess touched the disk, not before. For a single-user project this is usually fine (user `git checkout`s the file and re-dispatches). For CI/team settings, Layer B (ear-tagged) would give earlier interception.

Requires git — when the project isn't a git repo, the scan skips with `layer_c_status: skipped` in the dispatch log. Layer A still covers what it can.

Discovered during build: the existing glob polyfill in `hooks/check-test-protection.sh` (and sister hooks) uses bash's native `[[ == ]]` glob on bash 4+, which doesn't correctly handle `**/` as "zero-or-more directory components". The Layer C helper forces the regex polyfill unconditionally to fix this; the sister hooks may benefit from the same change (ear-tagged informally — not yet a roadmap item, low-risk for the current Claude-side use cases).

CHANGELOG reference: v0.13.0-dev "Cross-vendor bridge post-validation (Layer C — diff scan)".

### Windows hook portability mitigations — shipped in v0.13.0-dev

**Shipped:** 2026-06-08.
**Originally ear-tagged for:** v0.12.x.
**Original scope:** ~1 hour (held).

Four mitigations landed:

1. **`.gitattributes`** with `*.sh` / `*.bash` / `*.json` / `*.jsonl` / `*.yaml` / `*.md` / `*.py` / `*.mjs` forced to `eol=lf`. Prevents CRLF corruption on Windows clones. Hook scripts and bin scripts now have line-ending discipline at the repo level.
2. **`bin/code4me-preflight` check 0: Platform.** Detects OS + shell environment (Linux / macOS / Windows + WSL / Windows + Git Bash / unknown). Reported as the first preflight check so users can confirm their setup. Warns on Git Bash and unknown environments with pointers to the Windows how-to.
3. **`docs/howto-windows.md`** — full Diataxis how-to: pick WSL or Git Bash, install dependencies (jq, Node, Codex, Reasonix, codegraph), verify with preflight, known quirks (`$CLAUDE_PROJECT_DIR` path translation, CRLF on legacy clones, PowerShell launch issues), reporting Windows issues, when native Windows might happen.
4. **CONTRIBUTING.md Windows manual-test checklist.** Four-item list contributors run on Windows before merging changes that touch hooks/, bin/, or .gitattributes: line endings, shebang execution, preflight Platform line, path-handling.

Path-translation edge case (`\` → `/` normalization in `$CLAUDE_PROJECT_DIR`) **remains deferred** until empirical Windows-soak reports surface it.

CHANGELOG reference: v0.13.0-dev "Windows hook portability mitigations".
