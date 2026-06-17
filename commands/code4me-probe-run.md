---
description: Run the code4me probe suite programmatically via bin/code4me-probe-run. Each probe's Input prompt is presented for you to paste into a fresh Claude Code session; you paste the orchestrator's response back; an LLM-as-judge compares the response against the probe's Expected block and writes a JSONL result. Optional argument restricts to a probe subdirectory (classification | team-composition | auto-escalation | external-agents | hooks | cross-vendor).
argument-hint: [classification | team-composition | auto-escalation | external-agents | hooks | cross-vendor | <specific probe path>]
---

Wrapper for `bin/code4me-probe-run`. Run the script with the user's argument (or all probes if no argument given) and stream its output.

Procedure:

1. Resolve the plugin's path. The script lives at `<PLUGIN_DIR>/bin/code4me-probe-run`. If you can't determine the plugin path, ask the user.

2. Invoke via Bash:

   ```
   bash <PLUGIN_DIR>/bin/code4me-probe-run $ARGUMENTS
   ```

   Pass `$ARGUMENTS` through verbatim. The script supports:
   - No argument → runs every probe under `<PLUGIN_DIR>/probes/`
   - A subdirectory name (e.g., `classification`) → runs every probe in `<PLUGIN_DIR>/probes/classification/`
   - A specific probe path (relative or absolute) → runs just that probe

3. The script is interactive: for each probe, it prints the Input prompt and waits for the user to paste the orchestrator's response (terminated by a line containing `EOF` on its own). The user must run each probe in a separate fresh Claude Code session, then copy the orchestrator's full response back into this terminal. The script handles the LLM-as-judge comparison and writes results to `<PLUGIN_DIR>/probes/results-{YYYY-MM-DDTHHMMSS}.jsonl`.

4. **Required environment:** `ANTHROPIC_API_KEY` for the LLM-as-judge call. The script will error out clearly if it's missing.

5. After the script exits, print the path to the results file and a one-line summary (pass count / fail count / total).

Argument:

$ARGUMENTS
