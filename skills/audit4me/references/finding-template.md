# audit4me finding markdown shape

Every finding lives at `.code4me/audit4me/findings/{id}.md`. The shape is:

1. **YAML frontmatter** (machine-readable metadata; schema: `schemas/finding-frontmatter.schema.json`)
2. **Markdown body** (human-readable evidence, proposed fix, failing test, apply-readiness)

Tooling (`/audit4me-status`, `/audit4me-findings`, `/audit4me-apply`, `/audit4me-dismiss`) reads the frontmatter for filtering and state transitions; humans read the body for the actual content.

## File template

```markdown
---
id: F-2026-06-01-0023
severity: MAJOR
category: bugs
file: src/auth/login.cs
line_range: "87-92"
content_hash: "sha256:abc123..."
audited_at: "2026-06-01T22:18:47Z"
vendors_agreed: [anthropic, openai]
vendors_dissented: []
confidence: high
proposed_fix: true
failing_test_path: tests/auth/test_login_bypass_finding_0023.cs
rules_version: v0.1.0
status: open
---

> **Frontmatter convention:** quote the date-time, content_hash, and line_range
> values (as above). They are schema `type: string`; left unquoted, a YAML reader
> re-types `audited_at` to a timestamp and a single-line `line_range` to an integer,
> which then fail validation against `schemas/finding-frontmatter.schema.json`.

# Finding F-2026-06-01-0023

## Summary

{One paragraph stating what's wrong, in human terms. No jargon-as-drama. Specific about the failure mode, not generic about "security risk".}

## Evidence

### Anthropic's finding (verbatim excerpt)

> {The verbatim excerpt from claude-sonnet-4-6's audit response. Quote, don't paraphrase. Preserve the model's reasoning.}

### OpenAI's finding (verbatim excerpt)

> {Same for the OpenAI vendor's pass via codex-bridge.}

### DeepSeek's finding (verbatim excerpt — if applicable)

> {Same for the DeepSeek vendor's pass via deepseek-bridge. Omitted if vendor not in vendors_agreed.}

## Confidence signals

- **Multi-vendor agreement:** {list vendors that agreed} ({✓ | ✗})
- **Failing test written:** `{path/to/test.ext}` (included below) ({✓ | ✗ | N/A})
- **LSP cross-check:** {✓ if LSP independently flagged | ✗ if it didn't | N/A for non-type findings}
- **Test coverage at affected lines:** {✓ if affected lines are covered by existing tests | ✗ if not}

{Summary sentence: "All four signals positive → confidence: HIGH" or similar.}

## Proposed fix

```{language}
// before
{the current code at the affected lines}

// after
{the proposed replacement}
```

{One paragraph explaining the change: what specifically it fixes and why it's the right shape (e.g., "Uses the project's existing PasswordHasher.Verify which already does constant-time comparison against the full hash"). If the fix references existing project conventions, name them.}

## Failing test

```{language}
{the test code that demonstrates the bug — should fail against current source and pass against the proposed fix}
```

## Apply readiness

- File unchanged since audit: {✓ | ✗ — file is stale, re-audit required}
- Protected tests unaffected by proposed fix: {✓ | ✗ — touches `.code4me/protected-tests.txt`, cannot proceed}
- Auto-escalation: {weight the dispatch will use, e.g., "Standard (category=security → forced escalation)" or "Conversation (default)"}

To apply: `/audit4me-apply F-2026-06-01-0023`
```

## Frontmatter field semantics

See `schemas/finding-frontmatter.schema.json` for the authoritative schema. Quick reference:

- **`id`** — `F-{YYYY-MM-DD}-{NNNN}`. The four-digit sequence resets at UTC midnight. The orchestrator allocates IDs by counting existing findings with the same date prefix and incrementing.
- **`severity`** — `NIT` / `MINOR` / `MAJOR` / `CRITICAL`. Determined by the auditor's RETURN SCHEMA. `MAJOR` is the default threshold for `proposed_fix`.
- **`category`** — which of the five audit categories produced this finding.
- **`file` + `line_range`** — where in the project. `line_range` is `87` for a single line or `87-92` inclusive.
- **`content_hash`** — sha256 of the file at audit time. The freshness check.
- **`audited_at`** — ISO-8601 UTC.
- **`vendors_agreed`** — which vendors independently flagged this finding.
- **`vendors_dissented`** — vendors that audited the file in this category but did NOT flag this finding. In 2-vendor mode this is typically empty (if one vendor doesn't flag and the other does, that's not "agreed" so no finding gets written). In 3-vendor mode, this records the dissenting vendor when 2-of-3 agree.
- **`confidence`** — `low` / `medium` / `high`. Composite of the four confidence signals.
- **`proposed_fix`** — boolean. True when the finding meets all `confidence_thresholds` gates from the config. The markdown body MUST include a `## Proposed fix` section when this is true.
- **`failing_test_path`** — populated when the auditor wrote a failing test. The body MUST include a `## Failing test` section with the test code.
- **`rules_version`** — version of the audit ruleset that produced this finding.
- **`status`** — `open` (default), `applied` (`/audit4me-apply` was invoked), `dismissed` (`/audit4me-dismiss` was invoked, `dismissal_reason` populated), `stale` (file changed since audit, re-audit needed).

## Body section semantics

- **`## Summary`** — required. One paragraph stating what's wrong, in human terms. Specific about the failure mode.
- **`## Evidence`** — required. One subsection per vendor in `vendors_agreed`, each with the verbatim quote from that vendor's audit response.
- **`## Confidence signals`** — required. The four signals as a bulleted list, each marked ✓ / ✗ / N/A.
- **`## Proposed fix`** — required when `proposed_fix: true`; omitted otherwise. Includes a before/after code diff and a paragraph explaining the change.
- **`## Failing test`** — required when `failing_test_path` is populated; omitted otherwise. Includes the full test code.
- **`## Apply readiness`** — required when `proposed_fix: true`; omitted otherwise. Three bullets: file freshness, protected-tests check, auto-escalation prediction.

## Dismissed findings

When `/audit4me-dismiss <id> [--reason ...]` runs:

1. Frontmatter `status` flips to `dismissed`.
2. Frontmatter `dismissal_reason` is populated with the (required) reason.
3. The body gets an appended `## Dismissal` section recording: who dismissed (the slash-command operator is the current session user), when (ISO-8601), the reason verbatim.

Dismissed findings remain in `findings/` so the audit history is preserved. `/audit4me-findings` excludes them by default; `--status dismissed` surfaces them.

## Stale findings

When a re-audit detects the file has changed (`current_hash != content_hash`) and the finding's status is still `open`:

1. Frontmatter `status` flips to `stale`.
2. The body gets a note: "File changed since audit. Re-audit required before action."
3. The next `/audit4me-run` includes the file in the work set (content-change trigger); new findings produced supersede the stale ones.

The stale finding stays on disk but `/audit4me-apply` refuses to act on it (apply-readiness check fails). This is the same posture as a Conversation Mode PROVISIONAL deadline expiring — the artefact stays for the record, but action requires re-validation.

## What's NOT in this template

- **AC coverage tables** — that's a code4me concept (verification's per-AC verdicts). audit4me findings are not bound to milestones or ACs; they're free-floating against the codebase.
- **Workflow weight / dispatch metadata** — that's chosen at `/audit4me-apply` time, not encoded here. The `Apply readiness` section predicts the weight but doesn't commit to it.
- **INSIGHTs** — INSIGHTs are a code4me concept for routing observations between roles within a milestone. audit4me's analogue is the cross-file pattern detector (Phase 1+ inline LLM call at end of run) and the per-file orchestrator's optional `insight` return field. These are surfaced in the run-end report, not in individual finding files.
