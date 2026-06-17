---
name: deepseek-bridge
description: Direct bridge from the orchestrator thread to the Reasonix CLI (DeepSeek-native agentic coding agent) for cross-vendor execution of architect, developer, code-reviewer, spec-to-test, security-reviewer, verification, and lead-architect roles. Invoke from the orchestrator (not via Task tool subagent dispatch) when cross-vendor pairing is enabled for the milestone OR the user has named a specific deepseek-role at intake. The bridge handles prompt assembly, `reasonix run` invocation via Bash, response parsing, and validation; the orchestrator uses the structured result inline for Co-Approval, alternation, and gating decisions. Mirrors `codex-bridge` architecturally; DeepSeek is the third supported vendor alongside Anthropic and OpenAI (v0.11+).
---

# DeepSeek Bridge

A skill the orchestrator invokes inline from its own thread to bridge to DeepSeek via the **Reasonix CLI** (`reasonix run`). Reasonix is a DeepSeek-native agentic coding agent — built specifically around DeepSeek's prefix-cache stability and tool-call semantics, talking directly to `api.deepseek.com` with no translation shim. The bridge writes a prompt file, runs `reasonix run` via the Bash tool, reads the response, validates the structured JSON envelope embedded in the response, and uses the result for the next workflow step.

No Task-tool subagent is spawned. The orchestrator is already executing — it pays only the DeepSeek tokens, not double for a Claude wrapper. Reasonix's prefix-cache optimization means per-token cost on the DeepSeek side is dramatically lower than naive API use (the project reports ~99.8% cache hit rates in real sessions).

## When to invoke

Only when **one** of the following is true:

1. The user named a specific DeepSeek role at intake — e.g., "use deepseek-architect for this", "have deepseek-developer implement this", "let deepseek do the security review."
2. The user enabled cross-vendor pairing for this milestone AND DeepSeek is in the pairing set — the words "cross-vendor", "alternation", "alternation policy", or the `--cross-vendor` flag on `/code4me-dispatch`, AND either an explicit DeepSeek mention OR a project-level cross-vendor default in `CLAUDE.md` that names DeepSeek as one of the vendors.

Inferring "DeepSeek would be a good fit here" from the work's nature, the auto-escalation symptom list, or the team-template's pairing column is a workflow violation per the orchestrator's **deepseek-bridge dispatch gate** in `skills/code4me/SKILL.md`. When uncertain whether the user wants DeepSeek, surface as `NEEDS_DECISION` and ask.

## Pre-flight

Before invoking Reasonix for any role, the orchestrator runs **one** check via the Bash tool:

```
command -v reasonix
```

If it returns a non-zero exit or empty path: the bridge cannot run. Surface as a typed BLOCKED outcome with `blocker_type: reasonix_cli_not_installed`. Direct the user to install with `npm install -g reasonix` (or use `npx reasonix run` at the cost of slower start-up). Do not substitute a Claude-side dispatch unsolicited — the user opted into DeepSeek specifically; substitution without confirmation is a workflow violation.

**Authentication is the Reasonix CLI's responsibility.** Reasonix accepts the DeepSeek API key from EITHER source:

- `$DEEPSEEK_API_KEY` env var (set with `export DEEPSEEK_API_KEY=...`)
- `~/.reasonix/config.json` → `apiKey` field (populated by Reasonix's first-run wizard, or hand-edited)

The bridge does NOT pre-check auth — it lets Reasonix decide at invocation time. This mirrors codex-bridge's posture (which doesn't pre-check OPENAI_API_KEY because `codex login` OAuth credentials may be present instead). If neither auth source is configured, the `reasonix run` subprocess exits non-zero and the bridge catches that as `deepseek_subprocess_error` with the auth-failure stderr tail in `blocker_detail` — giving the user a clear remediation hint at the failure point.

The `command -v reasonix` check is cheap (sub-millisecond). It runs at every dispatch — the bridge does not cache the result across the milestone because PATH can change between sessions.

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

   Each reference is a near-verbatim mirror of the corresponding `codex-bridge/references/{role}.md` — same modes, same prompts, same return schemas, same validation. The bridge-substrate is the only thing that changes (`reasonix run` vs. `codex exec`).

2. **Assembles the DeepSeek prompt.** Each reference contains a mode-specific prompt template addressed to Reasonix in second person ("ROLE: You are the Challenger Architect...", "INPUTS:", "PROCEDURE:", "RETURN SCHEMA:"). The orchestrator substitutes `{placeholder}` fields with values from the Context Pack, then writes the literal string to `/tmp/deepseek-{slug}-{task_id}.txt` via the Write tool. The slug per role is: `arch`, `dev`, `cr`, `s2t`, `sec`, `ver`, `la`.

3. **Invokes Reasonix via Bash.** The command shape is:

   ```
   timeout {N} reasonix run \
     --model {resolved_model} \
     --effort {resolved_effort} \
     --transcript /tmp/deepseek-{slug}-{task_id}.transcript.jsonl \
     "$(cat /tmp/deepseek-{slug}-{task_id}.txt)" \
     > /tmp/deepseek-{slug}-{task_id}.out \
     2> /tmp/deepseek-{slug}-{task_id}.err
   ```

   Flag explanations:

   - **`--model {resolved_model}`** — Concrete DeepSeek model identifier (`deepseek-v4-flash` / `deepseek-v4-pro` / `deepseek-v4-pro[1m]`). Resolved by tier lookup (see "Tier resolution" below). NO `--preset` flag — Reasonix's `run` subcommand takes a direct model id. The flag overrides any model setting in `~/.reasonix/config.json`.
   - **`--effort {resolved_effort}`** — DeepSeek's reasoning effort knob: `low|medium|high|max`. Resolved per-tier: `low` tier → `medium`; `mid` tier → `high`; `high` tier → `max`. The flag overrides any effort setting in config.
   - **`--transcript /tmp/...`** — Write a JSONL transcript with usage / cost / prefix-cache data. The bridge logs the transcript path in the dispatch log so the audit tool can pick it up for cost rollup.
   - **`"$(cat ...)"`** — The prompt itself, read from the file we wrote in step 2. Passed as the positional `<task>` argument.
   - **`timeout {N}`** — Wall-clock cap. Defaults: 300s for architect-class, 600s for developer, 360s for verification's suite-run.

   **Note on `--no-config`:** earlier prototypes passed `--no-config` to force deterministic per-dispatch settings, but that broke users who'd authenticated via the first-run wizard (which stores the API key in `~/.reasonix/config.json`). The shipped bridge does NOT pass `--no-config` — it lets Reasonix's config file provide auth and any other persistent settings. The explicit `--model` and `--effort` flags still override config-file values for the things that affect bridge correctness, so determinism on the load-bearing parameters is preserved while user-configured auth, themes, web-search backends, and MCP servers inherit naturally.

4. **Parses and validates the response.** Read the `.out` file. The agent's response is plain text streamed to stdout (Reasonix's `run` doesn't have a JSON envelope mode). The bridge extracts the role's RETURN SCHEMA JSON from a fenced ` ```json ... ``` ` block at the end of the response — the per-role prompt templates instruct Reasonix to end with exactly this block. Failure to find a fenced JSON block → `BLOCKED` with `blocker_type: deepseek_response_invalid`. Failure to JSON.parse the extracted block → same blocker. Schema validation failure → `BLOCKED` with the role+mode-specific typed blocker (e.g., `mandatory_critique_violation`, `out_of_scope_target`, `severity_outcome_mismatch`).

   The `.transcript.jsonl` file is consulted for cost/cache metadata but is NOT the source of truth for the structured outcome — that lives in the stdout response.

5. **Post-validation diff scan (Layer C, v0.13+).** Before consuming the result, run the shared diff-scan helper to confirm the reasonix subprocess didn't touch anything it shouldn't have. Symmetric with codex-bridge:

   ```
   bash $PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh \
     --project-dir "$PROJECT_DIR" \
     --weight {weight} \
     --mode {read-only|read-write} \
     --vendor deepseek
   ```

   `--mode` is `read-only` for `architect`, `code-reviewer` (review-* modes), `security-reviewer`, `verification` (ac-coverage mode), `lead-architect`; `read-write` for `developer` (implement, spike), `spec-to-test` (generate).

   The helper inspects `git status --porcelain` and cross-references the changed paths against `.code4me/protected-tests.txt`, `.code4me/critical-allowlist.txt` (Critical-mode only), and `.code4me/forbidden-conditions.json` (Conversation-mode only). Parse the returned JSON; if `ok: false`, escalate the first violation as a typed blocker:
   - `test_protection_violation` → BLOCKED (overrides any "completed" outcome the reasonix response claimed)
   - `out_of_scope_target` → BLOCKED
   - `forbidden_condition_violation` → BLOCKED
   - `unexpected_modification` → BLOCKED with read-only-violation framing

   If `skipped: true` (no git, or not a git repo), log the skip (`layer_c_skipped: true`) and proceed. Layer C requires git; without git this layer is a no-op.

   **Why post-validation, not pre-validation.** Same reasoning as codex-bridge: reasonix runs as a subprocess; Claude Code's hooks don't fire inside it. Reasonix's own PreToolUse hooks (Layer B) are ear-tagged but not built yet — coverage of which tools its PreToolUse intercepts needs verification first. Layer C catches anything that landed on disk regardless of what the response claims. Deterministic; can't be lied about. Violations are caught after the touch (rolled back by the user), not before.

6. **Uses the result inline.** The orchestrator now has DeepSeek's structured output *and* a clean Layer C diff scan. For Co-Approval: compare with the Claude-side architect's `approved` field. For alternation: record both sides' findings. For scope-expansion: route as appropriate.

7. **Logs the invocation.** Append one line to `.code4me/dispatch-log.jsonl`:

   ```jsonl
   {
     "ts": "<ISO8601>",
     "milestone": "<id>", "task": "<id>", "weight": "<weight>",
     "subagent": "deepseek-{role} (skill-bridge)",
     "vendor": "deepseek", "model_tier": "<tier>", "default_tier": "<tier>",
     "tier_deviated_from_default": <bool>, "model": "<resolved id>", "effort": "<level>",
     "mode": "<mode>", "outcome": "<outcome>",
     "escalation_trigger": "<symptom or null>",
     "vendor_pairing": {...},
     "context_provenance": [...],
     "transcript_path": "/tmp/deepseek-{slug}-{task_id}.transcript.jsonl",
     "spec_kit_interop": <bool>,
     "layer_c_status": "<clean|violation|skipped>",
     "layer_c_violations": [<violation_type>, ...]
   }
   ```

   The `subagent` field uses the `deepseek-{role} (skill-bridge)` convention so audit-tool analytics aggregate by role name across all three vendors. The `transcript_path` is new in v0.11 — audit-tool surveillance can read it for per-dispatch cost/cache stats. `layer_c_status` / `layer_c_violations` are new in v0.13 — see codex-bridge SKILL.md §"Post-validation diff scan" for the layer-C semantics (identical across both bridges).

## Tier resolution

The DeepSeek model AND effort level per invocation are resolved by the standard rules (same as Anthropic and OpenAI):

1. **Map the bridge role to the Claude-side role name** for tier lookup:
   - `architect` → `challenger-architect` (default pairing direction; for the inverse use `lead-architect`)
   - `developer` → `developer`
   - `code-reviewer` → `code-reviewer`
   - `spec-to-test` → `spec-to-test`
   - `security-reviewer` → `security-reviewer`
   - `verification` → `verification`
   - `lead-architect` → `lead-architect`
2. Look up `(mapped_role, weight)` in `skills/code4me/references/model-selection.yaml` → tier (`low` / `mid` / `high`).
3. Resolve `(vendor=deepseek, tier)` in `skills/code4me/references/vendor-models.yaml` → concrete model identifier.
4. Resolve `(tier)` → effort level by this mapping:
   - tier `low` → effort `medium` (don't waste reasoning on cheap-tier work)
   - tier `mid` → effort `high`
   - tier `high` → effort `max`
5. Pass `--model {id} --effort {level}` to `reasonix run`.

Hard floors apply (architect ≥ `mid`; Critical ≥ `mid`; cross-vendor doesn't relax tier). Deviation rules apply the same as for Claude-side or Codex-side dispatches.

**Note on the `high` tier for DeepSeek:** the `vendor-models.yaml` `deepseek.high` entry maps to `deepseek-v4-pro[1m]` — the 1-million-context variant. Combined with `--effort max`, this gives DeepSeek's strongest configuration. For roles that don't need long context, the `mid` tier (`deepseek-v4-pro` without the `[1m]` suffix) is preferred to avoid the higher cost of the long-context variant.

## Failure modes

The bridge **does not retry on failure**. It records a typed `blocker_type` and the orchestrator's circuit breakers handle the rest. Common blocker_types across all roles:

- `reasonix_cli_not_installed` — pre-flight `command -v reasonix` failed
- `deepseek_timeout` — `timeout` killed `reasonix run` (exit code 124)
- `deepseek_subprocess_error` — `reasonix run` non-zero exit (other), with stderr tail in `blocker_detail`. **This is the failure mode when auth is unconfigured** — both `$DEEPSEEK_API_KEY` and the config-file `apiKey` are missing; Reasonix exits with an auth error visible in stderr. The bridge surfaces this as `deepseek_subprocess_error` with the auth-failure message rather than a dedicated `deepseek_api_key_missing` blocker, mirroring how codex-bridge surfaces missing-codex-auth as `codex_error`.
- `deepseek_response_invalid` — fenced JSON block missing from response, parse failure, or schema violation
- `deepseek_api_error` — DeepSeek-side API failure surfaced by Reasonix (rate limit, context-length exceeded, model not found); the bridge surfaces what Reasonix reports in `blocker_detail`

Plus role-specific blockers — see each `references/{role}.md`'s "Validation" section. The role-specific blocker set is identical to codex-bridge (`mandatory_critique_violation`, `mandatory_alternatives_violation`, `test_protection_violation`, `out_of_scope_target`, `gate_scope_violation`, `severity_outcome_mismatch`, `suite_status_outcome_mismatch`, `co_approval_violation`) — same names, same semantics, same validation rules.

## Context discipline

Reasonix responses can be substantial. Each role reference's validation step trims large fields the same way codex-bridge does (e.g., `test_runner_output_excerpt` limited to the last 50 lines; `findings` arrays kept whole because the orchestrator needs them).

The 1-million-context variant (`deepseek-v4-pro[1m]`) is reserved for the `high` tier and for milestones where the Context Pack genuinely exceeds 200K tokens. Defaulting to `[1m]` for all dispatches would waste cost — DeepSeek charges differently for the long-context variant.

If the orchestrator accumulates significant DeepSeek output across multiple cross-vendor invocations on the same milestone, it should `/compact` between phases.

## What this skill is NOT

- **Not a substitute for the Claude-side or Codex-side subagent roles.** When cross-vendor pairing is off, the orchestrator dispatches Claude-side subagents — same as before. The bridge is opt-in.
- **Not a fallback for missing `reasonix` CLI.** If `command -v reasonix` fails, the bridge BLOCKs. The orchestrator does NOT silently substitute another vendor — that would defeat the user's explicit opt-in.
- **Not a pre-flight auth checker.** The bridge does NOT check for `$DEEPSEEK_API_KEY` at pre-flight. Reasonix accepts either the env var OR its config-file apiKey (populated by the first-run wizard). Auth failures surface at invocation time as `deepseek_subprocess_error` with the auth-error stderr tail.
- **Not a context-gathering tool.** The bridge does not Read project files, Grep, or use LSP from the parent orchestrator's thread. It assembles a prompt from the Context Pack the orchestrator already has and passes it to Reasonix, which has its own tool surface for the work itself (Reasonix is a code-mode agent with file read/write/edit + bash). The orchestrator-thread context and Reasonix's per-invocation tool surface are distinct — they are not the same context window.

## Why Reasonix and not a nested Claude Code instance

An earlier v0.11 prototype used `claude --print` against DeepSeek's Anthropic-compatible endpoint (`https://api.deepseek.com/anthropic`). That worked mechanically but had three drawbacks:

1. **Recursion-prevention complexity.** A nested Claude Code instance could load the code4me plugin and try to be another orchestrator. Mitigations (cd /tmp, --disallowedTools Task) worked but were brittle.
2. **No prefix-cache stability.** Claude Code's prompt construction is optimized for Anthropic's tool-use format, not DeepSeek's prefix cache. The 5x cost reduction Reasonix achieves through stable-prefix design wasn't available.
3. **Mismatched tool semantics.** DeepSeek's tool-call format differs subtly from Anthropic's; Claude Code's translation through the Anthropic-compatible endpoint occasionally produced format errors.

Reasonix is purpose-built for DeepSeek: prefix-cache-first prompt ordering, native DeepSeek tool-call format, automatic tool-call repair, flash-first cost control. It's the right tool for the job and slots into the bridge architecture symmetrically with `codex exec`.

## Symmetry with codex-bridge

The deepseek-bridge is structured as a parallel skill to codex-bridge:

- **Identical dispatch flow** (pre-flight → load reference → assemble prompt → invoke → parse → use inline → log).
- **Identical role set** (7 roles: architect, developer, code-reviewer, spec-to-test, security-reviewer, verification, lead-architect).
- **Identical mode list per role** (challenge / consult / review-spec for architect, etc.).
- **Identical RETURN SCHEMA per role-mode** (same field names, same blocker_type naming, same outcome enums).
- **Identical tier resolution algorithm** (only `vendor-models.yaml`'s third block differs).
- **Identical dispatch-log shape** (the new `effort` and `transcript_path` fields are DeepSeek-specific; other fields are uniform).

This symmetry means: existing probes for codex-bridge (`probes/cross-vendor/01-05`) are mirrored as deepseek-bridge probes (`06-08`), audit-tool analytics work the same across all three vendors, and the orchestrator's reasoning at team-composition time treats DeepSeek as a peer of OpenAI rather than a special case.

## References

Open the relevant per-role reference when invoking:

- `references/architect.md` — challenger-architect role (cross-vendor pressure-testing on DeepSeek)
- `references/developer.md` — developer role (cross-vendor implementation, diff review, spike on DeepSeek)
- `references/code-reviewer.md` — code-reviewer role (cross-vendor quality review on DeepSeek)
- `references/spec-to-test.md` — spec-to-test engineer role (cross-vendor test generation on DeepSeek)
- `references/security-reviewer.md` — security-reviewer role (cross-vendor OWASP/STRIDE pass on DeepSeek)
- `references/verification.md` — verification engineer role (cross-vendor suite-run, AC coverage on DeepSeek)
- `references/lead-architect.md` — lead-architect role (DeepSeek-led architecture; inverts the default pairing)
