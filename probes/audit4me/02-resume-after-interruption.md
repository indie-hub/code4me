# Probe: `/audit4me-run` resumes cleanly after interruption

**Subject:** audit4me
**Coverage:** Verifies the Phase 1 resume semantics: because `audit-coverage.json`
is updated atomically after each file completes, an interrupted run leaves no
half-state, and the next `/audit4me-run` picks up from the next unaudited file
without re-auditing completed ones.

> **Probe type:** integration (run-and-inspect). Verified by interrupting a real
> run and inspecting the artifacts, not by an LLM-as-judge.

## Setup

1. As in probe `01`: `/audit4me-config` done, `vendors_available: ["anthropic"]`,
   `scope.include` over a directory with **several** files (≥4) so a mid-run
   interrupt is observable.
2. Empty coverage to start.

## Input prompt (two parts)

First, start a run and interrupt it after some — but not all — files complete:

> /audit4me-run --vendor anthropic --category bugs --paths "src/**"

Interrupt the session (Ctrl-C / close) after the run has reported completing at
least one file but before the summary is written. (Simulating a crash / box hit.)

Then, in a fresh session, run again:

> /audit4me-run --vendor anthropic --category bugs --paths "src/**"

## Expected

- **After the interrupt:** `audit-coverage.json` contains entries **only** for the
  files that fully completed before the interrupt — no partial or malformed entry
  for the in-flight file. `audit-events.jsonl` has one line per completed file.
  Finding files exist only for completed files. A `.lock` may remain (the crash
  prevented its release) — see "stale lock" below.
- **Stale lock handling:** the second run detects the leftover `.lock`. Per the
  command's pre-flight it refuses with a clear message telling the user to delete
  `.code4me/audit4me/.lock` if no run is active. After the user clears it (or the
  pre-flight auto-clears a lock whose `run_id` matches a known-dead run), the run
  proceeds.
- **Resume work set:** the second run's work set contains **only** the files not
  yet covered at their current hash — the previously completed files are absent
  (their coverage entry satisfies the no-re-audit check). The interrupted-but-not-
  completed file and any never-started files are present with `reason: "uncovered"`.
- **No double-audit:** completed files get no second finding file, no second event,
  and their coverage `audited_at` is unchanged by the second run.
- **Completion:** after the second run, every in-scope file has a coverage entry at
  its current hash; the union of finding files across both runs covers all flagged
  bugs exactly once.

## Pass criterion

1. Post-interrupt coverage is internally consistent and schema-valid — only fully
   completed files present, no half-written entry.
2. The second run's work set excludes already-completed files and includes the rest.
3. No completed file is re-audited (no duplicate findings/events; `audited_at` stable).
4. The leftover `.lock` is surfaced and handled (refuse-then-clear, or matched-run auto-clear) rather than silently clobbered.
5. After both runs, coverage is complete for the scope.

## Failure modes this catches

- A file's coverage entry written *before* its findings/events (ordering bug) — an
  interrupt would then skip a file that wasn't really audited.
- Coverage written non-atomically (partial/corrupt JSON on interrupt).
- The second run ignores coverage and re-audits everything (resume not implemented).
- The leftover `.lock` silently blocks all future runs with no recovery path, or is
  ignored entirely (defeating the concurrent-run guard).
- Duplicate finding IDs or duplicate events for a file audited across two runs.

## Notes

This is why the outer-loop discipline matters (per `docs/audit4me-design.md`
§"Resume semantics"): every coverage write is one atomic `mv` away from a
recoverable state, and the per-file order is **findings → event-append →
coverage-update** so that a crash can only ever lose work (redo a file), never
falsely mark a file audited. `bin/audit4me-rebuild-coverage.sh` is the backstop if coverage is lost
entirely — it reconstructs coverage from the append-only events log.
