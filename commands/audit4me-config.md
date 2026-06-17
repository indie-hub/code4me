---
description: One-time setup for audit4me. Probes which vendor CLIs are installed (claude / codex / reasonix), asks the user to confirm `vendors_available` and `scope.include`, writes `.code4me/audit4me-config.json` with sensible defaults for everything else, and scaffolds the `.code4me/audit4me/` state directory. After this runs, `/audit4me-status` can report on the (empty) coverage state; Phase 1 adds `/audit4me-run` for the actual audit dispatch.
argument-hint: [--overwrite | --patch | --dry-run]
---

Scaffold the project's audit4me configuration. This is a one-time setup; subsequent invocations of `/audit4me-status` (and Phase 1+ `/audit4me-run`) use the saved config without re-prompting.

Read `skills/audit4me/SKILL.md` §"`/audit4me-config` — one-time project setup" and `skills/audit4me/references/config-format.md` for the full procedure, schema, and field semantics. The procedure below is the slash-command entry point; the skill's reference docs are the canonical source.

## Procedure

1. **Pre-flight.**
   - Confirm `.code4me/` exists at the project root. If not, surface: *"No `.code4me/` directory — run `/code4me-init` first. audit4me's state files live alongside code4me's."* and stop.
   - If `.code4me/audit4me-config.json` already exists:
     - With `--overwrite`: proceed, replacing all fields.
     - With `--patch`: proceed, only filling in missing fields (preserve existing values).
     - With no flag: ask the user — *"Existing audit4me-config.json found. Overwrite (replaces all fields), patch (only fill in missing fields), or abort?"*. Wait for explicit choice.

2. **Probe vendor CLI availability.** Run via Bash:
   - `command -v claude` → anthropic candidate
   - `command -v codex` → openai candidate
   - `command -v reasonix` → deepseek candidate
   Surface the detected list to the user. Recommended phrasing: *"Detected CLIs: {list}. Which of these should audit4me use? (2-vendor minimum for auto-proposed fixes; 1-vendor mode supported for find-only.)"*

3. **Scope.**
   - Ask: *"Which paths should audit4me cover? (Glob patterns relative to project root. Common examples: `src/**`, `app/**`, `lib/**`. Multiple patterns allowed.)"*
   - Default exclude list: `["node_modules/**", "vendor/**", "dist/**", "build/**", "target/**", "**/*.min.js", "**/__snapshots__/**"]`. Ask if any additions are needed.

4. **Defaults.** Apply without prompting unless the user explicitly requests a non-default:
   - `default_categories: ["bugs"]`
   - `max_files_per_run: 50`
   - `max_cost_usd_per_run: 5.00`
   - `max_runtime_per_run: "4h"`
   - `rules_version: "v0.1.0"`
   - `refresh_interval_days: 90`
   - `concurrency_cap: 3`
   - `confidence_thresholds`: schema defaults
   - `apply_integration`: schema defaults (`dispatch_mode: conversation`, `auto_escalate_categories: ["security"]`)

5. **Compose and write the config.**
   - With `--dry-run`: print the proposed JSON content and exit without writing.
   - Otherwise: write `.code4me/audit4me-config.json` with 2-space indentation. Include the `"$schema": "audit4me-config-v1"` line at the top.

6. **Scaffold the state directory.** `mkdir -p .code4me/audit4me/findings` via Bash. Phase 1+ writes the coverage tracker, events log, and finding markdown here.

7. **Validate.** If `jq` is available, parse the file to confirm valid JSON. (Full JSON-schema validation against `schemas/config.schema.json` lands in Phase 1's pre-flight; Phase 0 does a JSON-parse sanity check.)

8. **Summary.** Print:
   - Path of the saved config file
   - The chosen `vendors_available` and `scope.include`
   - State directory: `.code4me/audit4me/`
   - Note: *"Phase 0 scope is config + status only. `/audit4me-status` will now report on the (empty) coverage state. The actual audit dispatch (`/audit4me-run`) lands in Phase 1."*
   - Pointer to `docs/audit4me-design.md` for the design doc and `skills/audit4me/references/config-format.md` for field-by-field guidance.

## When NOT to run

- If you don't want audit4me at all — just don't run it. Without `.code4me/audit4me-config.json`, the future `/audit4me-run` will refuse to start; nothing else in code4me depends on audit4me.
- If you're testing code4me in isolation — the absence of the config file is the canonical "audit4me off" switch.

Arguments:

$ARGUMENTS
