# How to run code4me on Windows

The plugin's hooks and bin scripts are bash. **You need either Git Bash (MINGW/MSYS) or WSL** to run them — native Windows (cmd.exe / PowerShell only) is **not supported**. CI runs the hook and installer regression suite with Windows Git Bash; client launch and PATH behavior still benefit from user reports.

This doc covers: which Windows environment to pick, how to install the dependencies, what's known to work, and what's known to be brittle.

## Pick one: WSL or Git Bash

Both work; they have different trade-offs.

### WSL (recommended)

[Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/install) gives you a full Linux environment inside Windows. The plugin behaves identically to native Linux. CI on `ubuntu-latest` is the closest analog to "WSL with Ubuntu," so if it passes CI, it works in WSL.

```powershell
wsl --install
# Restart, then open Ubuntu (or your chosen distro) from Start
```

Once in WSL, everything in this repo behaves like Linux. Clone the installer checkout into your WSL home directory:

```bash
git clone https://github.com/indie-hub/code4me.git code4me
cd code4me
```

Install the plugin with the Claude Code or Codex marketplace commands from the root README. Run the client from the WSL terminal (not from PowerShell), so it inherits the WSL environment. **This is the simplest path** if you don't already have Git Bash wired up.

### Git Bash (MINGW)

[Git for Windows](https://git-scm.com/download/win) bundles a bash environment called Git Bash. It runs Windows-native (no Linux VM) and supports most of what the plugin needs.

```powershell
winget install --id Git.Git
# or: choco install git
# or: download from https://git-scm.com/download/win
```

After install, "Git Bash" appears in your Start menu. Open it and clone the installer checkout:

```bash
git clone https://github.com/indie-hub/code4me.git code4me
cd code4me
```

Install the plugin with the Claude Code or Codex marketplace commands from the root README. Run the client from Git Bash so it inherits the Bash environment.

**Git Bash quirks to know:**

- **Path translation.** Git Bash auto-translates `C:\path` to `/c/path` in many contexts but not all. Claude supplies `$CLAUDE_PROJECT_DIR`; Codex hooks fall back to the process working directory. Both must be paths Bash can read. The path-matching hooks normalize Windows paths internally (see `hooks/c4m-pathlib.sh`): backslashes become `/`, drive-letter paths (`C:\...` / `C:/...`) are recognized as absolute, and matching is case-insensitive on Windows. This is covered by `tests/hooks/test-windows-paths.sh`.
- **Symlinks.** Git Bash on Windows doesn't always handle symlinks the way Linux does. None of the plugin's hooks or bin scripts create symlinks; keep Basic Memory and CocoIndex paths normal rather than symlinked when possible.
- **CRLF line endings.** Mitigated as of v0.13.0-dev via `.gitattributes` — `*.sh` and other text files are forced to LF on checkout regardless of `core.autocrlf` setting. If you cloned before v0.13.0-dev and your hooks have `\r` characters, re-clone or run `git add --renormalize .`.

## Install dependencies

From Git Bash or WSL, start with:

```bash
bash bin/code4me-install-deps --check
```

Install the standard memory/index tools and register their MCPs for the clients you use:

```bash
bash bin/code4me-install-deps --install core --install memory --install indexes --configure-mcp all
```

The command preserves existing registrations and ends with the remaining restart, trust, and per-project indexing steps.

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

After install, open the target project in Claude Code or Codex and run:

```text
/code4me-preflight
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

The three path-matching hooks (`check-critical-write-allowlist.sh`, `check-test-protection.sh`, `check-forbidden-conditions.sh`) now slashify the project directory and the tool's target path, and recognize drive-letter paths as absolute, via the shared `hooks/c4m-pathlib.sh` helper. This fixes the earlier bug where, with a Windows-style path, the absolute-path test (`case … in /*)`) mis-classified `C:\…` / `C:/…` as *relative*, prepended the project dir, and so matched no pattern — which made the critical-write allowlist guard **every** edit ("all files protected"), and made test-protection silently fail to protect anything. If you still see "no such file or directory" on a `C:\...` path inside a `[ -r "..." ]` test, launch the client from Git Bash itself (not a PowerShell terminal pointed at Git Bash) so the environment inherits the Bash path convention, and please [file an issue](../../issues) with the exact path string the hook saw.

### CRLF line endings

If you cloned the plugin **before v0.13.0-dev** (which added `.gitattributes`), shell scripts may have CRLF endings. Symptom: `bash: \r: command not found` or "Permission denied" on hook execution. Update/reinstall the marketplace plugin and make a fresh installer checkout:

```bash
git clone https://github.com/indie-hub/code4me.git code4me-fresh
```

Rerun `bin/code4me-install --project /path/to/project` from the fresh checkout for Claude; the installer also removes stray carriage returns from managed hook commands in `.claude/settings.json`.

### Powershell-native shells

If you launch Claude Code or Codex from PowerShell (not Git Bash), it inherits PowerShell's environment. The plugin's hooks invoke Bash, which may or may not be on that inherited PATH. **Launch the client from Git Bash or WSL** for predictable behavior.

### Hooks that silently don't fire

If a hook (e.g., `check-test-protection.sh`) doesn't seem to be firing on protected-test edits, check in order:

1. Run `/code4me-preflight` in the target project. Claude checks `.claude/settings.json`; Codex checks the bundled manifest and adapter.
2. Run `bash hooks/check-test-protection.sh < /dev/null` directly. If you get a shebang error, you have CRLF endings. Fix per above.
3. Confirm `.code4me/protected-tests.txt` exists with at least one entry — the hook auto-no-ops if not.
4. Confirm the project root seen by the client: Claude uses `CLAUDE_PROJECT_DIR`; Codex uses the hook process working directory.

## Reporting Windows issues

Use [GitHub Issues](../../issues) with the `bug_report` template. Please include:

- Output of `/code4me-preflight` (especially the Platform line)
- Your Windows environment (WSL distro name + version, or Git Bash version from `bash --version`)
- The exact failure: hook didn't fire, script errored on shebang, path lookup failed, etc.

The CI workflow includes a Windows Git Bash job for syntax and path-normalization coverage. User reports are still important for client-specific launch and PATH issues. Concrete repros are gold.

## When native Windows support might happen

Native Windows (cmd.exe / PowerShell, no Bash) would require rewriting the hooks and installer scripts in Node or Python. It is not currently supported; Windows support targets Git Bash and WSL, with Git Bash exercised in CI.

If WSL or Git Bash is genuinely unworkable for you, [open a discussion](../../discussions) explaining your constraint. Empirical demand drives the priority.
