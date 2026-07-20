#!/usr/bin/env bash
# Contract test for client-aware, project-only /code4me-init scaffolding.

set -u
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
INIT="$ROOT/commands/code4me-init.md"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has() { grep -F -q -- "$2" "$INIT" && ok "$1" || bad "$1"; }
lacks() { grep -F -q -- "$2" "$INIT" && bad "$1" || ok "$1"; }

has "Codex scaffolds AGENTS.md" 'Codex only: `AGENTS.md`'
has "Claude scaffolds CLAUDE.md" 'Claude only: `CLAUDE.md`'
has "runtime state remains common" 'Always: `.code4me/`'
has "init declares installer boundary" 'must **not** create `.mcp.json`, `.claude/settings.json`, `.codex/hooks.json`, or `.lsp.json`'
has "Codex hook trust is required" 'Codex only, review and trust the bundled code4me hooks with `/hooks`'
lacks "Codex hooks are not optional" 'optional Codex project hooks'
lacks "old MCP copy mapping removed" '.mcp.json` <-'
lacks "old Claude settings copy mapping removed" '.claude/settings.json` <-'
[ -r "$ROOT/templates/project-starter/AGENTS.md.example" ] && ok "Codex template exists" || bad "Codex template exists"

printf '\nPASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
