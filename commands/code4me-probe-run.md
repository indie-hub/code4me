---
description: Run the code4me probe suite via bin/code4me-probe-run. Each probe's Input prompt is presented for a fresh agent session; an LLM-as-judge evaluates its full Expected and Pass criterion contract and writes a JSONL result.
argument-hint: [classification | team-composition | auto-escalation | external-agents | hooks | cross-vendor | model-routing | improve | <specific probe path>]
---

Wrapper for `bin/code4me-probe-run`. Run the script with the user's argument (or all probes if no argument given) and stream its output.

Procedure:

1. Resolve the plugin's path. The script lives at `<PLUGIN_DIR>/bin/code4me-probe-run`. If you can't determine the plugin path, ask the user.

2. Invoke via Bash:

   ```
   bash <PLUGIN_DIR>/bin/code4me-probe-run $ARGUMENTS
   ```

   Pass `$ARGUMENTS` through verbatim. Probe selection supports:
   - No argument → runs every probe under `<PLUGIN_DIR>/probes/`
   - A subdirectory name (e.g., `classification`) → runs every probe in `<PLUGIN_DIR>/probes/classification/`
   - A specific probe path (relative or absolute) → runs just that probe
   - `--max-flips=N` → overrides the configured regression budget
   - `--baseline=PATH` → selects a baseline JSONL file
   - `--output PATH` or `--output=PATH` → writes results under an existing parent
   - `--manifest PATH` or `--manifest=PATH` → runs a hash-verified external
     held-out manifest; it requires an external `--output`
   - `--update-baseline` → promotes an error-free result file
   - `--no-budget` → skips baseline flip checking
   - `--judge-backend=anthropic-api|claude-p|codex|reasonix` → selects exactly
     one judge; there is no fallback
   - `--judge-provider=NAME` → Reasonix provider alias only
   - `--judge-model=MODEL` → overrides the backend's concrete model
   - `--judge-effort=low|medium|high|xhigh|max` → optional for `claude-p` and
     Codex; Anthropic API and Reasonix reject it

3. The script is interactive: for each probe, it prints the Input prompt and waits for the user to paste the orchestrator's response (terminated by a line containing `EOF` on its own). The user must run each probe in a separate fresh Claude Code session, then copy the orchestrator's full response back into this terminal. The script handles the LLM-as-judge comparison and writes results to `<PLUGIN_DIR>/probes/results-{YYYY-MM-DDTHHMMSS}.jsonl`.

4. **Judge requirements and billing paths:**
   - `anthropic-api` (default): `curl` plus `ANTHROPIC_API_KEY`; default model
     `claude-sonnet-5`. This uses separately billed Anthropic API credits.
   - `claude-p`: installed and authenticated `claude-p`; default model
     `claude-sonnet-5`. This uses the interactive Claude subscription path.
     The runner disables tools and gives the judge an empty temporary cwd.
   - `codex`: installed and signed-in Codex CLI; default model
     `gpt-5.6-terra`. This uses the Codex CLI account path and runs read-only in
     an empty temporary cwd.
   - `reasonix`: installed/configured Reasonix CLI; default provider
     `deepseek-pro` and concrete model `deepseek-v4-pro`. `reasonix doctor
     --json` must show that exact mapping. Billing follows the API provider
     configured in Reasonix. The runner uses an empty `-dir`.

   `CODE4ME_JUDGE_BACKEND`, `CODE4ME_JUDGE_PROVIDER`,
   `CODE4ME_JUDGE_MODEL`, and `CODE4ME_JUDGE_EFFORT` provide equivalent
   defaults. Explicit CLI flags win.

5. After the script exits, print the path to the results file and a one-line summary (pass count / fail count / total).

Argument:

$ARGUMENTS
