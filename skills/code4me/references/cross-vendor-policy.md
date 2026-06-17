# Cross-Vendor Pairing Policy

Rules for how the orchestrator picks which vendor runs which subagent when cross-vendor pairing is enabled for a milestone. Read alongside `model-selection.md` (per-(subagent, weight) tier defaults) and `model-selection.yaml` (machine-readable form). Together they answer the two dispatch questions: *which vendor?* (this file) and *which model on that vendor?* (the tier system).

## When this applies

Cross-vendor pairing is **opt-in per milestone**. The user enables it at intake by stating cross-vendor intent (or by invoking `/code4me-dispatch --cross-vendor`); otherwise the orchestrator treats every dispatch as single-vendor (Anthropic by default) and this file's rules are no-ops. The existing `codex-architect` Co-Approval pattern works whether or not the broader pairing is enabled — it's its own opt-in path.

When the policy is enabled, the orchestrator applies the alternation rule below to every dispatch in the milestone, records the pairing decision in the dispatch log, and surfaces it in the Team Transparency announcement.

## The alternation rule

When cross-vendor pairing is enabled, the orchestrator dispatches producer and verifier on **opposite vendors**. Claude-side roles dispatch as Task-tool subagents (the agent files in `agents/`); Codex-side roles invoke the `codex-bridge` skill at `skills/codex-bridge/` from the orchestrator's own thread (no subagent spawn — saves the Claude wrapper cost and eliminates the v0.6–v0.9 identity-drift failure mode). The pairing is computed at team-composition time, not per-dispatch, so the team transparency line shows the full pairing before the first dispatch.

The rule applies to these pairs:

| Producer | Verifier | Existing? |
|---|---|---|
| `lead-architect` | `challenger-architect` | Yes — Co-Approval (existing) |
| `spec-to-test` | `developer` | New — test author ≠ implementer |
| `developer` | `code-reviewer` | New — implementer ≠ reviewer |
| `developer` | `verification` | New — implementer ≠ verifier |
| `developer` | `security-reviewer` | New — Critical / auto-escalated only |

The "test author ≠ implementer" pairing is the strongest cross-vendor lever — same-vendor Spec-to-Test and Developer can match test shape unconsciously through shared distribution biases. Different vendors break that loop.

## Resolution algorithm

At team-composition time, the orchestrator:

1. **Check the gate.** Is cross-vendor enabled for this milestone? If not, every role defaults to `anthropic`. Skip the rest.
2. **Pick the producer's vendor.** Default `anthropic` unless cerebrum, a prior milestone override, or the user override says otherwise. Record this as the "anchor" vendor.
3. **For each pair the producer participates in,** set the verifier's vendor to the opposite of the anchor. Each agent's `cross_vendor_pair_with:` frontmatter declares which pairs it participates in.
4. **Resolve transitive conflicts.** If the same role appears as verifier in pair A and producer in pair B with conflicting vendor assignments, prefer the pair closest to the artifact under review (e.g., `developer↔code-reviewer` wins over `spec-to-test↔developer` when both compete for the developer's vendor). Record the resolution choice in the announcement.
5. **Check Codex bridge availability.** For every cross-vendor assignment that resolves to vendor=openai, confirm the `codex` CLI is on PATH (the orchestrator runs `command -v codex` once at team-composition time as part of the codex-bridge skill's pre-flight). If `codex` is missing, fall back to the anchor vendor for that role and record `pairing_degraded: codex_unavailable` in the dispatch log entry. Note: the bridge does NOT pre-check `OPENAI_API_KEY` — modern Codex CLI supports `codex login` (OAuth) OR the env var; auth failures (if any) surface when `codex exec` actually runs.
6. **Resolve concrete models.** For each (role, vendor) pair, look up the tier from `model-selection.yaml` and the concrete model identifier from `vendor-models.yaml`. The Task dispatch for Claude-side roles carries the explicit `model` string; the codex-bridge invocation for Codex-side roles passes it via `--model` to `codex exec`.

## Recording

Every dispatch log entry carries the pairing decision and the tier resolution:

```jsonl
{
  "ts": "<ISO8601>",
  "milestone": "<id>",
  "task": "<id>",
  "weight": "Standard",
  "subagent": "code-reviewer",
  "vendor": "openai",
  "model_tier": "mid",
  "default_tier": "mid",
  "tier_deviated_from_default": false,
  "model": "gpt-5.4",
  "mode": "review-diff",
  "outcome": "COMPLETE",
  "escalation_trigger": null,
  "vendor_pairing": {
    "policy": "alternation",
    "pair_role": "developer→code-reviewer",
    "alternates_with": "anthropic",
    "degraded": null
  }
}
```

The audit tool (`bin/code4me-audit-dispatch-log`) groups by `(vendor, tier)` and surfaces pairing-degraded entries as a separate section so cross-vendor cost rollups and Codex-availability problems both stay visible. Codex-bridge invocations appear in the log with `subagent: "codex-{role} (skill-bridge)"` to distinguish them from Claude-side Task dispatches.

## Failure modes and fallback

Three pairing-layer failure conditions, each with a typed handling rule:

1. **Codex unavailable for a required cross-vendor dispatch.** The alternation rule assigned a role to vendor=openai, but the `codex` CLI is missing from PATH (pre-flight `command -v codex` fails). **Action:** fall back to the anchor-vendor (Claude) for that role's dispatch; record `pairing_degraded: codex_unavailable` with the reason; do not block the milestone — cross-vendor benefit is degraded but the role still runs via the Claude-side subagent. The user gets visibility through the transparency announcement.
2. **Pairing conflict cannot be resolved.** The transitive-conflict step yields a contradiction that the "closer pair wins" rule cannot adjudicate. **Action:** prefer the pair tied to the most recent artifact under review (the one currently in flight); record the resolution in the transparency announcement; do not block.
3. **User declares "always Claude" mid-milestone.** The user overrides cross-vendor for the remainder of the milestone. **Action:** honour the override for every subsequent dispatch; record `pairing_degraded: user_override` on each; keep prior dispatches' pairing decisions intact in the log.

In all three cases the milestone proceeds. The pairing layer never blocks work — it strengthens dialectic when it can and gets out of the way when it cannot.

## Hard floors (vendor-agnostic)

Restated from `model-selection.yaml` for completeness — the pairing layer does not relax tier floors:

- Any role whose name contains "architect" never runs at tier `low`, regardless of vendor.
- Critical Mode never runs at tier `low` on any role, regardless of vendor.
- Auto-escalated work's tier is never downgraded below the resolved value.
- A Codex developer at Critical is still tier `high` — the vendor switch does not relax the tier.

## Transparency announcement format

Update from the existing `(anthropic:opus)` form to `(vendor:tier)`. The concrete model identifier lives in the dispatch log; the announcement stays compact.

Example (Standard milestone with cross-vendor enabled):

> Team for `M07-T03-DEV`: `lead-architect (claude:high)`, `codex-architect (codex:high, mode=challenge)`, `codex-spec-to-test (codex:mid)`, `developer (claude:mid)`, `codex-verification (codex:mid)`, `codex-code-reviewer (codex:mid)`, `qa (claude:mid)`, `codex-security-reviewer (codex:high)`, `doc-writer (claude:mid)`. Pairing: architect Co-Approval (Claude / Codex); test author (Codex) ≠ implementer (Claude); implementer (Claude) ≠ reviewer/verifier/security (Codex). QA and docs single-vendor.

## What this policy is not

- **Not a substitute for the Co-Approval Rule.** The architect Co-Approval Rule (Lead and Challenger both `approved: true`) applies whether or not broader cross-vendor pairing is enabled. They compose; they don't replace each other.
- **Not "run both vendors in parallel as verifiers."** Doubling verifier dispatches would multiply cost without commensurate benefit. The alternation rule provides cross-vendor coverage at the same dispatch count as single-vendor.
- **Not forced on Critical Mode.** Critical Mode is high-stakes but the cost surface is real. Users opt in per milestone; auto-escalation does not force cross-vendor on.
- **Not a substitute for the tier system.** Pairing decides *which vendor* — tier decides *which model on that vendor*. Both questions must be answered for every dispatch.

## Three-vendor pairing (v0.11+)

DeepSeek joins as a third vendor alongside Anthropic and OpenAI. The alternation rule generalises: for any pair where the producer is on vendor `V`, the verifier is on a vendor that is NOT `V`. With three vendors, the choice between the two non-anchor vendors uses the same closest-pair-wins rule as the two-vendor case, with an additional tiebreaker: prefer the vendor declared in `cross_vendor_pair_with: {role: ..., prefer_vendor: ...}` if set on the verifier's role, otherwise alphabetical by vendor name (anthropic < deepseek < openai).

The mechanism per vendor:

| Vendor | Mechanism | CLI requirement | Auth |
|---|---|---|---|
| anthropic | Task tool dispatching the Claude-side subagent (`agents/*.md`) | Claude Code (already running) | Inherited from session |
| openai | codex-bridge skill (`skills/codex-bridge/`) invoked inline | `codex` on PATH | `codex login` (OAuth) OR `OPENAI_API_KEY` env |
| deepseek | deepseek-bridge skill (`skills/deepseek-bridge/`) invoked inline | `reasonix` on PATH (DeepSeek-native CLI) | `$DEEPSEEK_API_KEY` env OR `~/.reasonix/config.json` `apiKey` field |

The orchestrator's pre-flight at team-composition time checks `command -v codex` (for openai assignments) and `command -v reasonix` (for deepseek assignments). Either CLI missing → `pairing_degraded: codex_unavailable` or `pairing_degraded: deepseek_unavailable` and the role falls back to the anchor vendor. Neither bridge pre-checks auth — that's the CLI's responsibility; auth failures surface at invocation time as `codex_error` / `deepseek_subprocess_error` with the stderr tail in `blocker_detail`. Install Reasonix with `npm install -g reasonix` (or use `npx reasonix run` at the cost of slower start-up); run `reasonix code` once to trigger its first-run auth wizard, or `export DEEPSEEK_API_KEY=...` — either works.

### Three-vendor announcement format

The transparency announcement extends naturally; vendor names enumerate as needed:

> Team for `M07-T03-DEV`: `lead-architect (claude:high)`, `deepseek-architect (deepseek:high, mode=challenge)`, `spec-to-test (claude:mid)`, `codex-developer (openai:mid)`, `verification (claude:mid)`, `deepseek-code-reviewer (deepseek:mid)`. Pairing: three-vendor — Lead architect (Anthropic) ↔ Challenger (DeepSeek) Co-Approval; test author (Anthropic) ≠ implementer (OpenAI); implementer (OpenAI) ≠ reviewer (DeepSeek) ≠ verifier (Anthropic). Doc-writer skipped; researcher and qa not in scope.

In practice most milestones won't use all three vendors at once — that's a cost call the user makes at intake. Two-vendor pairing (Anthropic + DeepSeek, Anthropic + OpenAI, or OpenAI + DeepSeek) is the common case.

### When the user names "DeepSeek" specifically

The user can opt into a single deepseek role even without enabling three-vendor pairing milestone-wide. Same intake patterns as the existing codex-* opt-in:

- "use deepseek-architect for this" → one-off DeepSeek challenger for this milestone's architect step; rest of team stays single-vendor anchor.
- "have deepseek-developer implement" → DeepSeek developer for this task only.
- "let deepseek do the security review" → DeepSeek security-reviewer.

The dispatch gate (`skills/code4me/SKILL.md` → "deepseek-bridge dispatch gate") enforces this — the orchestrator never invokes the deepseek-bridge unilaterally; it requires the user signal.

### Failure mode: `deepseek_unavailable`

Mirroring `codex_unavailable`. Triggered when `command -v reasonix` returns empty (Reasonix CLI not installed). **Action:** fall back to the anchor vendor for that role's dispatch; record `pairing_degraded: deepseek_unavailable` with the reason; do not block the milestone. The user gets visibility through the transparency announcement and a remediation hint: *"DeepSeek pairing degraded — install reasonix (`npm install -g reasonix`), then retry the next dispatch. The current milestone proceeds on the anchor vendor."*

**Note:** `deepseek_unavailable` is CLI-presence only, not auth. Auth failures (no `$DEEPSEEK_API_KEY` AND no `~/.reasonix/config.json` apiKey) surface at the bridge invocation as `deepseek_subprocess_error` with the auth-error stderr tail — mirroring how missing-codex-auth surfaces as `codex_error` rather than a pre-flight blocker. This keeps the pre-flight cheap and surfaces real auth state at the moment Reasonix actually tries to authenticate.
