# How to enable DeepSeek bridging

The plugin ships a `deepseek-bridge` skill that routes specific subagent roles to DeepSeek (via the Reasonix CLI) instead of Claude. It's opt-in — DeepSeek never dispatches by default. Enable it per-milestone or per-task when you want cross-vendor dialectic, vendor-diverse cost rollups, or cross-vendor pre-release security passes with DeepSeek as the non-Anthropic side.

This document mirrors `howto-enable-codex.md` for DeepSeek. The two are independent: you can enable both, either, or neither.

## The seven bridge roles

| Bridge role | Substitutes the Claude role | Modes |
|---|---|---|
| `deepseek-bridge[architect]` | challenger-architect | challenge (default) / consult / review-spec |
| `deepseek-bridge[developer]` | developer | implement (default) / review-diff / spike |
| `deepseek-bridge[code-reviewer]` | code-reviewer | review-diff (default) / review-files / review-spec-fit |
| `deepseek-bridge[spec-to-test]` | spec-to-test | generate (default) / review-test-spec |
| `deepseek-bridge[security-reviewer]` | security-reviewer | diff-focused (default) / comprehensive |
| `deepseek-bridge[verification]` | verification | suite-run (default) / ac-coverage |
| `deepseek-bridge[lead-architect]` | lead-architect | propose (default) / amend |

QA and Researcher remain Claude-only by design (same convention as codex-bridge).

## What the bridge invokes

The bridge spawns the **Reasonix CLI** — a DeepSeek-native agentic coding agent. Reasonix talks directly to `api.deepseek.com` with no translation shim, and is engineered around DeepSeek's prefix-cache stability (the project reports ~99.8% cache hit rates in real sessions, producing roughly 5x lower per-token cost than naive API use).

Reasonix exposes a `run` subcommand specifically designed for non-interactive headless invocation: read a task, execute, write the result to stdout, exit. That's the exact contract the bridge needs — directly analogous to OpenAI's `codex exec` for the codex-bridge.

## Setup

1. **Install Node.js 22+** (Reasonix's runtime requirement). Windows users also need Git for Windows.

2. **Install Reasonix:**

   ```
   npm install -g reasonix
   ```

   Or use `npx reasonix run ...` directly at the cost of slower start-up per invocation. The bridge pre-flight accepts either, but `npm install -g` is faster.

3. **Get a DeepSeek API key** at https://platform.deepseek.com/api_keys.

4. **Authenticate Reasonix** — two equally valid paths, pick whichever fits your workflow:

   **Path A (recommended for interactive use):** Run `reasonix code` (or `npx reasonix code`) once. The first-run wizard prompts for the API key and stores it in `~/.reasonix/config.json` under the `apiKey` field. Persistent across sessions; no env var needed.

   **Path B (CI / automation / multi-key):** Export `DEEPSEEK_API_KEY` in the shell that runs Claude Code:

   ```
   echo 'export DEEPSEEK_API_KEY=sk-...' >> ~/.zshrc
   source ~/.zshrc
   ```

   (Windows: `setx DEEPSEEK_API_KEY "sk-..."` then restart the terminal.)

   The bridge accepts either auth source. The env var takes precedence over the config file when both are present.

5. **Run `/code4me-preflight`** to confirm:
   - `reasonix` CLI on PATH
   - At least one auth source configured (env var or config-file apiKey)

   The "DeepSeek bridging (optional)" check should show `ok`. If neither auth source is found, the check downgrades to `warn` — the bridge can still attempt invocations but will fail with `deepseek_subprocess_error` until you authenticate.

## Two paths to using the bridge

### Path 1 — individual bridge use (single-role opt-in)

Tell the orchestrator at intake which bridge role you want, by name. Natural-language triggers work:

> Use deepseek-architect for the architecture review on this milestone.

The orchestrator substitutes `deepseek-bridge[architect] (mode=challenge)` for `challenger-architect` in the team composition. The Co-Approval Rule still applies — both Lead (Claude) and Challenger (DeepSeek) must return `approved: true`. No cross-vendor pairing semantics on the rest of the team; everything else stays Claude.

This path is for one-off cross-vendor checks. Combine freely with codex-bridge opt-ins:

> Use codex-architect for the challenger, deepseek-security-reviewer for the security pass, and run the rest on Claude.

That intake dispatches one Codex bridge invocation, one DeepSeek bridge invocation, and the rest on Anthropic — without enabling milestone-wide cross-vendor pairing.

### Path 2 — three-vendor pairing for the whole milestone

Enable the alternation policy at intake AND name DeepSeek in the vendor set:

```
/code4me-dispatch --cross-vendor --vendors anthropic,openai,deepseek
```

Or by natural language at intake:

> Enable three-vendor cross-vendor pairing — Claude + Codex + DeepSeek.

The orchestrator applies the alternation rule from `references/cross-vendor-policy.md` §"Three-vendor pairing (v0.11+)" generalised to three vendors. Producer and verifier are always on opposite vendors. When both non-anchor vendors are valid options for a given pair, the rule prefers the closest-pair-wins choice with alphabetical tiebreaker (anthropic < deepseek < openai).

Cost rises faster than two-vendor pairing. Use three-vendor when the milestone benefits from the broadest dialectic surface — usually Critical work where the value of catching divergent failures outweighs the additional spend.

## Model tier mapping for DeepSeek

| Tier | DeepSeek model (`--model`) | Effort (`--effort`) | Notes |
|---|---|---|---|
| low | `deepseek-v4-flash` | `medium` | Used by combined-reviewer at Conversation/Light weight |
| mid | `deepseek-v4-pro` | `high` | Default for spec-to-test, developer at Standard, verification, code-reviewer, qa, security-reviewer, doc-writer |
| high | `deepseek-v4-pro[1m]` | `max` | 1M-context variant for lead-architect, challenger-architect, security-reviewer at Critical, developer at Critical |

The `[1m]` suffix denotes DeepSeek's 1-million-context variant. Cost is higher than plain `v4-pro`, so the bridge only resolves to it when the role's tier is `high`. Combined with `--effort max`, this gives DeepSeek's strongest configuration.

The effort knob (`--effort low|medium|high|max`) is DeepSeek's reasoning-effort control. The bridge maps tier → effort directly: tier `low` gets `medium` effort (don't waste reasoning on cheap-tier work), tier `mid` gets `high`, tier `high` gets `max`.

## What the bridge does on each invocation

For each role × mode dispatch, the orchestrator:

1. **Pre-flights** `command -v reasonix` only — that's it. Missing CLI → BLOCKED with `reasonix_cli_not_installed`. Auth is the CLI's responsibility; if it fails at invocation time, the bridge surfaces it as `deepseek_subprocess_error` with the auth-error stderr tail (mirroring codex-bridge's auth posture).
2. **Loads the role reference** from `skills/deepseek-bridge/references/{role}.md`.
3. **Assembles the prompt** by substituting Context Pack values into the role reference's mode-specific template. Writes to `/tmp/deepseek-{slug}-{task_id}.txt`.
4. **Invokes Reasonix** via Bash:
   ```
   timeout 300 reasonix run \
     --model deepseek-v4-pro \
     --effort high \
     --no-config \
     --transcript /tmp/deepseek-arch-{task_id}.transcript.jsonl \
     "$(cat /tmp/deepseek-arch-{task_id}.txt)" \
     > /tmp/deepseek-arch-{task_id}.out \
     2> /tmp/deepseek-arch-{task_id}.err
   ```
   Timeouts vary by role (architect-class 300s; developer 600s; verification 360s; lead-architect 360s). The model + effort are resolved by tier.
5. **Parses the response** — extracts the fenced JSON block from the end of stdout, JSON-parses, validates against the role's RETURN SCHEMA.
6. **Logs to dispatch log** with `subagent: "deepseek-{role} (skill-bridge)"`, `vendor: "deepseek"`, the resolved `model` + `effort`, and `transcript_path` pointing at the JSONL receipt.

## Reasonix-specific flags the bridge uses

- **`--model <id>`** — exact DeepSeek model identifier. The bridge uses tier resolution (low/mid/high) rather than Reasonix's `--preset auto|flash|pro` — gives us deterministic control over which model fires. The flag overrides any model set in `~/.reasonix/config.json`.
- **`--effort low|medium|high|max`** — reasoning effort. Mapped from tier as above. Overrides any config-file effort setting.
- **`--transcript <path>`** — write a JSONL transcript with usage/cost/prefix-cache data. The bridge logs the path in the dispatch log; the audit tool can read it for cost rollup.
- **NOT used: `--no-config`** — earlier prototypes passed this for "deterministic per-dispatch settings", but it broke users who'd authenticated via Reasonix's first-run wizard (which stores the apiKey in the config file). The shipped bridge respects the config file; the explicit `--model` and `--effort` flags still override config-file values for the things that affect bridge correctness, so determinism on the load-bearing parameters is preserved.
- **NOT used:** `--system`, `--budget`, `--mcp` — current bridge keeps the prompt structure self-contained for symmetry with codex-bridge. Future versions may use `--system` to separate role-identity from task-spec, or `--mcp` to attach project MCPs.

## Verifying it works

Run probe 06 (`probes/cross-vendor/06-deepseek-pairing-three-vendor.md`) — three-vendor team composition.
Run probe 07 (`probes/cross-vendor/07-deepseek-unavailable-degrades.md`) — missing-`$DEEPSEEK_API_KEY` or missing-`reasonix` failure mode.
Run probe 08 (`probes/cross-vendor/08-deepseek-single-role-opt-in.md`) — Path 1's single-role opt-in.

After a real milestone, `/code4me-audit` should show DeepSeek dispatches in the vendor split section with the per-tier model breakdown. The transcript files include prefix-cache hit rate per call — useful for confirming Reasonix's cache optimization is firing.

## Limitations and caveats

- **Reasonix's tool surface is its own.** Inside a bridge invocation, Reasonix uses its own agentic tools (file read/write/edit, bash, etc.) — these are NOT shared with the orchestrator's Claude Code tool surface. The orchestrator passes the prompt; Reasonix runs its own loop; only the final stdout result returns. If you need the orchestrator's tools (e.g., a specific MCP) inside the bridge invocation, attach it via Reasonix's `--mcp <spec>` flag (not currently used by the bridge but supported by Reasonix).
- **No streaming progress to the parent thread.** The orchestrator waits for the subprocess to finish (up to the timeout) before seeing the result. Long developer-class invocations will block the orchestrator for minutes.
- **Cost rollups via transcript.** The bridge writes the transcript JSONL path to the dispatch log. Audit-tool surveillance can read those transcripts for per-dispatch token / cost / cache-hit data. Reasonix's prefix-cache means apparent costs can be dramatically lower than naive token-count math suggests.
- **No persistent session memory across invocations.** Each bridge call is a fresh `reasonix run`. There's no continuity between invocations on the DeepSeek side — the orchestrator's parent thread maintains continuity, each bridge call is a clean slate from Reasonix's perspective. (Reasonix does have a `--session` flag for its TUI, but the bridge's `--no-config` and per-dispatch shape doesn't use it.)
- **Reasonix is third-party.** Code is sent to DeepSeek's API for processing. DeepSeek's data policy states they do not use API inputs for training. If your project's auth/legal posture restricts non-US providers (DeepSeek operates from China), do not enable.

## Combining DeepSeek + Codex + Anthropic

The three vendors compose freely. Some patterns worth knowing:

- **Three-vendor Critical milestone** — anthropic anchors, codex challenges, deepseek reviews. Highest dialectic surface, highest cost. Justify when the milestone touches sensitive surfaces (auth, persistence, payments).
- **DeepSeek for cost-sensitive bulk work** — set DeepSeek as the developer (per-role opt-in), and use codex-bridge for the final security/code review. DeepSeek's per-token cost is meaningfully lower for routine implementation work, especially with Reasonix's prefix-cache.
- **Anthropic anchor, deepseek single-role for security only** — the lowest-overhead way to get cross-vendor security review. One bridge invocation per milestone; rest of team is single-vendor.

## When NOT to enable

- **You don't have a DeepSeek API key handy.** The bridge degrades gracefully (falls back to anchor) but adds noise to the dispatch log if every milestone records `pairing_degraded: deepseek_unavailable`. If you don't plan to use DeepSeek for a while, leave it disabled.
- **Your project's auth/legal posture forbids sending code to non-US providers.** See above.
- **You're new to code4me.** The plugin's value comes from getting one vendor working well first. Enable DeepSeek after you've run several milestones successfully on Anthropic.

## Cross-vendor protection: the three layers (v0.13+)

Claude Code's PreToolUse hooks only fire inside the Claude Code session itself. When the orchestrator dispatches to deepseek via `reasonix run`, the subprocess runs its own tool calls and Claude-side hooks never see them. v0.13 introduces layered protection to close this gap (symmetric with `howto-enable-codex.md` §"Cross-vendor protection"):

- **Layer A — Claude-side PreToolUse hooks (existing).** Fires on the orchestrator's own tool calls. Strongest protection.
- **Layer B — Reasonix-side PreToolUse hooks (ear-tagged, not yet built).** Reasonix supports lifecycle hooks (`PreToolUse` gating, `PostToolUse`, `UserPromptSubmit`, `Stop`) via project-level `<project>/.reasonix/` config and `~/.reasonix/config.json` (global). What reasonix's `PreToolUse` actually intercepts (single tool? all tools? specific subset?) needs verification before wiring — the roadmap (`docs/roadmap.md`) tracks this as a prerequisite for the Layer B build.
- **Layer C — Post-validation diff scan (v0.13+, shipped).** After `reasonix run` returns, the bridge runs `bin/code4me-bridge-diff-scan.sh` (the same helper codex-bridge uses) which inspects `git status --porcelain` and cross-references against `.code4me/protected-tests.txt`, `.code4me/critical-allowlist.txt` (Critical-mode), and `.code4me/forbidden-conditions.json` (Conversation-mode). Violations surface as typed blockers — the same blockers Claude-side hooks produce. Deterministic; can't be lied about.

**Layer C requires git.** When the project isn't a git repo, the diff scan skips with `layer_c_status: skipped` in the dispatch log. Layer C becomes a no-op; Layer A still covers what it can.

See `skills/deepseek-bridge/SKILL.md` §"Invocation flow" step 5 for the bridge-side details, and `probes/cross-vendor/09-bridge-post-validation-catches-protected-test-edit.md` for the directly-executable probe that verifies Layer C (helper is vendor-agnostic; one probe covers both bridges).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `reasonix_cli_not_installed` BLOCKED | Reasonix not on PATH | `npm install -g reasonix` and confirm with `command -v reasonix` |
| `deepseek_subprocess_error` with auth-error stderr | No DeepSeek API key configured anywhere | Run `reasonix code` once for the first-run wizard, OR `export DEEPSEEK_API_KEY=sk-...` |
| `deepseek_timeout` (exit 124) | DeepSeek-side latency, long tool loops, or runaway agentic recursion in Reasonix | Increase `timeout` for the role in the bridge invocation; check the `.err` file for tool-use traces; or check Reasonix's `--budget` setting if a per-session USD cap is needed |
| `deepseek_response_invalid` | Final fenced ```json block missing from response | Check the `.out` file. The prompt template asks Reasonix to end with a fenced JSON block matching the role's RETURN SCHEMA; if it didn't, DeepSeek may have misunderstood the prompt — try the `high` tier (with `--effort max`) for that dispatch |
| `deepseek_api_error` with HTTP 401 | API key invalid or expired | Verify the key at https://platform.deepseek.com/api_keys; regenerate if needed |
| `deepseek_api_error` with HTTP 429 | Rate limit | Wait, retry; consider lowering parallel DeepSeek invocations per milestone |
| `deepseek_api_error` with context-length error | Prompt + tool I/O exceeded the model's context window | Switch to the `high` tier (1M context variant) for that role; or reduce the Context Pack via `/compact` between phases |
| Apparent runaway cost | Reasonix's prefix-cache rarely fires | Long-lived sessions help cache stability; per-dispatch invocations like the bridge don't benefit as much as interactive TUI sessions. If cost is concerning, lower the tier or set `--budget <usd>` |
