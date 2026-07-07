# How to use Claude wrapper with code4me

[indie-hub/claude-wrapper](https://github.com/indie-hub/claude-wrapper) provides a `claude-p` CLI that drives the interactive Claude Code app through a PTY and returns `claude -p`-style output.

Use it when Codex is the code4me orchestrator and you want an optional local Claude specialist without routing through the Anthropic API path.

## Install

```bash
npm install -g github:indie-hub/claude-wrapper
claude-p --doctor
```

Smoke test:

```bash
claude-p "Respond exactly: CLAUDE_P_OK" --output-format json
```

## Behavior

- Uses the local Claude Code login state.
- Strips `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_BASE_URL` by default.
- Does not bypass subscription, account, or rate limits.
- Requires Claude Code installed and logged in on the same machine.
- Depends on Node.js 18+ and `@lydell/node-pty`, including native Windows PTY support.

## code4me usage

Keep this optional. Codex can orchestrate code4me without it; `claude-p` is only for a local Claude consultation backend.

Run:

```bash
bash bin/code4me-install-deps --check
bash bin/code4me-preflight
```

Preflight reports `Claude wrapper (optional)` when `claude-p` is on `PATH`.

When Codex needs a Claude-side role, use the bounded helper instead of calling an interactive session directly:

```bash
bash bin/code4me-claude-wrapper-run --prompt-file prompt.md --cwd "$PWD" --timeout-sec 300
```

The helper emits `claude-p --output-format json` output and accepts `--model`, `--session-id`, and `--raw-log` when a dispatch needs those fields.
