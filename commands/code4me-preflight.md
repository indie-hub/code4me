---
description: Run the code4me preflight sanity checks via bin/code4me-preflight. Validates that the environment is dispatch-ready — .code4me/ directory exists, hooks installed, structural indexes available, optional bridge CLIs present if needed, jq available for the audit/probe tools. Optional --critical flag enables extra checks (critical-allowlist content, hook scripts on disk). Exit code is non-zero if any required check fails.
argument-hint: [--critical] [--quiet]
---

Wrapper for `bin/code4me-preflight`. Run the script with the user's arguments and present its markdown output.

Procedure:

1. Resolve the plugin's checkout to find `bin/code4me-preflight`. If you can't determine the plugin path, ask the user.

2. Invoke via Bash:

   ```
   bash <PLUGIN_DIR>/bin/code4me-preflight $ARGUMENTS
   ```

3. The script prints a markdown report listing each check with verdict (`ok` / `warn` / `fail`) and detail. Exit code is non-zero only if any **required** check fails (warnings are advisory and don't fail the run).

4. After the script exits, summarize the findings in one line. If any check failed, highlight which one(s) and suggest the fix. If only warnings, note that the environment is functional but degraded in specific ways (codegraph/CocoIndex missing -> fallback source lookup; Codex CLI missing -> cross-vendor pairing dispatches will BLOCK at pre-flight).

5. **When to run:**
   - Before a Critical milestone: `--critical` enables extra checks for hook installation completeness and critical-allowlist state.
   - After plugin installation: confirms the environment is wired up correctly.
   - When troubleshooting unexpected BLOCKED outcomes that might be environmental.

Argument:

$ARGUMENTS
