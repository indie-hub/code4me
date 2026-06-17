# audit4me — build plan

**Sibling to:** `docs/audit4me-design.md` (which is the "what"). This doc is the **"how and when"** — per-phase sub-tasks, gates between phases, open decisions to resolve per phase, estimates, and the overall rhythm.

**Last updated:** 2026-06-16.
**Current state:** Phase 1 shipped (v0.13.1-dev). Phase 2 gated.

---

## State of play

Phase 0 landed in v0.13.0-dev. It shipped the data-model commitment (four JSON schemas) and the read-only surface (`/audit4me-config`, `/audit4me-status`) — deliberately no orchestrator, no actual auditing yet. The whole point of Phase 0 was to validate the file shapes and slash-command UX *before* committing the per-file orchestrator pattern, while code4me v0.12 continues soaking against real milestones.

Phase 1 shipped in v0.13.1-dev once the v0.12 soak bar was judged met. Note: during that soak, two real bugs were found and fixed in the Critical-mode hooks — Windows path normalisation, and the critical-write allowlist gating the orchestrator's own `.code4me/` and `.wolf/` state dirs (`hooks/c4m-pathlib.sh` + carve-out; covered by `tests/hooks/test-windows-paths.sh`). They were annoyances rather than correctness failures, and the soak signal held.

**Deviations from the plan, as built:**

- Two open decisions resolved per their recommendations: **file-level coverage granularity** and **invalidate-findings-on-hash-change**.
- The helpers were built as a single CLI (`bin/audit4me-helpers.sh <subcommand>`) rather than a sourced lib, so they're independently testable and callable from the SKILL.md bash steps. Smoke-tested against a synthetic project (scope resolution, all five re-audit triggers, atomic coverage update, JSONL append, id allocation, run-id mint) and `bin/audit4me-rebuild-coverage.sh` verified rebuilding coverage from events.
- Persist order pinned to **findings → event-append → coverage-update (last)** for crash-safe resume; coverage is the commit marker.
- Per-finding markdown is written by the main session (templating from the orchestrator's structured findings), not by bash — the design's "bash writes findings" was simplified since the content is structured by the subagent.

---

## Phase 1 — Minimal orchestrator + single-vendor bugs audit

**Status: SHIPPED — v0.13.1-dev, 2026-06-16.** Sub-tasks 1–8 below are complete; the end-to-end verification against a live repo (the three checks under "Verification before tagging Phase 1 done") is the remaining manual step before the soak window starts.

**Gate to start:** code4me v0.12 at 2 weeks of clean real-milestone usage.

**Open decisions to resolve first:**

- **Coverage granularity** — recommendation: file-level (per design doc open question #1).
- **Persisted findings vs. derived on file change** — recommendation: invalidate on hash change (per design doc open question #3).

**Estimate:** 1-2 days of focused work.

**Sub-tasks (roughly in order):**

1. **Write `skills/audit4me/references/audit-prompt-bugs.md`.** The actual audit prompt template addressed to the auditor in second person, plus the RETURN SCHEMA (a JSON shape the response must match). This is the load-bearing artifact for Phase 1; the orchestrator's job is mostly to invoke it and parse the result. RETURN SCHEMA fields: `findings[]` with `severity`, `line_range`, `summary`, `evidence`, `reproduction_steps`, `affected_inputs`, and (Phase 3+) `failing_test`.
2. **Write `skills/audit4me/subagents/code4me-audit-orchestrator.md`.** Minimal version: single vendor (Anthropic), single category (bugs), no category selection logic, no within-file aggregation (one vendor = nothing to aggregate yet). The input/output contract from the design doc §"What the per-file orchestrator does" is what matters here; the interior is trivial in Phase 1.
3. **Write `bin/audit4me-helpers.sh`** (or equivalent bash helpers). Functions: `hash_file <path>` (sha256), `compute_work_set <config> <coverage>` (work set from scope + triggers), `coverage_update <path> <vendor> <new_entry>` (atomic via `jq` + `mv`), `event_append <event_json>` (append to `audit-events.jsonl`), `allocate_finding_id` (`F-{YYYY-MM-DD}-{NNNN}` counting existing per-day).
4. **Write `commands/audit4me-run.md`.** Slash command. Args: `[--paths X] [--changed-since Nh] [--max-files M] [--vendor V] [--force-audit]`. Drives the outer loop per design doc §"What happens when you type `/audit4me-run`".
5. **Update `skills/audit4me/SKILL.md`** to add the `/audit4me-run` operating loop section. The Phase 0 SKILL.md only covers config + status; Phase 1 extends it.
6. **Write `bin/audit4me-rebuild-coverage.sh`** — disaster-recovery rebuild of `audit-coverage.json` from `audit-events.jsonl` (the documented rebuild path in `references/coverage-format.md`).
7. **Probes:**
   - `probes/audit4me/01-single-vendor-run.md` — single `/audit4me-run --vendor anthropic --paths X` invocation produces expected findings and coverage update.
   - `probes/audit4me/02-resume-after-interruption.md` — mid-run interrupt resumes cleanly from next unaudited file via the coverage tracker.
8. **CHANGELOG entry + bump to v0.13.1-dev.**

**Verification before tagging Phase 1 done:**

- Run `/audit4me-run` against the `code4me-plugin` codebase itself with `--vendor anthropic --paths skills/`. Confirm at least one finding lands as a properly-shaped finding markdown file.
- Interrupt the run mid-way; re-run; confirm only unaudited files are processed.
- `/audit4me-status` post-run shows non-zero coverage with `coverage_level: single-vendor`.

---

## Phase 2 — Multi-vendor agreement (the real orchestrator)

**Gate to start:**

- Phase 1 stable (≥1 week of clean Phase 1 use, no rework backlog).
- **Subagent-nesting open question resolved** — see `docs/decisions/0001-subagent-nesting.md` (provisional: nesting is *not* available; subagents get no Task tool). Confirm in the Claude Code CLI via `probes/audit4me/03-subagent-nesting.md` before finalising the orchestrator prompt.
- **Multi-vendor disagreement handling decision** (design doc open question #2 — recommendation: agreement-covered + record dissent).

**Estimate:** 1-2 days.

**Sub-tasks:**

1. **Probe subagent-nesting — DONE (provisional).** Result recorded in `docs/decisions/0001-subagent-nesting.md` and reproducible via `probes/audit4me/03-subagent-nesting.md`. Outcome: subagents are **not** given an agent-spawning tool, so nested per-category Claude subagents are unavailable. Consequence for Phase 2: vendor fan-out uses inline `codex-bridge`/`deepseek-bridge` **subprocesses** (parallel, no nesting needed); any per-category Claude parallelism is achieved by fanning out per-(file × category) at the **main loop**, not inside the orchestrator. Confirm the result in the Claude Code CLI before locking the orchestrator prompt.
2. **Extend `subagents/code4me-audit-orchestrator.md`** to dispatch to multiple vendors via `codex-bridge` and `deepseek-bridge` inline. Vendor passes fan out in parallel.
3. **Add category-selection logic** to the orchestrator (config defaults + per-file pruning hooks like "no security audit on `.css`"). Even though Phase 2 still only has one category implemented (bugs), the selection logic needs to exist so Phase 5's category additions slot in.
4. **Implement within-file finding aggregation.** Dedupe findings by `file + line_range + category` across vendors; produce single multi-vendor entries; preserve verbatim per-vendor quotes in the markdown body.
5. **Implement coverage-level computation** (`uncovered` / `single-vendor` / `agreement-covered` / `full-covered`) tied to `vendors_available`.
6. **Implement composite confidence scoring.** Phase 2 wires the multi-vendor-agreement signal only; the other three signals (failing test, LSP cross-check, test coverage at line) are stubbed `null` and filled in by later phases.
7. **Write `commands/audit4me-findings.md`** — slash command to browse findings with filters: `--severity X --confidence high --category bugs --status open`.
8. **Probes:**
   - `03-multi-vendor-run.md` — 2-vendor run produces an agreement-covered finding with both vendors' quotes preserved.
   - `04-disagreement-recorded.md` — 3-vendor run with 2-of-3 agreement records the dissenting vendor.
   - `05-coverage-level-transitions.md` — file transitions `uncovered → single-vendor → agreement-covered` correctly across runs.
9. **CHANGELOG + bump to v0.13.2-dev.**

**Verification:**

- Multi-vendor run against the `code4me-plugin` codebase produces at least one agreement-covered finding.
- A single-vendor finding from Phase 1 should NOT auto-propose a fix (no agreement to compute); a Phase 2 agreement-covered finding should be a candidate for proposed-fix (gated by Phase 3's failing test requirement).

---

## Phase 3 — Failing-test generation

**Gate to start:** Phase 2 stable (~3-5 days of clean Phase 2 use).
**Estimate:** ~1 day.

**Sub-tasks:**

1. **Extend `references/audit-prompt-bugs.md`** RETURN SCHEMA to require a `failing_test` field for severity ≥ MAJOR findings. The auditor returns the test code, target language, and target test file path.
2. **Add test-staging-write step** in the orchestrator. After a finding is produced with a failing-test field, write the test to a staging path (e.g., `.code4me/audit4me/staged-tests/<finding_id>/`). The finding markdown's `failing_test_path` frontmatter field references the staged path.
3. **Add pre-validation:** actually invoke the test runner against current source to confirm the test fails. Demote the finding (no `proposed_fix: true`) if the test passes — the model thought there was a bug but couldn't prove it.
4. **Wire `propose_fix_requires_failing_test` threshold** into the confidence-scoring step (Phase 2 had this stubbed).
5. **Probe:** `06-failing-test-validates-before-propose.md`.
6. **CHANGELOG + bump to v0.13.3-dev.**

**Verification:**

- A finding with severity MAJOR + agreement-covered + failing test that demonstrably fails → `proposed_fix: true`.
- A finding with severity MAJOR + agreement-covered + a "failing" test that actually passes → `proposed_fix: false` (demoted), with the demotion reason recorded in the finding body.

---

## Phase 4 — `/audit4me-apply` integration with code4me

**Gate to start:** Phase 3 stable.
**Estimate:** ~half day.

**Sub-tasks:**

1. **Write `commands/audit4me-apply.md`** — dispatches a finding's proposed fix into code4me's Conversation Mode.
2. **Write `commands/audit4me-dismiss.md`** — marks a finding as won't-fix; records `dismissal_reason` in frontmatter; appends `## Dismissal` block to the body.
3. **Implement Conversation Note construction** from a finding. The bug description becomes "what's changing"; the failing test becomes "how to know it worked"; the proposed fix becomes initial input.
4. **Wire dispatch into code4me's Conversation Mode workflow** — calls the existing dispatch machinery with the constructed note.
5. **Apply-readiness re-check at dispatch time.** File unchanged since audit (content hash still matches); protected tests not touched by the proposed fix; rules version still current. If any check fails, the apply refuses and surfaces the staleness reason.
6. **Auto-escalation handoff for security-category findings.** Per `apply_integration.auto_escalate_categories`, security findings dispatch as Standard regardless of `dispatch_mode`. code4me's existing auto-escalation rules also apply (e.g., touching auth code).
7. **Rename `/code4me-audit` → `/code4me-dispatch-audit`** (per design doc Appendix A). Update README cheat sheet, `commands/code4me-audit.md` → `commands/code4me-dispatch-audit.md`, all docs.
8. **Probes:**
   - `07-apply-dispatches-conversation.md`
   - `08-dismiss-records-reason.md`
   - `09-stale-finding-blocked.md`
   - `10-code4me-audit-rename.md` (the rename is non-breaking from a behavior standpoint but breaks muscle memory)
9. **CHANGELOG + bump to v0.13.4-dev.**

**Verification:**

- `/audit4me-apply <finding_id>` for a real Phase 3 finding actually dispatches a Conversation Mode workflow and the fix lands behind the same gates any other Conversation Mode work would.
- `/audit4me-dismiss <finding_id> --reason "false positive — the trim() is intentional for input normalization"` correctly records the reason and removes the finding from default `/audit4me-findings` view.

---

## Phase 5 — Remaining categories + audit-tool integration

**Gate to start:** Phase 4 stable. Each category is independently shippable; no need to wait for all of them.
**Estimate:** 2-3 days (incremental).

**Sub-tasks (in any order):**

1. **Write `references/audit-prompt-security.md`** — RETURN SCHEMA additions: `cwe_id`, `attack_vector`, `mitigation`.
2. **Write `references/audit-prompt-performance.md`** — RETURN SCHEMA additions: `profiling_evidence`, `estimated_impact`, `complexity_class`.
3. **Write `references/audit-prompt-maintainability.md`** — RETURN SCHEMA additions: `refactoring_suggestion`, `complexity_metric`.
4. **Write `references/audit-prompt-test_gaps.md`** — RETURN SCHEMA additions: `uncovered_lines`, `proposed_test_cases`.
5. **Extend the orchestrator's category-selection logic** to handle all five categories. Per-extension category-fitness rules (e.g., no `security` audit on `.css`, no `test_gaps` audit on `.md`).
6. **Extend `bin/code4me-audit-dispatch-log`** with an audit4me activity section: findings per category, vendor agreement rate, apply-vs-dismiss rate, average per-vendor disagreement count.
7. **Probes per category:**
   - `11-security-audit-with-cwe.md`
   - `12-performance-audit-with-evidence.md`
   - `13-maintainability-audit.md`
   - `14-test-gaps-audit.md`
8. **CHANGELOG entry per category** as it lands; final entry **cuts v0.13.0 stable** (drops the `-dev` suffix) when all five categories are live.

**Verification:**

- One example finding per category against the `code4me-plugin` codebase (or against a separate test corpus).
- The audit-tool extension's audit4me activity section renders non-trivially after a run with multiple categories.

---

## Beyond v0.13

Three items the design doc lists as deferred. Each is roughly half-day to one-day after v0.13.0 ships.

- **Cross-cutting pattern detection.** The end-of-run inline LLM call that clusters findings into themes (design doc §Architecture step 4). Needs a real corpus of findings to be useful, so it makes sense to ship after Phase 5 when there ARE findings to cluster. Likely v0.13.5 or v0.14.0.
- **Symbol-level coverage granularity.** Promotes coverage from file-level to function/symbol-level. Requires LSP integration to enumerate symbols. Trigger: file-level coverage produces noticeable noise from "file changed but only imports moved" re-audits. Defer until that noise is measured, not anticipated.
- **Scheduled-task integration.** Wire `mcp__scheduled-tasks__create_scheduled_task` for unattended overnight runs. Trivial after Phase 1 works; just needs the trigger documented.

---

## Per-phase gates summary

| Gate | What it protects | Decision/signal needed |
|---|---|---|
| Phase 0 → Phase 1 | code4me v0.12 architectural stability | 2-week clean-soak signal on v0.12 |
| Phase 1 → Phase 2 | Orchestrator pattern viability under load | Phase 1 stable ≥1 week; subagent-nesting probe; disagreement-handling decision |
| Phase 2 → Phase 3 | Multi-vendor signal quality | Phase 2 stable; no rework backlog |
| Phase 3 → Phase 4 | Test-as-evidence is reliable | Phase 3 stable; failing-test demotions feel correct |
| Phase 4 → Phase 5 | End-to-end apply flow works | Phase 4 stable; at least one real `/audit4me-apply` round-tripped to a merged fix |

---

## Total time + rhythm

Excluding soak windows, the actual work is roughly **6-8 days** spread over **3-4 weeks of wall clock**. The deliberate rhythm:

```
[Phase 1 build: 1-2 days] → [Phase 1 soak: ~3-5 days] →
[Phase 2 build: 1-2 days] → [Phase 2 soak: ~3-5 days] →
[Phase 3 build: 1 day]    → [Phase 3 soak: ~2-3 days] →
[Phase 4 build: 0.5 day]  → [Phase 4 soak: ~2-3 days] →
[Phase 5 build: 2-3 days, categories landed incrementally]
```

The soak windows between phases aren't busywork — they're when foundational assumptions get stress-tested by real use before the next phase commits to them. Skipping the soak windows is exactly how Phase 3+ ends up depending on a Phase 1 assumption that turned out to be wrong.

---

## When to update this doc

- **After each phase ships:** mark the phase complete, record any deviations from the plan, note follow-ups discovered during build.
- **When a gate decision is made:** record the decision and rationale (consider an ADR under `docs/decisions/`).
- **If a phase's scope changes materially:** edit the sub-task list here; don't let the doc drift from reality.

This is a living build plan. The design doc is the spec; this is the operational mechanics.
