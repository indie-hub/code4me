# Security Policy

## Reporting a vulnerability

If you discover a security issue in code4me, please **do not open a public GitHub issue**. Instead, report it privately so the maintainer can assess and fix it before public disclosure.

### How to report

Email the maintainer or use GitHub's [private vulnerability reporting](https://docs.github.com/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) feature (Security tab → "Report a vulnerability" on this repo).

Include:

- A description of the issue.
- Steps to reproduce (smallest reproduction possible).
- The version (`plugin.json`'s `version` field) and your platform (Linux/macOS/Windows).
- The impact you observed (e.g., "hook ask-gate bypassed", "dispatch-log entry forged", "bridge subprocess executed unintended command").
- Whether you've shared this with anyone else.

The maintainer will acknowledge within 7 days and aim to ship a fix or mitigation within 30 days for high-severity issues, longer for low-severity. Disclosure timing will be coordinated with you.

## What's in scope

code4me's attack surface is primarily:

- **PreToolUse hooks** (`hooks/*.sh`) — bash scripts that read JSON from stdin and emit JSON to stdout. They process tool_input that the agent constructs. A hook that fails to sanitize input could be coerced into surprising shell behaviour, command injection, or bypassing its ask-gate.
- **Bridge subprocesses** (`skills/codex-bridge/`, `skills/deepseek-bridge/`) — the orchestrator spawns `codex exec` and `reasonix run` via Bash. The prompt files passed to these CLIs are user-influenced; if an attacker can write to the project's Context Pack (Tech Spec, milestone spec, etc.) they could shape the prompt the external CLI executes.
- **Dispatch log writes** (`.code4me/dispatch-log.jsonl`) — append-only, written by the orchestrator. An attacker who can write here could forge dispatch entries that the audit tool would surface as legitimate.
- **State files written by orchestrator hooks** (`.code4me/protected-tests.txt`, `forbidden-conditions.json`, `critical-allowlist.txt`) — drive the runtime hooks' ask-gating. An attacker who can manipulate these could disable test protection, suppress forbidden-condition gates, or expand the Critical-Mode allowlist.
- **The Trello sync skill's API calls** — submit card titles/descriptions to a Trello board. The data passed comes from the milestone-status-tracker; if that's compromised, Trello receives the corrupted data too.
- **Auto-wired `hooks/hooks.json`** — registers PreToolUse hooks on plugin install. A malicious modification to this file would auto-activate any hook script the user has on disk at the named path. The script paths use `${CLAUDE_PLUGIN_ROOT}` which is constrained by Claude Code's plugin loader, but the broader principle holds: changes to this file deserve careful review.

## What's NOT in scope

- **Bugs that require pre-existing write access to `.code4me/`, `~/.claude/`, the plugin checkout, or the user's project source.** code4me operates as a trusted layer over a project the user already controls. If an attacker can write to those locations, they have already escalated past code4me's surface.
- **Reasonix's, Codex's, and the LSP servers' own vulnerabilities.** These are third-party tools the plugin invokes. Report issues with those projects directly to their maintainers.
- **MCP server vulnerabilities** (context-mode, Trello MCP, OpenWolf, etc.). Report to the respective project.
- **Issues caused by the user disabling the runtime hooks** (removing entries from `.claude/settings.json` or `hooks/hooks.json`). The hooks are defence-in-depth; disabling them is the user's choice and not a code4me vulnerability.
- **The cost-of-operation risk** (an attacker tricking the orchestrator into dispatching expensive cross-vendor pairings). The dispatch gates require explicit user opt-in for bridge invocations; absent that opt-in, no bridge runs. Cost-management is part of the plugin's discipline, not a security boundary.

## Supported versions

The plugin is in active `0.x` development. Only the current dev branch receives security fixes. When `1.0` ships, this section will document a supported-versions matrix (likely "latest minor receives fixes; one previous minor receives critical-only fixes").

## What to expect from a fix

A security fix typically includes:

- A patch landed under the next dev version (`X.Y.Z-dev`).
- An entry in `CHANGELOG.md` describing the issue, the fix, and the version it shipped in. CVE numbers are issued via GitHub's advisory system when the issue meets the threshold.
- An updated probe under `probes/security/` exercising the failure mode so a regression would be caught.
- Coordinated public disclosure after the fix is available — typically within 7 days of the patch landing.

## Hardening for production deployments

If you run code4me in a context where the project's `.code4me/` artefacts could be modified by untrusted parties (CI workflows that run on PRs from forks, shared developer machines, etc.), consider:

- Making `.code4me/` read-only outside the orchestrator's own writes (advanced; requires custom tooling around the orchestrator's persistence step).
- Verifying `hooks/hooks.json` and `hooks/*.sh` against a known-good signature before each session.
- Running the orchestrator in a sandboxed environment where the bridge subprocesses can't reach arbitrary network destinations.

These hardenings are above and beyond what the plugin ships by default; the default posture assumes a trusted local development context.
