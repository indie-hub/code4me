---
description: Execute an audit4me sweep. Computes the work set from coverage + flags, dispatches a code4me-audit-orchestrator subagent per file, persists findings + coverage + events, and writes a run summary. Phase 1 scope (v0.13.1-dev) — single vendor (anthropic), single category (bugs), no proposed fixes. Honours the cost/time/files boxes from audit4me-config.json. Read-only on production source; the only writes are bookkeeping under .code4me/audit4me/.
argument-hint: [--paths GLOB] [--changed-since Nh] [--max-files M] [--vendor anthropic] [--category bugs] [--force-audit]
---

Run an audit4me sweep over the in-scope files that need auditing. The full
operating loop, the orchestrator contract, and the persistence steps are in
`skills/audit4me/SKILL.md` §"`/audit4me-run` — the operating loop" and
`skills/audit4me/subagents/code4me-audit-orchestrator.md`. The procedure below is
the slash-command entry point; the skill is canonical.

**Read-only on production source.** The only writes are under `.code4me/audit4me/`
(coverage tracker, events log, findings markdown, run summary). audit4me never
edits code — accepted fixes are applied later via `/audit4me-apply` (Phase 4),
which dispatches code4me Conversation Mode.

## Phase 1 limits

- Single vendor: `anthropic` (the `--vendor` flag accepts only `anthropic` in
  Phase 1; multi-vendor lands in Phase 2).
- Single category: `bugs` (the `--category` flag accepts only `bugs` in Phase 1).
- No proposed fixes / no failing tests (Phases 3–4). Findings are surfaced only.

## Procedure

1. **Pre-flight.**
   - Confirm `.code4me/audit4me-config.json` exists; if not: *"No audit4me config — run `/audit4me-config` first."* and stop.
   - Confirm `bin/audit4me-helpers.sh` is reachable and `jq` is on PATH.
   - Acquire the run lock: if `.code4me/audit4me/.lock` exists, refuse (*"An audit4me run is already in progress (.lock present). If you're sure none is, delete `.code4me/audit4me/.lock` and retry."*). Otherwise create it with the new run id inside.
   - Mint a `run_id` via `bash bin/audit4me-helpers.sh new-run-id`.

2. **Compute the work set.** Pass the flags straight through to the helper:

   ```bash
   bash bin/audit4me-helpers.sh work-set \
     .code4me/audit4me-config.json .code4me/audit4me/audit-coverage.json \
     --vendor anthropic --category bugs \
     [--paths "$PATHS"] [--changed-since "$SINCE"] [--force]
   ```

   This emits one JSON line per file needing audit (`{file, content_hash,
   coverage_entry, vendor, category, reason}`). Apply `--max-files` (flag, else
   `config.max_files_per_run`) by truncating the worklist. Announce the count, the
   reasons breakdown, and a rough cost estimate before dispatching.

3. **Loop over the worklist.** For each entry (sequentially in Phase 1):
   1. **Dispatch** a `code4me-audit-orchestrator` subagent via the Task tool, passing
      `{file_path, content_hash, coverage_entry, config, run_id, vendor:"anthropic",
      model, category:"bugs"}`. Resolve `model` from `skills/code4me/references/vendor-models.yaml`
      (the audit tier — mid by default).
   2. **Validate** the returned JSON parses and has `outcome`, `findings`,
      `updated_coverage_entry`. If malformed, record `outcome:"failed"` for the file
      and continue (never abort the whole run for one file).
   3. **Persist** — order matters for crash-safety. Coverage is the resume marker,
      so it is written **last**, only after the findings and the event are durably on disk:
      - For each finding: `id=$(bash bin/audit4me-helpers.sh alloc-finding-id .code4me/audit4me/findings)`,
        then write `.code4me/audit4me/findings/$id.md` using the Phase 1 frontmatter
        (`vendors_agreed: ["anthropic"]`, `confidence: "low"`, `proposed_fix: false`,
        `status: "open"`) per `references/finding-template.md`.
      - `bash bin/audit4me-helpers.sh event-append .code4me/audit4me/audit-events.jsonl "$event"`
        where `$event` is built from `{ts, run_id, vendor, model, file, content_hash,
        category:"bugs", outcome, findings:<count>, rules_version}`.
      - `bash bin/audit4me-helpers.sh coverage-update .code4me/audit4me/audit-coverage.json "$file" "$updated_coverage_entry"`
        — the commit point. A crash *before* this re-audits the file next run (safe:
        redo, never false-skip); a crash *after* means the file is durably done.
   4. **Check the boxes** after each file: if cumulative cost ≥ `max_cost_usd_per_run`,
      elapsed ≥ `max_runtime_per_run`, or files-done ≥ `max_files`, stop the loop and
      commit partial state (everything already written stands; coverage reflects only
      completed files — this is the resume-safe partial-sweep state).

4. **Summarise.** Aggregate this run's events (filter `audit-events.jsonl` by
   `run_id`) and write `.code4me/audit4me/morning-report.md`: files audited,
   findings by severity, failures, partial-sweep verdict if a box was hit, and the
   next-sweep hint. Surface any orchestrator `insight` values.

5. **Release the lock.** Delete `.code4me/audit4me/.lock`. Do this even on error
   (treat it like a `finally`).

6. **Return** a one-line summary: files audited, findings count, where the report is.

## Resume semantics

Coverage is updated atomically after each file. If a run is interrupted, the next
`/audit4me-run` recomputes the work set from coverage and picks up at the next
unaudited file — completed files are not re-audited. A stale `.lock` from a crashed
run is the one manual cleanup; the pre-flight tells the user how.

## When NOT to run

- Before `/audit4me-config` — there's no config or scope.
- Inside a `/code4me-housekeeping` flow — audit4me runs detached from milestones.

Arguments:

$ARGUMENTS
