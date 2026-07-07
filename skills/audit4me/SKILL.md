---
name: audit4me
description: "Batch, cross-vendor codebase auditor. Sibling product to code4me. audit4me proposes findings (bugs, security, performance, maintainability, test-gaps) with confidence scoring from multi-vendor agreement; code4me applies them via Conversation Mode when the user invokes `/audit4me-apply`. Phase 1 scope (current): single-vendor (anthropic), single-category (bugs) auditing via `/audit4me-run`, on top of the Phase 0 config + status surface and committed data model. No proposed fixes yet (multi-vendor agreement, failing tests, and `/audit4me-apply` land in Phases 2-4). Invoke this skill via `/audit4me-config` (one-time setup) or `/audit4me-status` (read-only coverage report)."
---

# audit4me

A batch, ambient, codebase-wide analyzer. Runs detached from any milestone. Audits the codebase across multiple LLM vendors, computes per-finding confidence from inter-vendor agreement, produces findings the user reviews and (selectively) applies via code4me.

In one sentence: **audit4me proposes; code4me applies.** audit4me never edits production source. Accepted fixes get dispatched through code4me's Conversation Mode workflow, which means every applied fix goes through the same quality gates as any other code change.

## Current scope (Phase 1)

audit4me is built incrementally. **Phase 0** shipped the data-model commitment and the read-only surface. **Phase 1** (v0.13.1-dev) adds the first real auditing: a single-vendor (`anthropic`), single-category (`bugs`) sweep via `/audit4me-run`, dispatched through the per-file `code4me-audit-orchestrator` subagent, with findings + coverage + events persisted under `.code4me/audit4me/`. No proposed fixes yet.

Phase 0 surface (still current):

- **JSON schemas** for the four data-model files: config, coverage, events, finding-frontmatter. Live under `schemas/`. These pin the file shapes Phase 1+ will produce and consume.
- **`/audit4me-config`** slash command — writes a default `.code4me/audit4me-config.json` the user edits. Interactive prompts for `vendors_available` and `scope.include`; sensible defaults for everything else.
- **`/audit4me-status`** slash command — reads `.code4me/audit4me-config.json` and `.code4me/audit4me/audit-coverage.json` (if present) and produces a read-only coverage report.

**Shipped in Phase 1 (v0.13.1-dev):**

- `/audit4me-run [--paths --changed-since --max-files --vendor anthropic --category bugs --force-audit]` — the single-vendor bugs sweep
- The per-file `code4me-audit-orchestrator` subagent (minimal: one vendor, one category)
- `bin/audit4me-helpers.sh` (scope / work-set / hash / coverage / events / id) and `bin/audit4me-rebuild-coverage.sh`
- `references/audit-prompt-bugs.md` — the bugs audit prompt + RETURN SCHEMA

**Not yet (later phases):**

- Multi-vendor agreement + within-file aggregation, `/audit4me-findings` (Phase 2)
- Failing-test generation (Phase 3)
- `/audit4me-apply`, `/audit4me-dismiss` — code4me Conversation Mode integration (Phase 4)
- Categories beyond `bugs`: security, performance, maintainability, test_gaps (Phase 5)

See `docs/audit4me-design.md` for the full design doc and phasing plan.

## When this skill loads

The skill loads when:

- The user invokes `/audit4me-config` or `/audit4me-status` (slash command → skill dispatch).
- Future phases: also `/audit4me-run`, `/audit4me-findings`, `/audit4me-apply`, `/audit4me-dismiss`.

The skill does **not** auto-load from the orchestrator's operating loop. audit4me runs detached from code4me's milestone workflow; the orchestrator only interacts with audit4me when the user explicitly dispatches `/audit4me-apply <finding_id>`, which is Phase 4.

## `/audit4me-config` — one-time project setup

Scaffolds `.code4me/audit4me-config.json` with sensible defaults and minimal user input. The full config schema is in `schemas/config.schema.json`; the prose explanation of each field is in `references/config-format.md`.

### Procedure

1. **Pre-flight.** Confirm `.code4me/` exists at the project root. If not, surface: *"No `.code4me/` directory — run `/code4me-init` to scaffold one. audit4me lives alongside code4me's working files."* and stop.

2. **Existing config check.** If `.code4me/audit4me-config.json` already exists, ask: *"Existing audit4me-config.json found. Overwrite (replaces all fields), patch (only fill in missing fields), or abort?"* — wait for explicit user choice.

3. **Vendors available.** Ask the user which vendors are available for this project. Recommended phrasing: *"Which LLM vendors can audit4me use in this project? (Defaults to the vendors you have CLI installed for. The 2-vendor minimum applies for auto-proposed fixes; single-vendor mode surfaces findings only.)"*. Probe via Bash:

   - `command -v claude` → anthropic candidate (always available if the user is here)
   - `command -v codex` → openai candidate
   - `command -v reasonix` → deepseek candidate

   Surface which vendors are CLI-available; ask the user to confirm or restrict.

4. **Scope.** Ask the user for `scope.include` patterns. Recommended phrasing: *"Which paths should audit4me cover? (Glob patterns relative to project root. Common: `src/**` or `app/**`. Add multiple as needed.)"*. Default exclude list:

   ```json
   ["node_modules/**", "vendor/**", "dist/**", "build/**", "target/**", "**/*.min.js", "**/__snapshots__/**"]
   ```

   Ask if any additional excludes are needed.

5. **Defaults for everything else.** Use these values:

   - `default_categories: ["bugs"]` (Phase 0/1; expand as later phases ship categories)
   - `max_files_per_run: 50`
   - `max_cost_usd_per_run: 5.00`
   - `max_runtime_per_run: "4h"`
   - `rules_version: "v0.1.0"` (the Phase 0 ruleset baseline; Phase 1 may bump this when it locks the first real audit prompt)
   - `refresh_interval_days: 90`
   - `concurrency_cap: 3`
   - `confidence_thresholds`: all defaults (MAJOR severity, requires failing test, requires unanimous within available vendors)
   - `apply_integration`: defaults (`dispatch_mode: conversation`, `auto_escalate_categories: ["security"]`)

   Don't ask the user about these unless they request a non-default — Phase 0's job is to get the file written, not to tune every knob.

6. **Write the file.** Use the Write tool to create `.code4me/audit4me-config.json` with the collected values + defaults. Use 2-space indentation. Include the `$schema: "audit4me-config-v1"` line at the top.

7. **Create the audit4me state directory.** `mkdir -p .code4me/audit4me/findings` via Bash. This is where Phase 1+ will write the coverage tracker, events log, and finding markdown.

8. **Smoke test.** Validate the written config against `schemas/config.schema.json`. If `jq` is available, also reformat the file with `jq` to canonicalize indentation. If validation fails, surface the specific error and offer to fix.

9. **Summary.** Print:
   - Path of the saved config file
   - The chosen `vendors_available` and `scope`
   - A note: *"Phase 0 is config + status only. Run `/audit4me-status` to see the coverage report (empty until Phase 1 ships `/audit4me-run`). The full audit dispatch lands in Phase 1."*
   - A pointer to `docs/audit4me-design.md` for the design doc.

### When NOT to run

- If you don't want audit4me at all — just don't run it. Without the config file, the future `/audit4me-run` will refuse to start, and nothing else in code4me depends on audit4me.
- If you're testing code4me workflows in isolation — audit4me's absence is the canonical "off switch."

## `/audit4me-status` — read-only coverage report

Reports the current audit state of the project. Read-only on all files; no dispatches; no writes. The full data model is documented in `references/coverage-format.md`.

### Procedure

1. **Pre-flight.** Confirm `.code4me/audit4me-config.json` exists. If not, surface: *"No audit4me config found at `.code4me/audit4me-config.json`. Run `/audit4me-config` first."* and stop.

2. **Parse the config.** Read and validate `.code4me/audit4me-config.json` against `schemas/config.schema.json`. Extract `vendors_available`, `default_categories`, `scope`, `rules_version`, `refresh_interval_days`.

3. **Resolve scope.** Use Bash + globs to enumerate files matching `scope.include` minus `scope.exclude`. Count them.

4. **Read coverage.** If `.code4me/audit4me/audit-coverage.json` exists, parse it. If not (Phase 0 default — nothing's been audited yet), the report shows "no audit history" gracefully.

5. **Compute the report:**

   - **In scope:** N files matching `scope.include` minus `scope.exclude`.
   - **Audited:** M files with at least one entry in `audit-coverage.json` (Phase 0: always 0).
   - **By coverage level:** counts of `uncovered` / `single-vendor` / `agreement-covered` / `full-covered`. In Phase 0, all in-scope files are `uncovered`.
   - **By rules version:** how many files were audited at the current `rules_version` vs. earlier versions (re-audit candidates).
   - **Stale by refresh:** count of files whose `last_updated` is older than `refresh_interval_days` ago.
   - **Findings on disk:** count of files in `.code4me/audit4me/findings/*.md`, broken down by `status` (open / applied / dismissed / stale). In Phase 0 this is always 0.

6. **Estimated next-run cost.** Compute a rough estimate for "what would a full sweep cost":

   - Files needing audit = `in_scope - already_covered_at_current_rules`
   - Per-file estimate = roughly `tokens_per_file * vendor_count * category_count`. Use a placeholder of ~5000 tokens/file/vendor/category at audit-time pricing (Phase 1 will lock real numbers).
   - Multiply by per-vendor pricing from `skills/code4me/references/vendor-models.yaml` (read inline).
   - Surface as a range, not a point estimate.

7. **Emit the report.** Single markdown block. See template below.

### Output shape

```markdown
# audit4me status — {ISO8601}

## Configuration
- Vendors available: {list from config}
- Default categories: {list from config}
- Rules version: {rules_version}
- Refresh interval: {refresh_interval_days} days

## Scope
- In-scope files: {N}
- Includes: {scope.include}
- Excludes: {scope.exclude}

## Coverage
- Audited (any vendor, current rules): {M} files
- By coverage level:
  - uncovered: {X}
  - single-vendor: {Y}
  - agreement-covered: {Z}
  - full-covered: {W}
- Stale by refresh interval (>{refresh_interval_days}d): {S} files
- Behind current rules_version: {R} files

## Findings on disk ({total})
- open: {open}
- applied: {applied}
- dismissed: {dismissed}
- stale: {stale}

## Next-run estimate (full sweep)
- Files needing audit: {N - M_at_current_rules}
- Estimated cost: ${low}-${high}
- Estimated wall clock: {minutes-hours range}

## Phase note
Phase 1 (v0.13.1-dev): single-vendor (`anthropic`), single-category (`bugs`) auditing via
`/audit4me-run`. Multi-vendor agreement, failing tests, and `/audit4me-apply` land in Phases 2-4.
See `docs/audit4me-design.md` for the phasing plan.
```

If any read fails (corrupt JSON, missing schema, etc.), note it in the report but continue with what's available. Phase 0's job here is to give the user confidence the wiring is correct, not to do the audit.

### When NOT to run

- Before `/audit4me-config` — there's no config to report on.
- Inside a `/code4me-housekeeping` flow — housekeeping focuses on code4me workflow state; audit4me has its own surface.

## `/audit4me-run` — the operating loop (Phase 1)

`/audit4me-run` executes a sweep. The **outer loop runs in the main session** and
is deterministic — it shells out to `bin/audit4me-helpers.sh` for bookkeeping and
dispatches the judgment-heavy per-file work to the `code4me-audit-orchestrator`
subagent. No LLM thinking happens between the bash steps except validating that a
subagent returned well-formed JSON and writing the per-finding markdown.

The split (per `docs/audit4me-design.md` §Architecture):

- **Deterministic (bash + `jq`):** mint run id, compute the work set, hash files,
  atomic coverage update, events-log append, finding-id allocation, run summary.
- **Judgment (Task tool → subagent):** for each file, one `code4me-audit-orchestrator`
  dispatch. In Phase 1 that subagent *is* the single (`anthropic`) auditor running
  the `bugs` prompt; Phase 2 makes it fan out across vendors and aggregate.

### The loop

1. **Pre-flight + lock.** Verify config + helpers + `jq`. Refuse if
   `.code4me/audit4me/.lock` exists; else create it. Mint `run_id` via
   `bash bin/audit4me-helpers.sh new-run-id`.
2. **Work set.** `bash bin/audit4me-helpers.sh work-set <config> <coverage>
   --vendor anthropic --category bugs [--paths …] [--changed-since …] [--force]`
   → one JSON line per file needing audit (with the re-audit `reason`). Truncate to
   `--max-files` / `config.max_files_per_run`. Announce count + reasons + rough cost.
3. **Per file (sequential in Phase 1):**
   1. Dispatch `code4me-audit-orchestrator` (Task tool) with `{file_path,
      content_hash, coverage_entry, config, run_id, vendor:"anthropic", model,
      category:"bugs"}`. Resolve `model` from `skills/code4me/references/vendor-models.yaml`.
   2. Validate the returned JSON (`outcome`, `findings`, `updated_coverage_entry`).
      Malformed → record `outcome:"failed"` for the file, continue.
   3. Persist, in this order (coverage last = the crash-safe commit marker): write
      each finding to `findings/<id>.md` (`alloc-finding-id`, Phase 1 frontmatter:
      `vendors_agreed:["anthropic"]`, `confidence:"low"`, `proposed_fix:false`,
      `status:"open"`); `event-append` one event for the file; then `coverage-update`
      with the returned entry.
   4. Box check: stop and commit partial state if cost / runtime / files box is hit.
4. **Summary.** Filter `audit-events.jsonl` by `run_id`, write
   `.code4me/audit4me/morning-report.md` (files audited, findings by severity,
   failures, partial-sweep verdict, surfaced `insight`s).
5. **Release the lock** (always, even on error). Return a one-line summary.

### Resume

Coverage is updated atomically per file, so an interrupted run resumes from the next
unaudited file on the next invocation — completed files are never re-audited. A stale
`.lock` from a crashed run is the only manual cleanup. If `audit-coverage.json` is ever
lost or corrupted, rebuild it from the events log with
`bin/audit4me-rebuild-coverage.sh <events> <coverage> [config]`.

## Files in this skill

```
skills/audit4me/
├── SKILL.md                                    # this file
├── schemas/
│   ├── config.schema.json                      # .code4me/audit4me-config.json
│   ├── audit-coverage.schema.json              # .code4me/audit4me/audit-coverage.json
│   ├── audit-event.schema.json                 # each line of .../audit-events.jsonl
│   └── finding-frontmatter.schema.json         # YAML frontmatter in findings/{id}.md
├── subagents/
│   └── code4me-audit-orchestrator.md           # per-file orchestrator (Phase 1: 1 vendor, 1 category)
└── references/
    ├── config-format.md                        # prose on the config schema
    ├── coverage-format.md                      # prose on the coverage + events model
    ├── finding-template.md                     # finding markdown shape (body + frontmatter)
    └── audit-prompt-bugs.md                    # Phase 1 — bugs audit prompt + RETURN SCHEMA
```

Helpers live at the plugin root: `bin/audit4me-helpers.sh` (outer-loop bookkeeping)
and `bin/audit4me-rebuild-coverage.sh` (coverage rebuild from the events log).

Phase 2+ will add:

```
skills/audit4me/references/
├── audit-prompt-security.md                    # Phase 5
└── ... (one per remaining category)
```

## Pointers

- **Design:** `docs/audit4me-design.md` — full design doc with architecture, data model, phasing plan, and open design questions.
- **Roadmap:** `docs/roadmap.md` — audit4me's entry under conditional/future items with trigger condition.
- **code4me integration:** `skills/code4me/SKILL.md` — the orchestrator that will receive `/audit4me-apply` dispatches in Phase 4.
