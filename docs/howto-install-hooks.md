# How to install the runtime hooks

The plugin ships three opt-in PreToolUse hooks that move specific protections from prompt-level enforcement (trust the subagent) to runtime enforcement (block at the tool boundary). All three return `permissionDecision: ask` (never `deny`) and silently pass through when their state files are absent — a misconfigured hook degrades to a warning, never a hard block.

| Hook | Fires when | State file written by |
|---|---|---|
| `check-test-protection.sh` | Edit/Write/MultiEdit targets a path in the protected-tests manifest | Spec-to-Test subagent during canonical workflows |
| `check-forbidden-conditions.sh` | Write creates a new file matching a Conversation-Mode forbidden glob (migrations, schema, feature flags, secrets, persistence layers, sensitive-data paths) | Orchestrator at Conversation-Mode dispatch; deleted at task close |
| `check-critical-write-allowlist.sh` | Edit/Write/MultiEdit targets a path NOT in the Critical-mode allowlist | Orchestrator at Critical-Mode dispatch; deleted at task close |

## Setup

**Recommended: run the installer instead of editing by hand.** `bash <PLUGIN_DIR>/bin/code4me-install --project <your-project>` self-locates the plugin, writes the correct absolute paths, and merges idempotently (no duplicates, stale paths replaced). Use `--with-lsp` only for legacy LSP setup. Use `--dry-run` to preview; it backs up to `.bak`. The manual steps below are the fallback if you'd rather wire it yourself.

Add the following to your project's `.claude/settings.json` (or merge into the existing `hooks` block). Replace `<PLUGIN_DIR>` with the absolute path to this plugin's checkout:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash <PLUGIN_DIR>/hooks/check-test-protection.sh"
          },
          {
            "type": "command",
            "command": "bash <PLUGIN_DIR>/hooks/check-forbidden-conditions.sh"
          },
          {
            "type": "command",
            "command": "bash <PLUGIN_DIR>/hooks/check-critical-write-allowlist.sh"
          }
        ]
      }
    ]
  }
}
```

If the plugin lives at `~/.claude/plugins/code4me/`, point at `~/.claude/plugins/code4me/hooks/...`. If you cloned elsewhere, point at that path. Use absolute paths — `~` and environment-variable expansion in hook commands is fragile across shells.

`/code4me-init` (the scaffolder) handles this automatically when copying `claude-settings.json.example` and substituting `<PLUGIN_DIR>`. If you're installing the hooks manually after the fact, copy the snippet above instead.

## When NOT to use a specific hook

- **`check-test-protection.sh`** — no-op without a populated `.code4me/protected-tests.txt`. Free to leave installed; never fires until Spec-to-Test writes the manifest. Remove only if you have an external test-protection mechanism that would double-prompt.
- **`check-forbidden-conditions.sh`** — fires only during Conversation Mode dispatches. Free to leave installed on Standard/Critical-only workflows.
- **`check-critical-write-allowlist.sh`** — no-op without `.code4me/critical-allowlist.txt`. Free to leave installed on Conversation/Light/Standard-only workflows. Fires only when the orchestrator has written an active allowlist at Critical dispatch.

## Verifying

Three probes exercise the hook paths. Run them after installation:

- `probes/hooks/01-test-protection-hook-fires.md`
- `probes/hooks/02-forbidden-conditions-hook-fires-conversation-mode.md`
- `probes/hooks/03-critical-write-allowlist-hook-fires.md`

Each probe walks you through dispatching a scenario, observing the hook's `permissionDecision: ask` return, and verifying the developer subagent maps the gate to the correct typed outcome (TEST_QUESTION / FORBIDDEN_CONDITION_ENCOUNTERED / OUT_OF_SCOPE_TARGET).

If a hook doesn't fire when expected, the most likely cause is the corresponding state file not being written by the orchestrator at the appropriate workflow gate. Check `.code4me/` to confirm.

## What each typed outcome means

| Hook fires | Developer returns | Orchestrator routes |
|---|---|---|
| `check-test-protection.sh` | `outcome: TEST_QUESTION` with test name + issue + proposed interpretation | to Spec-to-Test |
| `check-forbidden-conditions.sh` | `outcome: FORBIDDEN_CONDITION_ENCOUNTERED` with the specific condition | escalates weight to Standard |
| `check-critical-write-allowlist.sh` | `outcome: OUT_OF_SCOPE_TARGET` with path + non-matching patterns | surfaces re-scope vs. reject to user; on re-scope, routes to Lead Architect for amendment + updates `.code4me/critical-allowlist.txt` + increments Scope Change Limit counter |

Each hook is a real protocol bridge between the runtime tool boundary and the dispatch flow — not just a permission prompt. The orchestrator's response to a gate is what makes the workflow correct; the hook just prevents the wrong action from happening silently.

## Symmetry across vendors (v0.9+)

The hooks fire on Claude Code's tool calls. Codex runs in a subprocess whose tool calls don't pass through Claude Code's hook system. As of v0.9, the `codex-developer` shim's implement-mode validation pre-screens Codex's `files_touched` against:

- `.code4me/protected-tests.txt` → BLOCKS with `blocker_type: test_protection_violation`
- `.code4me/critical-allowlist.txt` (when present) → BLOCKS with `blocker_type: out_of_scope_target`

So the same protections apply whether you dispatch the Claude-side developer or the codex-developer shim. The protocol is symmetric; the mechanism differs (hook vs. shim post-validation).
