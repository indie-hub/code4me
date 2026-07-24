# Install and verify runtime hooks

code4me uses the same workflow guards in Claude Code and Codex, but each client loads them differently.

| Client | Hook source | Required action | Guard decision |
|---|---|---|---|
| Claude Code | Project `.claude/settings.json` | Run `bin/code4me-install` | `ask` for user approval |
| Codex | Plugin-bundled `hooks/hooks.json` | Trust with `/hooks` | `deny` with an actionable explanation |

Codex uses `deny` because its PreToolUse API does not support Claude's `ask` decision. Missing state files pass through silently in both clients.

## Claude Code

From the code4me checkout, install or refresh the project hooks:

```bash
bash bin/code4me-install --project /absolute/path/to/project
```

The installer self-locates the plugin, backs up `.claude/settings.json` to `.bak`, removes stale code4me entries, and writes current absolute paths without disturbing unrelated settings or hooks. It is safe to rerun after moving or updating the plugin.

Preview without writing:

```bash
bash bin/code4me-install --project /absolute/path/to/project --dry-run
```

Legacy LSP configuration is separate and opt-in. Add `--with-lsp` only when codegraph and CocoIndex do not cover the project's source-navigation needs.

`/code4me-init` does not install hooks.

## Codex

Codex loads the required hooks from the installed plugin. Do not create `.codex/hooks.json` or substitute plugin paths manually.

After installing or updating code4me, start Codex and run:

```text
/hooks
```

Review and trust the code4me hook definition. Codex skips untrusted hooks and asks for review again when their hash changes.

## Guards

| Hook | Protects | Active state |
|---|---|---|
| `check-test-protection.sh` | Tests authored by Spec-to-Test | `.code4me/protected-tests.txt` |
| `check-forbidden-conditions.sh` | Conversation-Mode scope boundaries | `.code4me/forbidden-conditions.json` |
| `check-critical-write-allowlist.sh` | Critical-Mode write scope | `.code4me/critical-allowlist.txt` |
| `check-structural-first-on-source.sh` | codegraph/CocoIndex precedence over raw source searches | Source-search tool call |

The first three guards are dormant when their state file is absent. Structural-first remains active as a non-blocking additional-context nudge toward structural indexes.

## Verify

Initialize the project, then run:

```text
/code4me-preflight
```

Claude preflight verifies project hook registration and path resolution. Codex preflight verifies the bundled hook manifest and adapter. For focused repository tests:

```bash
bash tests/hooks/test-codex-hooks.sh
bash tests/hooks/test-windows-paths.sh
```

On Windows, run installers and tests from Git Bash or WSL. Native PowerShell-only and `cmd.exe` environments are not supported.

When a guard fires, fix or explicitly revise the relevant `.code4me` policy before retrying. Claude can surface an approval prompt; Codex blocks the call because it cannot pause for an `ask` decision.
