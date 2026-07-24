# Probe: structural-first hook surfaces code indexes

**Subject:** hooks / integration
**Coverage:** Verifies `check-structural-first-on-source.sh` adds non-blocking guidance to source-code lookup through whole-file `Read`, bare-symbol `Grep`, and context-mode shell search when codegraph or CocoIndex is available, while passing through when no structural source index is present.

## Setup note

This probe is directly executable via bash; no Claude or Codex session is needed. The hook reads tool-call JSON on stdin and emits `additionalContext` without a `permissionDecision`.

## Programmatic verification

Run four scenarios in sequence. All four must pass.

### Scenario A - no structural surface, pass-through

```bash
WORKDIR=$(mktemp -d)
mkdir -p "$WORKDIR/src"
printf 'class Foo: pass\n' > "$WORKDIR/src/foo.py"

OUTPUT=$(jq -n --arg p "$WORKDIR/src/foo.py" \
  '{tool_name:"Read",tool_input:{file_path:$p}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

[ "$OUTPUT" = "{}" ] && echo "PASS A" || echo "FAIL A"
```

### Scenario B - codegraph present, whole-file Read is nudged

```bash
mkdir -p "$WORKDIR/.codegraph"
touch "$WORKDIR/.codegraph/codegraph.db"

OUTPUT=$(jq -n --arg p "$WORKDIR/src/foo.py" \
  '{tool_name:"Read",tool_input:{file_path:$p}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

CONTEXT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext')
DECISION=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision // "pass"')
[ "$DECISION" = "pass" ] && echo "$CONTEXT" | grep -q "codegraph_explore" && echo "PASS B" || echo "FAIL B"
```

### Scenario C - CocoIndex present, bare-symbol Grep is nudged

```bash
rm -rf "$WORKDIR/.codegraph"
mkdir -p "$WORKDIR/.cocoindex_code"

OUTPUT=$(jq -n '{tool_name:"Grep",tool_input:{pattern:"Foo",type:"py"}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

CONTEXT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext')
DECISION=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision // "pass"')
[ "$DECISION" = "pass" ] && echo "$CONTEXT" | grep -q "CocoIndex" && echo "PASS C" || echo "FAIL C"
```

### Scenario D - context-mode batch command is nudged and logged

```bash
OUTPUT=$(jq -n '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute",tool_input:{commands:[{label:"find foo",command:"rg Foo src/foo.py"}]}}' \
  | CLAUDE_PROJECT_DIR="$WORKDIR" bash <PLUGIN_DIR>/hooks/check-structural-first-on-source.sh)

CONTEXT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext')
DECISION=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision // "pass"')
LOG_COUNT=$(jq -r 'select(.event == "nudge" and .cocoindex_available == true) | .ts' "$WORKDIR/.code4me/structural-first-events.jsonl" 2>/dev/null | wc -l | tr -d ' ')

[ "$DECISION" = "pass" ] && echo "$CONTEXT" | grep -q "context-mode" && [ "$LOG_COUNT" -ge 1 ] && echo "PASS D" || echo "FAIL D"
```

## Pass criterion

Four `PASS` lines and no `FAIL` lines.

## Failure modes this catches

- Guidance disappears when a code index is available.
- The nudge accidentally emits a permission decision.
- CocoIndex detection via `.cocoindex_code/` breaks.
- Context-mode batch command inspection regresses.
- `structural-first-events.jsonl` loses code-index availability fields.

## Cleanup

```bash
rm -rf "$WORKDIR"
```
