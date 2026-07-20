# Run code4me with Codex

## Quickstart

Clone the plugin:

```bash
git clone https://github.com/indie-hub/code4me.git code4me
cd code4me
bash bin/code4me-install-deps --check
```

Install it through the Codex plugin marketplace:

```bash
codex plugin marketplace add indie-hub/code4me
codex plugin add code4me@code4me-marketplace
```

Then install the common integrations and configure their MCP/plugin entries:

```bash
bash bin/code4me-install-deps --install core --install memory --install indexes --configure-mcp codex
```

The configuration step registers Basic Memory and CocoIndex, delegates codegraph registration to `codegraph install`, and installs context-mode through the Codex plugin marketplace when no conflicting manual entry exists. Follow the checklist printed at the end, then restart Codex.

In the target project, run `/code4me-init`. Under Codex it previews and creates only `AGENTS.md` and `.code4me/`; MCPs remain installer-owned and hooks come from the plugin bundle.

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

## Required Codex hooks

The plugin bundles its Codex hooks. No `.codex/hooks.json` copy or path replacement is needed. Start Codex and run:

```text
/hooks
```

Review and trust the current code4me hook definition. Codex skips untrusted plugin hooks, so this is a required one-time action after installation and again whenever the bundled hook definition changes.

## Preflight

From the target project, inside Codex:

```text
/code4me-preflight
```

Missing optional tools degrade gracefully. Basic Memory, codegraph, CocoIndex, and `claude-p` improve the workflow but are not required for simple code4me operation. The bundled Codex hooks are part of the core workflow.
