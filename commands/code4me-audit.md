---
description: Run the dispatch-log audit via bin/code4me-audit-dispatch-log and surface the markdown report. Summarises dispatches per subagent, weight distribution, vendor split, tier distribution, model deviations, outcome distribution, and auto-escalation triggers. Optional argument is a path to a specific dispatch log (default .code4me/dispatch-log.jsonl).
argument-hint: [path-to-log]
---

Wrapper for `bin/code4me-audit-dispatch-log`. Run the script and present its output.

Procedure:

1. Determine the dispatch log path. If the user passed an argument, use that. Otherwise default to `.code4me/dispatch-log.jsonl` (relative to the project root / cwd).

2. Resolve the plugin's checkout to find `bin/code4me-audit-dispatch-log`. If you can't determine the plugin path, ask the user.

3. Invoke via Bash:

   ```
   bash <PLUGIN_DIR>/bin/code4me-audit-dispatch-log $ARGUMENTS
   ```

4. **Required environment:** `jq` on PATH (the script will error out clearly if missing).

5. After the script completes, present its markdown output. If there are obvious signals worth surfacing (e.g., a deviation pattern, a vendor cost imbalance, frequent circuit-breaker firings), append a one-paragraph human-readable note pointing them out — but the script's output is the source of truth.

Argument:

$ARGUMENTS
