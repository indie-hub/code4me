# Model Selection

The prose explanation of how to pick a model per dispatch. The **authoritative machine-readable form** lives in two YAML files the orchestrator consumes at dispatch time:

- `model-selection.yaml` — per-(subagent, weight) tier defaults, plus hard floors and deviation rules
- `vendor-models.yaml` — vendor → tier → concrete model resolution

This file is the *why* — the reasoning behind the defaults, when to deviate, and the consistency checks. The YAML is the *what*. When the two disagree, the YAML wins (it's what the orchestrator reads); update the YAML and refresh the prose here.

## The three tiers

Model selection is vendor-aware through a tier abstraction. Both Anthropic (Claude) and OpenAI (Codex) have analogous tiers; the orchestrator picks a tier per (subagent, weight) and resolves to a concrete model via the chosen vendor.

- **`low`** — fast, low-cost, less nuanced. Use for mechanical work, simple checks, narrow scope. (Claude: Haiku · Codex: GPT-5.4-mini)
- **`mid`** — balanced default. Good reasoning at reasonable speed and cost. Use when in doubt. (Claude: Sonnet · Codex: GPT-5.4)
- **`high`** — deep reasoning, slower, more expensive. Reserved for work where the stakes warrant depth. (Claude: Opus · Codex: GPT-5.5, or `gpt-5.3-codex` for code-heavy work via `high_code`)

There is no separate "effort" knob exposed per dispatch — the tier choice **is** the effort knob. "Make it think harder" maps to "pick a higher tier."

## Default heuristic (mirrors `model-selection.yaml`)

| Subagent / phase | Default tier | Reasoning |
|---|---|---|
| Conversation Mode Developer | `low` | Small, narrow, often mechanical |
| Conversation Mode Combined Reviewer | `low` | Combined-review is mostly a check, not synthesis |
| Light Mode Developer | `mid` | Pattern-following, but warrants balance |
| Light Mode Combined Reviewer | `low` | Prior-example check is mechanical |
| Standard Developer | `mid` | Default; balances cost and quality |
| Standard Lead Architect | `high` | Architecture is where overinvestment pays off |
| Standard Challenger Architect | `high` | Critique benefits from depth |
| Standard Spec-to-Test | `mid` | Pattern-aware translation |
| Standard Verification | `mid` | Defensible review work |
| Standard Code Reviewer | `mid` | Quality assessment |
| Standard QA | `mid` | Exploratory but bounded |
| Standard Documentation Writer | `mid` | Composition + audience tuning |
| Standard Researcher | `mid` (`high` for nuanced comparison) | Mostly synthesis |
| Standard Security Reviewer | `mid` | OWASP / STRIDE / secrets / supply chain |
| Critical anything load-bearing | `high` | Stakes warrant depth |
| Critical Code Reviewer / Security Reviewer | `high` | Cost of a missed Critical-tier issue is high |
| Bug reproduction QA | `low` | Mechanical |
| Incident root-cause investigation | `high` | Uncertainty + complex reasoning |

Codex shims (`codex-architect`, `codex-developer`, `codex-code-reviewer`, `codex-spec-to-test`, `codex-security-reviewer`) inherit the same tier defaults as the role they shim — see `model-selection.yaml`.

## When to deviate from the default

Deviate when:

- **Complexity surprises you.** If a Standard Developer task turns out to involve gnarly logic the Tech Spec didn't fully describe, dispatch the Developer at tier `high` instead of `mid`. Record the deviation as `tier_deviated_from_default: true` with `default_tier` and `actual_tier` in the dispatch log entry.
- **Stakes change mid-flight.** Auto-escalation to Standard or Critical implies upgrading the team's tier. Reissue the Context Pack at the new level.
- **A previous attempt failed.** If a subagent at the default tier produced a poor result and is being re-dispatched, upgrade one tier (`low` → `mid`, `mid` → `high`). Don't re-dispatch at the same tier expecting different results.
- **The user explicitly asks for cheap.** Honor "use the cheapest viable tier." But the auto-escalation override stays in force — symptom-class work still gets at least tier `mid` regardless.

## When NOT to deviate (hard floors — also enforced by `model-selection.yaml`)

- Don't downgrade Architect roles below tier `mid`. Architecture mistakes are the most expensive class of mistake; cheap architects are a false economy. Applies regardless of vendor.
- Don't downgrade Critical Mode work. Critical exists precisely because the stakes warrant depth.
- Don't downgrade auto-escalated work — the override implies a tier upgrade, not a bypass.
- Don't downgrade because the user said "this is small" if the auto-escalation symptom list applies. The user's stated stakes do not override technical signals.
- Cross-vendor pairing does not relax tier floors — a Codex developer at Critical is still tier `high`.

## The orchestrator's own model

The orchestrator (the Claude session running this skill) makes classification, dispatch, escalation, and routing decisions whose mistakes propagate through the entire team. Cheap orchestrator misclassifications cause wrong teams to be assembled and wrong subagent models to be picked — the cost compounds.

**Recommended: run the orchestrator on Opus.**

The orchestrator's depth is the cheapest leverage available for getting everything else right. Opus for the orchestrator is small relative to the cost of running an entire misassembled team on Sonnet, or worse, Critical work that should have been escalated proceeding silently as Light.

This is a recommendation to the user, not something the plugin can enforce — the user picks their session model when they invoke the plugin. The README states the recommendation prominently.

## Vendor dimension

The default vendor for every dispatch is Anthropic (Claude). Two opt-in paths bring OpenAI Codex into the picture:

1. **Individual shim use.** The user enables Codex (sets up the CLI and key) and the orchestrator routes specific roles through the corresponding `codex-*` shim — `codex-architect`, `codex-developer`, `codex-code-reviewer`, `codex-spec-to-test`, `codex-security-reviewer`. Each shim's frontmatter description spells out when to prefer it. No cross-vendor pairing semantics apply automatically.
2. **Cross-vendor pairing.** The user enables cross-vendor at intake (per-milestone, separate opt-in). The orchestrator applies the alternation rule from `references/cross-vendor-policy.md`: producer and verifier dispatch on opposite vendors where shims exist. The architect Co-Approval Rule (Lead and Challenger both `approved: true`) composes with this — they're not the same thing.

Tier resolution is vendor-agnostic. The same `(subagent, weight) → tier` defaults table applies regardless of vendor; the only thing that changes is which row in `vendor-models.yaml` the tier resolves through. Hard floors apply across vendors — a Codex developer at Critical is still tier `high`.

### Per-shim guidance (non-pairing use)

When cross-vendor pairing is **not** enabled but individual shims are:

- **`codex-architect (mode=challenge)` as `challenger-architect` substitute** — recommended for architecture-introducing Standard or Critical work where cross-vendor dialectic strengthens pressure-testing. The `approved` field still satisfies the Co-Approval Rule, so Lead (Claude) and Challenger (Codex) compose normally. `mode=consult` for focused architecture questions, `mode=review-spec` for Tech Spec soundness checks.
- **`codex-developer (mode=implement)` as `developer` substitute** — recommended only on pattern-following Conversation/Light work where the spec is unambiguous. The shim re-encodes Test Protection and Conversation-Mode forbidden conditions; Claude-side Developer remains the default for Standard/Critical. `mode=review-diff` for read-only diff review; `mode=spike` for throwaway prototypes.
- **`codex-code-reviewer`** — read-only quality review on the diff or a file list; `mode=review-spec-fit` for spec-implementation drift.
- **`codex-spec-to-test (mode=generate)`** — when you want a different vendor authoring tests than the planned implementer. Generate mode writes test files and the protected-tests manifest. `mode=review-test-spec` for read-only soundness check.
- **`codex-security-reviewer`** — OWASP / STRIDE / secrets / supply chain on `diff-focused` or `comprehensive` modes. Particularly valuable on auto-escalated work where vendor diversity catches different OWASP categories.
- **`codex-verification`** (v0.8+) — `mode=suite-run` runs the test suite via Codex's shell access, parses results, does AC coverage + test integrity check; `mode=ac-coverage` is a read-only AC traceability pass. Completes the cross-vendor verification chain on Critical milestones so the alternation rule no longer degrades on the verifier role.
- **`codex-lead-architect`** (v0.8+) — `mode=propose` produces an architecture proposal with mandatory ≥ 2 named alternatives; `mode=amend` integrates Challenger amendments into a Tech Spec draft. Use when you want the inverse architect pairing — Codex-Lead with Claude-Challenger — so Claude's training distribution pressure-tests Codex's design.

### Transparency announcement format

The announcement uses `(vendor:tier)` — concrete model IDs live in the dispatch log:

> Team for `M03-T07-DEV` (Standard): `lead-architect (claude:high)`, `challenger-architect (claude:high)`, `developer (claude:mid)`, ...

For cross-vendor work, `claude` and `codex` interleave per the pairing decisions:

> Team for `M07-T03-DEV` (Critical, cross-vendor enabled): `lead-architect (claude:high)`, `codex-architect (codex:high, mode=challenge)`, `codex-spec-to-test (codex:mid)`, `developer (claude:mid)`, ...

Cost tracking: record `vendor: anthropic | openai`, `model_tier`, and the resolved `model` per dispatch in the Milestone Status Tracker and dispatch-log JSONL so cross-vendor cost rollups exist by (vendor, tier). The template under `templates/.code4me-skeleton/` includes the relevant columns.

## Why no fallback model in subagent frontmatter

Subagent definitions intentionally do not lock in a model via frontmatter. Locking would create a default the orchestrator would have to override every time, hiding the cost decision in inheritance. Every dispatch should be a deliberate choice.

If you ever want a hard floor — for example, "Architects always at Sonnet or Opus, never Haiku" — encode that as a constraint in the table above, not in the subagent definition.

## Pairing with workflow weight

The tier heuristic pairs with the workflow weight by design:

- **Conversation team** → `low` tier (cheap, fast, narrow)
- **Light team** → mixed `low` / `mid`
- **Standard team** → `mid` tier with `high` architects
- **Critical team** → `high` tier on load-bearing roles

The weight already implies a tier budget. Stay consistent: if a Conversation request seems to need `high`, that's a signal the weight is wrong — escalate the weight, don't overpower the tier.

## Recording deviations

When you deviate from the default for a specific dispatch, record it in the dispatch-log JSONL as `tier_deviated_from_default: true` with `default_tier` and `actual_tier`. The Milestone Status Tracker captures the human-readable rationale: subagent, default tier, deviated tier, reason. This builds a corpus you can audit later — patterns of deviation are signal that the `model-selection.yaml` defaults need tuning. The audit tool (`bin/code4me-audit-dispatch-log`) surfaces persistent deviation patterns automatically when running across multiple milestones.
