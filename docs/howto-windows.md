# How to run code4me on Windows

The plugin's hooks and bin scripts are bash. **You need either Git Bash (MINGW/MSYS) or WSL** to run them — native Windows (cmd.exe / PowerShell only) is **not supported**. CI doesn't run on Windows; verification depends on user reports and the manual checklist below.

This doc covers: which Windows environment to pick, how to install the dependencies, what's known to work, and what's known to be brittle.

## Pick one: WSL or Git Bash

Both work; they have different trade-offs.

### WSL (recommended)

[Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/install) gives you a full Linux environment inside Windows. The plugin behaves identically to native Linux. CI on `ubuntu-latest` is the closest analog to "WSL with Ubuntu," so if it passes CI, it works in WSL.

```powershell
wsl --install
# Restart, then open Ubuntu (or your chosen distro) from Start
```

Once in WSL, everything in this repo behaves like Linux. Clone the plugin into your WSL home directory:

```bash
mkdir -p ~/.claude/plugins
cd ~/.claude/plugins
git clone https://github.com/Bruno/code4me-plugin code4me
```

Run Claude Code from the WSL terminal (not from PowerShell), so it inherits the WSL environment. **This is the simplest path** if you don't already have Git Bash wired up.

### Git Bash (MINGW)

[Git for Windows](https://git-scm.com/download/win) bundles a bash environment called Git Bash. It runs Windows-native (no Linux VM) and supports most of what the plugin needs.

```powershell
winget install --id Git.Git
# or: choco install git
# or: download from https://git-scm.com/download/win
```

After install, "Git Bash" appears in your Start menu. Open it and clone the plugin:

```bash
mkdir -p "$HOME/AppData/Roaming/Claude/plugins"
cd "$HOME/AppData/Roaming/Claude/plugins"
git clone https://github.com/Bruno/code4me-plugin code4me
```

Run Claude Code from Git Bash so it inherits the bash environment.

**Git Bash quirks to know:**

- **Path translation.** Git Bash auto-translates `C:\path` to `/c/path` in many contexts but not all. The hooks expect `$CLAUDE_PROJECT_DIR` to be a path bash can read; if Claude Code passes a Windows-style path, you may need to set `MSYS_NO_PATHCONV=1` to disable translation for specific commands, or `MSYS_ARG_CONV_EXCL="*"` to preserve arguments. The path-matching hooks now normalize Windows paths internally (see `hooks/c4m-pathlib.sh`): backslashes are converted to `/`, drive-letter paths (`C:\...` / `C:/...`) are recognized as absolute, and matching is case-insensitive on Windows. This is covered by `tests/hooks/test-windows-paths.sh`.
- **Symlinks.** Git Bash on Windows doesn't always handle symlinks the way Linux does. None of the plugin's hooks or bin scripts create symlinks; keep Basic Memory and CocoIndex paths normal rather than symlinked when possible.
- **CRLF line endings.** Mitigated as of v0.13.0-dev via `.gitattributes` — `*.sh` and other text files are forced to LF on checkout regardless of `core.autocrlf` setting. If you cloned before v0.13.0-dev and your hooks have `\r` characters, re-clone or run `git add --renormalize .`.

## Install dependencies

From Git Bash or WSL, start with:

```bash
bash bin/code4me-install-deps --check
```

Use `--install <group>` only when you want the script to run package-manager commands for a group.

The hooks need `jq`. The optional integrations may need additional CLIs.

### `jq` (required)

```powershell
# PowerShell, any of these
winget install --id stedolan.jq
choco install jq
scoop install jq
```

In Git Bash, `winget`-installed binaries are on PATH automatically. Confirm with `command -v jq`.

### Node (required for the clangd C++ proxy; optional otherwise)

The C++ LSP integration uses a Node-based shim. Most Windows dev setups already have Node; if not:

```powershell
winget install --id OpenJS.NodeJS
```

### Codex CLI (optional, for OpenAI cross-vendor pairing)

```bash
npm install -g @openai/codex
codex login   # OAuth, or set OPENAI_API_KEY
```

### Reasonix CLI (optional, for DeepSeek cross-vendor pairing)

```bash
npm install -g reasonix
reasonix code   # First-run wizard prompts for DEEPSEEK_API_KEY
```

### codegraph (optional, for the structural-first hook integration)

```bash
npm i -g @colbymchenry/codegraph
codegraph install   # Auto-wires the MCP server into ~/.claude.json
cd /your/project
codegraph init -i   # Builds .codegraph/codegraph.db
```

See `docs/howto-use-codegraph.md` for the full setup.

## Verify your environment

After install, run the preflight from your terminal of choice (Git Bash, or a WSL shell):

```bash
bash bin/code4me-preflight
```

The first line of the output should be a **Platform** check identifying your environment as one of:

- `Linux` — native Linux (or you're in WSL and the check didn't detect it; see below)
- `Windows + WSL` — detected via `WSL_DISTRO_NAME` env var or `/proc/version` containing "microsoft"
- `Windows + Git Bash` — detected via `MINGW*` / `MSYS*` / `CYGWIN*` in `uname -s`
- `macOS` — Darwin

If the platform shows as `unknown`, the script is running in an environment we don't recognize — likely native Windows somehow. The hooks won't fire correctly; switch to Git Bash or WSL.

## Known quirks

### `$CLAUDE_PROJECT_DIR` path format

Claude Code passes the project directory to hook scripts via this env var. On native Linux/macOS it's a POSIX path (`/home/user/proj`). On Git Bash it MAY arrive as a Windows path (`C:\Users\user\proj`). The hooks read this var for the `.code4me/` lookup and the `.lsp.json` lookup.

The three path-matching hooks (`check-critical-write-allowlist.sh`, `check-test-protection.sh`, `check-forbidden-conditions.sh`) now slashify `$CLAUDE_PROJECT_DIR` and the tool's target path, and recognize drive-letter paths as absolute, via the shared `hooks/c4m-pathlib.sh` helper. This fixes the earlier bug where, with a Windows-style path, the absolute-path test (`case … in /*)`) mis-classified `C:\…` / `C:/…` as *relative*, prepended the project dir, and so matched no pattern — which made the critical-write allowlist ask-gate **every** edit ("all files protected"), and made test-protection silently fail to protect anything. If you still see "no such file or directory" on a `C:\...` path inside a `[ -r "..." ]` test, re-run Claude Code from within Git Bash itself (not a PowerShell terminal pointed at Git Bash) so the env var inherits the bash path convention, and please [file an issue](../../issues) with the exact path string the hook saw.

### CRLF line endings

If you cloned the plugin **before v0.13.0-dev** (which added `.gitattributes`), shell scripts may have CRLF endings. Symptom: `bash: \r: command not found` or "Permission denied" on hook execution. Fix:

```bash
cd ~/.claude/plugins/code4me
git config core.autocrlf input
git rm --cached -r .
git reset --hard
```

This re-checks-out all files with LF endings per `.gitattributes`.

### Powershell-native shells

If you launch Claude Code from PowerShell (not Git Bash), it inherits PowerShell's environment. The plugin's hooks invoke bash via `#!/usr/bin/env bash`, which on a PowerShell-launched Claude Code may find or fail to find bash depending on what's on PATH. **Always launch Claude Code from Git Bash or WSL** for a clean environment inheritance.

### Hooks that silently don't fire

If a hook (e.g., `check-test-protection.sh`) doesn't seem to be firing on protected-test edits, check in order:

1. Run `bin/code4me-preflight`. If "Hook installation" is warn or fail, the hook isn't wired in `.claude/settings.json`.
2. Run `bash hooks/check-test-protection.sh < /dev/null` directly. If you get a shebang error, you have CRLF endings. Fix per above.
3. Confirm `.code4me/protected-tests.txt` exists with at least one entry — the hook auto-no-ops if not.
4. Confirm `CLAUDE_PROJECT_DIR` is what you expect — `echo "$CLAUDE_PROJECT_DIR"` in your shell, then the same from a Claude Code session via a Bash tool call.

## Reporting Windows issues

Use [GitHub Issues](../../issues) with the `bug_report` template. Please include:

- Output of `bin/code4me-preflight` (especially the Platform line)
- Your Windows environment (WSL distro name + version, or Git Bash version from `bash --version`)
- The exact failure: hook didn't fire, script errored on shebang, path lookup failed, etc.

The CI workflow includes a Windows Git Bash job for syntax and path-normalization coverage. User reports are still important for client-specific launch and PATH issues. Concrete repros are gold.

## When native Windows support might happen

Native Windows (cmd.exe / PowerShell, no bash) would require rewriting the hooks and bin scripts in Node or Python — substantial work. It's not on the roadmap as of v0.13.2-dev. The reasoning: most Windows developers who use Claude Code also have WSL or Git Bash, and the cost of dropping bash everywhere is high (we'd lose the shellcheck CI gate, the per-hook simplicity, the well-trodden bash idioms).

If WSL or Git Bash is genuinely unworkable for you, [open a discussion](../../discussions) explaining your constraint. Empirical demand drives the priority.
