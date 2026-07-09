# Code4Me

**A multi-agent SDLC orchestrator for Claude Code and Codex.** Turn a one-line user request into a structured workflow: a lead architect designs, a challenger architect critiques, a spec-to-test engineer authors the test gate, a developer implements, and a quality-gate loop (verification + code review + QA) attests the work — all dispatched as agent roles, with optional cross-vendor pairing through OpenAI's Codex CLI or DeepSeek's Reasonix CLI for dialectic.

**Status:** `0.13.4-dev` — actively soaking against real milestones. Public-release prep underway (Phase 1 portability done; Phase 2 community infrastructure landing now).

## What it does, concretely

You write:

> Standard milestone: add a CSV export endpoint to the user-profile API. Acceptance criteria: (1) user can export their own data, (2) export includes column headers, (3) requests for other users return 403.

The orchestrator:

1. **Classifies** the request (Standard weight, kind=product, no auto-escalation).
2. **Decomposes** the milestone into ≥1 task per acceptance criterion (v0.12+) — 3 ACs → typically 5-7 dispatched tasks, mapped explicitly.
3. **Announces the team** before any dispatch: *"Team for M07 (Standard): lead-architect (claude:high), challenger-architect (claude:high), spec-to-test (claude:mid), developer (claude:mid), verification (claude:mid), code-reviewer (claude:mid), qa (claude:mid), doc-writer (claude:mid)."*
4. **Dispatches** each subagent via the Task tool, persists artefacts (Tech Spec, Test Spec, AC mapping) under `.code4me/`, and routes INSIGHT messages between roles.
5. **Optionally projects** the milestone to a Trello Kanban board — one card per acceptance criterion, cards move from Inbox → In Progress → In Review → Done as gates pass.
6. **Closes** with verification's AC coverage table, the code-review verdict, and (if applicable) the doc-writer's user-doc updates.

You see the work happen. You stay the Product Owner. The orchestrator handles the rest.

## Install

Clone the plugin once:

```bash
git clone https://github.com/indie-hub/code4me.git code4me
cd code4me
bash bin/code4me-install-deps --check
```

The repo ships both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`; Claude Code and Codex can load the same checkout.

### Claude Code as orchestrator

Put the checkout where Claude Code loads plugins, commonly `~/.claude/plugins/code4me`, then open a Claude Code session in your project:

```text
/code4me-init        # scaffold templates: CLAUDE.md, .claude/settings.json, .code4me/
/code4me-preflight   # confirm jq, hooks wired, optional integrations available
```

### Codex as orchestrator

Install or expose this checkout as a Codex plugin so Codex sees `.codex-plugin/plugin.json`. Then run the dependency check from the plugin checkout:

```bash
bash bin/code4me-install-deps --check
```

Recommended Codex-side setup:

```bash
bash bin/code4me-install-deps --install core
bash bin/code4me-install-deps --install memory
bash bin/code4me-install-deps --install indexes
```

Optional local Claude consultation backend:

```bash
bash bin/code4me-install-deps --install claude-wrapper
claude-p --doctor
```

`claude-p` comes from [indie-hub/claude-wrapper](https://github.com/indie-hub/claude-wrapper). It lets a Codex Producer consult local Claude Code through the user's existing Claude Code login state. It is optional; code4me still works in Codex without it.

code4me's bounded subprocess helper is `bin/code4me-claude-wrapper-run`; it invokes `claude-p --output-format json` with an explicit prompt file, cwd, timeout, and optional model/session metadata.

For OpenAI/DeepSeek cross-vendor agents:

```bash
bash bin/code4me-install-deps --install agents
```

Then start Codex in the target project and use the same code4me commands/prompts. See [Run code4me with Codex](docs/howto-run-with-codex.md) for the quickstart. From there, the [tutorial](docs/tutorial.md) walks through your first Conversation Mode milestone end-to-end (~10 minutes).

**On Windows:** the hooks and bin scripts are bash. You need WSL or Git Bash — native Windows (cmd.exe / PowerShell only) is not supported. See [docs/howto-windows.md](docs/howto-windows.md) for the setup steps and known quirks.

## Five things that make code4me different

1. **Five workflow weights, not one process.** Trivial / Conversation / Light / Standard / Critical. The orchestrator classifies per-request and runs the smallest workflow that satisfies the stakes. A typo fix doesn't pay Standard-Mode dispatch overhead; a Critical change gets dual architect Co-Approval, full quality-gate loop, and Security Review. v0.13 adds an orthogonal **solo execution mode**: on explicit request, the orchestrator implements Conversation/Light/Standard work inline — loop speed — while still dispatching one fresh-context review gate and keeping the protection hooks binding on its own edits.
2. **The Producer is the orchestrator, you're the Product Owner.** No separate PM role to coordinate. The orchestrator does classification, team composition, dispatch, persistence, and routing. You confirm intent, sign off on closes, and stay out of the dispatch loop.
3. **Multi-vendor pairing without inventing new CLIs.** OpenAI's `codex exec` and DeepSeek's `reasonix run` are vendor-native agentic CLIs. The plugin's two bridge skills (`codex-bridge`, `deepseek-bridge`) spawn them as subprocesses with the orchestrator's prompts and parse structured returns — symmetric architecture, fully opt-in, gracefully degrades when a CLI is missing.
4. **Hooks ask, never deny.** Four PreToolUse hooks (test protection, Conversation-Mode forbidden conditions, Critical-Mode write allowlist, structural-first redirect) all return `permissionDecision: ask`. A misconfigured hook is a warning, never a hard block. Defense-in-depth without panic-button risk.
5. **Probes are the spec.** Every behaviour the orchestrator promises has a corresponding probe under `probes/`. Regressions are caught by running the probe suite (`bin/code4me-probe-run`). The audit tool (`bin/code4me-audit-dispatch-log`) reads the dispatch-log JSONL to surveille drift in dispatch patterns, cost rollups, hook ask-gate rates, and Trivial-weight classification frequency.

## Optional integrations

All optional — the plugin works fully without any of them:

- **[Basic Memory](docs/howto-use-basic-memory.md)** — persistent project memory through MCP. Use it for prior decisions, recurring fixes, and user preferences across Claude, Codex, and other MCP clients.
- **[codegraph](docs/howto-use-codegraph.md)** — tree-sitter-based MCP server that pre-indexes the repo into a local SQLite graph (calls, imports, extends, cross-language edges). Preferred for exact graph-shaped source-code lookup.
- **[CocoIndex Code](docs/howto-use-cocoindex.md)** — AST-aware semantic code search via `ccc search` or MCP. Preferred for fuzzy/natural-language source discovery.
- **context-mode** — context-window-saving MCP plugin. Use it after codegraph/CocoIndex for derived analysis, logs, docs, and large non-source outputs.
- **[LSP servers](docs/howto-configure-lsp.md)** — legacy optional path for type-precise language-server queries. Standard installs no longer generate `.lsp.json`; use `bin/code4me-install --with-lsp` only if needed.
- **[OpenAI Codex CLI](docs/howto-enable-codex.md)** — enables the `codex-bridge` skill for cross-vendor pairing with OpenAI models.
- **[Claude wrapper (`claude-p`)](docs/howto-use-claude-wrapper.md)** — optional local Claude Code subscription-session backend, useful when Codex is the orchestrator and you want to consult Claude without the Anthropic API path.
- **[Codex hooks](docs/howto-use-codex-hooks.md)** — optional `.codex/hooks.json` template for structural-first and write-protection hooks in Codex.
- **[DeepSeek / Reasonix CLI](docs/howto-enable-deepseek.md)** — enables the `deepseek-bridge` skill for DeepSeek models. Authentication via `DEEPSEEK_API_KEY` env var OR the wizard-populated `~/.reasonix/config.json`.
- **[Trello MCP](skills/trello-sync/SKILL.md)** — projects the milestone tracker to a Trello board. One card per acceptance criterion (v0.12+).
- **[Spec Kit](docs/howto-use-spec-kit.md)** — consume GitHub Spec Kit `spec.md` / `plan.md` artifacts at intake.

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
  - [Use Spec Kit](docs/howto-use-spec-kit.md)
  - [Use codegraph](docs/howto-use-codegraph.md)
  - [Use CocoIndex](docs/howto-use-cocoindex.md)
  - [Run on Windows](docs/howto-windows.md)
- **[Reference](docs/reference.md)** — workflow weights, all subagents, slash commands, model tiers, cross-vendor pairing, runtime hooks, audit and analytics, context-query schema, dispatch log shape, folder layout.
- **[Explanation](docs/explanation.md)** — design-decision rationale. Why five weights, why Co-Approval, why Producer-as-orchestrator, why opt-in cross-vendor, why hooks ask instead of deny.
- **[Roadmap](docs/roadmap.md)** — ear-tagged work that's been considered, scoped, and intentionally deferred. Twelve active items as of v0.13.4-dev; explicit trigger conditions on the conditional ones.
- **[audit4me design](docs/audit4me-design.md)** — sibling product spec. Batch, after-hours, cross-vendor codebase auditor. Proposes fixes; code4me applies them via Conversation Mode. Phase 0 (data model + read-only surface) shipped in v0.13.0-dev; Phase 1+ gated on code4me v0.12 soak.
- **[audit4me build plan](docs/audit4me-build-plan.md)** — operational plan with per-phase sub-tasks, gates, open decisions, and rhythm. Living doc; updated as phases ship.

## Slash commands (cheat sheet)

| Command | Purpose |
|---|---|
| `/code4me-init` | Scaffold a new project (templates + `.code4me/`) |
| `/code4me-preflight [--critical]` | Sanity-check the dispatch environment |
| `/code4me-classify <task>` | Intake + classification only (no dispatch) |
| `/code4me-dispatch <weight> [--cross-vendor] [--solo] <task>` | Explicit weight, skip intake; `--solo` runs it solo (v0.13+) |
| `/code4me-status [milestone_id]` | Read-only snapshot of `.code4me/` |
| `/code4me-promote-or-revert <task_id>` | Close the Conversation Mode loop |
| `/code4me-probe-run [subdir\|path]` | Programmatic probe runner with regression budget |
| `/code4me-audit [path]` | Dispatch-log analytics |
| `/code4me-trello-init` | One-time Trello board scaffold |
| `/code4me-housekeeping` | Session-boundary checkpoint (audit + handoff manifest for safe resume) |
| `/audit4me-config` | One-time audit4me setup (vendor probe + config scaffold) |
| `/audit4me-status` | Read-only audit4me coverage report |

## What's new

The [CHANGELOG](CHANGELOG.md) carries the version-by-version history with rationale per cut. Headline arc:

- **v0.13.2** — Codex plugin manifest, Codex-as-orchestrator guidance, dependency checker/installer (`bin/code4me-install-deps`), Basic Memory replacing OpenWolf/buglog, CocoIndex support, `claude-p` subprocess helper/docs/preflight, optional Codex hooks template, and structural-first ordering so context-mode stays behind codegraph/CocoIndex.
- **v0.13.1** — audit4me Phase 1, self-locating project installer, session-wiring detector, Windows path-normalization tests, and legacy LSP made opt-in.
- **v0.13** — solo execution mode, structural-index-first source lookup, codegraph integration, and public-release portability work.
- **v0.12** — Milestone decomposition enforced at intake (≥1 task per acceptance criterion). Trello cards become AC-shaped, one card per acceptance criterion.
- **v0.11** — DeepSeek joins as a third vendor via the `deepseek-bridge` skill (Reasonix CLI).
- **v0.10** — Codex-* subagent shims replaced by the `codex-bridge` skill, invoked inline from the orchestrator's thread.
- **v0.6** — declarative `context_queries:` schema; dispatch-log audit tool; probe fixture skeleton; two PreToolUse hooks.
- **v0.7** — vendor-aware model tiers; cross-vendor pairing policy; three Tier-1 Codex shims; slash commands; starter templates; programmatic probe runner.
- **v0.8** — Tier-2 shims (codex-verification, codex-lead-architect); regression budget; dispatch-log analytics extensions; context-query provenance; third PreToolUse hook (critical-write-allowlist).
- **v0.9** — codex-developer allowlist pre-screening; Playwright softened to disabled-by-default; Spec Kit interop; pre-flight sanity checks; Diataxis docs split.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for patterns (how to add a subagent, a bridge, a hook, a probe), the PR checklist, and the versioning policy.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

Security issues: see [SECURITY.md](SECURITY.md) for private reporting.

## License

MIT. See [LICENSE](LICENSE).
