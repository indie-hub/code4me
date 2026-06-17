# Probe: single-vendor `/audit4me-run` produces findings + updates coverage

**Subject:** audit4me
**Coverage:** Verifies the Phase 1 (v0.13.1-dev) `/audit4me-run` outer loop end-to-end with a single vendor (`anthropic`) and a single category (`bugs`): the work set is computed from scope + coverage, a `code4me-audit-orchestrator` subagent is dispatched per file, at least one finding is written as a properly-shaped `findings/{id}.md`, `audit-coverage.json` is updated with a per-vendor entry at the file's current hash, and `audit-events.jsonl` gains one event per file.

> **Probe type:** integration (run-and-inspect), not LLM-as-judge. Unlike the code4me classification probes, this one is verified by running `/audit4me-run` against a fixture and asserting on the artifacts under `.code4me/audit4me/`. The `bin/audit4me-helpers.sh` smoke tests cover the deterministic helpers in isolation; this probe covers the loop + orchestrator contract together.

## Setup

1. A project with `/code4me-init` run and `/audit4me-config` completed so
   `.code4me/audit4me-config.json` exists with `vendors_available: ["anthropic"]`,
   `default_categories: ["bugs"]`, `rules_version: "v0.1.0"`, and a `scope.include`
   covering a small directory (e.g. `src/**`).
2. The scope contains at least one file with a **known, unambiguous bug** — e.g. an
   off-by-one or a missing null check. The probe fixture under
   `probes/fixture-skeleton/src/` (e.g. `ScoreFormatter.cs`, `Leaderboard.cs`) is a
   suitable corpus; point `scope.include` at it.
3. No prior coverage: `.code4me/audit4me/audit-coverage.json` absent or `{}`.

## Input prompt

> /audit4me-run --vendor anthropic --category bugs --paths "src/**"

## Expected

- **Pre-flight + lock.** The run mints a `run_id` matching
  `^run-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z-[a-z0-9]{4}$`, creates
  `.code4me/audit4me/.lock`, and releases (deletes) it at the end.
- **Work set.** Every in-scope file is queued with `reason: "uncovered"` (empty
  coverage). The run announces the file count before dispatching.
- **Per-file dispatch.** One `code4me-audit-orchestrator` subagent per file, each
  returning a JSON object with `outcome`, `findings`, and a complete
  `updated_coverage_entry`. The orchestrator never edits production source.
- **Findings on disk.** For the known-bug file, at least one
  `.code4me/audit4me/findings/F-YYYY-MM-DD-NNNN.md` is written. Its frontmatter
  validates against `schemas/finding-frontmatter.schema.json` and has:
  `category: bugs`, `vendors_agreed: ["anthropic"]`, `confidence: low`,
  `proposed_fix: false`, `status: open`, a `line_range` matching `^\d+(-\d+)?$`, and
  a `content_hash` equal to the audited file's current hash.
- **Coverage.** `audit-coverage.json` has an entry per audited file. Each entry has
  `vendors.anthropic` with `audited_hash == content_hash`,
  `categories_covered: ["bugs"]`, a `findings_count` equal to the number of finding
  files written for that file, `rules_version_at_audit: "v0.1.0"`, and
  `coverage_level: "full-covered"` (single-vendor deployment ⇒ one vendor is the
  full surface). Validates against `schemas/audit-coverage.schema.json`.
- **Events.** `audit-events.jsonl` has one line per file with
  `outcome: "completed"`, `vendor: "anthropic"`, `category: "bugs"`, the shared
  `run_id`, and `findings` equal to that file's finding count. Each line validates
  against `schemas/audit-event.schema.json`.
- **Summary.** `.code4me/audit4me/morning-report.md` is written and lists files
  audited and findings by severity.
- **Idempotence.** Immediately re-running `/audit4me-run --vendor anthropic
  --category bugs --paths "src/**"` (no file changes) produces an **empty work
  set** — no files are re-audited, no new findings or events. (This is the
  coverage-tracker doing its job.)

## Pass criterion

1. ≥1 finding file written for the known-bug file, frontmatter schema-valid.
2. `audit-coverage.json` and every `audit-events.jsonl` line are schema-valid.
3. Coverage `findings_count` per file equals the number of finding files for it.
4. The immediate re-run audits zero files (idempotent on unchanged content).
5. No production source file was modified by the run (audit4me is read-only on code).

## Failure modes this catches

- Orchestrator edits the source file instead of only reporting (read-only invariant broken).
- Finding written with `proposed_fix: true` or `confidence` above `low` in Phase 1 (premature — those need Phases 2–3).
- Coverage written with `coverage_level: "single-vendor"` in a 1-vendor deployment (should be `full-covered`).
- `findings_count` in coverage disagrees with the number of finding files on disk.
- The re-run re-audits unchanged files (coverage not consulted / hash not compared).
- `.lock` left behind after the run completes, or no lock taken (concurrent-run hazard).
- Events appended as multi-line/pretty JSON, breaking JSONL parseability.

## Notes

Phase 1 is single-vendor by construction, so there is no agreement to compute and
no proposed fix — findings are surfaced for review only. The probe deliberately
asserts `confidence: low` and `proposed_fix: false` to lock that boundary; Phase 2
(multi-vendor) and Phase 3 (failing tests) are what unlock higher confidence and
proposed fixes.
