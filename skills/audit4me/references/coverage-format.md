# audit4me coverage tracking

audit4me's coverage state — what's been audited, by whom, against which rules version, at which content hash — lives in two files:

- **`.code4me/audit4me/audit-coverage.json`** — current state projection. Per-file entry; values describe the most recent audit pass per vendor. Schema: `schemas/audit-coverage.schema.json`.
- **`.code4me/audit4me/audit-events.jsonl`** — append-only history. One line per (vendor × file × category × run) audit pass. Schema: `schemas/audit-event.schema.json`.

The events log is the **source of truth.** The coverage JSON is derivable from it (replay all events and project) and exists as a cache for fast `/audit4me-status` queries without re-streaming the log.

## Why two files instead of one

Different access patterns. `/audit4me-status` needs random-access "what's the current state of file X?" — that's the coverage JSON's job; one disk read, one `jq` query. `/audit4me-run` needs append-only "record that this pass happened" — that's the events JSONL's job; no read-modify-write race against parallel passes.

The split also lets the events log carry detail the projection doesn't need (per-pass tokens, cost, duration, failure reasons) without bloating the lookup file.

## Re-audit triggers

A file enters the next run's work set when **any** of these fires:

1. **Content change.** Current `sha256` ≠ the `audited_hash` in the coverage entry for at least one vendor in `vendors_available`.
2. **Rule version change.** `rules_version_at_audit` in the coverage entry ≠ current `rules_version` in `.code4me/audit4me-config.json`.
3. **Periodic refresh.** `last_updated` in the coverage entry is older than `refresh_interval_days` ago.
4. **New vendor added.** A vendor was added to `vendors_available` since the last audit; existing coverage doesn't include it.
5. **New category enabled.** `default_categories` (or the explicit `--categories` flag) now requests categories absent from the file's `categories_covered`.

Plus an explicit override: `/audit4me-run --force-audit src/auth/` re-audits regardless of coverage state.

## Coverage levels

Computed from `vendors_available` (config) and the per-vendor `audited_hash == content_hash` check:

| Level | Meaning |
|---|---|
| `uncovered` | Zero vendors have audited this file at its current content hash. |
| `single-vendor` | Exactly one vendor has audited this file at current hash. Possible only when `len(vendors_available) >= 2`. |
| `agreement-covered` | Two or more vendors have audited this file at current hash. Agreement-based confidence is computable. |
| `full-covered` | All vendors in `vendors_available` have audited this file at current hash. Maximum dialectic surface for this deployment. |

In 2-vendor mode, `agreement-covered` and `full-covered` coincide. In 3-vendor mode they're distinct.

## How updates flow during a run

For each file the per-file orchestrator processes:

1. **Read** the existing coverage entry (or null if uncovered).
2. **Compute work** — which (vendor × category) pairs need to run, given coverage state + re-audit triggers + flags.
3. **Dispatch** vendor passes; collect responses.
4. **Append** one event per (vendor × category) pass to `audit-events.jsonl` with `outcome` and metrics.
5. **Compute** the updated coverage entry — refresh `content_hash`, `rules_version_at_audit`, per-vendor `audited_at` / `audited_hash` / `categories_covered` / `findings_count`, recompute `coverage_level`, set `last_updated`.
6. **Atomically write** the updated coverage entry into `audit-coverage.json` (read-modify-write via `jq` + `mv` for atomicity).
7. **Write** any new finding markdown files under `findings/`.

The atomic step 6 is the recovery invariant: at any interruption, `audit-coverage.json` reflects exactly the files that completed. The next run reads it and resumes from the first unaudited file.

## Resume semantics

If a run is interrupted (session crash, network failure, manual abort, box-hit), the partial state is:

- Coverage JSON: updated for every file that completed; untouched for files that didn't start or were in-flight.
- Events JSONL: complete entries for completed passes; in-flight passes have no entry (they didn't reach step 4).
- Findings: written for completed passes only.

The next `/audit4me-run` reads coverage, computes the work set from current triggers, and naturally skips completed files. **There's no "resume from where you left off" command** — resume IS just running the run command again. The coverage tracker handles it.

## Rebuilding coverage from events

If `audit-coverage.json` is lost or corrupted, it can be reconstructed:

```bash
# Conceptual — actual rebuild script lands in Phase 1
jq -s '
  group_by(.file) |
  map({
    key: .[0].file,
    value: { ... projection from events ... }
  }) |
  from_entries
' .code4me/audit4me/audit-events.jsonl > .code4me/audit4me/audit-coverage.json
```

This is the disaster-recovery story: the events log is authoritative; the projection is a cache.

## Storage growth

Coverage JSON grows O(files-in-scope). For 10,000 files with the schema above, expect ~5-10 MB JSON (depends on vendor count and category count per file). Acceptable; readable with `jq`.

Events JSONL grows O(audit-passes-ever). With 3 vendors × 5 categories × 200 files × weekly full sweep over a year, that's ~150,000 lines, maybe 50 MB. Use `jq` streaming for analysis. The audit-tool extension in Phase 5 will provide read-side helpers.

Rotation policy: none built in for v0.1. Manual archival of old events log lines (split by year) is fine if size becomes a concern.

## Gitignore policy

- `audit-events.jsonl` — **gitignore**. Per-machine state; merge conflicts are pointless.
- `audit-coverage.json` — **gitignore**. Same reason; can be rebuilt from events.
- `findings/*.md` — **commit (typically)**. The findings ARE the artefact; sharing them is the point. Exception: if a finding is sensitive (e.g., security finding before disclosure), keep it local.
- `.code4me/audit4me-config.json` — **commit (typically)**. See `config-format.md` for the per-user-vendor edge case.
