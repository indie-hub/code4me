# Spec Kit Interop

How the code4me orchestrator detects and consumes [GitHub Spec Kit](https://github.com/github/spec-kit) artifacts (`specs/<feature>/spec.md` and `specs/<feature>/plan.md`), adapting the canonical workflow so the architecture-discussion artifacts don't have to be re-derived from scratch.

Spec Kit produces structured spec + plan files at the front of the SDLC — the same conceptual layer code4me's Producer / Product Coach / Lead Architect produce when starting from a raw user request. When the user has already run Spec Kit on a feature, those files are a cleaner input than re-running the intake-from-scratch flow. The interop preserves code4me's quality gates (Challenger review, Co-Approval, Spec-to-Test, Verification, etc.) while honouring the upstream artifacts the user already invested in.

## Detection

At intake (step 2 of the orchestrator's operating loop), the orchestrator checks for:

1. `specs/<feature>/spec.md` — a Spec Kit specification file (Markdown with frontmatter following Spec Kit's conventions). The `<feature>` slug is either the milestone slug the user named at intake or the most recently-modified `specs/*/` directory.
2. `specs/<feature>/plan.md` — a Spec Kit technical plan, if present.

If neither file exists, the orchestrator runs the original intake flow (Product Coach if Standard/Critical; freeform clarification otherwise). The interop is purely additive: the absence of Spec Kit files is the no-op case.

## Adapted workflow when `spec.md` is present

The orchestrator's canonical operating loop adapts as follows:

| Step | Without Spec Kit | With `spec.md` present |
|---|---|---|
| Intake | Producer asks clarifying questions; Product Coach optional | Read `spec.md` as the Milestone Spec; skip Product Coach |
| Classify | Producer classifies kind + weight | Same — Spec Kit doesn't replace classification |
| Auto-escalation | Symptom-class check | Same — applies regardless |
| Architecture | Lead Architect produces proposal → Challenger critiques → Co-Approval | If `plan.md` also present: use it as the Lead Architect's *draft* input; dispatch Challenger (or codex-architect) for soundness review on the plan content; Lead reviews/amends; Co-Approval as usual |
| Spec-to-Test | Standard path | Same |
| Developer | Standard path | Same |
| Verification / Code Reviewer / QA | Standard path | Same |

The downstream gates (Spec-to-Test, Quality Gate Loop, Doc Writer, Release) are unchanged. The interop affects only the front of the SDLC where Spec Kit's contribution overlaps with code4me's intake + architecture phase.

## Adapted workflow when only `plan.md` is present (no `spec.md`)

Treat the same as the no-Spec-Kit case for intake (Product Coach if warranted; freeform otherwise). The `plan.md` becomes an additional input the Lead Architect should reference, but the architectural decisions are not pre-committed.

This is uncommon — Spec Kit's normal flow produces `spec.md` first — but the interop handles it gracefully rather than treating a partial Spec Kit run as broken.

## What gets persisted into `.code4me/`

When `spec.md` is consumed as the Milestone Spec, the orchestrator:

1. Writes a Milestone Spec reference at `.code4me/milestone-specs/{milestone_id}-source.md` containing a one-line provenance note: `Sourced from Spec Kit: specs/<feature>/spec.md (SHA: <git blob SHA at intake time>)`.
2. Does NOT copy the spec content into `.code4me/` verbatim — the Spec Kit file remains the source of truth. The Milestone Status Tracker references it by path.
3. Records `spec_kit_interop: true` in the dispatch log entries for the milestone (a new top-level field in the JSONL line).

When `plan.md` is consumed as the Lead Architect's draft input, similarly:

1. The Architecture Discussion Record's first entry is `Sourced from Spec Kit plan: specs/<feature>/plan.md (SHA: <git blob SHA>)`.
2. The Tech Spec produced at the end of the architecture-discussion phase lives in `.code4me/tech-specs/` as normal — the Spec Kit `plan.md` is the input, not the output.

## Transparency announcement

The orchestrator's transparency announcement gains a one-line provenance prefix when Spec Kit interop is active:

> **Inputs**: Spec Kit (`specs/checkout-redesign/spec.md`; plan present and forwarded as architect draft input).
>
> **Team for M-CHECKOUT-T01-ARCH** (Standard): `lead-architect (claude:high)`, `challenger-architect (claude:high)`, ...

This makes the input provenance visible in the audit trail without requiring users to dig through the dispatch log.

## When to use Spec Kit alongside code4me

The two tools have non-overlapping strongest leverage:

- **Spec Kit's leverage:** front-of-SDLC artifact structure that's portable across agents (Claude Code, Copilot, Codex CLI, Gemini CLI, 30+ tools). Use Spec Kit when the spec needs to be readable / reviewable / consumable by multiple agent toolchains, or when the team's review process already runs on Spec Kit's templates.
- **Code4me's leverage:** execution-side discipline — weight classification, auto-escalation, Co-Approval Rule, Quality Gate Loop, cross-vendor pairing, runtime hooks. Use code4me when you want a Producer-as-orchestrator running the dispatch and the gates.

The interop lets both run at full strength: Spec Kit produces the inputs; code4me dispatches the team that executes against them.

## When NOT to use the interop

- **Hot-path Conversation Mode work.** Spec Kit is overkill for a "change the button colour" task; the interop is a no-op there anyway because no spec.md exists for the feature. Spec Kit slows down the loop for genuinely small changes.
- **Tech debt or refactor work where the spec doesn't exist.** Spec Kit assumes a forward-going feature; tech-debt refactors don't fit its frame. Use code4me's canonical flow without Spec Kit.
- **Spec Kit specs you don't trust.** If the team produced a `spec.md` you suspect doesn't reflect actual intent, surface it as a NEEDS_PRODUCT_CLARIFICATION at intake rather than silently consuming a wrong spec.

## Backward compatibility

This is additive. Projects that don't use Spec Kit see no behavior change. Projects that adopt Spec Kit gain the interop the first time `specs/<feature>/spec.md` appears at intake. No setup or configuration required beyond the Spec Kit installation itself.
