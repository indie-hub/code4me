# Team Templates

The tables below are **informative** — common subagent compositions for tasks of each shape, drawn from how the legacy framework was used. They are not prescriptions. The orchestrator decides which subagents this specific task actually needs, applying the hard-floor rules below. Treat the tables as a starting reference for *"what tasks of this shape have historically used,"* not a contract.

The orchestrator's job is active judgment: read the task, weigh its actual surface and risk, and compose the team that fits. The templates exist so you don't have to invent compositions from scratch every time; the hard floors exist so the floor of safety doesn't shift.

## Common compositions

### Product engineering work (kind = product)

| Weight | Default team | Default order |
|--------|--------------|---------------|
| Conversation | developer, combined-reviewer | dev → combined-reviewer (loop on REWORK) |
| Light | lead-architect (notify only), developer, combined-reviewer | architect-notify (non-blocking) → dev → combined-reviewer |
| Standard | lead-architect, challenger-architect, spec-to-test, developer, verification, code-reviewer, qa, doc-writer | canonical order |
| Critical | Standard team + qa (post-release pass) + user (sign-off) | Standard order, then post-release QA, then user sign-off before release |

### Other kinds

| Kind | Default team |
|------|--------------|
| Bug Fix | qa (reproduce) → developer → qa (re-verify); add verification + code-reviewer if severity warrants |
| Tech Debt / Refactor | one architect (scope description only) → developer → code-reviewer → qa |
| Spike | developer or researcher (timeboxed) → spike report to requesting role |
| Incident | developer + qa (parallel investigation) → diagnosis → routes to Bug Fix, Canonical, or Spike for follow-up |
| Scope Change | architect (classify amendment vs. re-scope); on amendment → reissue Context Packs to in-flight tasks; on re-scope → pause, rewrite Tech Spec, re-plan |

---

## Composition rules

The orchestrator chooses the team for each task. The following rules apply:

| Decision | When | Requires |
|----------|------|----------|
| **Add a specialist** not in the template (e.g., add Researcher for a domain question, Security Reviewer for crypto-touching work) | Orchestrator judgment | Record addition and rationale in the Milestone Status Tracker |
| **Choose not to invoke** a subagent the template lists (e.g., not invoke Doc Writer for an internal-only change; not invoke Spec-to-Test for a pattern-following change) | Orchestrator judgment, *unless* a hard floor applies | Record rationale in the Milestone Status Tracker |
| **Reorder** the default sequence (e.g., Verification + Code Review in parallel; QA before Code Review) | Orchestrator judgment | Record reasoning briefly |
| **Substitute** one subagent for another (e.g., Researcher in place of Spike when the question is investigative-only) | Orchestrator judgment | Record substitution rationale |
| **Add a subagent** because an auto-escalation symptom class fired | Unconditional | Notify the user (do not ask permission); see `auto-escalation.md` |
| **Re-dispatch a subagent** after rework | Rework returns to the Developer; downstream re-runs only the affected gate(s) — Verification fail → V→R→Q; Code Review fail → R→Q; QA fail → QA only. Conversation Mode: loop Developer → Combined Reviewer until ACCEPT. | Record in the Milestone Status Tracker |

### Hard floors

Some compositions are non-negotiable regardless of orchestrator judgment:

- **Critical Mode runs the full team.** No subtractions, no substitutions on the core gates. Critical's whole point is depth.
- **Auto-escalation symptom classes always invoke their associated subagents** regardless of declared weight — see `auto-escalation.md`.
- **Architecture-introducing work always invokes Lead Architect + Challenger Architect.** A new public interface, new data flow, or new cross-cutting concern crosses this threshold.
- **Co-Approval Rule applies whenever architects are dispatched.** Both Lead and Challenger must return `approved: true`; the orchestrator does not advance until both approvals are on record.
- **Architects run on Sonnet or Opus, never Haiku** (model-selection constraint, not team-composition — see `model-selection.md`).

### Team transparency

Every team composition decision is announced and justified to the user at dispatch time, not silently followed. Format:

> Team for `{task_id}`: {subagent list with annotations}. {Additions with reasons.} {Skips with consent reference.} {Non-default order, if applicable.}

Example:

> Team for `M03-T07-DEV`: lead-architect, challenger-architect, spec-to-test, developer, verification, combined-reviewer, qa. **Adding** researcher (domain question about Unity addressables). **Skipping** doc-writer (no user-visible behaviour change; you confirmed at intake on 2026-05-08). **Order**: verification and combined-reviewer running in parallel after developer completion.

This makes the Producer's reasoning auditable. Probes can verify "given this task shape, did the Producer pick the right team?" against a concrete declaration in the transcript.

---

## What's currently built

All current subagents are implemented (twelve core + two opt-in external-vendor shims = fourteen total):

- ✅ `developer` — `agents/developer.md`
- ✅ `combined-reviewer` — `agents/combined-reviewer.md` (Conversation/Light combined-pass reviewer)
- ✅ `lead-architect` — `agents/lead-architect.md`
- ✅ `challenger-architect` — `agents/challenger-architect.md`
- ✅ `spec-to-test` — `agents/spec-to-test.md`
- ✅ `verification` — `agents/verification.md`
- ✅ `code-reviewer` — `agents/code-reviewer.md` (Standard-mode quality-only reviewer; distinct from `combined-reviewer`)
- ✅ `qa` — `agents/qa.md`
- ✅ `doc-writer` — `agents/doc-writer.md`
- ✅ `researcher` — `agents/researcher.md` (desk-based investigation, comparison, synthesis; used for Research tasks and optional team augmentation)
- ✅ `product-coach` — `agents/product-coach.md` (optional systematic-intake helper for Standard/Critical work)
- ✅ `security-reviewer` — `agents/security-reviewer.md` (OWASP/STRIDE security pass; fires on auto-escalation symptom classes; modes `diff-focused`, `comprehensive`)

*Note (v0.10):* the pre-v0.10 `codex-*` subagent shims have been removed. Cross-vendor execution now goes through the `codex-bridge` skill — see `skills/codex-bridge/SKILL.md` and the "Cross-vendor execution" subsection below.

### Security pass on auto-escalation

When the auto-escalation override fires for one of these symptom classes — *changes to authentication, authorisation, or sensitive-data handling*; *new external dependencies*; *changes that require data migration or feature-flagged rollout*; *cross-user data leakage*; *shared-state corruption*; *session-isolation failures*; *authorization boundary violations*; *concurrency-correlated regressions* — `security-reviewer (mode=diff-focused)` is automatically added to the team. This is a hard floor: the escalation creates the space for security work, and `security-reviewer` is the agent that fills it. The gate fails on any Critical finding.

### Cross-vendor execution via the codex-bridge skill (v0.10+)

When the user has enabled cross-vendor pairing for a milestone (or named a specific Codex role at intake), the orchestrator invokes the `codex-bridge` skill at `skills/codex-bridge/` from its own thread — no Task subagent spawn. Seven roles are supported via per-role references at `skills/codex-bridge/references/`: `architect` (Challenger role on Codex side), `developer`, `code-reviewer`, `spec-to-test`, `security-reviewer`, `verification`, `lead-architect`.

Typical substitutions when cross-vendor pairing is enabled:

- **codex-bridge `architect` (mode=challenge) substitutes for `challenger-architect`** on architecture-introducing work. The Co-Approval Rule applies normally — Lead (Claude) and Challenger (Codex) must both return `approved: true`.
- **codex-bridge `developer` (mode=implement) substitutes for `developer`** only on pattern-following Conversation/Light work; Claude-side Developer remains the default for Standard/Critical.
- See `references/cross-vendor-policy.md` for the full alternation rule (which producers pair with which verifiers on the opposite vendor) and for the failure-mode handling when Codex is unavailable.

Cross-vendor invocations are announced with `codex-bridge[role] (codex:tier, mode=...)` notation in the transparency line. The bridge's `BLOCKED` outcomes have typed `blocker_type` values that map cleanly to the orchestrator's circuit breakers; see `skills/codex-bridge/SKILL.md` "Failure modes" and each per-role reference's "Validation" section.

When you spawn a subagent, pass it only the Context Pack content appropriate to its weight and role. Do not pass the full superset.
