---
description: Read-only audit4me coverage report. Parses .code4me/audit4me-config.json + .code4me/audit4me/audit-coverage.json (if present) and surfaces: scope file count, per-coverage-level breakdown, stale-by-refresh count, rules-version drift, findings on disk by status, estimated next-run cost. Does NOT dispatch any audits and does NOT modify any files. In Phase 0, coverage is always empty (no audits have run yet); the report mostly validates the wiring.
---

Produce a read-only status snapshot of audit4me at the project root. **Do not modify any files. Do not dispatch any audits or subagents.**

Read `skills/audit4me/SKILL.md` §"`/audit4me-status` — read-only coverage report" and `skills/audit4me/references/coverage-format.md` for the full procedure and data-model semantics.

## Procedure

1. **Pre-flight.**
   - Confirm `.code4me/audit4me-config.json` exists. If not, surface: *"No audit4me config found at `.code4me/audit4me-config.json`. Run `/audit4me-config` first."* and stop.
   - Parse the config via Bash + `jq`. If parse fails, surface the error and stop.

2. **Resolve scope.** Use Bash + globs (or `find` + `grep`) to enumerate files matching `scope.include` minus `scope.exclude`. Count them.

3. **Read coverage.**
   - If `.code4me/audit4me/audit-coverage.json` exists, parse it and extract per-file entries.
   - If not (Phase 0 default; Phase 1+ writes it after first run), the report shows "no audit history" gracefully — coverage counts are all zero, `uncovered` count equals `in_scope` count.

4. **Compute report fields.**
   - **In scope** — count from step 2.
   - **Audited (any vendor, current rules)** — files in coverage with at least one vendor entry where `rules_version_at_audit == config.rules_version`.
   - **By coverage level** — counts of `uncovered` / `single-vendor` / `agreement-covered` / `full-covered`. In Phase 0, `uncovered` = in-scope count; others zero.
   - **Stale by refresh** — files where `last_updated` is older than `refresh_interval_days` ago.
   - **Behind current rules_version** — files where `rules_version_at_audit < config.rules_version`.
   - **Findings on disk** — count files in `.code4me/audit4me/findings/*.md`. Read each frontmatter for `status`; count per status.

5. **Estimated next-run cost.** Rough placeholder estimate for "what would a full sweep cost":
   - Files needing audit = `in_scope - audited_at_current_rules`
   - Per-file estimate ≈ `5000 tokens × vendor_count × category_count` (placeholder; Phase 1 locks real numbers from observed audit-pass costs)
   - Multiply by per-vendor pricing read inline from `skills/code4me/references/vendor-models.yaml`
   - Surface as a range, not a point estimate

6. **Emit the report** as a single markdown block with the template below.

If any read fails (corrupt JSON, missing file mid-operation, etc.), note it in the report but continue with the rest. Phase 0's job here is to confirm wiring; resilience matters more than completeness.

## Output template

```markdown
# audit4me status — {ISO8601}

## Configuration
- Vendors available: {list}
- Default categories: {list}
- Rules version: {version}
- Refresh interval: {N} days
- Concurrency cap: {N}

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
- Stale by refresh interval (>{N}d): {S} files
- Behind current rules_version: {R} files

## Findings on disk ({total})
- open: {open}
- applied: {applied}
- dismissed: {dismissed}
- stale: {stale}

## Next-run estimate (full sweep)
- Files needing audit: {N}
- Estimated cost: ${low}-${high}
- Estimated wall clock: {minutes-hours range}

## Notes
- audit4me is currently in Phase 0 (config + status only). The actual audit dispatch
  (`/audit4me-run`) lands in Phase 1. See `docs/audit4me-design.md` for the phasing plan.
- Coverage will populate after the first `/audit4me-run` invocation in Phase 1+.
```

## Special cases

- **Empty scope.** If `scope.include` resolves to zero files, surface: *"Scope resolves to zero files. Check `scope.include` patterns in `.code4me/audit4me-config.json`."* The rest of the report still emits with zeros.
- **Coverage file missing but findings present.** Unusual but possible if coverage was deleted while findings remained. Note in the report; recommend reconstructing coverage from `audit-events.jsonl` (Phase 1+ provides the rebuild script).
- **Findings present but no config.** Pre-flight catches this and stops. The findings remain on disk but are uninterpretable without a config.

## Why this isn't a subagent dispatch

`/audit4me-status` is bookkeeping — same category as `/code4me-status` and `/code4me-housekeeping`. The session runs it inline from its own thread (no Task call). It's READ-ONLY on all files.
