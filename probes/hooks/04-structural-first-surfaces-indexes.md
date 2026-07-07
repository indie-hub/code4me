# Probe: structural-first hook surfaces code indexes

**Subject:** hooks / integration
**Coverage:** Verifies `check-structural-first-on-source.sh` ask-gates source-code lookup through whole-file `Read`, bare-symbol `Grep`, and context-mode shell search when codegraph or CocoIndex is available, while passing through when no structural source index is present.

## Setup note

This probe is directly executable via bash; no Claude session is needed. The hook
reads tool-call JSON on stdin and emits `permissionDecision` JSON on stdout.

## Programmatic verification

Run four scenarios in sequence. All four must pass.

### Scenario A - no structural surface, pass-through

```bash
WORKDIR=$(mktemp -d)
mkdir -p "$WORKDIR/src"
printf 'class Foo: pass\n' > "$WORKDIR/src/foo.py"

OUTPUT=$(jq -n --arg p "$WORKDIR/src/foo.py" '{tool_name:"Read", tool_input:{file_path:$p}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

[ "$OUTPUT" = "{}" ] && echo "PASS A" || echo "FAIL A"
```

### Scenario B - codegraph present, whole-file Read is redirected

```bash
mkdir -p "$WORKDIR/.codegraph"
touch "$WORKDIR/.codegraph/codegraph.db"

OUTPUT=$(jq -n --arg p "$WORKDIR/src/foo.py" '{tool_name:"Read", tool_input:{file_path:$p}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

REASON=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecisionReason')
echo "$REASON" | grep -q "codegraph_explore" && echo "PASS B" || echo "FAIL B"
```

### Scenario C - CocoIndex present, bare-symbol Grep is redirected

```bash
rm -rf "$WORKDIR/.codegraph"
mkdir -p "$WORKDIR/.cocoindex_code"

OUTPUT=$(jq -n '{tool_name:"Grep", tool_input:{pattern:"Foo", type:"py"}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

REASON=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecisionReason')
echo "$REASON" | grep -q "CocoIndex" && echo "PASS C" || echo "FAIL C"
```

### Scenario D - context-mode batch command is redirected and logged

```bash
OUTPUT=$(jq -n '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute", tool_input:{commands:[{label:"find foo", command:"rg Foo src/foo.py"}]}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

REASON=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecisionReason')
LOG_COUNT=$(jq -r 'select(.cocoindex_available == true) | .ts' "$WORKDIR/.code4me/structural-first-events.jsonl" 2>/dev/null | wc -l | tr -d ' ')

echo "$REASON" | grep -q "context-mode" && [ "$LOG_COUNT" -ge 1 ] && echo "PASS D" || echo "FAIL D"
```

## Expected

All four scenarios print `PASS X`; no `FAIL` lines.

## Pass criterion

Four `PASS` lines and no `FAIL` lines.

## Failure modes this catches

- Source lookup falls through to `Read`, `Grep`, or context-mode despite a code index being available.
- CocoIndex detection via `.cocoindex_code/` breaks.
- context-mode batch command inspection regresses.
- `structural-first-events.jsonl` loses code-index availability fields.

## Cleanup

```bash
rm -rf "$WORKDIR"
```
