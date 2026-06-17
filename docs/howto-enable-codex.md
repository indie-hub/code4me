# How to enable the Codex shims

The plugin ships seven external-vendor shims that route specific subagent roles to OpenAI's Codex CLI instead of Claude. They're opt-in — none of them dispatch by default. Enable them per-milestone or per-task when you want cross-vendor dialectic, vendor-diverse cost rollups, or cross-vendor pre-release security passes.

## The seven shims

| Shim | Shims the role | Modes |
|---|---|---|
| `codex-architect` | challenger-architect | challenge (default) / consult / review-spec |
| `codex-developer` | developer | implement (default) / review-diff / spike |
| `codex-code-reviewer` (v0.7+) | code-reviewer | review-diff (default) / review-files / review-spec-fit |
| `codex-spec-to-test` (v0.7+) | spec-to-test | generate (default) / review-test-spec |
| `codex-security-reviewer` (v0.7+) | security-reviewer | diff-focused (default) / comprehensive |
| `codex-verification` (v0.8+) | verification | suite-run (default) / ac-coverage |
| `codex-lead-architect` (v0.8+) | lead-architect | propose (default) / amend |

QA and Researcher remain Claude-only by design — `codex-qa` and `codex-researcher` are not part of the plan.

## Setup

1. **Install the Codex CLI** per [OpenAI's instructions](https://github.com/openai/codex). Verify with `command -v codex` printing a path.

2. **Export `OPENAI_API_KEY`** in the shell that runs Claude Code:

   ```
   echo 'export OPENAI_API_KEY=sk-...' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **(Optional) Set a default Codex model identifier.** The shims pass `--model <id>` if you provide one; otherwise they use the CLI default. The orchestrator's tier resolution (v0.7+) picks a concrete model per dispatch via `references/vendor-models.yaml`, so this default is rarely used.

4. **Run `/code4me-preflight`** to confirm the Codex CLI is reachable.

## Two paths to using the shims

### Path 1 — individual shim use

Tell the orchestrator at intake which shim you want, by name. The natural-language trigger works:

> Use codex-architect for the architecture review on this milestone.

The orchestrator substitutes `codex-architect (mode=challenge)` for `challenger-architect` in the team composition. The Co-Approval Rule still applies — both Lead (Claude) and Challenger (Codex) must return `approved: true`. No cross-vendor pairing semantics on the rest of the team; everything else stays Claude.

This path is for one-off cross-vendor checks (a specific architecture decision, a sensitive security pass, a different-vendor diff review).

### Path 2 — cross-vendor pairing for the whole milestone

Enable the alternation policy at intake or via the slash command:

```
/code4me-dispatch Standard --cross-vendor <task description>
```

The orchestrator applies `references/cross-vendor-policy.md`'s alternation rule: producer and verifier dispatch on opposite vendors wherever shims exist. See `docs/howto-enable-cross-vendor.md` for the full pairing pattern.

This path is for whole-milestone work where you want end-to-end different-distribution coverage (test author Codex → implementer Claude → reviewer Codex → verifier Codex → security-reviewer Codex).

## Per-shim quick reference

| Use case | Shim + mode |
|---|---|
| Cross-vendor architecture pressure-test | `codex-architect (mode=challenge)` |
| Focused architecture question | `codex-architect (mode=consult)` |
| Tech Spec soundness pass | `codex-architect (mode=review-spec)` |
| Cross-vendor implementation on Conversation/Light | `codex-developer (mode=implement)` |
| Read-only diff review (any weight) | `codex-developer (mode=review-diff)` OR `codex-code-reviewer (mode=review-diff)` |
| Throwaway prototype | `codex-developer (mode=spike)` — output marked `PROTOTYPE_NOT_FOR_MERGE`, not routed through quality gates |
| Cross-vendor quality review (Standard+) | `codex-code-reviewer (mode=review-diff)` |
| Spec-implementation drift check | `codex-code-reviewer (mode=review-spec-fit)` |
| Cross-vendor test generation | `codex-spec-to-test (mode=generate)` |
| Read-only Test Spec soundness | `codex-spec-to-test (mode=review-test-spec)` |
| Cross-vendor security pass | `codex-security-reviewer (mode=diff-focused)` |
| Comprehensive security audit | `codex-security-reviewer (mode=comprehensive)` |
| Cross-vendor full verification | `codex-verification (mode=suite-run)` |
| Read-only AC traceability | `codex-verification (mode=ac-coverage)` |
| Codex-led architecture | `codex-lead-architect (mode=propose)` then `challenger-architect (claude)` |
| Codex amendment integration | `codex-lead-architect (mode=amend)` |

The shim's `description` frontmatter has the full per-mode contract; the orchestrator picks defaults when mode isn't specified.

## Failure modes and what they look like

Every shim does pre-flight checks before invoking Codex:

1. `command -v codex` returns a path → otherwise `BLOCKED` with `blocker_type: codex_cli_not_installed`
2. `OPENAI_API_KEY` is non-empty → otherwise `BLOCKED` with `blocker_type: codex_auth_missing`

Plus shim-specific validation on Codex's response. Common typed `blocker_type` values:

- `codex_timeout` — Codex didn't respond within the shim's timeout (300s architect, 600s developer, varies by shim)
- `codex_error` — Codex exited non-zero with output (stderr tail included in `blocker_detail`)
- `codex_response_invalid` — Codex's response wasn't valid JSON matching the mode's schema
- `mandatory_critique_violation` — `codex-architect (mode=challenge)` returned without all five area examinations
- `mandatory_alternatives_violation` — `codex-lead-architect (mode=propose)` returned without ≥ 2 named alternatives
- `test_protection_violation` — `codex-developer (mode=implement)` returned `files_touched` containing a protected-test path
- `out_of_scope_target` (v0.9+) — `codex-developer (mode=implement)` returned `files_touched` containing paths outside the Critical-mode allowlist
- `review_mode_files_touched` — read-only mode (review-diff, review-files, review-spec-fit, review-test-spec, ac-coverage, diff-focused, comprehensive) returned a non-empty `files_touched`
- `severity_outcome_mismatch` — finding-severity and outcome don't agree (e.g., Critical security finding but outcome PASS_WITH_FINDINGS)

The orchestrator's circuit breakers handle the rest: a BLOCKED return surfaces to the user; repeated BLOCKED on the same cause hits the Rework Limit; persistent CLI/auth failures route to user escalation rather than continuing to retry.

## Cost tracking

Every Codex dispatch records `vendor: openai`, `model_tier`, and the resolved `model` in the dispatch log JSONL line. The audit tool (`bin/code4me-audit-dispatch-log`, or `/code4me-audit`) surfaces:

- Vendor × tier rollup table — counts by (vendor, tier) pair
- Cross-vendor split totals — Anthropic vs. OpenAI dispatch counts
- Pairing degradation summary (if cross-vendor was active) — counts by degrade reason

Use these with your Anthropic and OpenAI billing data for cross-vendor cost rollups. Per-tier dispatch counts are directly comparable across vendors at the same tier.

## When NOT to enable Codex shims

- **Default everyday work.** Claude-side agents remain the default; opt-in is per-milestone or per-task, not project-wide. Trying to make Codex the default is friction.
- **Critical milestones, until soaked.** Each shim re-encodes protections but adds a translation surface (Codex's response → shim validation → orchestrator). For Critical work, prefer Claude-on-both-sides until the shims have run cleanly through several Standard milestones in your project.
- **Where setup friction interrupts flow.** Pre-flight checks BLOCK on missing setup. Desirable when you have opted in; noisy when you haven't.

## Cross-vendor protection: the three layers (v0.13+)

Claude Code's PreToolUse hooks only fire inside the Claude Code session itself. When the orchestrator dispatches to codex via `codex exec`, the subprocess runs its own tool calls and Claude-side hooks never see them. v0.13 introduces layered protection to close this gap:

- **Layer A — Claude-side PreToolUse hooks (existing).** Fires on the orchestrator's own tool calls. Strongest protection; pre-call interception; covers Read/Grep/Edit/Write/MCP/Bash.
- **Layer B — Codex-side PreToolUse hooks (ear-tagged, not yet built).** Codex CLI supports `~/.codex/hooks.json` for native lifecycle hooks (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`). Critical limitation: Codex's `PreToolUse` currently fires only for the `Bash` tool — it doesn't intercept file writes, MCP, or `WebSearch`. Codex's docs are explicit: *"The model can still work around this by writing its own script to disk and then running that script with Bash, so treat this as a useful guardrail rather than a complete enforcement boundary."* The roadmap (`docs/roadmap.md`) tracks the Layer B build.
- **Layer C — Post-validation diff scan (v0.13+, shipped).** After `codex exec` returns, the bridge runs `bin/code4me-bridge-diff-scan.sh` which inspects `git status --porcelain` and cross-references the changed paths against `.code4me/protected-tests.txt`, `.code4me/critical-allowlist.txt` (Critical-mode), and `.code4me/forbidden-conditions.json` (Conversation-mode). Violations surface as typed blockers (`test_protection_violation`, `out_of_scope_target`, `forbidden_condition_violation`, `unexpected_modification`) — the same blockers Claude-side hooks produce. The bridge sets the dispatch outcome to BLOCKED on violation, overriding whatever the codex response claimed.

**Layer C is deterministic and post-call.** A codex subprocess that touched a protected test gets caught regardless of what its structured response said. The trade-off vs Layer A: violations are caught *after* the touch (the user `git checkout`s the file and the dispatch is re-tried), not *before*. For a single-user project this is usually fine; for CI/team settings Layer B (when built) gives earlier interception.

**Layer C requires git.** When the project isn't a git repo, the diff scan skips with `layer_c_status: skipped` in the dispatch log. Layer C becomes a no-op; Layer A still covers what it can. The bridge does NOT refuse to run without git — Layer C is opt-in by your repo being a git repo.

See `skills/codex-bridge/SKILL.md` §"Invocation flow" step 5 for the bridge-side details, and `probes/cross-vendor/09-bridge-post-validation-catches-protected-test-edit.md` for the directly-executable probe that verifies Layer C across all violation types.
