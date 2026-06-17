# Code4Me

**A multi-agent SDLC orchestrator for Claude Code.** Turn a one-line user request into a structured workflow: a lead architect designs, a challenger architect critiques, a spec-to-test engineer authors the test gate, a developer implements, and a quality-gate loop (verification + code review + QA) attests the work — all dispatched as Claude Code subagents, with optional cross-vendor pairing through OpenAI's Codex CLI or DeepSeek's Reasonix CLI for dialectic.

**Status:** `0.13.0-dev` — actively soaking against real milestones. Public-release prep underway (Phase 1 portability done; Phase 2 community infrastructure landing now).

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

In your Claude Code plugin directory (typically `~/.claude/plugins/`):

```bash
# TODO: replace <REPO_URL> with the public repository URL at release
git clone <REPO_URL> code4me
```

In a Claude Code session for your project:

```
/code4me-init        # scaffold templates: CLAUDE.md, .claude/settings.json, .code4me/
/code4me-preflight   # confirm jq, hooks wired, optional integrations available
```

That's the minimum to start. From there, the [tutorial](docs/tutorial.md) walks through your first Conversation Mode milestone end-to-end (~10 minutes).

**On Windows:** the hooks and bin scripts are bash. You need WSL or Git Bash — native Windows (cmd.exe / PowerShell only) is not supported. See [docs/howto-windows.md](docs/howto-windows.md) for the setup steps and known quirks.

## Five things that make code4me different

1. **Five workflow weights, not one process.** Trivial / Conversation / Light / Standard / Critical. The orchestrator classifies per-request and runs the smallest workflow that satisfies the stakes. A typo fix doesn't pay Standard-Mode dispatch overhead; a Critical change gets dual architect Co-Approval, full quality-gate loop, and Security Review. v0.13 adds an orthogonal **solo execution mode**: on explicit request, the orchestrator implements Conversation/Light/Standard work inline — loop speed — while still dispatching one fresh-context review gate and keeping the protection hooks binding on its own edits.
2. **The Producer is the orchestrator, you're the Product Owner.** No separate PM role to coordinate. The orchestrator does classification, team composition, dispatch, persistence, and routing. You confirm intent, sign off on closes, and stay out of the dispatch loop.
3. **Multi-vendor pairing without inventing new CLIs.** OpenAI's `codex exec` and DeepSeek's `reasonix run` are vendor-native agentic CLIs. The plugin's two bridge skills (`codex-bridge`, `deepseek-bridge`) spawn them as subprocesses with the orchestrator's prompts and parse structured returns — symmetric architecture, fully opt-in, gracefully degrades when a CLI is missing.
4. **Hooks ask, never deny.** Four PreToolUse hooks (test protection, Conversation-Mode forbidden conditions, Critical-Mode write allowlist, LSP-first redirect) all return `permissionDecision: ask`. A misconfigured hook is a warning, never a hard block. Defense-in-depth without panic-button risk.
5. **Probes are the spec.** Every behaviour the orchestrator promises has a corresponding probe under `probes/`. Regressions are caught by running the probe suite (`bin/code4me-probe-run`). The audit tool (`bin/code4me-audit-dispatch-log`) reads the dispatch-log JSONL to surveille drift in dispatch patterns, cost rollups, hook ask-gate rates, and Trivial-weight classification frequency.

## Optional integrations

All optional — the plugin works fully without any of them:

- **[OpenWolf](docs/explanation.md#openwolf-integration)** — persistent project-knowledge layer (`.wolf/cerebrum.md` / `anatomy.md` / `buglog.json`). When present, the orchestrator consults cerebrum first to avoid re-litigating decisions across sessions.
- **[context-mode](docs/howto-configure-lsp.md#runtime-enforcement-the-lsp-first-hook)** — context-window-saving MCP plugin. The LSP-first hook redirects symbol-shaped queries to LSP when context-mode tries to grep source files.
- **[LSP servers](docs/howto-configure-lsp.md)** — C# (Roslyn), Swift (SourceKit-LSP), C++ (clangd), Python (Pyright) all wired by default in `templates/project-starter/.lsp.json.example`. Adding a language is a `.lsp.json` entry.
- **[codegraph](docs/howto-use-codegraph.md)** — tree-sitter-based MCP server that pre-indexes the repo into a local SQLite graph (calls, imports, extends, cross-language edges). Detected automatically by the LSP-first hook (v0.13+); when present, the hook lists `codegraph_*` tools alongside LSP in its redirect message. Complementary to LSP — LSP for type precision, codegraph for graph-shaped questions across files.
- **[OpenAI Codex CLI](docs/howto-enable-codex.md)** — enables the `codex-bridge` skill for cross-vendor pairing with OpenAI models.
- **[DeepSeek / Reasonix CLI](docs/howto-enable-deepseek.md)** — enables the `deepseek-bridge` skill for DeepSeek models. Authentication via `DEEPSEEK_API_KEY` env var OR the wizard-populated `~/.reasonix/config.json`.
- **[Trello MCP](skills/trello-sync/SKILL.md)** — projects the milestone tracker to a Trello board. One card per acceptance criterion (v0.12+).
- **[Spec Kit](docs/howto-use-spec-kit.md)** — consume GitHub Spec Kit `spec.md` / `plan.md` artifacts at intake.

## Documentation

The docs follow a [Diataxis](https://diataxis.fr/) split:

- **[Tutorial](docs/tutorial.md)** — 10-minute walkthrough from install to first Conversation Mode close.
- **How-to recipes:**
  - [Install hooks](docs/howto-install-hooks.md)
  - [Configure LSP](docs/howto-configure-lsp.md)
  - [Enable Codex](docs/howto-enable-codex.md)
  - [Enable DeepSeek](docs/howto-enable-deepseek.md)
  - [Enable cross-vendor pairing](docs/howto-enable-cross-vendor.md)
  - [Use Spec Kit](docs/howto-use-spec-kit.md)
  - [Use codegraph](docs/howto-use-codegraph.md)
  - [Run on Windows](docs/howto-windows.md)
- **[Reference](docs/reference.md)** — workflow weights, all subagents, slash commands, model tiers, cross-vendor pairing, runtime hooks, audit and analytics, context-query schema, dispatch log shape, folder layout.
- **[Explanation](docs/explanation.md)** — design-decision rationale. Why five weights, why Co-Approval, why Producer-as-orchestrator, why opt-in cross-vendor, why hooks ask instead of deny.
- **[Roadmap](docs/roadmap.md)** — ear-tagged work that's been considered, scoped, and intentionally deferred. Twelve active items as of v0.13.0-dev; explicit trigger conditions on the conditional ones.
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

- **v0.6** — declarative `context_queries:` schema; dispatch-log audit tool; probe fixture skeleton; two PreToolUse hooks.
- **v0.7** — vendor-aware model tiers; cross-vendor pairing policy; three Tier-1 Codex shims; slash commands; starter templates; programmatic probe runner.
- **v0.8** — Tier-2 shims (codex-verification, codex-lead-architect); regression budget; dispatch-log analytics extensions; context-query provenance; third PreToolUse hook (critical-write-allowlist).
- **v0.9** — codex-developer allowlist pre-screening; Playwright softened to disabled-by-default; Spec Kit interop; pre-flight sanity checks; Diataxis docs split.
- **v0.10** — Codex-* subagent shims replaced by the `codex-bridge` skill, invoked inline from the orchestrator's thread.
- **v0.11** — DeepSeek joins as a third vendor via the `deepseek-bridge` skill (Reasonix CLI). LSP-first hook (v0.10.5+) auto-wires via `hooks/hooks.json` and covers Read / Grep / context-mode tool calls.
- **v0.12** — Milestone decomposition enforced at intake (≥1 task per acceptance criterion). Trello cards become AC-shaped, one card per acceptance criterion. Public-release portability (`templates/project-starter/.lsp.json.example`, `bin/clangd-didopen-proxy.mjs`).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for patterns (how to add a subagent, a bridge, a hook, a probe), the PR checklist, and the versioning policy.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

Security issues: see [SECURITY.md](SECURITY.md) for private reporting.

## License

MIT. See [LICENSE](LICENSE).
