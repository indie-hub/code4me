# Probe: three-vendor pairing with DeepSeek on a Standard milestone (v0.11+)

**Subject:** cross-vendor
**Coverage:** Verifies the orchestrator applies the three-vendor alternation rule from `references/cross-vendor-policy.md` §"Three-vendor pairing (v0.11+)" when the user enables cross-vendor pairing with DeepSeek explicitly in the pairing set. Claude-side roles dispatch as Task subagents; OpenAI-side roles invoke the `codex-bridge` skill; DeepSeek-side roles invoke the `deepseek-bridge` skill. The tier system resolves the model per vendor; the transparency announcement uses `(vendor:tier)` format with `deepseek-bridge[role]` for the DeepSeek bridge invocations.

## Input prompt

> Standard milestone: refactor the rate-limiter middleware to use a sliding-window algorithm instead of token-bucket. The change goes in `src/middleware/rate_limit.cs` with paired test file. Enable three-vendor cross-vendor pairing — Claude + Codex + DeepSeek. I want to see DeepSeek act as the challenger architect this time.

## Fixture

No fixture required — this probe measures team-composition and announcement format, not implementation against real code.

## Expected

- **Kind:** product
- **Weight:** Standard
- **Auto-escalation:** none
- **Cross-vendor:** enabled for the milestone, with three-vendor pairing
- **Team:**
  - `lead-architect (claude:high)` — anchor architect
  - `deepseek-bridge[architect] (deepseek:high, mode=challenge)` — Challenger Architect, Co-Approval with Lead
  - `codex-bridge[spec-to-test] (openai:mid)` — test author on opposite vendor from developer
  - `developer (claude:mid)` — implementer (anchor)
  - `verification (claude:mid)` — verifier (closest to artifact; anchor vendor)
  - `deepseek-bridge[code-reviewer] (deepseek:mid, mode=review-diff)` — code reviewer on opposite vendor from developer
  - `qa (claude:mid)` — single-vendor by choice (no deepseek-qa, no codex-qa)
  - `doc-writer (claude:mid)` — single-vendor (no doc-writer bridge for either)
- **Pre-flight order at team-composition time:**
  1. `command -v codex` — if missing, `codex_unavailable` fires for the openai assignment (the spec-to-test role falls back to the anchor).
  2. `command -v reasonix` — if missing, `deepseek_unavailable` fires for the deepseek assignments (architect and code-reviewer fall back to the anchor).
  3. **No `$DEEPSEEK_API_KEY` pre-check** — auth is the Reasonix CLI's responsibility (accepts either env var OR config-file apiKey). Auth failures surface at bridge invocation time as `deepseek_subprocess_error`, not as a pre-flight blocker.
- **Order/notes:** The user named DeepSeek explicitly ("act as the challenger architect"), so the deepseek-bridge dispatch gate is satisfied. Three-vendor alternation applies. Cost rises vs. two-vendor — the orchestrator should note this in the announcement so the user can confirm.

## Pass criterion

Orchestrator's transparency announcement:

1. Names every dispatched agent with the `(vendor:tier)` annotation, including `deepseek` as a valid vendor.
2. Names the milestone-level setting `(Standard, cross-vendor enabled — three-vendor)` in the header.
3. Cites the Co-Approval Rule by name for the architect pair (Lead on Anthropic / Challenger on DeepSeek).
4. Cites the alternation rule's three active pairings with explicit vendor naming: `spec-author (openai) ≠ implementer (anthropic)`, `implementer (anthropic) ≠ reviewer (deepseek)`, architect Co-Approval (anthropic / deepseek).
5. Does NOT triple-dispatch any role (no parallel reviewers across three vendors — alternation, not chorus).
6. Records `vendor_pairing.policy: alternation, pair_role: <name>, alternates_with: <other vendor>` for each cross-vendor dispatch in the dispatch log.

## Failure modes this catches

- Orchestrator infers "three-vendor would be nice" without the user's explicit signal — workflow violation per the deepseek-bridge dispatch gate.
- Orchestrator dispatches DeepSeek architect AND Codex architect AND Claude architect in parallel (triple Co-Approval) — wastes ~3x cost without alternation benefit.
- Orchestrator pre-checks `$DEEPSEEK_API_KEY` and degrades to anchor when it's missing — that's the OLD pre-flight regime (≤v0.10.x). v0.11 dropped the env-var pre-check; auth happens at invocation, surfaces as `deepseek_subprocess_error`.
- Orchestrator places spec-to-test and developer on the same vendor (defeating the test-author-≠-implementer pairing) because it hadn't generalised the alternation rule to three vendors.
- Announcement uses an inconsistent vendor label (`gpt`, `oai`, `ds`) instead of canonical `anthropic` / `openai` / `deepseek`.
- Orchestrator forgets the Co-Approval Rule because the architect pair is now Anthropic↔DeepSeek instead of Anthropic↔OpenAI.
- Orchestrator routes the QA dispatch to deepseek-bridge "for symmetry" — QA stays single-vendor per the rule (no deepseek-qa exists).

## Audit-tool integration

After the milestone closes, run `/code4me-audit`. The vendor split section should show three vendor entries (`anthropic`, `openai`, `deepseek`) with roughly the dispatch counts expected from the team composition. The "Cross-vendor pairing" section should show no degradations (assuming both `$DEEPSEEK_API_KEY` and `codex` were available) and a pair-role distribution covering each of the three active pairings.
