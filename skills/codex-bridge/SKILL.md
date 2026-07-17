---
name: codex-bridge
description: Direct bridge from the orchestrator thread to the OpenAI Codex CLI for cross-vendor execution of architect, developer, code-reviewer, spec-to-test, security-reviewer, verification, and lead-architect roles. Invoke from the orchestrator (not via Task tool subagent dispatch) when cross-vendor pairing is enabled for the milestone OR the user has named a specific codex-role at intake. The bridge handles prompt assembly, `codex exec` invocation via Bash, response parsing, and validation; the orchestrator uses the structured result inline for Co-Approval, alternation, and gating decisions. Replaces the v0.6–v0.9 `codex-*` subagent shims; saves the Claude-subagent spawn cost and eliminates the identity-drift failure mode the shims were prone to.
---

# Codex Bridge

A skill the orchestrator invokes inline from its own thread to bridge to the OpenAI Codex CLI. The orchestrator writes a prompt file via the Write tool, invokes `codex exec` via the Bash tool, reads the response, validates the structured JSON, and uses the result for the next workflow step (Co-Approval check, alternation comparison, scope-expansion routing, etc.).

No Task-tool subagent is spawned. The orchestrator is already executing — it pays only the Codex tokens, not double for a Claude wrapper.

## When to invoke

Only when **one** of the following is true:

1. The user named a specific Codex role at intake — e.g., "use codex-architect for this", "have codex-developer implement this", "let codex do the security review."
2. The user enabled cross-vendor pairing for this milestone — the words "cross-vendor", "alternation", "alternation policy", or the `--cross-vendor` flag on `/code4me-dispatch`, OR a project-level cross-vendor default declared in `CLAUDE.md`.

Inferring "Codex would be a good fit here" from the work's nature, the auto-escalation symptom list, or the team-template's pairing column is a workflow violation per the orchestrator's **Codex shim dispatch gate** in `skills/code4me/SKILL.md`. When uncertain whether the user wants Codex, surface as `NEEDS_DECISION` and ask.

## Pre-flight

Before invoking Codex for any role, the orchestrator runs **one** check via the Bash tool:

```
command -v codex
```

If it returns a non-zero exit or empty path: the bridge cannot run. Surface to the user as a typed BLOCKED outcome with `blocker_type: codex_cli_not_installed`. Do not substitute a Claude-side dispatch unsolicited — the user opted into Codex specifically; substitution without confirmation is a workflow violation.

**Authentication is the Codex CLI's responsibility.** Modern Codex supports `codex login` (OAuth, credentials stored under `~/.codex/`) OR `OPENAI_API_KEY` env var — either works. The bridge does NOT pre-check auth. If Codex can't authenticate when invoked, `codex exec` exits non-zero and the bridge catches that as `codex_error` with the stderr tail in `blocker_detail`.

## Invocation flow

For each role × mode dispatch, the orchestrator:

1. **Loads the role reference.** `references/{role}.md` where `{role}` is one of:
   - `architect` — challenge / consult / review-spec modes
   - `developer` — implement / review-diff / spike modes
   - `code-reviewer` — review-diff / review-files / review-spec-fit modes
   - `spec-to-test` — generate / review-test-spec modes
   - `security-reviewer` — diff-focused / comprehensive modes
   - `verification` — suite-run / ac-coverage modes
   - `lead-architect` — propose / amend modes

2. **Assembles the Codex prompt.** Each reference contains a mode-specific prompt template addressed to Codex in second person ("ROLE: You are the Challenger Architect...", "INPUTS:", "PROCEDURE:", "RETURN SCHEMA:"). The orchestrator substitutes `{placeholder}` fields with the actual values from the Context Pack, then writes the literal string to `/tmp/codex-{slug}-{task_id}.txt` via the Write tool. The slug per role is: `arch`, `dev`, `cr`, `s2t`, `sec`, `ver`, `la`.

3. **Invokes Codex via Bash.** Send the prompt on stdin; current Codex does not support the previously documented `--prompt-file` flag:

   ```
   codex exec --model {resolved_model} \
     -c 'model_reasoning_effort="{resolved_effort}"' - \
     < /tmp/codex-{slug}-{task_id}.txt \
     > /tmp/codex-{slug}-{task_id}.out 2> /tmp/codex-{slug}-{task_id}.err
   ```

   Apply the role time limit through the Bash/tool process timeout, not GNU `timeout` (which stock macOS does not ship). `{resolved_effort}` is resolved independently from the model. The bridge validates the value for the installed Codex backend and records `effort_applied: true` only when it was passed.

4. **Parses and validates the response.** Read the `.out` file. `JSON.parse` it. Validate against the mode-specific schema in the role reference. Failure to parse → `BLOCKED` with `blocker_type: codex_response_invalid`. Schema validation failure → `BLOCKED` with the role+mode-specific typed blocker (e.g., `mandatory_critique_violation`, `out_of_scope_target`, `severity_outcome_mismatch`).

5. **Post-validation diff scan (Layer C, v0.13+).** Before consuming the result, run the shared diff-scan helper to confirm the codex subprocess didn't touch anything it shouldn't have. The helper inspects `git status --porcelain` and cross-references the changed paths against `.code4me/protected-tests.txt`, `.code4me/critical-allowlist.txt` (Critical-mode only), and `.code4me/forbidden-conditions.json` (Conversation-mode only).

   ```
   bash $PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh \
     --project-dir "$PROJECT_DIR" \
     --weight {weight} \
     --mode {read-only|read-write} \
     --vendor codex
   ```

   The `--mode` argument reflects whether the role is expected to write files:
   - `read-only` for `architect`, `code-reviewer` (review-* modes), `security-reviewer`, `verification` (ac-coverage mode), `lead-architect`. Any modification by the subprocess is `unexpected_modification`.
   - `read-write` for `developer` (implement, spike), `spec-to-test` (generate). Modifications outside protected/allowlist/forbidden patterns are allowed.

   The helper returns JSON. Parse it; if `ok: false`, escalate the first violation as a typed blocker matching the violation type:
   - `test_protection_violation` → BLOCKED (overrides any "completed" outcome the codex response claimed)
   - `out_of_scope_target` → BLOCKED
   - `forbidden_condition_violation` → BLOCKED
   - `unexpected_modification` → BLOCKED with role-specific framing ("role was dispatched read-only; subprocess modified file unexpectedly")

   If `skipped: true` (no git, or not a git repo), log the skip in the dispatch log (`layer_c_skipped: true` field) and proceed. Layer C requires git; without git, this layer is a no-op — Claude-side hooks (Layer A) and codex/reasonix-side hooks (Layer B, when wired) still cover what they can.

   **Why post-validation, not pre-validation.** Codex runs as a subprocess; Claude Code's PreToolUse hooks don't fire inside it. Codex's own PreToolUse hooks are Bash-only and not currently wired by code4me (Layer B is ear-tagged but not built). Layer C catches anything that landed on disk regardless of what the response claims. Deterministic; can't be lied about. The trade-off: violations are caught *after* the touch (rolled back by the user), not before.

6. **Uses the result inline.** The orchestrator now has Codex's output as structured data, *and* a clean Layer C diff scan. For Co-Approval: compare with the Claude-side architect's `approved` field. For alternation: record both sides' findings. For scope-expansion: route as appropriate. The orchestrator's existing workflow logic consumes the result the same way it would consume a subagent return payload.

7. **Logs the invocation.** Append one line to `.code4me/dispatch-log.jsonl`:

   ```jsonl
   {
     "ts": "<ISO8601>",
     "milestone": "<id>", "task": "<id>", "weight": "<weight>",
     "subagent": "codex-{role} (skill-bridge)",
     "vendor": "openai", "model_tier": "<tier>", "default_tier": "<tier>",
     "tier_deviated_from_default": <bool>, "model": "<resolved id>",
     "effort": "<level>", "default_effort": "<level>",
     "effort_deviated_from_default": <bool>,
     "effort_source": "<default|explicit_deviation|legacy_tier_fallback>",
     "effort_applied": true,
     "mode": "<mode>", "outcome": "<outcome>",
     "escalation_trigger": "<symptom or null>",
     "vendor_pairing": {...},
     "context_provenance": [...],
     "spec_kit_interop": <bool>,
     "layer_c_status": "<clean|violation|skipped>",
     "layer_c_violations": [<violation_type>, ...]
   }
   ```

   The `subagent` field uses the `codex-{role} (skill-bridge)` convention so audit-tool analytics (vendor × tier rollup, weight × outcome heatmap, etc.) still aggregate by role name. The "skill-bridge" suffix distinguishes these from the legacy subagent dispatches in older logs.

   `layer_c_status` is `clean` when the diff scan returned `ok: true`, `violation` when `ok: false` (and the outcome above was set to BLOCKED accordingly), or `skipped` when the helper couldn't run (no git, not a git repo). `layer_c_violations` lists the violation types from the scan; empty when status is clean or skipped.

## Tier resolution

The Codex model used per invocation is resolved by the standard rules:

1. **Map the bridge role to the Claude-side role name** for tier lookup:
   - `architect` → `challenger-architect` (the Codex-side architect plays the Challenger role in the default pairing direction; for the inverse direction use `lead-architect`)
   - `developer` → `developer`
   - `code-reviewer` → `code-reviewer`
   - `spec-to-test` → `spec-to-test`
   - `security-reviewer` → `security-reviewer`
   - `verification` → `verification`
   - `lead-architect` → `lead-architect`
2. Look up `(mapped_role, weight)` in `skills/code4me/references/model-selection.yaml` → tier (`low` / `mid` / `high`).
3. Resolve `(vendor=openai, tier)` in `skills/code4me/references/vendor-models.yaml` → concrete model identifier.
4. Resolve effort independently from `effort_defaults`; if absent, use the legacy tier fallback.
5. Pass `--model {id}` and `-c 'model_reasoning_effort="{effort}"'` to `codex exec`, with the prompt on stdin.

Hard floors apply (architect ≥ `mid`; Critical ≥ `mid`; cross-vendor doesn't relax tier). Deviation rules apply the same as for Claude-side dispatches.

## Failure modes

The bridge **does not retry on failure**. It records a typed `blocker_type` and the orchestrator's circuit breakers handle the rest. Common blocker_types across all roles:

- `codex_cli_not_installed` — pre-flight `command -v codex` failed
- `codex_timeout` — the host tool/process time limit expired
- `codex_error` — `codex exec` non-zero exit (other), with stderr tail in `blocker_detail`
- `codex_response_invalid` — JSON parse failure or schema violation

Plus role-specific blockers — see each `references/{role}.md`'s "Validation" section. Common examples:

- `mandatory_critique_violation` (architect challenge mode)
- `mandatory_alternatives_violation` (lead-architect propose mode)
- `test_protection_violation` (developer implement mode)
- `out_of_scope_target` (developer implement mode, when Critical-allowlist is active)
- `gate_scope_violation` (spec-to-test generate mode)
- `severity_outcome_mismatch` (code-reviewer / security-reviewer)
- `suite_status_outcome_mismatch` (verification suite-run mode)
- `co_approval_violation` (lead-architect amend mode)

## Context discipline

Codex responses can be substantial (especially `verification (mode=suite-run)` with test-runner output or `security-reviewer (mode=comprehensive)` with full findings). Each role reference's validation step **trims large fields** (e.g., `test_runner_output_excerpt` limited to the last 50 lines; `findings` arrays kept whole because the orchestrator needs them).

If the orchestrator accumulates significant Codex output across multiple cross-vendor invocations on the same milestone, it should `/compact` between phases — the contract is that intermediate raw responses can be summarised; the final structured outcomes must stay.

## What this skill is NOT

- **Not a substitute for the Claude-side subagent roles.** When cross-vendor pairing is off (which is the default), the orchestrator dispatches `developer`, `code-reviewer`, `verification`, etc. as Task-tool subagents — same as before. The bridge is opt-in.
- **Not a fallback for missing Codex.** If `command -v codex` fails, the bridge BLOCKs. The orchestrator does NOT silently substitute a Claude-side dispatch — that would defeat the user's explicit opt-in.
- **Not a context-gathering tool.** The bridge does not Read project files, Grep, or use LSP. It assembles a prompt from the Context Pack the orchestrator already has and passes it to Codex. Any context Codex needs must be in the prompt itself.

## References

Open the relevant per-role reference when invoking:

- `references/architect.md` — challenger-architect role (cross-vendor pressure-testing)
- `references/developer.md` — developer role (cross-vendor implementation, diff review, spike)
- `references/code-reviewer.md` — code-reviewer role (cross-vendor quality review)
- `references/spec-to-test.md` — spec-to-test engineer role (cross-vendor test generation)
- `references/security-reviewer.md` — security-reviewer role (cross-vendor OWASP/STRIDE pass)
- `references/verification.md` — verification engineer role (cross-vendor suite-run, AC coverage)
- `references/lead-architect.md` — lead-architect role (Codex-led architecture; inverts the v0.7 default pairing)
