# Use code4me hooks with Codex

code4me bundles required Codex hooks in the plugin's standard `hooks/hooks.json`. Do not copy a project `.codex/hooks.json` or replace plugin paths manually.

Codex hooks are enabled by default. An administrator can disable all non-managed hooks, but doing so leaves code4me without its pre-tool guardrails.

```toml
[features]
hooks = false
```

The older `codex_hooks` feature key is a deprecated alias; prefer `hooks`.

## Installation

After installing or updating the plugin, start Codex and run:

```text
/hooks
```

Review and trust the bundled code4me hook definition. Codex records trust against the hook hash, so changed hooks require review again. Untrusted hooks are skipped.

## What maps cleanly

- `PreToolUse` can run command hooks for `Bash`, `apply_patch`, and MCP tool names.
- `SessionStart` can add read-only session context on startup, resume, clear, and compact.
- code4me's structural-first hook should run before source-code shell searches or context-mode source lookups, nudging the agent toward codegraph/CocoIndex first.
- The compatibility adapter expands multi-file `apply_patch` payloads and checks every added, updated, deleted, or moved path.

## Decision behavior

Codex PreToolUse hooks support `allow` and `deny`, but not Claude's `ask` decision. Matching code4me guards therefore block the Codex call and explain which `.code4me` condition must be resolved. Claude Code keeps its approval-prompt behavior. `bin/code4me-bridge-diff-scan.sh` and normal review gates remain defense in depth.
