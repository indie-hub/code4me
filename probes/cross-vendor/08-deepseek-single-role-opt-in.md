# Probe: single-role DeepSeek opt-in without milestone-wide cross-vendor (v0.11+)

**Subject:** cross-vendor
**Coverage:** Verifies the deepseek-bridge dispatch gate's intake pattern (b1): the user names a specific DeepSeek role at intake without enabling full cross-vendor pairing. Mirrors the existing `codex-architect` intake pattern from v0.7 but for DeepSeek. The orchestrator should compose a single-vendor (anchor) team for everyone else AND invoke `deepseek-bridge[security-reviewer]` for that one role.

## Input prompt

> Critical milestone: refactor the OAuth token exchange handler. Schema changes are involved (new token-binding column). I want DeepSeek to do the security review specifically — let DeepSeek find the auth-handling bugs.

## Fixture

`command -v reasonix` succeeds. Reasonix is authenticated (either via `$DEEPSEEK_API_KEY` env OR via its config-file apiKey — either works; the bridge doesn't pre-check). The user has NOT used the words "cross-vendor", "alternation", or `--cross-vendor`. They have named exactly one DeepSeek role: `security-reviewer`.

## Expected

- **Kind:** product
- **Weight:** Critical (auto-escalated from declared Standard due to schema + auth — both auto-escalation symptoms)
- **Cross-vendor:** NOT enabled milestone-wide. Single-role opt-in for security-reviewer only.
- **Team:**
  - `lead-architect (claude:high)`
  - `challenger-architect (claude:high)` — Co-Approval (single-vendor, both Anthropic)
  - `spec-to-test (claude:mid)`
  - `developer (claude:high)` — Critical hard floor
  - `verification (claude:mid)`
  - `code-reviewer (claude:high)` — Critical hard floor
  - `qa (claude:mid)`
  - `deepseek-bridge[security-reviewer] (deepseek:high, mode=comprehensive)` — the **only** DeepSeek dispatch, fired by the user's explicit naming
  - `doc-writer (claude:mid)`
- **Auto-escalation trigger:** `schema_or_data_migration` AND `authentication_or_sensitive_data` — both fire; Security Reviewer is on the team because of the latter.
- **Transparency announcement** includes:
  > Team for Critical milestone. Security review on DeepSeek per your explicit request. Rest of team single-vendor (Anthropic). Co-Approval architect pair on Anthropic. Auto-escalation fired (schema + auth) — Security Reviewer is mandatory.

## Pass criterion

1. The orchestrator dispatches exactly ONE deepseek-bridge invocation: `deepseek-bridge[security-reviewer]`.
2. Every other role is on Anthropic (the anchor).
3. The orchestrator runs the `command -v reasonix` pre-flight at team-composition time (per probe 07's discipline) — single-role opt-in still requires the CLI pre-flight to fire. No `$DEEPSEEK_API_KEY` pre-check; auth is Reasonix's responsibility at invocation time.
4. The dispatch log entry for the security review carries `vendor: deepseek`, `vendor_pairing.policy: single-role-opt-in` (or equivalent), and `vendor_pairing.degraded: null`.
5. The orchestrator does NOT generalise "the user named DeepSeek for one role" into "the user probably wants three-vendor for the whole milestone." That generalisation is a workflow violation per the dispatch gate's strict opt-in discipline.

## Failure modes this catches

- Orchestrator infers milestone-wide cross-vendor pairing from the single-role naming — burns ~5x cost composing a three-vendor team the user didn't ask for.
- Orchestrator dispatches Security Reviewer on Anthropic anyway, citing "I should not invoke the bridge without milestone-wide cross-vendor enabled." The intake pattern (b1) explicitly authorises single-role bridge invocations.
- Orchestrator dispatches BOTH `security-reviewer` (Anthropic) AND `deepseek-bridge[security-reviewer]` in parallel, doubling cost. The user said "DeepSeek do the security review" — that's a substitution, not an addition.
- Orchestrator forgets to mark the security review as `vendor_pairing.policy: single-role-opt-in` in the dispatch log — audit-tool surveillance loses visibility into how often this intake pattern fires.
- Orchestrator dispatches `security-reviewer` at `mid` tier instead of `high` — Critical hard floor for security-reviewer is `high`, and the vendor switch (per cross-vendor-policy.md hard floors) does not relax the tier.

## Companion notes

This probe is structurally identical to a probe like `04-codex-verification-completes-alternation.md` but for the DeepSeek-equivalent intake pattern. The deepseek-bridge dispatch gate's two patterns (single-role opt-in vs. milestone-wide cross-vendor with DeepSeek in the set) compose with the existing codex intake patterns — the user can mix any subset.

For example, a valid (if expensive) intake: "Use codex-architect for the challenger, deepseek-security-reviewer for the security pass, and run the rest on Claude." That dispatches `codex-bridge[architect]` once, `deepseek-bridge[security-reviewer]` once, and everything else on Anthropic — without enabling three-vendor pairing milestone-wide. The orchestrator runs both pre-flights at team-composition time.
