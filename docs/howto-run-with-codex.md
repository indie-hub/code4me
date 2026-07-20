# Run code4me with Codex

## Quickstart

Clone the plugin:

```bash
git clone https://github.com/indie-hub/code4me.git code4me
cd code4me
bash bin/code4me-install-deps --check
```

Expose this checkout as a Codex plugin so Codex can read `.codex-plugin/plugin.json`. Then install the common optional tools you want:

```bash
bash bin/code4me-install-deps --install core
bash bin/code4me-install-deps --install memory
bash bin/code4me-install-deps --install indexes
bash bin/code4me-install-deps --configure-mcp codex
```

The configuration step registers Basic Memory and CocoIndex, delegates codegraph registration to `codegraph install`, and installs context-mode through the Codex plugin marketplace when no conflicting manual entry exists. Follow the checklist printed at the end, then restart Codex.

Start Codex in the target project and ask it to use code4me for the milestone:

```text
Use code4me Standard mode: add a CSV export endpoint. Acceptance criteria: ...
```

## Optional local Claude backend

When Codex is the orchestrator and you want a Claude-side consult without the Anthropic API path, install `claude-p`:

```bash
bash bin/code4me-install-deps --install claude-wrapper
claude-p --doctor
```

code4me calls it through:

```bash
bash <CODE4ME_PLUGIN_DIR>/bin/code4me-claude-wrapper-run --prompt-file prompt.md --cwd "$PWD"
```

The wrapper returns `claude-p --output-format json` output and uses the local Claude Code login state.

## Optional Codex hooks

See [Use code4me hooks with Codex](howto-use-codex-hooks.md). The short version:

```bash
mkdir -p .codex
cp <CODE4ME_PLUGIN_DIR>/templates/project-starter/codex-hooks.json.example .codex/hooks.json
```

Replace `<PLUGIN_DIR>`, then run `/hooks` in Codex to review and trust the hooks.

## Preflight

From the plugin checkout:

```bash
bash bin/code4me-preflight
```

Missing optional tools degrade gracefully. Basic Memory, codegraph, CocoIndex, Codex hooks, and `claude-p` improve the workflow but are not required for simple code4me operation.
