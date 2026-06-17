# Probe: LSP-first hook surfaces codegraph when project is indexed

**Subject:** hooks / integration
**Coverage:** Verifies the `check-lsp-first-on-source.sh` PreToolUse hook (v0.13+) detects the presence of `.codegraph/codegraph.db` at the project root and surfaces codegraph's MCP tools alongside LSP in its redirect message. When the database is absent, the hook falls back to LSP-only — same behavior as v0.12 and earlier.

## Setup note

This probe is directly executable via bash; no Claude session needed. The hook script is a standalone bash script that reads tool-call JSON from stdin and emits a `permissionDecision` JSON to stdout. The probe stands up a synthetic project directory, feeds the hook synthetic input, and asserts on the output.

## Programmatic verification

Run these four scenarios in sequence. All four must pass.

### Scenario A — `.codegraph/codegraph.db` absent, hook surfaces LSP only

```bash
WORKDIR=$(mktemp -d)
cd "$WORKDIR"
echo '[{"extensionToLanguage": {".cs": "csharp"}}]' > .lsp.json

OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"src/foo.cs"}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-lsp-first-on-source.sh)

REASON=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecisionReason')

# Pass criteria:
echo "$REASON" | grep -q "LSP gives a structural answer in one call" \
  && ! echo "$REASON" | grep -q "codegraph" \
  && echo "PASS A" || echo "FAIL A"
```

### Scenario B — `.codegraph/codegraph.db` present, hook surfaces BOTH codegraph and LSP

```bash
mkdir -p .codegraph && touch .codegraph/codegraph.db

OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"src/foo.cs"}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-lsp-first-on-source.sh)

REASON=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecisionReason')

# Pass criteria:
echo "$REASON" | grep -q "both LSP" \
  && echo "$REASON" | grep -q "codegraph_explore" \
  && echo "$REASON" | grep -q "codegraph_callers" \
  && echo "$REASON" | grep -q "codegraph_impact" \
  && echo "$REASON" | grep -q "textDocument/definition" \
  && echo "PASS B" || echo "FAIL B"
```

### Scenario C — Read with offset+limit passes through (no ask-gate), regardless of codegraph state

```bash
OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"src/foo.cs","offset":10,"limit":50}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-lsp-first-on-source.sh)

# Pass criteria: empty pass-through JSON, no permissionDecisionReason
[ "$OUTPUT" = "{}" ] && echo "PASS C" || echo "FAIL C"
```

### Scenario D — Events log records codegraph_available correctly

```bash
# After Scenarios A and B above, the events log should have two entries with
# different codegraph_available values.

CODEGRAPH_FALSE_COUNT=$(jq -r 'select(.codegraph_available == false) | .ts' \
  "$WORKDIR/.code4me/lsp-first-events.jsonl" 2>/dev/null | wc -l)
CODEGRAPH_TRUE_COUNT=$(jq -r 'select(.codegraph_available == true) | .ts' \
  "$WORKDIR/.code4me/lsp-first-events.jsonl" 2>/dev/null | wc -l)

# Pass criteria: at least one of each.
[ "$CODEGRAPH_FALSE_COUNT" -ge 1 ] && [ "$CODEGRAPH_TRUE_COUNT" -ge 1 ] \
  && echo "PASS D" || echo "FAIL D"
```

## Expected

All four scenarios print `PASS X` to stdout. No `FAIL` lines.

## Pass criterion

Four `PASS` lines and no `FAIL` lines.

## Failure modes this catches

- **Codegraph detection breaks silently.** A future refactor moves the detection logic and forgets to update the `.codegraph/codegraph.db` check; Scenario B silently falls back to LSP-only.
- **Codegraph message leaks into non-codegraph environments.** A typo or copy-paste error makes the LSP-only branch include codegraph mentions; Scenario A catches the leak.
- **Pass-through carve-out regresses.** The Read offset+limit narrowing stops working (e.g., a refactor of the matcher); Scenario C catches it.
- **Events log loses the `codegraph_available` field.** Future log format change drops or renames the field; Scenario D catches it, which protects downstream audit-tool surveillance.

## Why this lives in `probes/hooks/`

Same category as the existing test-protection, forbidden-conditions, and critical-write-allowlist probes — it asserts on a PreToolUse hook's behavior under specific input. The hook is independently bash-testable; no Claude session needed for verification.

## Cleanup

```bash
rm -rf "$WORKDIR"
```
