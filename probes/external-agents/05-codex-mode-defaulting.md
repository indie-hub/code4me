# Probe: codex mode defaults to challenge/implement and the defaulting is auditable

> **SUPERSEDED IN v0.10.** Pre-v0.10 shim-mode-defaulting behaviour. The mode-default rules (architect → `challenge`, developer → `implement`, etc.) are preserved in each `skills/codex-bridge/references/{role}.md` modes table; the mechanism is now skill invocation rather than subagent dispatch.

**Subject:** classification
**Coverage:** Verifies that when `mode` is unset in the dispatch Context Pack, `codex-architect` defaults to `challenge` and `codex-developer` defaults to `implement`, and that the defaulting is logged in `convergence_notes` (for architect) or `assumptions` (for developer) so the audit trail makes the default visible. The user did not declare an intent for mode, so the shim's documented defaulting behaviour in `agents/codex-architect.md` ("If `mode` is unset, default to `challenge` and append `\"mode defaulted to challenge — orchestrator did not specify\"` to `convergence_notes`") must fire — and the same auditability principle applies to codex-developer's implement default.

## Input prompt

> Architecture coming up: add a new public endpoint for exporting user data as CSV. Use codex-architect.

## Expected

- **Kind:** product
- **Weight:** Standard (default for product work without a declared weight)
- **Auto-escalation:** none (no symptom class fires on this prompt alone)
- **Team:** `lead-architect (anthropic:opus)`, `codex-architect (openai:<model>) [mode=challenge — defaulted]`, spec-to-test, developer, verification, code-reviewer, qa, doc-writer
- **Order/notes:** Architecture-introducing hard floor applies (new public endpoint). Co-Approval Rule cited explicitly — both `lead-architect` and `codex-architect` must return `approved: true` before the orchestrator advances. Codex's `convergence_notes` includes the exact defaulting string `mode defaulted to challenge — orchestrator did not specify` per `agents/codex-architect.md` line 37. For the codex-developer variant, the implement default is recorded in the `assumptions` array.

## Pass criterion

Orchestrator's transparency announcement names `codex-architect (openai:<model>) [mode=challenge — defaulted]` with the defaulting flagged, dispatches both `lead-architect` and `codex-architect` for the architecture-introducing hard floor, cites the Co-Approval Rule, and the response payload's `convergence_notes` field contains the exact string `mode defaulted to challenge — orchestrator did not specify`.

## Failure modes this catches

- Shim defaults to `challenge` but writes nothing to `convergence_notes`, hiding the defaulting from the audit trail — a later reader cannot tell whether the orchestrator chose challenge mode deliberately or fell through to the default.
- Orchestrator paraphrases the defaulting note ("mode was unspecified") instead of preserving the exact string from `agents/codex-architect.md`, breaking string-match audits.
- Orchestrator silently fills in `mode=challenge` in the Context Pack itself, suppressing the shim's defaulting branch and erasing the signal that the user did not declare a mode.
- Shim defaults to a different mode (`consult` or `review-spec`) for architecture-introducing work, skipping the Co-Approval Rule entirely.
- For the codex-developer variant: shim defaults to `implement` but writes the defaulting note to a freeform `blocker` field instead of `assumptions`, hiding it from the standard audit surface.
