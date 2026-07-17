# Reference

The substantial reference content for code4me, organized for lookup rather than learning. For step-by-step walkthroughs see `docs/tutorial.md`; for task-oriented recipes see the `docs/howto-*.md` files; for design rationale see `docs/explanation.md`.

## Workflow weights

| Weight | When | Team |
|---|---|---|
| Trivial (v0.10.4+) | tiny, single-file, no behaviour change (whitelist-bounded) | none — inline orchestrator edit with mandatory justification |
| Conversation | small, well-understood, reversible work | Developer + Combined Reviewer |
| Light | small but pattern-following | Architect (notify) + Developer + Combined Reviewer |
| Standard | default; non-trivial, new interfaces or data flow | full crew |
| Critical | high-stakes (auth, payments, privacy, public APIs) | full crew + extra QA + your sign-off |

The orchestrator enforces an **auto-escalation override**: if the work touches authentication, sensitive data, cross-cutting concerns, new external dependencies, or any other listed symptom class, the weight is escalated to at least Standard regardless of what you declared. This is deliberate and non-negotiable.

**Solo execution mode (v0.13+)** is orthogonal to weight: on explicit request only ("solo" at intake, `--solo` flag, or `CLAUDE.md` default), the orchestrator implements Conversation/Light/Standard tasks inline, always dispatching one fresh-context gate (Combined Reviewer, or Verification for Standard). Critical never runs solo; escalation and architecture floors still dispatch. Full rules: `skills/code4me/references/solo-mode.md`.

Full symptom-class list: `skills/code4me/references/auto-escalation.md`. Detailed weight definitions: `skills/code4me/references/workflow-weights.md`.

## Standard Mode flow

```
User (Product Owner)
   │
   ▼
Producer
   │  intake → classify → auto-escalate
   ▼
Product Coach   (optional, Standard/Critical; skipped when Spec Kit interop is active)
   │
   ▼
Lead Architect  ⇄  Challenger Architect    ── Co-Approval Rule (both: approved=true)
   │
   ▼  Tech Spec + Execution Dependency Plan
Spec-to-Test                                ── Pre-Implementation Test Gate
   │
   ▼  Test Spec + protected test skeletons
Developer                                   ── Implementation Gate
   │
   ▼  implementation + tech docs
Verification  →  Code Reviewer  →  QA       ── Quality Gate Loop (re-run on fail)
   │
   ▼  all pass
Doc Writer
   │
   ▼  user-facing docs
Release                                     ── Critical: + post-release QA + user sign-off
```

Conversation Mode collapses this to: Producer → Developer → Combined Reviewer (loop on REWORK). Light Mode adds an architect-notify (non-blocking) before Developer.

## Available subagents (15 total)

Claude-side:

- `developer` — implements code changes per the spec or Conversation Note
- `combined-reviewer` — single combined-pass reviewer for Conversation and Light Mode
- `lead-architect` — architecture proposals, Tech Specs, Execution Dependency Plans
- `challenger-architect` — pressure-tests architecture; mandatory critique with named alternatives
- `spec-to-test` — Test Spec + initial test files with Given/When/Then discipline
- `verification` — designated owner of full-suite confirmation; AC coverage assessment
- `code-reviewer` — quality-only reviewer for Standard Mode (distinct from `combined-reviewer`)
- `qa` — exploratory testing beyond the Test Spec; also Bug Fix reproduction (Claude-only by design)
- `doc-writer` — user-facing documentation
- `researcher` — desk-based investigation, comparison, synthesis (Claude-only by design)
- `product-coach` — optional systematic-intake helper for Standard/Critical
- `security-reviewer` — OWASP-Top-10 + STRIDE security pass; fires automatically on auto-escalation symptom classes

Codex shims (opt-in; see `docs/howto-enable-codex.md`):

- `codex-architect` — three modes (`challenge`, `consult`, `review-spec`); cross-vendor co-architecture
- `codex-developer` — three modes (`implement`, `review-diff`, `spike`); cross-vendor implementation
- `codex-code-reviewer` — three modes (`review-diff`, `review-files`, `review-spec-fit`)
- `codex-spec-to-test` — two modes (`generate`, `review-test-spec`)
- `codex-security-reviewer` — two modes (`diff-focused`, `comprehensive`)
- `codex-verification` (v0.8+) — two modes (`suite-run`, `ac-coverage`)
- `codex-lead-architect` (v0.8+) — two modes (`propose`, `amend`)

`codex-qa` and `codex-researcher` do not exist by design — QA and Researcher stay Claude-only.

## Slash commands

- `/code4me-classify <task>` — intake + classification, no dispatch (read-only)
- `/code4me-dispatch <weight> [--cross-vendor] [--solo] <task>` — explicit weight, skip intake; auto-escalation still applies; `--solo` (v0.13+) runs the task in solo execution mode
- `/code4me-status [milestone_id]` — read-only snapshot of `.code4me/`
- `/code4me-init` — scaffold a new project; never overwrites
- `/code4me-probe-run [subdir|path]` — programmatic probe runner with LLM-as-judge + regression-budget
- `/code4me-improve --held-out-manifest PATH [probe scope]` — supervised baseline/candidate experiment with external hash-verified held-out probes, explicit approval, and keep/revert
- `/code4me-audit [path]` — wraps the dispatch-log audit tool
- `/code4me-promote-or-revert <task_id>` — closes the Conversation Mode loop
- `/code4me-preflight [--critical] [--quiet]` (v0.9+) — sanity-check the dispatch environment
- `/code4me-trello-init` — one-time Trello board scaffold for the trello-sync skill
- `/code4me-housekeeping` (v0.12+) — session-boundary checkpoint; writes a handoff manifest

(The `/audit4me-config`, `/audit4me-run`, and `/audit4me-status` commands belong to the audit4me surface — see `skills/audit4me/SKILL.md`.)

## Vendor-aware models and independent effort (v0.14+)

| Profile | Claude | Codex (OpenAI) | DeepSeek |
|---|---|---|---|
| `low` | `claude-haiku-4-5` | `gpt-5.6-luna` | `deepseek-v4-flash` |
| `mid` | `claude-sonnet-5` | `gpt-5.6-terra` | `deepseek-v4-pro` |
| `high` | `claude-opus-4-8` | `gpt-5.6-sol` | `deepseek-v4-pro` |

Anthropic `frontier: claude-fable-5` is explicit-only. Effort is resolved separately as `low`, `medium`, or `high`; `xhigh` and `max` require an explicit deviation and backend support. Legacy entries without effort use `low -> low`, `mid -> medium`, `high -> high` with `effort_source: legacy_tier_fallback`.

Hard floors:

- Architect roles never run at tier `low`
- Critical Mode never runs at tier `low`
- Auto-escalated work: tier never downgraded
- Cross-vendor pairing does not relax tier floors

## Cross-vendor pairing (v0.7+, completed v0.8)

Opt-in per milestone (`--cross-vendor` flag or natural-language signal at intake). When enabled, the alternation rule from `references/cross-vendor-policy.md` runs producer and verifier dispatches on opposite vendors. Pairs:

- `lead-architect` ↔ `challenger-architect` (Co-Approval; existing pre-v0.7)
- `spec-to-test` → `developer` (test author ≠ implementer)
- `developer` → `code-reviewer` (implementer ≠ reviewer)
- `developer` → `verification` (implementer ≠ verifier)
- `developer` → `security-reviewer` (Critical / auto-escalated only)

See `docs/howto-enable-cross-vendor.md` for the operational walkthrough.

## Runtime hooks

Three opt-in PreToolUse hooks; all return `permissionDecision: ask` (never `deny`); silent pass-through when state file is absent. See `docs/howto-install-hooks.md` for installation.

| Hook | Fires when | State file |
|---|---|---|
| `check-test-protection.sh` | Edit/Write targets a protected test | `.code4me/protected-tests.txt` |
| `check-forbidden-conditions.sh` | Conversation-Mode Write creates a forbidden new file | `.code4me/forbidden-conditions.json` |
| `check-critical-write-allowlist.sh` (v0.8+) | Critical-Mode Edit/Write outside the allowlist | `.code4me/critical-allowlist.txt` |

Symmetric across vendors as of v0.9: the codex-developer shim's implement-mode validation pre-screens `files_touched` against the protected-tests and critical-allowlist files, so Codex-side dispatches respect the same protections even though they don't pass through Claude Code's hook system.

## Audit and analytics (v0.8+)

The dispatch-log audit tool (`bin/code4me-audit-dispatch-log`, via `/code4me-audit`) reads `.code4me/dispatch-log.jsonl` and surfaces:

- Dispatches per subagent / weight / vendor / tier / outcome
- Vendor × tier rollup (for cost rollups)
- Weight × outcome heatmap (gate tuning signal)
- Tier deviation pattern detection (auto-flags (subagent, weight) combos with >50% deviation rate)
- Cross-vendor pairing summary (degradation count + reasons + pair-role distribution)
- Auto-escalation triggers
- Legacy model deviation (pre-v0.7 dispatches)

The probe runner (`bin/code4me-probe-run`, via `/code4me-probe-run`) supports a regression budget (`--max-flips=N`; default from `probes/budget.toml`) and a baseline file (`probes/baseline.jsonl`) — see `docs/probe-baselines.md` for the workflow.

The trace-review discipline (`docs/trace-review.md`) operationalises Hamel Husain's 30-minute trace-reading practice against the audit tool's output.

## Context-query schema (v0.6+, v0.8 added provenance)

Every agent declares a `context_queries:` frontmatter block. The orchestrator resolves these at dispatch time, records `context_provenance` in the dispatch log (which artifact / SHA fed each pack item; v0.8+), and assembles the Context Pack. Schema: `skills/code4me/references/context-queries-schema.md`.

## Dispatch log JSONL shape

One line per Task-tool dispatch in `.code4me/dispatch-log.jsonl`:

```jsonl
{
  "ts": "<ISO8601>",
  "milestone": "<id>", "task": "<id>", "weight": "<weight>",
  "subagent": "<name>", "vendor": "anthropic|openai|deepseek",
  "model_tier": "low|mid|high", "default_tier": "<tier>",
  "tier_deviated_from_default": <bool>, "model": "<concrete id>",
  "effort": "low|medium|high|xhigh|max", "default_effort": "<effort>",
  "effort_deviated_from_default": <bool>,
  "effort_source": "default|explicit_deviation|legacy_tier_fallback",
  "effort_applied": <bool>,
  "mode": "<mode or null>", "outcome": "<outcome>",
  "escalation_trigger": "<symptom class or null>",
  "vendor_pairing": {"policy": "...", "pair_role": "...", "alternates_with": "...", "degraded": "..."},
  "context_provenance": [{"query_kind": "...", "query_descriptor": "...", "resolved_artifact": "...", "resolved_sha": "...", "skipped": <bool>}, ...],
  "spec_kit_interop": <bool>
}
```

Field provenance:

- v0.6: base fields (ts, milestone, task, weight, subagent, vendor, model, mode, outcome, escalation_trigger)
- v0.7: `model_tier`, `default_tier`, `tier_deviated_from_default`, `vendor_pairing`
- v0.8: `context_provenance`
- v0.9: `spec_kit_interop`
- v0.10.4: `trivial_justification` (Trivial entries only; `subagent: "orchestrator-inline (trivial)"`)
- v0.13: `execution_mode` (`"solo"` on all entries of a solo task), `solo_requested_via`, `solo_justification` (solo implementation entries only; `subagent: "orchestrator-inline (solo)"`)
- v0.14: `effort`, `default_effort`, `effort_deviated_from_default`, `effort_source`, `effort_applied`

The log is append-only, local to the project, not part of the plugin distribution. The audit tool reads it; you may parse it yourself with `jq` for ad-hoc queries.

## Folder layout

```
code4me/
├── .claude-plugin/
│   └── plugin.json
├── .lsp.json                       # LSP configs for C#, Swift, C/C++, Python
├── bin/
│   ├── code4me-audit-dispatch-log
│   ├── code4me-probe-run
│   └── code4me-preflight           # v0.9+
├── commands/                       # slash commands (v0.7+)
├── skills/
│   └── code4me/
│       ├── SKILL.md                # slim orchestrator contract
│       ├── ETHOS.md                # shared operating principles
│       └── references/
│           ├── playbook.md
│           ├── context-queries-schema.md
│           ├── workflow-weights.md
│           ├── conversation-mode.md
│           ├── team-templates.md
│           ├── insight.md
│           ├── auto-escalation.md
│           ├── tooling.md
│           ├── model-selection.md        # prose
│           ├── model-selection.yaml      # machine-readable tier defaults (v0.7+)
│           ├── vendor-models.yaml        # vendor → tier → model (v0.7+)
│           ├── cross-vendor-policy.md    # alternation rule (v0.7+)
│           ├── spec-kit-interop.md       # Spec Kit consumption (v0.9+)
│           ├── canonical-workflow.md
│           ├── canonical-artifacts.md
│           ├── release.md
│           ├── circuit-breakers.md
│           └── languages/
│               ├── csharp.md
│               ├── swift.md
│               ├── cpp.md
│               └── python.md
├── agents/                         # 15 subagents (8 Claude-side + 7 Codex shims)
├── templates/
│   ├── conversation_note.md
│   ├── .code4me-skeleton/          # runtime working dir scaffold
│   └── project-starter/            # project-conventions starter (v0.7+)
├── hooks/                          # 3 opt-in PreToolUse hooks
│   ├── check-test-protection.sh
│   ├── check-forbidden-conditions.sh
│   └── check-critical-write-allowlist.sh  # v0.8+
├── probes/                         # executable spec; run after framework changes
│   ├── README.md
│   ├── budget.toml                 # regression budget for /code4me-probe-run (v0.8+)
│   ├── fixture-skeleton/
│   ├── classification/
│   ├── team-composition/
│   ├── auto-escalation/
│   ├── external-agents/
│   ├── hooks/
│   └── cross-vendor/               # v0.7+
├── docs/                           # Diataxis quadrants (v0.9+)
│   ├── tutorial.md
│   ├── howto-*.md
│   ├── reference.md (this file)
│   ├── explanation.md
│   ├── trace-review.md
│   └── probe-baselines.md
├── CHANGELOG.md
└── README.md                       # short pointer at the docs/
```
