# Use code4me hooks with Codex

Codex hooks are enabled by default. To disable them globally, set:

```toml
[features]
hooks = false
```

The older `codex_hooks` feature key is a deprecated alias; prefer `hooks`.

## Project setup

Copy the starter template into the project:

```bash
mkdir -p .codex
cp <CODE4ME_PLUGIN_DIR>/templates/project-starter/codex-hooks.json.example .codex/hooks.json
```

Then replace `<PLUGIN_DIR>` inside `.codex/hooks.json` with the absolute path to this code4me checkout. Start Codex in the project and run `/hooks` to review and trust the project hook file.

## What maps cleanly

- `PreToolUse` can run command hooks for `Bash`, `apply_patch`, and MCP tool names.
- `SessionStart` can add read-only session context on startup, resume, clear, and compact.
- code4me's structural-first hook should run before source-code shell searches or context-mode source lookups, nudging the agent toward codegraph/CocoIndex first.
- The write-protection hooks can run for `apply_patch`/edit surfaces when Codex provides compatible `tool_name` and `tool_input` payloads.

## Current limits

Claude Code and Codex hook payloads are close but not identical across every tool. The Codex template is intentionally optional and conservative; keep `bin/code4me-bridge-diff-scan.sh` and normal review gates as the final check for now.
