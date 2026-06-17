# Probe: codex-developer shim returns typed blocker when CLI/auth missing

> **SUPERSEDED IN v0.10.** Pre-v0.10 shim failure-mapping behaviour. v0.10 replaced the codex-* shims with the `codex-bridge` skill; the failure-mapping logic is preserved (typed `blocker_type` values, circuit-breaker integration) but the mechanism is now skill invocation rather than subagent dispatch. See `skills/codex-bridge/SKILL.md` "Failure modes" and `probes/cross-vendor/03-pairing-degrades-when-shim-missing.md` for the v0.10 equivalent.

**Subject:** auto-escalation
**Coverage:** Verifies that when the Codex CLI is missing (or `OPENAI_API_KEY` is unset), the `codex-developer` shim returns a typed `blocker_type` rather than a generic error, and the orchestrator surfaces the `BLOCKED` outcome to the user. The orchestrator must NOT silently fall back to Claude-side `developer` — that would erase the user's explicit cross-vendor opt-in and bypass the circuit-breaker bookkeeping that depends on typed blockers.

**Setup note:** Run this probe in a session where `command -v codex` returns nothing OR `OPENAI_API_KEY` is unset, so the shim's pre-flight check actually fails. Without that, this probe exercises the wrong path.

## Input prompt

> Use codex-developer to change the welcome message from 'Hello' to 'Welcome!' in src/ui/Welcome.cs.

## Expected

- **Kind:** product
- **Weight:** Conversation (one-line string edit, no forbidden conditions, no symptom class)
- **Auto-escalation:** none
- **Team:** single dispatch to `codex-developer (openai:<model>)`
- **Order/notes:** Shim's pre-flight check fails. Outcome `BLOCKED` with `blocker_type: codex_cli_not_installed` (if `command -v codex` returns nothing) or `blocker_type: codex_auth_missing` (if CLI present but `OPENAI_API_KEY` unset). Orchestrator surfaces the typed `blocker_type` in its reply to the user and does NOT auto-retry with the Claude-side `developer`.

## Pass criterion

Orchestrator returns the typed `blocker_type` (`codex_cli_not_installed` or `codex_auth_missing`, exact strings) in its summary to the user, references the setup section of the plugin README, and does not silently retry with the Claude-side `developer`. The user retains the choice to fix the setup or explicitly re-request with the Claude-side developer.

## Failure modes this catches

- Orchestrator catches the shim's `BLOCKED` and silently re-dispatches to `developer (anthropic:sonnet)`, hiding the setup gap and erasing the user's cross-vendor choice.
- Orchestrator surfaces a generic "Codex failed" message without the typed `blocker_type`, defeating the circuit breakers in `references/circuit-breakers.md` that key off typed blockers.
- Shim invents content (mid-air-collision retry, alternative model fallback) instead of returning `BLOCKED` per its prime directive ("fidelity to the protocol, not editorial intervention").
- Orchestrator paraphrases the blocker (e.g. "codex not set up") instead of surfacing the exact `blocker_type` string the shim returned.
