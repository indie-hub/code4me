# audit4me config file format

The audit4me configuration lives at `.code4me/audit4me-config.json` and is the canonical declaration of *which vendors this project can use, what's in scope, how much to spend, and how strict the confidence threshold is.* The schema is `schemas/config.schema.json` — what follows is the prose explanation of each field and how the values interact.

## Minimum viable config

```json
{
  "$schema": "audit4me-config-v1",
  "vendors_available": ["anthropic", "openai"],
  "default_categories": ["bugs"],
  "rules_version": "v0.1.0",
  "scope": {
    "include": ["src/**"]
  }
}
```

Everything else has sensible defaults. The four required fields are: `$schema`, `vendors_available`, `default_categories`, `rules_version`, `scope.include`.

## `vendors_available` — the vendor floor

audit4me's confidence signal depends on multi-vendor agreement. Three legal shapes:

- **3-vendor** (`["anthropic", "openai", "deepseek"]`) — maximum dialectic surface. Agreement is "≥2 of 3"; full-covered is "3 of 3". Most expensive; most defensible findings.
- **2-vendor** (any pair) — the realistic floor for corporate environments where data-residency, contract scope, or vendor approval limits the available set. Agreement = both agreed. There is no "full-covered" beyond that.
- **1-vendor** (single vendor) — find-only mode. Findings get surfaced but **cannot be auto-proposed** (no agreement to compute). Useful for air-gapped or budget-constrained projects that want some signal.

The 2-vendor floor is the realistic operating mode, not an edge case. The CHANGELOG and `docs/audit4me-design.md` make this prominent.

## `default_categories` — what runs by default

When the user invokes `/audit4me-run` without explicit category flags, these categories run. Five legal values: `bugs`, `security`, `performance`, `maintainability`, `test_gaps`. Each has its own audit prompt and RETURN SCHEMA (see `docs/audit4me-design.md` §"The five audit categories" — built incrementally per the phasing plan, with `bugs` first in Phase 1 and the others added in Phase 5).

Recommended starting set: `["bugs"]` while audit4me is in Phase 1. Expand as later phases add the other categories.

## `rules_version` — re-audit trigger

Semver of the audit prompts themselves. When the prompt text materially changes (a new bug pattern, a new security check, a tightened threshold), bump this version. All files become stale for re-audit at the next run.

Default at Phase 0: `v0.1.0`. Bump to `v0.1.1` for patch-level prompt tweaks; `v0.2.0` when a new category lands or a category's prompt is rewritten.

## `scope` — what to audit

`include` is required; `exclude` is optional. Both take arrays of glob patterns evaluated relative to project root. `exclude` is applied after `include`.

Common exclusions to consider:

- `node_modules/**`, `vendor/**`, `dist/**`, `build/**`, `target/**` — third-party / generated
- `**/*.min.js`, `**/*.bundle.js` — minified output
- `**/__snapshots__/**`, `**/*.snap` — test snapshots (low audit value)
- `**/migrations/**` — database migrations (typically not auditable for the categories audit4me targets)

A file in scope = matches at least one `include` glob AND does not match any `exclude` glob.

## Cost and time boxes

Three independent caps, all soft (they trigger partial-commit, not abort):

- **`max_files_per_run`** (default 50) — file count cap. Useful for incremental runs where you want bounded duration.
- **`max_cost_usd_per_run`** (default $5.00) — USD cap, computed from token counts × per-vendor pricing.
- **`max_runtime_per_run`** (default "4h") — wall-clock cap. Format: `Ns` / `Nm` / `Nh`.

When any box hits, the run commits coverage for files that completed and exits with an "incomplete sweep" verdict. The next run picks up from the first unaudited file via the coverage tracker.

## `refresh_interval_days`

Default 90. Files audited longer ago than this enter the work set even when content is unchanged. Catches drift from changes in surrounding context (dependencies updated, threat landscape shifted) that don't change the file itself but change what's worth flagging.

## `concurrency_cap`

Default 3. Max number of per-file audit orchestrators dispatched in parallel during a run. Higher caps run more files in parallel but multiply token burn rate and may hit vendor rate limits. Tune based on your rate-limit headroom and the size of the codebase.

## `confidence_thresholds` — when fixes get proposed

A finding becomes "fix-proposed" (vs. "review only") when:

- `severity >= propose_fix_min_severity` (default `MAJOR` — NIT and MINOR are surfaced for review only)
- `failing_test_path` populated, if `propose_fix_requires_failing_test` is true (default true)
- All `vendors_available` agreed, if `propose_fix_requires_all_available_vendors_agreed` is true (default true — unanimous within available vendors)

These are independent gates; all must pass for `proposed_fix: true` in the finding frontmatter.

Loosening any of these is a deliberate posture choice — e.g., a small project might set `propose_fix_min_severity: MINOR` to lower the bar; a high-stakes codebase might leave defaults strict.

## `apply_integration` — what `/audit4me-apply` does

When the user accepts a proposed fix via `/audit4me-apply <finding_id>`, audit4me hands the fix off to code4me's Conversation Mode workflow:

- **`dispatch_mode`** (default `conversation`) — default code4me weight used for the dispatched fix. Auto-escalation triggers in code4me may override per finding (e.g., a security finding touching auth code escalates to Standard automatically — that's a code4me rule, not an audit4me config).
- **`auto_escalate_categories`** (default `["security"]`) — findings in these categories dispatch as Standard (full Tech Spec + quality gates) regardless of `dispatch_mode`. Reason: security findings shouldn't go through Conversation Mode's lightweight gates.

## What's NOT in this file

- Per-finding state (open/applied/dismissed) — that's in each `findings/{id}.md` frontmatter.
- Coverage state — that's in `audit-coverage.json`.
- Audit events — that's in `audit-events.jsonl`.
- Per-vendor pricing tables — that's a runtime concern wired through `skills/code4me/references/vendor-models.yaml` and the bridge skills.

This file is *configuration* — it changes rarely. The other files are *state* — they change every run.

## Editing the file

`.code4me/audit4me-config.json` is human-editable JSON. After editing, run `/audit4me-status` to confirm the new config parses and the scope resolves to the file set you expect. There's no schema migration tool yet — if the schema version bumps, edit the file by hand (the migration will be tiny in v0.1).

Gitignore policy: the file should generally be committed (so all collaborators audit against the same vendors, scope, and rules). The exception is when `vendors_available` reflects per-user availability (e.g., one user has DeepSeek, another doesn't). In that case, commit a `audit4me-config.example.json` and have each contributor copy + customize.
