# Probe: buglog-helper hook redirects buglog reads/edits to code4me-buglog

**Subject:** hooks / integration
**Coverage:** Verifies the `check-buglog-helper.sh` PreToolUse hook (v0.13.1+) ask-gates
whole-file `Read`/`Grep`/raw-shell reads of `.wolf/buglog.json` (redirecting to
`code4me-buglog search|get|stats`) and `Edit`/`Write`/shell-writes of it (redirecting
to `code4me-buglog add|update`). The hook self-disables (silent pass-through) when
there is no `.wolf/buglog.json`, exempts Bash commands that invoke `code4me-buglog`
itself, and lets narrowed reads (offset+limit) through. It returns
`permissionDecision: ask` (never deny), matching the LSP-first hook's philosophy.

> **Probe type:** programmatic (run-and-inspect via stdin fixtures), not LLM-as-judge.
> The committed shell test `tests/buglog/test-buglog-hook.sh` runs these in CI.

## Setup note

Run against `hooks/check-buglog-helper.sh` directly, feeding tool-call JSON on stdin
with `CLAUDE_PROJECT_DIR` pointed at a temp project. Create `.wolf/buglog.json`
(`{"version":1,"bugs":[]}`) in that project to arm the hook; omit it to test
self-disable.

## Programmatic verification

For each case, pipe a `{tool_name, tool_input}` object to the hook and inspect stdout:
`{}` means pass-through; an object containing `permissionDecision: "ask"` means gated.

### Scenario 1 — whole-file Read of the buglog → ask (read redirect)

```bash
echo '{"tool_name":"Read","tool_input":{"file_path":".wolf/buglog.json"}}' \
  | CLAUDE_PROJECT_DIR="$PROJ" bash hooks/check-buglog-helper.sh
# Pass criteria: output contains "permissionDecision":"ask" and the reason names
# `code4me-buglog search`.
```

### Scenario 2 — narrowed Read (offset+limit) → pass

```bash
echo '{"tool_name":"Read","tool_input":{"file_path":".wolf/buglog.json","offset":1,"limit":50}}' \
  | CLAUDE_PROJECT_DIR="$PROJ" bash hooks/check-buglog-helper.sh
# Pass criteria: output is exactly {} (a narrowed read is cheap; not gated).
```

### Scenario 3 — Edit / Write of the buglog → ask (write redirect)

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":".wolf/buglog.json","old_string":"a","new_string":"b"}}' \
  | CLAUDE_PROJECT_DIR="$PROJ" bash hooks/check-buglog-helper.sh
# Pass criteria: gated; reason names `code4me-buglog add` / `update`.
```

### Scenario 4 — Bash that invokes the helper → pass (no self-gating)

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"python3 bin/code4me-buglog --buglog .wolf/buglog.json search --tag cpp"}}' \
  | CLAUDE_PROJECT_DIR="$PROJ" bash hooks/check-buglog-helper.sh
# Pass criteria: output is {} — a command containing `code4me-buglog` is exempt,
# even though it references .wolf/buglog.json.
```

### Scenario 5 — raw shell read / append → ask; unrelated Bash → pass

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"cat .wolf/buglog.json | jq ."}}'   | CLAUDE_PROJECT_DIR="$PROJ" bash hooks/check-buglog-helper.sh   # ask (read)
echo '{"tool_name":"Bash","tool_input":{"command":"echo {} >> .wolf/buglog.json"}}'   | CLAUDE_PROJECT_DIR="$PROJ" bash hooks/check-buglog-helper.sh   # ask (write)
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'                          | CLAUDE_PROJECT_DIR="$PROJ" bash hooks/check-buglog-helper.sh   # pass
```

### Scenario 6 — no `.wolf/buglog.json` → pass (self-disable)

```bash
echo '{"tool_name":"Read","tool_input":{"file_path":".wolf/buglog.json"}}' \
  | CLAUDE_PROJECT_DIR="$EMPTY_PROJ" bash hooks/check-buglog-helper.sh
# Pass criteria: output is {} — the hook no-ops when the project has no buglog.
```

### Scenario 7 — Windows path normalisation

```bash
# project rooted at a literal C:/proj; CLAUDE_PROJECT_DIR passed backslash-style
echo '{"tool_name":"Read","tool_input":{"file_path":"C:\\proj\\.wolf\\buglog.json"}}' \
  | CLAUDE_PROJECT_DIR='C:\proj' bash hooks/check-buglog-helper.sh
# Pass criteria: gated — backslash + drive-letter path resolves to the buglog
# (the hook slashifies via hooks/c4m-pathlib.sh).
```

## Failure modes this catches

- Hook fails to gate the expensive whole-file Read (the ~90k-token consult the tool exists to avoid).
- Hook gates the `code4me-buglog` helper's own Bash invocation (would deadlock the redirect).
- Hook gates narrowed reads or unrelated tool calls (over-gating / noise).
- Hook returns `deny` instead of `ask` (must stay overridable).
- Hook fires when the project has no `.wolf/buglog.json` (should self-disable).
- Windows-style paths slip through unmatched.

## Notes

Mirrors `check-lsp-first-on-source.sh`: structural redirection, `ask` never `deny`,
self-disabling when the relevant artifact is absent, auto-wired via
`hooks/hooks.json`. The prompt side (telling agents *how* to use the helper)
lives in `skills/code4me/references/tooling.md`; this hook is the enforcement so the
guidance actually holds under drift.
