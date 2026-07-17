# How to enable cross-vendor pairing (v0.7+)

Cross-vendor pairing is the framework's most leveraged form of dialectic. Instead of substituting individual Codex shims one at a time, the alternation rule from `references/cross-vendor-policy.md` runs producer and verifier dispatches on opposite vendors across the entire milestone — wherever shims exist.

Prereqs: Codex CLI installed and `OPENAI_API_KEY` set per `docs/howto-enable-codex.md`. Run `/code4me-preflight` to confirm.

## What the alternation rule does

When cross-vendor pairing is enabled for a milestone, the orchestrator dispatches producer and verifier pairs on opposite vendors by default. The pairs are:

| Producer | Verifier | Co-Approval / pairing |
|---|---|---|
| `lead-architect` | `challenger-architect` | Co-Approval Rule (both must return `approved: true`) |
| `spec-to-test` | `developer` | test author ≠ implementer breaks shared-distribution biases on test shape |
| `developer` | `code-reviewer` | implementer ≠ reviewer |
| `developer` | `verification` | implementer ≠ verifier |
| `developer` | `security-reviewer` | implementer ≠ security-reviewer (Critical and auto-escalated only) |

The "anchor" vendor for a milestone defaults to Anthropic (Claude). Verifier dispatches flip to OpenAI (Codex) per role-pair. If you want the inverse direction (Codex-Lead with Claude-Challenger), name `codex-lead-architect` explicitly at intake.

## Enabling per-milestone

Three equivalent ways to enable:

### 1. Slash command flag

```
/code4me-dispatch Standard --cross-vendor <task description>
```

Explicit, recorded in the audit trail. Recommended for one-off cross-vendor milestones.

### 2. Natural language at intake

> Standard milestone for the CSV export feature. Enable cross-vendor pairing for this milestone.

The orchestrator picks up "cross-vendor pairing" / "alternation policy" / "use the cross-vendor flow" as signals.

### 3. Project-default in CLAUDE.md

In your project's `CLAUDE.md`, under a "Cross-vendor pairing" section:

```markdown
## Cross-vendor pairing

**Default for Critical milestones:** enabled. Spec-to-Test on opposite vendor from Developer; Developer on opposite vendor from Code Reviewer / Verification / Security Reviewer.
**Default for Standard:** disabled (opt-in per milestone).
```

The orchestrator reads this at intake; the `--cross-vendor` flag can override per dispatch.

## What you see in the transparency announcement

A Standard milestone with cross-vendor enabled:

> Team for `M07-T03-DEV` (Standard, cross-vendor enabled): `lead-architect (claude:high)`, `codex-architect (codex:high, mode=challenge)`, `codex-spec-to-test (codex:mid)`, `developer (claude:mid)`, `codex-verification (codex:mid)`, `codex-code-reviewer (codex:mid)`, `qa (claude:mid)`, `doc-writer (claude:mid)`. **Pairing**: architect Co-Approval (Claude/Codex); test author (Codex) ≠ implementer (Claude); implementer (Claude) ≠ reviewer/verifier (Codex). QA and docs single-vendor.

The `(vendor:tier)` annotation remains the load-bearing model signal. The announcement also includes a separate effort summary; concrete model identifiers and effort-application status go in the dispatch log.

## What happens when a shim is unavailable

The alternation rule degrades gracefully:

- Codex CLI missing → the specific shim dispatch BLOCKs with `codex_cli_not_installed`; the orchestrator falls back to the anchor vendor and records `pairing_degraded: shim_unavailable` in the dispatch log entry.
- `OPENAI_API_KEY` missing → same outcome, with `codex_auth_missing` as the blocker_type.
- User opts out mid-milestone → the orchestrator honours the override for subsequent dispatches and records `pairing_degraded: user_override`.

In all three cases the milestone proceeds. Cross-vendor benefit is degraded for that pair, not lost overall — same-vendor on both sides means the dialectic is missing but the verifier still runs.

The audit tool's "Cross-vendor pairing" section surfaces persistent degradations:

```
### Pairing degradations: 4 of 12 (33.3%)

| Degrade reason | Count |
|---|---|
| shim_unavailable | 3 |
| user_override | 1 |
```

Persistent `shim_unavailable` means a required shim is consistently missing — install it or remove cross-vendor pairing from the milestone intake.

## When NOT to enable cross-vendor pairing

- **Conversation Mode work.** The weight is supposed to be cheap; cross-vendor doubles the dispatch surface and erodes the cost advantage.
- **First milestone after framework changes.** Run a clean same-vendor milestone first to confirm the framework's normal behaviour, then enable cross-vendor on the next one. Mixing "is the framework working?" with "is the alternation right?" makes debugging harder.
- **Tier-3 candidates.** QA and Researcher are Claude-only by design (no codex-qa or codex-researcher exists or is planned). Cross-vendor pairing doesn't affect them.

## Cost considerations

Cross-vendor pairing **does not** multiply dispatch count — it splits dispatches across two providers. Total token usage drops on the Claude side; total tokens appear on the OpenAI side. The net cost change depends on relative pricing and the size of each role's typical context pack.

The dispatch log's vendor × tier rollup table makes empirical comparison easy after a few milestones. Use this:

```
/code4me-audit
```

The "Vendor × tier rollup" section shows `(vendor, tier)` dispatch counts; combine with your billing data for actual cost rollups.

## When the cross-vendor pairing is the highest leverage

- **Critical milestones** where blast radius matters most. Different-distribution coverage on the verifier pair catches different OWASP categories, different test-shape biases, different reasoning blind spots.
- **Architecture-introducing work.** Same-vendor Lead + Challenger architects can converge on shared blind spots; the Co-Approval Rule with cross-vendor is genuinely stronger.
- **Pre-release security passes.** `codex-security-reviewer (mode=diff-focused)` after the Claude-side gate has run is the canonical "second opinion on the auth code" pattern.

When the cross-vendor pairing matters least is when the change is small and well-understood — Conversation Mode, Light Mode, simple refactors. The cost surface dominates the dialectic value.

## Quick-start recipe

A first Standard milestone with cross-vendor:

1. Confirm setup: `/code4me-preflight`.
2. Pick a task that's normally Standard (a new feature, an interface addition). Avoid Conversation-sized work.
3. Invoke: `/code4me-dispatch Standard --cross-vendor <task description>`.
4. Watch the transparency announcement — confirm the team alternates as expected.
5. Let the milestone run. Each Codex dispatch will print pre-flight verification (CLI present, key set) before invoking.
6. After the milestone closes, run `/code4me-audit` to see the vendor × tier rollup, any pairing degradations, and the cost characteristics.

If degradations appear, address them (install the missing shim, or set the missing key) and re-run a similar milestone. Two clean runs is the empirical signal that the framework can be trusted to do cross-vendor on default Critical milestones.
