# Probe: deepseek_unavailable degradation falls back to anchor without blocking (v0.11+)

**Subject:** cross-vendor
**Coverage:** Verifies the orchestrator's pre-flight check for the Reasonix CLI at team-composition time, and the graceful fallback documented in `references/cross-vendor-policy.md` §"Failure mode: `deepseek_unavailable`". When the user enables cross-vendor pairing with DeepSeek in the pairing set but Reasonix isn't installed, the orchestrator falls back to the anchor vendor for the affected roles, records `pairing_degraded: deepseek_unavailable` in the dispatch log, and surfaces the remediation hint to the user — without blocking the milestone.

The probe also covers an adjacent failure mode: missing auth (no `$DEEPSEEK_API_KEY` env var AND no `~/.reasonix/config.json` apiKey). This is NOT pre-flight-detected (mirroring how codex-bridge handles missing-codex-auth); it surfaces at bridge invocation as `deepseek_subprocess_error`.

## Input prompt

> Standard milestone: validate the import CSV format and reject malformed rows with structured errors. Goes in `src/import/csv_validator.cs` with paired test file. Enable cross-vendor pairing with DeepSeek as the challenger architect and code-reviewer.

## Scenario A — Reasonix CLI missing (pre-flight degrades)

### Fixture

`command -v reasonix` returns empty exit (the user has not installed Reasonix). `$DEEPSEEK_API_KEY` may or may not be set — irrelevant; the pre-flight degrades on CLI absence alone.

### Expected

- **Pre-flight result:** `command -v reasonix` → exit 1 → `pairing_degraded: deepseek_unavailable`.
- **Team after degradation:**
  - `challenger-architect (claude:high)` — **degraded from `deepseek-bridge[architect]`** — fell back to anchor (Anthropic). `vendor_pairing.degraded: deepseek_unavailable`.
  - `code-reviewer (claude:mid)` — **degraded from `deepseek-bridge[code-reviewer]`** — same.
  - Everything else unchanged on the anchor.
- **Transparency announcement** includes:
  > Pairing degraded for `deepseek-bridge[architect]` and `deepseek-bridge[code-reviewer]` — `reasonix` CLI not on PATH. Falling back to anchor vendor (anthropic) for these two roles. The milestone proceeds. To re-enable DeepSeek for the next milestone, `npm install -g reasonix` (or use `npx reasonix run`) and retry.

### Pass criterion

1. The orchestrator does NOT block the milestone on missing Reasonix. The milestone runs to completion on the anchor vendor.
2. The orchestrator runs the `command -v reasonix` pre-flight BEFORE composing the team — not at dispatch time. Composing with `deepseek-bridge[*]` only to discover the CLI is missing at invocation would burn token context on a doomed plan.
3. Dispatch log entries for the two degraded roles carry `vendor_pairing.degraded: deepseek_unavailable`.
4. The announcement names the remediation step (install Reasonix; link or command name).
5. No deepseek-bridge skill is invoked.

## Scenario B — Reasonix CLI installed but no auth configured (invocation degrades)

### Fixture

`command -v reasonix` succeeds (installed via `npm install -g reasonix`). BOTH auth sources are absent: `$DEEPSEEK_API_KEY` is unset AND `~/.reasonix/config.json` either doesn't exist or has no `apiKey` field. Pre-flight passes; bridge invocation fails.

### Expected

- **Pre-flight result:** `command -v reasonix` → exit 0. Bridge invocation proceeds.
- **`reasonix run` outcome:** non-zero exit with auth error in stderr (Reasonix reports the missing-key state).
- **Bridge catches the failure:** surfaces as `BLOCKED` with `blocker_type: deepseek_subprocess_error`, `blocker_detail` = stderr tail naming the auth error.
- **Orchestrator handles it:** circuit-breaker engages, the role escalates as a typed blocker to the user (NOT silently fallback — the user explicitly opted into DeepSeek; tell them why it failed).
- **Remediation hint** in the user-facing message: "Reasonix can't authenticate. Either run `reasonix code` once to trigger its first-run wizard (stores apiKey in ~/.reasonix/config.json), OR `export DEEPSEEK_API_KEY=...` and retry."

### Pass criterion

1. The bridge does NOT silently fallback to anchor on auth failure (the auth state is opaque pre-invocation; we don't know if it's a transient API issue or a missing key without inspecting Reasonix's stderr).
2. The `deepseek_subprocess_error` blocker carries the stderr tail in `blocker_detail` so the user has the actionable signal.
3. The orchestrator's transparency-announcement step surfaces the auth-failure remediation explicitly.
4. No further bridge invocations fire for the same milestone — the orchestrator escalates.

## Failure modes both scenarios catch

- Orchestrator blocks the entire milestone on missing Reasonix CLI — Scenario A's degradation is the rule, blocking is the exception.
- Orchestrator pre-checks auth (env var + config file) and blocks at pre-flight — this is what the v0.11 prototype did; v0.11 final dropped the pre-check for symmetry with codex-bridge. Pre-flight checks CLI presence only.
- Orchestrator runs the pre-flight only once at session start and caches the result for the whole session. Env vars and PATH can change between sessions. Pre-flight runs at every milestone's team-composition step.
- Orchestrator surfaces the remediation as "set DEEPSEEK_API_KEY" without mentioning the config-file alternative (Reasonix's first-run wizard) — half the supported auth surface gets lost.
- Orchestrator conflates Scenario A and Scenario B blockers: missing CLI is `deepseek_unavailable` (pre-flight degradation); missing auth is `deepseek_subprocess_error` (invocation failure). The two have different remediations and the user-facing messages differ accordingly.

## Companion probe

This is the DeepSeek equivalent of probe 03 (`03-pairing-degrades-when-shim-missing.md`). The two should pass in parallel: if `codex` is missing AND `reasonix` is missing, both degradations fire and the milestone runs entirely on the anchor vendor (no cross-vendor benefit, but no block either).

## Audit-tool integration

After the milestone closes, run `/code4me-audit`. The "Cross-vendor pairing" section should show:

- For Scenario A: `deepseek_unavailable: 2` in the degrade-reason table; total cross-vendor dispatches: 0 (both degraded to anchor).
- For Scenario B: 0 degradations recorded (pre-flight passed); 2 bridge invocations attempted with `outcome: BLOCKED` and `blocker_type: deepseek_subprocess_error`.

If Scenario B records `deepseek_unavailable`, the probe failed — the orchestrator pre-checked auth instead of letting Reasonix decide.
