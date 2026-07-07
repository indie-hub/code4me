# audit4me — v0.1 design doc

**Status:** design — not yet built.
**Sibling to:** code4me (this plugin). audit4me starts life as a skill inside code4me (`skills/audit4me/`) with the option to extract to a standalone plugin later if it grows distinct.
**Last updated:** 2026-06-03.

---

## What audit4me is

A **batch, ambient, codebase-wide analyzer** that runs detached from any milestone. The user invokes it after normal hours (or any time on demand); it audits the codebase across multiple LLM vendors, computes per-finding confidence from inter-vendor agreement, and produces a morning report. High-confidence findings come with proposed fixes the user can apply via a single command; medium- and low-confidence findings are flagged for review only.

In one sentence: **audit4me proposes; code4me applies.** audit4me never edits production source. When the user accepts a proposed fix, it gets dispatched into code4me's existing Conversation Mode workflow (Developer + Combined Reviewer + PROVISIONAL tag), which means every applied fix goes through the same quality gates as any other code change.

## What makes it different from code4me's existing quality gates

code4me has `code-reviewer`, `verification`, `qa`, and `security-reviewer` subagents. They run **on a current diff**, as part of a milestone's quality-gate loop, against the change the developer just produced. They're synchronous: invoked, return, milestone advances.

audit4me runs on **the whole codebase**, **outside of any milestone**, **as a batch job that can take hours**. It's not gating new work — it's continuously surfacing existing latent issues. The audit categories overlap with the quality gates' concerns (bugs, security, code quality), but the framing is different: "find things we haven't fixed yet" vs. "is this new change OK to ship."

The two products share infrastructure: the dispatch log, the cross-vendor bridges (codex-bridge, deepseek-bridge), the hooks (protected tests, forbidden conditions, critical-write allowlist), Basic Memory integration, and the code-index layer. audit4me is a consumer of code4me's plumbing; it doesn't reimplement.

## Cross-vendor: 2-vendor minimum, configurable

**audit4me requires at least 2 vendors.** Multi-vendor agreement is the primary confidence signal; with only one vendor, there's no agreement to compute. Single-vendor mode is technically possible (and useful for `find but don't propose`) but it can never auto-propose fixes — that's an explicit constraint, not a deployment choice.

The available vendor set is per-project, declared in a new config file `.code4me/audit4me-config.json`:

```json
{
  "vendors_available": ["anthropic", "openai"],
  "default_categories": ["bugs", "security", "test_gaps"],
  "max_files_per_run": 50,
  "max_cost_usd_per_run": 5.00,
  "rules_version": "v0.1.0",
  "refresh_interval_days": 90,
  "scope": {
    "include": ["src/**", "tests/**"],
    "exclude": ["node_modules/**", "dist/**", "vendor/**", "**/*.min.js"]
  }
}
```

Three real configurations the design supports:

- **3-vendor (Anthropic + OpenAI + DeepSeek).** Maximum dialectic surface. Agreement is "≥2 of 3"; full-covered is "3 of 3". Most expensive; most defensible findings.
- **2-vendor (Anthropic + OpenAI, or Anthropic + DeepSeek, or OpenAI + DeepSeek).** The realistic floor for many corporate environments where data-residency, contract scope, or vendor approval limits available vendors. Agreement is "both agreed" (strictest case); there is no "full-covered" beyond that.
- **1-vendor.** Degenerate mode — findings get surfaced but **cannot be auto-proposed**, only flagged. Useful for projects that can't cross-check (e.g., air-gapped or budget-constrained) but want some signal.

The CHANGELOG and docs should make the 2-vendor floor prominent — it's the realistic operating mode, not an edge case.

## Architecture: execution model

audit4me is **skill-shaped, not script-shaped**. There is no standalone `bin/audit4me-run` executable. When the user invokes `/audit4me-run` from a Claude Code session, the main session itself runs the loop — driven by the `audit4me` skill's SKILL.md.

The split between "deterministic" and "judgment" work matters:

- **Bookkeeping is deterministic** — read coverage, compute work set, hash files, update coverage, append events log, write findings markdown, aggregate end-of-run report. The main session runs these as Bash invocations with `jq`. No LLM thinking between Bash calls.
- **Per-file audit decisions are judgment** — which categories apply to this file, which vendors per category, how to handle partial failures, how to aggregate findings within a file. The main session dispatches a `code4me-audit-orchestrator` subagent per file via the Task tool, the same way code4me's main orchestrator dispatches role-specific subagents.

### Why this shape

Two design pulls in tension:

- An LLM-driven orchestrator running across hundreds of files for hours would burn tokens on coordination decisions that are mostly mechanical (read JSON, set-difference, write JSON, loop).
- A pure bash script with no LLM at the file level would lose the per-file judgment (which categories apply, asymmetric vendor pairings, partial-failure handling).

The per-file orchestrator gets the symmetry with code4me — per-file feels like a Conversation Mode-shaped flow: classify, compose team, dispatch, aggregate, close — without the coordination overhead of a run-level orchestrator. The outer loop stays scriptable; the inner judgment stays LLM-driven.

### What happens when you type `/audit4me-run`

The main session, loaded with the audit4me skill, does:

1. **Bash:** `jq` over `.code4me/audit4me/audit-coverage.json` to list files needing audit, filtered by scope flags. Write `/tmp/audit4me-worklist.jsonl`.
2. **Loop over worklist** (sequential or parallel batches up to `concurrency_cap`):
   1. **Task tool:** dispatch `code4me-audit-orchestrator` subagent with `{ file_path, file_hash, coverage_entry, config }`.
   2. **Subagent returns:** `{ findings[], updated_coverage_entry, insight? }`.
   3. **Bash:** write `findings/<id>.md`; `jq`-update `audit-coverage.json`; append `audit-events.jsonl`.
3. **Bash:** aggregate events for this run; compute summary metrics.
4. **Inline LLM call** (single Haiku turn or main-session turn): cluster findings into themes; flag any cross-file patterns worth surfacing as Basic Memory candidates.
5. **Bash:** write `morning-report.md`.
6. **Return:** one-line summary to the user.

Steps 1, 2.3, 3, 5 are Bash. Step 2.1 is the Task tool. Step 4 is one focused LLM call. The main session's "thinking" happens at steps 4 and 6 (plus a tiny amount of "did this subagent return well-formed JSON?" validation between dispatches); the rest is bash.

### What the per-file orchestrator does

`subagents/code4me-audit-orchestrator.md` is the per-file judgment unit. Input/output contract:

- **Input:** `{ file_path, content_hash, coverage_entry, config }` where `coverage_entry` is the file's current entry from `audit-coverage.json` (or `null` if uncovered) and `config` is the parsed `audit4me-config.json`.
- **Output:** `{ findings: [Finding], updated_coverage_entry: CoverageEntry, insight: string | null }`.

Inside, the subagent:

1. Decides which categories apply to this file. Default = config defaults; can prune if extension/path obviously doesn't need a category (e.g., no security audit on a `.css` file).
2. For each (category × vendor) pair in scope, dispatches the audit pass. Claude vendor uses inline references like `audit-prompt-bugs.md`; OpenAI uses `codex-bridge`; DeepSeek uses `deepseek-bridge`.
3. Aggregates within-file: dedupes findings flagged by multiple vendors into single multi-vendor entries; preserves each vendor's verbatim quotes.
4. Applies confidence scoring per finding (the four signals from §Confidence scoring).
5. Filters by threshold; produces output.
6. Optionally returns an `insight` field — a short observation worth surfacing run-wide (e.g., "this file has 5 findings; consider refactoring it whole rather than patching individually").

The orchestrator is bounded to one file. It does not see other files; it does not maintain run-state. The outer loop handles aggregation across files.

### Interactive vs scheduled

The same skill code runs in two paths:

- **Interactive.** User opens a Claude Code session, types `/audit4me-run`. Their session *is* the audit until the run completes or hits a box. They can watch progress live.
- **Scheduled.** `mcp__scheduled-tasks__create_scheduled_task` fires at e.g. 22:00 daily. A fresh headless Claude session spawns, loads the audit4me skill, runs the same loop. The session ends when the loop completes; the morning report is in `.code4me/audit4me/morning-report.md` when the user opens their next session.

Both paths produce identical artifacts. The only difference is what spawned the session.

### Resume semantics

`audit-coverage.json` is updated atomically after each file completes. If the run is interrupted (session crash, network failure, manual abort), the next `/audit4me-run` reads coverage, sees which files completed, and picks up from the next uncovered file. No half-state, no re-audit of completed files.

This is why the outer-loop discipline matters: every Bash update to coverage is one atomic write away from a recoverable state. An LLM orchestrator running between files (instead of bash) would risk inconsistent state if it crashed mid-decision.

### Concurrency model

Two layers:

- **Per-file orchestrator concurrency.** The main session dispatches per-file orchestrators in batches up to `concurrency_cap` (default 3). Higher caps run more files in parallel but multiply token burn rate and may hit vendor rate limits.
- **Within-orchestrator concurrency.** Each per-file orchestrator can fan out its vendor passes in parallel (Claude inline + codex-bridge + deepseek-bridge). This is bounded by vendor rate limits but is the dominant time-saver.

Wall clock ≈ `(total_files / concurrency_cap) × per-file-orchestrator-duration`. For 200 files with cap=3 and ~90s per per-file orchestrator, that's ~100 minutes — not 4 hours.

A lock file at `.code4me/audit4me/.lock` prevents concurrent runs from clobbering coverage.

## The data model

Two files under `.code4me/audit4me/`:

### `audit-coverage.json` — current state projection

One entry per file in scope. Coverage is multi-vendor and tied to current content hash.

```json
{
  "src/auth/login.cs": {
    "content_hash": "sha256:abc123...",
    "vendors": {
      "anthropic": {
        "audited_at": "2026-06-01T22:14:03Z",
        "audited_hash": "sha256:abc123...",
        "categories_covered": ["bugs", "security"],
        "findings_count": 2
      },
      "openai": {
        "audited_at": "2026-06-01T22:18:47Z",
        "audited_hash": "sha256:abc123...",
        "categories_covered": ["bugs", "security"],
        "findings_count": 2
      }
    },
    "rules_version_at_audit": "v0.1.0",
    "coverage_level": "agreement-covered",
    "last_updated": "2026-06-01T22:18:47Z"
  }
}
```

`coverage_level` is computed from `vendors_available` (from config) and the per-vendor `audited_hash == content_hash` check. Possible values:

- `uncovered` — 0 vendors have audited at the current hash.
- `single-vendor` — 1 vendor has audited at current hash; only possible when `len(vendors_available) ≥ 2` (otherwise it'd be full-covered).
- `agreement-covered` — ≥2 vendors have audited at current hash. Agreement-based confidence is computable.
- `full-covered` — `len(vendors_available)` vendors have audited at current hash. Maximum dialectic surface for this deployment.

Note: `agreement-covered` and `full-covered` are the same level when `vendors_available` is exactly 2.

### `audit-events.jsonl` — append-only history

One line per (vendor × file × category × run). The source of truth; `audit-coverage.json` is derivable from this.

```jsonl
{"ts":"2026-06-01T22:14:03Z","vendor":"anthropic","model":"claude-sonnet-4-6","file":"src/auth/login.cs","content_hash":"sha256:abc123","category":"bugs","duration_ms":4720,"findings":2,"tokens_in":3204,"tokens_out":891,"cost_usd":0.018,"rules_version":"v0.1.0"}
{"ts":"2026-06-01T22:18:47Z","vendor":"openai","model":"gpt-5.4","file":"src/auth/login.cs","content_hash":"sha256:abc123","category":"bugs","duration_ms":3890,"findings":2,"tokens_in":3115,"tokens_out":702,"cost_usd":0.024,"rules_version":"v0.1.0"}
```

### `findings/{finding_id}.md` — per-finding markdown

One markdown file per accepted finding (i.e., after multi-vendor agreement filter, before user review). The file contains:

- Metadata (id, severity, file, line range, category, confidence)
- The finding itself (what's wrong, why, evidence)
- Each vendor's perspective (which vendors found this, with verbatim quotes from their responses)
- A proposed fix (if confidence ≥ threshold)
- A failing test (if the auditor could write one — see "Confidence" below)
- Apply-readiness: whether `/audit4me-apply <finding_id>` would currently succeed

These are the artifacts the user reviews in the morning.

## Re-audit triggers

A file enters the next run's work set when ANY of these fires:

1. **Content change.** `current_hash ≠ audited_hash` for at least one required vendor.
2. **Rule version change.** `rules_version_at_audit ≠ current rules_version`. When audit prompts materially change (a new bug pattern, a new security check), bump the rules version; all files become stale for re-audit.
3. **Periodic refresh.** Files audited longer ago than `refresh_interval_days` (default 90).

Plus an explicit override: `--force-audit src/auth/`.

## Confidence scoring

Confidence per finding is a composite from four signals:

| Signal | Weight | How it's measured |
|---|---|---|
| **Multi-vendor agreement** | Highest | Did all required vendors (per `vendors_available`) independently flag this same finding? |
| **Reproducibility** | High | Could the auditor write a failing test demonstrating the bug? If yes, the test path is included in the finding file. |
| **LSP / linter cross-check** | Medium | For type-related findings: does LSP independently flag? For style: does the linter flag? |
| **Test coverage at the affected line** | Low | Is the affected line covered by existing tests? Bugs in tested code are higher-confidence than bugs in untested code (where intent is ambiguous). |

The confidence threshold to auto-propose a fix is:

- **All `vendors_available` agreed on the finding** (strict — `agreement-covered` covers the minimum case where ≥2 vendors agree, but for "propose fix" we require unanimous among available vendors).
- **AND** the auditor wrote a failing test.
- **AND** the proposed fix doesn't touch any file in `.code4me/protected-tests.txt` (test integrity is not overridable).
- **AND** severity is at least `MAJOR` (NIT-level proposals are noise; MAJOR-and-above is the proposing threshold).

Findings below the threshold are still surfaced — they just don't get a proposed fix attached. The user reviews them manually.

## The five audit categories

Each category has its own audit prompt and its own per-finding RETURN SCHEMA. Common envelope (id, severity, file, line range, summary, evidence, vendor perspectives) plus category-specific fields.

| Category | Prompt focus | Category-specific RETURN SCHEMA fields |
|---|---|---|
| **bugs** | Logic errors, off-by-one, missing null checks, race conditions, state-machine violations | `reproduction_steps`, `failing_test_path` (if writeable), `affected_inputs` |
| **security** | Injection paths, secrets in code, weak crypto, missing input validation, SSRF, auth bypass | `cwe_id` (where applicable), `attack_vector`, `mitigation` |
| **performance** | N+1 queries, sync I/O on hot paths, allocation in loops, memory leaks, complexity drift | `profiling_evidence` (if available), `estimated_impact`, `complexity_class` |
| **maintainability** | Code smells, dead code, complexity threshold breaches, naming clarity, layer violations | `refactoring_suggestion`, `complexity_metric` |
| **test_gaps** | Code paths not exercised by tests, edge cases not covered, mutation-testing-style holes | `uncovered_lines`, `proposed_test_cases` |

Categories are independent — a file can be `agreement-covered` for bugs but `uncovered` for performance. Coverage tracking is per-category.

## Integration with code4me

The load-bearing piece. audit4me proposes; code4me applies.

### Applying a finding: `/audit4me-apply <finding_id>`

When the user invokes this:

1. audit4me reads `findings/{finding_id}.md`.
2. Validates the finding still applies (file hasn't changed since the audit; protected tests still satisfied; etc.).
3. Constructs a Conversation Note from the finding: the bug description becomes "what's changing," the failing test becomes "how to know it worked."
4. Dispatches a code4me Conversation Mode workflow with the Conversation Note + the failing test + the proposed fix as initial input.
5. The Conversation Mode dispatch runs the normal gates (Developer + Combined Reviewer + PROVISIONAL tag with a promote-or-revert deadline).
6. The user promotes-or-reverts as usual.

This means **every applied fix gets a smoke test, a Combined Reviewer pass, and a PROVISIONAL deadline.** The audit's confidence rating doesn't bypass the quality loop; it just decides whether the fix is worth proposing at all.

If the finding's category triggers auto-escalation (e.g., a security finding touching auth code is `authentication_or_sensitive_data` symptom), the Conversation Mode workflow auto-escalates to Standard, which means Tech Spec + Spec-to-Test + full quality gates. The escalation is unchanged from code4me's existing rules.

### Why this division is right

- audit4me is read-only on the project. Production source modification only happens through code4me's existing dispatch pipeline.
- The audit doesn't bypass test protection, forbidden conditions, or the critical-write allowlist. Hooks fire on the fix-application step (as they would for any Conversation Mode dispatch).
- A user can ignore findings — they sit in `findings/{id}.md` until acted on. There's no auto-application; everything is explicit user consent via `/audit4me-apply`.

## Slash commands

| Command | Purpose |
|---|---|
| `/audit4me-config` | Interactive setup: declare `vendors_available`, scope patterns, category preferences. One-time per project. Writes `.code4me/audit4me-config.json`. |
| `/audit4me-status` | Read-only coverage report. Shows files audited by vendor, per-category coverage, pending work set, estimated cost for next full sweep. No audits run. |
| `/audit4me-run [--changed-since 24h \| --paths X \| --full] [--max-cost N] [--max-files M] [--vendors X,Y]` | Execute audits. Computes work set from coverage + flags, dispatches to vendors, validates findings, updates coverage. |
| `/audit4me-apply <finding_id>` | Take a finding's proposed fix and dispatch into code4me Conversation Mode for application. |
| `/audit4me-findings [--severity X --confidence high --category bugs --status open]` | Filter and browse findings. Read-only. |
| `/audit4me-dismiss <finding_id> [--reason ...]` | Mark a finding as won't-fix (intentional code, false positive, out-of-scope). Reason is required and logged for audit. |

The existing `/code4me-audit` (dispatch-log analytics) gets renamed to **`/code4me-dispatch-audit`** to disambiguate. The rename is part of audit4me's v0.1 ship.

## Cost and time discipline

Running an audit across a real codebase is expensive. Three independent boxes:

- **Time-box.** `--max-runtime 4h` caps wall-clock. When hit, partial coverage is committed (findings written for files that completed; coverage.json reflects the partial state); the run exits with an "incomplete sweep" verdict.
- **Cost-box.** `--max-cost 5.00` caps USD. Computed from token counts × per-vendor pricing. When hit, same partial-commit semantics.
- **Files-box.** `--max-files 50` caps file count. Useful for incremental runs.

Default mode is incremental: `--changed-since 24h` runs on files modified in the last day. Full sweeps are weekly or on-demand, not daily. The "what was audited" status command surfaces when a full sweep is overdue.

Concurrency is covered in §Architecture: execution model → Concurrency model. Short version: per-file orchestrators dispatched in batches up to `concurrency_cap` (default 3); vendor passes inside each orchestrator fan out in parallel; the lock file at `.code4me/audit4me/.lock` prevents concurrent runs.

## Phasing

Five cuts, each independently shippable.

### Phase 1 — single-vendor coverage tracking + minimal per-file orchestrator

Validates the architecture end-to-end (outer loop + per-file orchestrator) with the simplest possible interior. ~1-2 days.

- Define `audit-coverage.json` + `audit-events.jsonl` + `findings/{id}.md` schemas.
- Implement `/audit4me-config` interactive setup.
- Implement `/audit4me-status` (read-only).
- Build `skills/audit4me/SKILL.md` with the outer-loop instructions (worklist computation, batch dispatch, atomic coverage update).
- Build `subagents/code4me-audit-orchestrator.md` — minimal version: single vendor (Anthropic), single category (bugs). No category selection logic yet; no multi-vendor aggregation. The orchestrator's input/output contract is what matters at this phase.
- Implement `/audit4me-run --vendor anthropic --paths src/` exercising the full pipeline: outer-loop dispatch → per-file orchestrator → finding return → coverage atomic update.
- Two test passes: an initial full sweep, then a `--changed-since 24h` incremental run. Verify coverage reflects both correctly; verify a mid-run interrupt resumes cleanly from the next uncovered file.

No proposed fixes; no multi-vendor; just findings + the coverage tracker + the per-file orchestrator contract working.

### Phase 2 — multi-vendor agreement (the real per-file orchestrator)

Adds the dialectic. The per-file orchestrator gets its full shape here. ~1-2 days.

- Extend `code4me-audit-orchestrator` to dispatch to multiple vendors per file via `codex-bridge` and `deepseek-bridge`. Vendor passes fan out in parallel inside the orchestrator (see §Architecture → Concurrency model).
- Add category-selection logic to the orchestrator (config defaults + per-file pruning hooks — e.g., no security audit on `.css` files).
- Implement within-file aggregation: dedupe findings flagged by multiple vendors into single multi-vendor entries; preserve verbatim per-vendor quotes.
- Implement coverage-level computation (`uncovered` / `single-vendor` / `agreement-covered` / `full-covered`) tied to `vendors_available`.
- Confidence-scoring algorithm using multi-vendor agreement (one of the four signals).
- `/audit4me-findings` filtering by confidence level.

Resolve the subagent-nesting open question (see §Open design questions) **before** starting this phase — if Claude Code supports two-level Task-tool nesting, the orchestrator can dispatch per-category Claude subagents in parallel; if not, categories run sequentially in the orchestrator's own thread.

Findings get confidence labels; high-confidence ones are visible but not yet auto-proposed.

### Phase 3 — failing-test generation

Makes "propose a fix" meaningful. ~1 day.

- For each high-confidence finding in the `bugs` category, the auditor writes a failing test demonstrating the bug.
- The test is included in the finding's `findings/{id}.md` as a separate code block.
- Confidence threshold for "propose fix" now requires `failing_test_path` populated.

### Phase 4 — `/audit4me-apply` integration

Hooks audit findings into code4me's Conversation Mode. ~half day.

- `/audit4me-apply <finding_id>` reads the finding, constructs a Conversation Note, dispatches Conversation Mode with the failing test as the smoke test.
- code4me's Developer + Combined Reviewer run as usual.
- Auto-escalation triggers (auth, schema, etc.) bump to Standard automatically.
- `/audit4me-dismiss <finding_id>` for won't-fix flow.

End-to-end: audit → apply → quality-gate → promote-or-revert.

### Phase 5 — additional categories + audit-tool integration

Incremental. ~2-3 days total.

- Security audit prompt + RETURN SCHEMA (`cwe_id`, `attack_vector`).
- Performance, maintainability, test-gaps audits added one at a time.
- Audit-tool extension: `bin/code4me-audit-dispatch-log` gets a section reporting audit4me activity (findings per category, vendor agreement rate, apply-vs-dismiss rate).
- Probes covering each category's typical findings.

## Open design questions

Four things not yet decided; nail down before the relevant phase build.

1. **Coverage granularity.** File-level is simple and sufficient. Function/symbol-level is finer but requires LSP integration to enumerate symbols. Recommendation: start file-level; promote to symbol-level in Phase 5+ if false-positive re-audits (file changed but only imports moved) become real noise. *Decide before Phase 1.*
2. **Multi-vendor disagreement handling.** When `vendors_available` = 3 and 2 of 3 agree on a finding but the third disagrees, what happens? Options: (a) accept as agreement-covered with confidence rating reflecting the disagreement; (b) require unanimous; (c) record the dissent in the finding markdown but still allow auto-propose. Recommendation: (a) for "agreement-covered" + (c) recording dissent. Strict unanimous threshold makes the 2-vendor case unworkable. *Decide before Phase 2.*
3. **Persisted findings vs. derived.** When a file changes, are existing findings against its prior content invalidated and re-audited, or do we try to map findings forward (line shifts, etc.)? Recommendation: simple — invalidate. Findings reference a specific content hash; when the hash changes, the finding is stale until re-audit confirms. *Decide before Phase 1.*
4. **Subagents-of-subagents.** The per-file `code4me-audit-orchestrator` may want to dispatch one Claude subagent per audit category in parallel (e.g., for a Python API file: dispatch a bugs auditor, a security auditor, and a performance auditor concurrently). That's two levels of Task-tool nesting: main session → per-file orchestrator → category-specific auditor. If Claude Code supports this nesting depth cleanly, the orchestrator gets the cleanest within-file parallelism. If not, the orchestrator runs audit categories sequentially in its own thread (slower per file but bounded and predictable; cross-vendor passes via `codex-bridge` / `deepseek-bridge` are skill-shaped calls inline from the orchestrator, not nested subagents, so those still parallelize regardless). *Decide before Phase 2; ear-marked as the most consequential open question because it shapes the orchestrator's prompt.* **Resolved (provisional) — see `docs/decisions/0001-subagent-nesting.md`:** subagents receive no agent-spawning tool, so nesting is unavailable. Phase 2 uses inline cross-vendor subprocess bridges (parallel) and moves any category fan-out to the main loop; confirm via `probes/audit4me/03-subagent-nesting.md` in the CLI.

## Why this isn't urgent

audit4me is genuinely useful and shaped well now, but it's also a separate product from code4me's core orchestrator. The current code4me 0.12.0-dev surface still needs live-testing against real milestones. Building audit4me before code4me is soaked would risk both — audit4me's value is amplified by code4me's `/audit4me-apply` integration, and that integration is best validated against a code4me that's already known to work.

Recommendation: ear-tag this design doc as a v0.13+ target. Soak code4me v0.12 against real milestones first. When code4me feels stable for ~2 weeks of real use, then start Phase 1 of audit4me.

## Where this fits in the roadmap

audit4me as a whole is added to `docs/roadmap.md` as a conditional item — trigger condition: code4me v0.12.0 has 2 weeks of clean real-milestone usage. Don't start audit4me before that; soak signals are more important than feature velocity right now.

This design doc is the spec audit4me's build will implement. Update it as the design firms up; treat the doc as canonical.

**See also:** `docs/audit4me-build-plan.md` — the operational build plan with per-phase sub-tasks, gates between phases, open decisions, and the build rhythm. This design doc is the "what"; the build-plan doc is the "how and when".

---

## Appendix A — naming and the `/code4me-audit` rename

The existing `/code4me-audit` (dispatch-log analytics — `bin/code4me-audit-dispatch-log`) gets renamed to **`/code4me-dispatch-audit`** when audit4me ships. The rename:

- `commands/code4me-audit.md` → `commands/code4me-dispatch-audit.md`
- README cheat-sheet entry updated
- Any documentation referring to `/code4me-audit` updated to `/code4me-dispatch-audit`
- Add a transitional note in CHANGELOG: "v0.13: `/code4me-audit` renamed to `/code4me-dispatch-audit` to disambiguate from `/audit4me-*` commands."

The new `/audit4me-*` commands take the unqualified "audit" namespace.

## Appendix B — config-file schema (v0.1)

```json
{
  "$schema": "audit4me-config-v1",
  "vendors_available": ["anthropic", "openai"],
  "default_categories": ["bugs", "security", "test_gaps"],
  "max_files_per_run": 50,
  "max_cost_usd_per_run": 5.00,
  "max_runtime_per_run": "4h",
  "rules_version": "v0.1.0",
  "refresh_interval_days": 90,
  "scope": {
    "include": ["src/**", "tests/**"],
    "exclude": ["node_modules/**", "dist/**", "vendor/**", "**/*.min.js"]
  },
  "confidence_thresholds": {
    "propose_fix_min_severity": "MAJOR",
    "propose_fix_requires_failing_test": true,
    "propose_fix_requires_all_available_vendors_agreed": true
  },
  "apply_integration": {
    "dispatch_mode": "conversation",
    "auto_escalate_categories": ["security"],
    "comment": "category=security dispatches as Standard (Tech Spec + full quality gates) regardless of size — auth findings shouldn't go through Conversation Mode's lightweight gates"
  }
}
```

## Appendix C — example finding markdown

```markdown
# Finding F-2026-06-01-0023

**Severity:** MAJOR
**Category:** bugs
**File:** src/auth/login.cs
**Line range:** 87-92
**Confidence:** agreement-covered (anthropic + openai)
**Content hash:** sha256:abc123...
**Audited at:** 2026-06-01T22:18:47Z
**Status:** open

## Summary

The `ValidatePassword` method allows a one-character bypass when the password parameter is exactly the string `null` (literal four-character string, not a null reference). Combined with the trim-and-compare on line 89, an empty-after-trim input matches a previously-set-then-cleared password.

## Evidence

### Anthropic's finding (verbatim excerpt)

> Line 89: `if (input.Trim() == storedHash.Substring(0, 4)) { return true; }` — the truncation to first 4 characters means any input whose trimmed prefix matches any 4-char prefix of the stored hash returns true. With a known 4-char prefix (which is leaked by the password reset email), an attacker bypasses with that prefix as input.

### OpenAI's finding (verbatim excerpt)

> Validate-password path on line 87-92 has a substring comparison that is insufficient. The Substring(0,4) call truncates the comparison to four characters, meaning any input matching the first 4 of the hash succeeds. Plus the Trim() removes whitespace; a 4-char-with-leading-spaces input passes.

## Confidence signals

- **Multi-vendor agreement:** anthropic + openai (both available vendors agreed) ✓
- **Failing test written:** `tests/auth/test_login_bypass_finding_0023.cs` (included below) ✓
- **LSP cross-check:** N/A (logic finding, not type)
- **Test coverage at line:** the affected lines are covered by `test_login_happy_path`, but the bypass case isn't ✓

All four signals positive → confidence: **HIGH** → propose-fix eligible.

## Proposed fix

```csharp
// before
if (input.Trim() == storedHash.Substring(0, 4)) { return true; }

// after
if (PasswordHasher.Verify(input, storedHash)) { return true; }
```

Removes the truncation bypass; uses the project's existing `PasswordHasher.Verify` (which already does constant-time comparison against the full hash).

## Failing test

```csharp
[Fact]
public void Test_ValidatePassword_RejectsTruncationBypass()
{
    var login = new LoginService();
    login.SetPassword("test_user", "the-real-password");
    var storedHash = login.GetHashForUser("test_user");
    var truncationAttempt = storedHash.Substring(0, 4);
    Assert.False(login.ValidatePassword("test_user", truncationAttempt));
}
```

## Apply readiness

- File unchanged since audit ✓
- Protected tests unaffected by proposed fix ✓
- Auto-escalation: yes (category=bugs touching auth = Standard, not Conversation) — `/audit4me-apply F-2026-06-01-0023` will dispatch Standard Mode with this fix.
```
