---
name: Bug report
about: Something in the plugin isn't behaving as documented
title: "[bug] "
labels: bug
assignees: ""
---

## What happened

<!-- One or two sentences. What did the plugin do, what did you expect instead? -->

## Reproduction

<!-- Smallest reproduction. If a specific probe catches this, name it. -->

1. Project state (any flags from `bin/code4me-preflight` worth noting):
2. The intake prompt or slash command that triggered the behaviour:
3. What the orchestrator did (transparency announcement + tool calls visible in the session):
4. What you expected to happen:

## Environment

- **Plugin version** (from `.claude-plugin/plugin.json`): `0.X.Y-dev` or `0.X.Y`
- **Claude Code version** (`claude --version`):
- **OS**: macOS / Linux / Windows + Git Bash / WSL
- **Bash version** (`bash --version` first line):
- **jq version** (`jq --version`):
- **Affected vendor**: anthropic / openai (codex-bridge) / deepseek (deepseek-bridge) / multiple / N/A

## Dispatch log

<!-- Paste the relevant entries from .code4me/dispatch-log.jsonl. Redact anything sensitive. -->

```jsonl

```

## Hook events (if a hook misfired)

<!-- Paste relevant entries from .code4me/lsp-first-events.jsonl OR a stderr capture of the failing hook. -->

```

```

## Probe coverage

- [ ] An existing probe catches this regression (name it): `probes/...`
- [ ] No existing probe; I'd suggest adding one at `probes/...`
- [ ] Not sure / would benefit from maintainer guidance

## Additional context

<!-- Anything else: screenshots of a Trello card showing wrong state, a milestone spec excerpt, a CLAUDE.md fragment that influences behaviour, etc. Avoid pasting full project code; link to a minimal repo if reproduction needs it. -->
