# Code4Me

**A multi-agent SDLC orchestrator for Claude Code and Codex.** Turn a one-line user request into a structured workflow: a lead architect designs, a challenger architect critiques, a spec-to-test engineer authors the test gate, a developer implements, and a quality-gate loop (verification + code review + QA) attests the work — all dispatched as agent roles, with optional cross-vendor pairing through OpenAI's Codex CLI or DeepSeek's Reasonix CLI for dialectic.

**Status:** `0.15.5-dev` — Claude Code and Codex share one installable workflow with client-aware hooks and project initialization.

## What it does, concretely

You write:

> Standard milestone: add a CSV export endpoint to the user-profile API. Acceptance criteria: (1) user can export their own data, (2) export includes column headers, (3) requests for other users return 403.

The orchestrator:

1. **Classifies** the request (Standard weight, kind=product, no auto-escalation).
2. **Decomposes** the milestone into ≥1 task per acceptance criterion (v0.12+) — 3 ACs → typically 5-7 dispatched tasks, mapped explicitly.
3. **Announces the team** before any dispatch, including independent model/effort choices: *"Team for M07 (Standard): lead-architect (claude:high), developer (claude:mid), verification (claude:mid), ... Effort: architect=high; developer/verification=medium."*
4. **Dispatches** each subagent via the Task tool, persists artefacts (Tech Spec, Test Spec, AC mapping) under `.code4me/`, and routes INSIGHT messages between roles.
5. **Optionally projects** the milestone to a Trello Kanban board — one card per acceptance criterion, cards move from Inbox → In Progress → In Review → Done as gates pass.
6. **Closes** with verification's AC coverage table, the code-review verdict, and (if applicable) the doc-writer's user-doc updates.

You see the work happen. You stay the Product Owner. The orchestrator handles the rest.

## Install

### 1. Prerequisites

Install Git plus Claude Code, Codex, or both. On Windows, run the shell commands below from Git Bash or WSL; native `cmd.exe` and PowerShell-only environments are not supported.

### 2. Clone the repository

```bash
git clone https://github.com/indie-hub/code4me.git code4me
cd code4me
```

Keep this checkout: its installer scripts configure dependencies and Claude project hooks.

### 3. Install the plugin

For Codex:

```bash
codex plugin marketplace add indie-hub/code4me
codex plugin add code4me@code4me-marketplace
```

For Claude Code:

```bash
claude plugin marketplace add indie-hub/code4me
claude plugin install --scope user code4me@code4me-marketplace
```

Run both pairs when using both clients.

### 4. Install dependencies and configure MCPs

From the code4me checkout, install the core utilities, Basic Memory, codegraph, CocoIndex, and context-mode, then configure the selected client:

```bash
# Codex
bash bin/code4me-install-deps --install core --install memory --install indexes --configure-mcp codex

# Claude Code
bash bin/code4me-install-deps --install core --install memory --install indexes --configure-mcp claude

# Both clients
bash bin/code4me-install-deps --install core --install memory --install indexes --configure-mcp all
```

The script preserves existing MCP entries and prints a final checklist for anything it could not complete automatically.

Optional cross-vendor agent CLIs:

```bash
bash bin/code4me-install-deps --install agents
```

Optional subscription-backed Claude backend for a Codex orchestrator:

```bash
bash bin/code4me-install-deps --install claude-wrapper
claude-p --doctor
```

`claude-p` comes from [indie-hub/claude-wrapper](https://github.com/indie-hub/claude-wrapper) and uses the local Claude Code login rather than the Anthropic API.

### 5. Restart the client

Restart Claude Code and/or Codex so the plugin and MCP configuration reload.

### 6. Initialize the project

Open the target project in the orchestrator and run:

```text
/code4me-init
```

Confirm the preview. Codex creates `AGENTS.md` plus `.code4me/`; Claude Code creates `CLAUDE.md` plus `.code4me/`. Existing files are not overwritten. Init does not own MCP, hook, or LSP configuration.

### 7. Activate hooks

Claude Code stores project hook paths in `.claude/settings.json`. Install or refresh them from the checkout:

```bash
bash bin/code4me-install --project /absolute/path/to/project
```

Do not add `--with-lsp` unless the project deliberately needs the legacy LSP integration.

Codex hooks are bundled with the plugin and require no project hook file. In Codex, run:

```text
/hooks
```

Review and trust the code4me hooks. Repeat this whenever an update changes their definition. Claude uses approval prompts for write-guarded actions; Codex denies the same guarded writes with an actionable explanation because Codex PreToolUse does not support `ask`. Structural-first only adds non-blocking guidance.

### 8. Index the project

From the target project directory:

```bash
codegraph init -i
ccc index
```

### 9. Run preflight

Inside the orchestrator, run:

```text
/code4me-preflight
```

Resolve failures before dispatching work. Warnings identify optional or degraded integrations.

### Updating

Pull the checkout, update the marketplace plugin with the client, rerun the dependency/MCP command from step 4, and restart. Claude users should rerun `code4me-install`; Codex users should rerun `/hooks`. Finish with `/code4me-preflight`.

See [Run code4me with Codex](docs/howto-run-with-codex.md), the [tutorial](docs/tutorial.md), and the [Windows guide](docs/howto-windows.md) for client-specific details.

## Five things that make code4me different

1. **Five workflow weights, not one process.** Trivial / Conversation / Light / Standard / Critical. The orchestrator classifies per-request and runs the smallest workflow that satisfies the stakes. A typo fix doesn't pay Standard-Mode dispatch overhead; a Critical change gets dual architect Co-Approval, full quality-gate loop, and Security Review. v0.13 adds an orthogonal **solo execution mode**: on explicit request, the orchestrator implements Conversation/Light/Standard work inline — loop speed — while still dispatching one fresh-context review gate and keeping the protection hooks binding on its own edits.
2. **The Producer is the orchestrator, you're the Product Owner.** No separate PM role to coordinate. The orchestrator does classification, team composition, dispatch, persistence, and routing. You confirm intent, sign off on closes, and stay out of the dispatch loop.
3. **Adaptive routing without silent vendor changes.** Model profile and reasoning effort are separate decisions. Vendor bridges remain explicit opt-ins; changing effort never enables Codex, DeepSeek, or Claude wrapper participation.
4. **Hooks guard the workflow.** Three PreToolUse write guards cover test protection, Conversation-Mode forbidden conditions, and Critical-Mode write scope. Claude receives approval prompts; Codex blocks matching writes because its PreToolUse API does not support an `ask` decision. Structural-first routing is a non-blocking nudge that adds codegraph/CocoIndex guidance without granting or denying the tool call.
5. **Probes are the spec.** Every behaviour the orchestrator promises has a corresponding probe under `probes/`. Regressions are caught by running the probe suite (`bin/code4me-probe-run`). The audit tool (`bin/code4me-audit-dispatch-log`) reads the dispatch-log JSONL to surveille drift in dispatch patterns, cost rollups, structural-first nudge rates, and Trivial-weight classification frequency.

## Optional integrations

All optional — the plugin works fully without any of them:

- **[Basic Memory](docs/howto-use-basic-memory.md)** — persistent project memory through MCP. Use it for prior decisions, recurring fixes, and user preferences across Claude, Codex, and other MCP clients.
- **[codegraph](docs/howto-use-codegraph.md)** — tree-sitter-based MCP server that pre-indexes the repo into a local SQLite graph (calls, imports, extends, cross-language edges). Preferred for exact graph-shaped source-code lookup.
- **[CocoIndex Code](docs/howto-use-cocoindex.md)** — AST-aware semantic code search via `ccc search` or MCP. Preferred for fuzzy/natural-language source discovery.
- **context-mode** — context-window-saving MCP plugin. Use it after codegraph/CocoIndex for derived analysis, logs, docs, and large non-source outputs.
- **[LSP servers](docs/howto-configure-lsp.md)** — legacy optional path for type-precise language-server queries. Standard installs no longer generate `.lsp.json`; use `bin/code4me-install --with-lsp` only if needed.
- **[OpenAI Codex CLI](docs/howto-enable-codex.md)** — enables the `codex-bridge` skill for cross-vendor pairing with OpenAI models.
- **[Claude wrapper (`claude-p`)](docs/howto-use-claude-wrapper.md)** — optional local Claude Code subscription-session backend, useful when Codex is the orchestrator and you want to consult Claude without the Anthropic API path.
- **[DeepSeek / Reasonix CLI](docs/howto-enable-deepseek.md)** — enables the `deepseek-bridge` skill for DeepSeek models. Authentication via `DEEPSEEK_API_KEY` env var OR the wizard-populated `~/.reasonix/config.json`.
- **[Trello MCP](skills/trello-sync/SKILL.md)** — projects the milestone tracker to a Trello board. One card per acceptance criterion (v0.12+).

## Current model and effort routing

| Profile | Anthropic | OpenAI | DeepSeek |
|---|---|---|---|
| `low` | `claude-haiku-4-5` | `gpt-5.6-luna` | `deepseek-v4-flash` |
| `mid` | `claude-sonnet-5` | `gpt-5.6-terra` | `deepseek-v4-pro` |
| `high` | `claude-opus-4-8` | `gpt-5.6-sol` | `deepseek-v4-pro` |

Anthropic `claude-fable-5` is an explicit-only frontier option. Effort defaults
to `low`, `medium`, or `high` independently of the model profile; `xhigh` and
`max` require an explicit deviation and backend support. Current Reasonix does
not apply effort, so DeepSeek dispatches record `effort_applied: false`.

## Documentation

The docs follow a [Diataxis](https://diataxis.fr/) split:

- **[Tutorial](docs/tutorial.md)** — 10-minute walkthrough from install to first Conversation Mode close.
- **How-to recipes:**
  - [Install hooks](docs/howto-install-hooks.md)
  - [Run with Codex](docs/howto-run-with-codex.md)
  - [Use Codex hooks](docs/howto-use-codex-hooks.md)
  - [Configure LSP](docs/howto-configure-lsp.md)
  - [Use Basic Memory](docs/howto-use-basic-memory.md)
  - [Enable Codex](docs/howto-enable-codex.md)
  - [Use Claude wrapper](docs/howto-use-claude-wrapper.md)
  - [Enable DeepSeek](docs/howto-enable-deepseek.md)
  - [Enable cross-vendor pairing](docs/howto-enable-cross-vendor.md)
  - [Use codegraph](docs/howto-use-codegraph.md)
  - [Use CocoIndex](docs/howto-use-cocoindex.md)
  - [Run on Windows](docs/howto-windows.md)
- **[Reference](docs/reference.md)** — workflow weights, all subagents, slash commands, model tiers, cross-vendor pairing, runtime hooks, audit and analytics, context-query schema, dispatch log shape, folder layout.
- **[Explanation](docs/explanation.md)** — design-decision rationale. Why five weights, why Co-Approval, why Producer-as-orchestrator, why opt-in cross-vendor, and why hook decisions differ by client.
- **[Roadmap](docs/roadmap.md)** — ear-tagged work that's been considered, scoped, and intentionally deferred; explicit trigger conditions on conditional items.
- **[audit4me design](docs/audit4me-design.md)** — sibling product spec. Batch, after-hours, cross-vendor codebase auditor. Proposes fixes; code4me applies them via Conversation Mode. Phase 0 (data model + read-only surface) shipped in v0.13.0-dev; Phase 1+ gated on code4me v0.12 soak.
- **[audit4me build plan](docs/audit4me-build-plan.md)** — operational plan with per-phase sub-tasks, gates, open decisions, and rhythm. Living doc; updated as phases ship.

## Slash commands (cheat sheet)

| Command | Purpose |
|---|---|
| `/code4me-init` | Scaffold native project instructions (`AGENTS.md` or `CLAUDE.md`) + `.code4me/` |
| `/code4me-preflight [--critical]` | Sanity-check the dispatch environment |
| `/code4me-classify <task>` | Intake + classification only (no dispatch) |
| `/code4me-dispatch <weight> [--cross-vendor] [--solo] <task>` | Explicit weight, skip intake; `--solo` runs it solo (v0.13+) |
| `/code4me-status [milestone_id]` | Read-only snapshot of `.code4me/` |
| `/code4me-promote-or-revert <task_id>` | Close the Conversation Mode loop |
| `/code4me-probe-run [subdir\|path]` | Programmatic probe runner with regression budget |
| `/code4me-improve --held-out-manifest PATH [--judge-backend=NAME] [--judge-provider=NAME] [scope]` | Supervised experiment with a frozen Anthropic API, `claude-p`, Codex, or Reasonix judge identity and explicit keep/revert |
| `/code4me-audit [path]` | Dispatch-log analytics |
| `/code4me-trello-init` | One-time Trello board scaffold |
| `/code4me-housekeeping` | Session-boundary checkpoint (audit + handoff manifest for safe resume) |
| `/audit4me-config` | One-time audit4me setup (vendor probe + config scaffold) |
| `/audit4me-run` | Run the configured audit4me sweep |
| `/audit4me-status` | Read-only audit4me coverage report |

## What's new

The [CHANGELOG](CHANGELOG.md) carries the version-by-version history with rationale per cut. Headline arc:

- **v0.15.4** — complete Claude/Codex installation flow, required plugin-bundled Codex hooks, client-aware hook behavior, and project-only init ownership.
- **v0.15.0** — isolated multi-vendor probe judges (`anthropic-api`, `claude-p`, `codex`, `reasonix`) with frozen backend/provider/model/effort metadata and no billing-changing fallback.
- **v0.14.1** — current Anthropic/OpenAI/DeepSeek mappings, independent model and effort routing, project-overrideable Reasonix aliases, full-contract probe judging, and supervised `/code4me-improve` experiments with executable external held-out evaluation.
- **v0.13.2** — Codex plugin manifest, Codex-as-orchestrator guidance, dependency checker/installer (`bin/code4me-install-deps`), Basic Memory replacing OpenWolf/buglog, CocoIndex support, `claude-p` subprocess helper/docs/preflight, and structural-first ordering so context-mode stays behind codegraph/CocoIndex.
- **v0.13.1** — audit4me Phase 1, self-locating project installer, session-wiring detector, Windows path-normalization tests, and legacy LSP made opt-in.
- **v0.13** — solo execution mode, structural-index-first source lookup, codegraph integration, and public-release portability work.
- **v0.12** — Milestone decomposition enforced at intake (≥1 task per acceptance criterion). Trello cards become AC-shaped, one card per acceptance criterion.
- **v0.11** — DeepSeek joins as a third vendor via the `deepseek-bridge` skill (Reasonix CLI).
- **v0.10** — Codex-* subagent shims replaced by the `codex-bridge` skill, invoked inline from the orchestrator's thread.
- **v0.6** — declarative `context_queries:` schema; dispatch-log audit tool; probe fixture skeleton; two PreToolUse hooks.
- **v0.7** — vendor-aware model tiers; cross-vendor pairing policy; three Tier-1 Codex shims; slash commands; starter templates; programmatic probe runner.
- **v0.8** — Tier-2 shims (codex-verification, codex-lead-architect); regression budget; dispatch-log analytics extensions; context-query provenance; third PreToolUse hook (critical-write-allowlist).
- **v0.9** — codex-developer allowlist pre-screening, Playwright softened to disabled-by-default, pre-flight sanity checks, and the Diataxis docs split.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for patterns (how to add a subagent, a bridge, a hook, a probe), the PR checklist, and the versioning policy.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

Security issues: see [SECURITY.md](SECURITY.md) for private reporting.

## License

MIT. See [LICENSE](LICENSE).
