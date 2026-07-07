# How to configure legacy LSP for code4me

LSP is now a legacy optional path. Standard code4me installs prefer:

1. codegraph for exact symbol graph questions
2. CocoIndex Code for semantic source discovery
3. context-mode for derived analysis and non-source large outputs

Use LSP only when a project still benefits from language-server-specific
precision: hover types, diagnostics, implementation lookup, or exact
single-language references.

## Generate `.lsp.json`

Run:

```bash
bash <code4me-plugin>/bin/code4me-install --project <project> --with-lsp
```

The installer probes for available servers and writes only entries that can run
on the current machine. It is idempotent and backs up existing files to `.bak`.

## Supported legacy entries

- C#: `roslyn-language-server`
- Swift: `xcrun sourcekit-lsp` on macOS or `sourcekit-lsp` elsewhere
- C/C++: `clangd`, with the Node didopen proxy on Windows/Git Bash when needed

Use `--lsp-all` to scaffold all entries even when the servers are not on PATH.
Use `--clang-proxy auto|always|never` to control the C/C++ proxy path.

## Runtime enforcement

New installs wire `hooks/check-structural-first-on-source.sh`, not an LSP-first
hook. That hook lists codegraph and CocoIndex before LSP, and it only mentions
LSP when `.lsp.json` exists.

The old `hooks/check-lsp-first-on-source.sh` file remains as a compatibility
wrapper for existing `.claude/settings.json` files.

## Verify

Run:

```bash
bash <code4me-plugin>/bin/code4me-preflight
```

If `.lsp.json` is present, preflight validates JSON and checks proxy paths. If
Python is available, it also runs the legacy LSP handshake checker.
