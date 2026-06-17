# Contributing to code4me

Thanks for considering a contribution. This document covers the patterns the plugin relies on so a PR is reviewable against the same conventions everything else follows.

## Code of conduct

By participating, you agree to abide by the [Code of Conduct](./CODE_OF_CONDUCT.md).

## Before you start

- **Read [docs/tutorial.md](./docs/tutorial.md)** if you're new to code4me. It walks through what the plugin does end-to-end.
- **Skim [docs/explanation.md](./docs/explanation.md)** for the architectural intent. Understanding *why* code4me classifies workflow weight, dispatches subagents, and persists artefacts under `.code4me/` makes the patterns below make sense.
- **Run `/code4me-preflight`** in a real project to verify your local setup before changing anything. If the preflight fails, fix that first.

## What kind of contributions are welcome

| Welcome | Less welcome |
|---|---|
| Bug fixes (with a probe or test that exercises the regression) | New top-level skills without a clear orchestrator integration story |
| New subagents that fit the existing role model | Subagents that duplicate existing roles |
| New bridges for additional vendors (mirror `codex-bridge`'s shape) | Bridges to non-agentic LLMs (the bridge contract assumes an agentic loop) |
| New PreToolUse hooks following the existing four hooks' pattern | Hooks that return `deny` (the plugin convention is `ask` only) |
| Probes covering edge cases or regressions | Probes without explicit pass criteria |
| Documentation improvements, especially for new-user onboarding | Documentation that duplicates existing docs |
| Per-language LSP configs in `templates/project-starter/.lsp.json.example` | LSP configs that hardcode user-specific paths |
| Translations of user-facing docs | Translations of internal references (they shift too often) |

If unsure, open an issue first and discuss before sending a PR.

## Repository layout

```
code4me-plugin/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (name, version, description)
│   └── hooks.json           # auto-wired PreToolUse hooks
├── skills/
│   ├── code4me/             # the orchestrator skill (SKILL.md + references/)
│   ├── codex-bridge/        # OpenAI Codex bridge
│   ├── deepseek-bridge/     # DeepSeek (Reasonix) bridge
│   └── trello-sync/         # Trello Kanban projection
├── agents/                  # subagent specs (one .md per role)
├── hooks/                   # PreToolUse bash hooks
├── bin/                     # plugin-shipped scripts (preflight, audit, probe-run)
├── probes/                  # behavioural probes by subject
├── docs/                    # Diataxis-split docs (tutorial, how-to, reference, explanation)
├── templates/               # project-starter configs + per-language guidance
├── commands/                # /code4me-* slash command shims
├── CHANGELOG.md             # version history (append-only)
└── README.md                # newcomer landing page
```

## Adding a new subagent

Subagents live in `agents/*.md` with YAML frontmatter. The minimum contract:

```yaml
---
name: my-new-role
description: One sentence on what this role does and when the orchestrator should dispatch it. Include 1-2 <example> blocks showing intake → dispatch shape.

context_queries:
  - kind: artifact
    type: tech-spec
    filter: milestone={milestone_id}
    required: true
    when: "weight in [Standard, Critical]"
  - kind: dispatch-reminder
    content: tooling-hierarchy
  # ... more queries; see skills/code4me/references/context-queries-schema.md

cross_vendor_pair_with:
  - role: developer
    relation: paired-with
---

# My New Role

You [one sentence on what this role does].

## Prime directive

Operating principles in `skills/code4me/ETHOS.md`. As the my-new-role, your specific directive is: [...].

## Inputs you must receive
[...]

## Return contract
[...]
```

Required:

1. **`context_queries:` frontmatter is mandatory.** An agent without it is treated as malformed (the orchestrator returns `BLOCKED` with `blocker_type: agent_definition_invalid`). See `skills/code4me/references/context-queries-schema.md` for the schema.
2. **A Prime directive section** referencing `skills/code4me/ETHOS.md`.
3. **A Return contract section** specifying the structured return envelope. Look at `agents/developer.md` or `agents/verification.md` for shape.
4. **At least one probe** under `probes/team-composition/` or `probes/<subject>/` exercising the new role's dispatch.
5. **A `team-templates.md` entry** if the role belongs in any standard team composition.
6. **A `model-selection.yaml` entry** with default tiers per weight.

## Adding a new bridge

Bridges spawn external CLI subprocesses for cross-vendor execution. Two bridges ship today: `codex-bridge` (OpenAI Codex CLI) and `deepseek-bridge` (DeepSeek via Reasonix). Adding a third follows the same shape:

1. **`skills/<vendor>-bridge/SKILL.md`** — top-level skill with `name`, `description`, "When to invoke", "Pre-flight", "Invocation flow", "Tier resolution", "Failure modes", "Context discipline" sections. Mirror `skills/codex-bridge/SKILL.md` or `skills/deepseek-bridge/SKILL.md`.
2. **`skills/<vendor>-bridge/references/{role}.md`** — one per supported role (architect, developer, code-reviewer, spec-to-test, security-reviewer, verification, lead-architect). Each contains the prompt template, return schema, and validation rules.
3. **STRICT BRIDGE PROTOCOL** — every per-role reference declares the protocol up front. Copy from existing bridges.
4. **Dispatch gate in `skills/code4me/SKILL.md`** — add a new "X bridge dispatch gate (vN+)" block under operating-loop step 5. The gate's discipline: never invoke the bridge unless the user explicitly opted in (named a specific bridge role at intake OR enabled cross-vendor pairing with this vendor in the set).
5. **`skills/code4me/references/vendor-models.yaml`** — add a third (or fourth) vendor block with `low` / `mid` / `high` tier → model identifier mapping.
6. **`skills/code4me/references/cross-vendor-policy.md`** — update the §"Three-vendor pairing" mechanism table (add a row for your vendor); add a §"Failure mode: `<vendor>_unavailable`" section.
7. **`bin/code4me-preflight`** — add a check `5c: <vendor> bridging (optional)` verifying the CLI is on PATH (and any required auth env var). Soft warning, never a hard failure.
8. **Probes** under `probes/cross-vendor/` exercising the new bridge: alternation, single-role opt-in, and the unavailable-degradation failure mode.
9. **`docs/howto-enable-<vendor>.md`** — user-facing setup guide mirroring `docs/howto-enable-codex.md` or `docs/howto-enable-deepseek.md`.

## Adding a new PreToolUse hook

Hooks live in `hooks/*.sh` and follow defensive conventions:

1. **`set -u`** at the top — fail on undefined variables.
2. **`PASS_THROUGH='{}'`** with `emit_pass_through()` and `emit_ask()` helpers. Pattern from `hooks/check-test-protection.sh`.
3. **Never return `deny`** — the convention is `permissionDecision: "ask"` only. A misconfigured hook should degrade to a warning, never a hard block.
4. **Silent pass-through on missing inputs** — if the hook's state file isn't there, if jq is missing, if the tool input is malformed, return `{}` and exit 0. Better to under-protect than to break every Edit/Write.
5. **Wire via `hooks/hooks.json`** (plugin root — NOT `.claude-plugin/`, which holds only `plugin.json`) if the hook should auto-enable on plugin-system installs. Note: a plugin referenced by path (not installed via the plugin system) does NOT auto-load `hooks/hooks.json` — for those, wire as opt-in via `templates/project-starter/claude-settings.json.example`.
6. **Document the hook** in the relevant `docs/howto-*.md`.
7. **Add a probe** under `probes/hooks/` exercising the ask-gate firing and the silent-pass-through case.

## Adding a probe

Probes are markdown specifications of agent behaviour. Each probe is run by reading the input prompt to a fresh Claude Code session against the fixture skeleton and observing whether the orchestrator's transparency announcement and tool calls match the expected behaviour.

Structure:

```markdown
# Probe: <one-line statement of what's being verified>

**Subject:** <subject>
**Coverage:** <what this probe tests, by reference to the spec/skill it's exercising>

## Setup
[fixtures, environment, prerequisites]

## Input prompt
> [the literal user message]

## Expected
- **Kind:** <product | bug-fix | tech-debt | spike | incident | scope-change>
- **Weight:** <Trivial | Conversation | Light | Standard | Critical>
- **Auto-escalation:** <trigger or "none">
- **Team:** [bullet list with (vendor:tier) annotations]

## Pass criterion
[specific, measurable conditions the run must satisfy]

## Failure modes this catches
[bullet list of specific regressions this probe would detect]
```

Run probes with `bin/code4me-probe-run <subject>` (or `<path>`). The runner handles fixture setup and reports pass/fail.

## Versioning

The plugin follows **semantic versioning** with one nuance: every change is logged under the **next dev version** (`X.Y.Z-dev`). When the version is finalised, the `-dev` suffix drops and the next change starts a new dev cycle.

- **Major bump (X)** — breaking changes to the orchestrator contract, removal of features, changes to the dispatch-log shape that break the audit tool. Communicated in CHANGELOG with a `### Breaking changes` section.
- **Minor bump (Y)** — new capabilities (a new bridge, a new hook, a new subagent role, a new workflow weight), prose changes to references that subagents act on, schema additions to `.code4me/` artifacts.
- **Patch bump (Z)** — bug fixes, doc improvements, internal refactors that don't change behaviour.

When in doubt, prefer minor over patch — the audit tool needs to be able to surface deviations across versions, and a clearer version boundary helps.

## Running probes locally

```bash
# Run a single probe
bin/code4me-probe-run probes/classification/10-trivial-vs-conversation.md

# Run all probes in a subject
bin/code4me-probe-run probes/hooks/

# Run with a regression budget (fail if >N probes flip from pass to fail)
bin/code4me-probe-run probes/ --max-flips 2
```

The CI pipeline (`.github/workflows/probe.yml`) runs all probes on Linux + macOS. Windows is supported but not CI'd (Git Bash CI is fragile); run manually on Windows before submitting changes that touch hook regexes or path handling.

## PR checklist

Use `.github/PULL_REQUEST_TEMPLATE.md` — it covers most of what's expected. Highlights:

- [ ] CHANGELOG entry under the current `-dev` version
- [ ] Probe added or updated if behaviour changed
- [ ] Verify `bin/code4me-preflight` still passes
- [ ] Verify `bin/code4me-audit-dispatch-log` runs cleanly on a small fixture
- [ ] No hardcoded user-specific paths (search for absolute paths under `/Users/`, `/home/`, `C:/Users/`, etc.)
- [ ] No first-person voice in user-facing prose ("my", "I built", etc.)

## Windows manual-test checklist

CI runs on `ubuntu-latest` and `macos-latest` only — Windows is skipped by design (no native bash; bash-via-Git-Bash is supported but not CI-tested). When your PR touches any of `hooks/`, `bin/`, or `.gitattributes`, manually verify on Windows or ask a Windows-using reviewer to. The minimum checklist:

- [ ] **Line endings.** After your change, the hook scripts and bin scripts still have LF line endings. Verify: `file hooks/*.sh bin/code4me-*` should NOT report "with CRLF" anywhere. `.gitattributes` should keep this true automatically, but a careless `git config core.autocrlf true` can override it.
- [ ] **Shebang execution.** `bash hooks/check-test-protection.sh < /dev/null` should not error on the shebang line. If you see `bash: \r: command not found` or similar, your file has CRLF — fix before merging.
- [ ] **Preflight Platform line.** Run `bash bin/code4me-preflight` from Git Bash (or WSL) on a Windows machine. The output's first check should be `Platform: Windows + Git Bash` (or `Windows + WSL`), not `unknown`. If you added new platform-conditional logic, this is the test that exercises it.
- [ ] **Path-handling.** If your change reads or writes `$CLAUDE_PROJECT_DIR`, test that the path resolves correctly in Git Bash. Common failure: `[ -r "$CLAUDE_PROJECT_DIR/.lsp.json" ]` evaluates false because `$CLAUDE_PROJECT_DIR` is `C:\Users\...` (Windows-style) and bash's `[ -r ... ]` can't read it. The path-translation fix is deferred; for now, document any new path-translation needs in `docs/howto-windows.md` §"Known quirks".

If you can't manually test on Windows, **request a Windows-using reviewer** before merging. See `docs/howto-windows.md` for the full Windows support story.

## Reviewing

If you're a reviewer:

- **The Co-Approval Rule applies to architectural changes.** Two architects (Lead + Challenger) must approve any change to `skills/code4me/SKILL.md`, `skills/code4me/references/playbook.md`, `skills/code4me/references/canonical-workflow.md`, or `skills/code4me/references/cross-vendor-policy.md`. Use the GitHub review system; one reviewer marks the architectural surface, a second confirms.
- **Probes are the spec.** A behaviour change without a corresponding probe update is not reviewable — request the probe before approving.
- **Drift is the enemy.** Watch for new patterns that don't fit the existing conventions. If a contributor invents a new way to do something existing code already does (e.g., adds a fifth way to declare context queries), redirect to the existing pattern.

## Reporting issues

Use [GitHub Issues](../../issues) with the appropriate template:

- **Bug report** — something broke. Include the failing probe (if applicable), a minimal reproduction, and the version.
- **Feature request** — propose something new. Reference existing patterns; explain how the new thing fits.
- **Probe failed** — a specific probe regressed. Include the probe path, the expected vs. observed orchestrator behaviour, and the dispatch-log lines.

## Questions

Open a [GitHub Discussion](../../discussions) for "how do I", "should I", or "what's the convention for" questions. Issues are for bugs / features / probe failures specifically.
