# How to use Spec Kit alongside code4me (v0.9+)

[GitHub Spec Kit](https://github.com/github/spec-kit) produces structured specification + technical-plan files at the front of the SDLC — the same conceptual layer that code4me's intake + architecture phase produces from a raw user request. When you've already run Spec Kit on a feature, code4me's interop consumes those files directly instead of re-deriving them.

This is opt-in by virtue of the files existing: if `specs/<feature>/spec.md` is at the project root, the orchestrator detects and uses it. No flag or configuration needed.

## What gets consumed

| Spec Kit artifact | code4me consumes as | Adapted behaviour |
|---|---|---|
| `specs/<feature>/spec.md` | Milestone Spec | Skip Product Coach (Standard/Critical default-on otherwise) |
| `specs/<feature>/plan.md` | Lead Architect draft input | Dispatch Challenger Architect / codex-architect for soundness review of the plan |

Downstream gates (Spec-to-Test, Quality Gate Loop, Doc Writer, Release) are unchanged. The interop affects only the intake + architecture front of the SDLC.

## Recommended workflow

For a new feature where you'd benefit from Spec Kit's portable artifact structure:

1. **Run Spec Kit** first. From the Spec Kit's installation, in the project root:

   ```
   /specify <feature description>     # produces specs/<feature>/spec.md
   /plan                              # produces specs/<feature>/plan.md
   /tasks                             # produces a task list (Spec Kit-side)
   ```

   The `/tasks` step is Spec Kit's task-decomposition; code4me doesn't consume it directly (the orchestrator's own Execution Dependency Plan replaces it for execution).

2. **Hand off to code4me** for execution:

   ```
   Standard milestone for the <feature> feature. The spec and plan are in specs/<feature>/.
   ```

   The orchestrator detects the Spec Kit files at intake, prefixes its transparency announcement with an `**Inputs**:` line citing the consumed paths, skips Product Coach, dispatches Lead Architect with the plan as draft input, and proceeds through the canonical flow.

3. **Run `/code4me-status`** at any point to confirm the milestone tracks the Spec Kit inputs in its provenance:

   ```
   .code4me/milestone-specs/{milestone_id}-source.md
       → Sourced from Spec Kit: specs/<feature>/spec.md (SHA: <git blob>)
   ```

## What the transparency announcement looks like

A milestone with Spec Kit interop active:

> **Inputs**: Spec Kit (`specs/checkout-redesign/spec.md`; plan present and forwarded as architect draft input).
>
> Team for `M-CHECKOUT-T01-ARCH` (Standard): `lead-architect (claude:high)`, `challenger-architect (claude:high)`, `spec-to-test (claude:mid)`, `developer (claude:mid)`, `verification (claude:mid)`, `code-reviewer (claude:mid)`, `qa (claude:mid)`, `doc-writer (claude:mid)`. **Skipping** Product Coach (spec.md is the Milestone Spec).

The `**Inputs**` line is the audit trail signal that Spec Kit was the source.

## What does NOT change

- **Weight classification.** Spec Kit doesn't replace code4me's kind + weight classifier. Auto-escalation symptom classes still apply.
- **Co-Approval Rule.** Lead Architect produces the final Tech Spec from the plan.md draft; Challenger reviews; both must approve. The plan.md is the input, not the output.
- **Spec-to-Test.** The Test Spec is still derived from the Tech Spec; Spec Kit's task list isn't a substitute.
- **Quality gates.** Verification, Code Reviewer, QA, Doc Writer all run normally.

## When Spec Kit interop is the highest leverage

- **Multi-agent workflows.** Spec Kit's artifacts are portable across Claude Code, Copilot, Codex CLI, Gemini CLI, 30+ tools. If the spec needs to be readable / reviewable by multiple agent toolchains, use Spec Kit's templates and let code4me consume them.
- **Team review processes already on Spec Kit.** If your team's PR review or pre-implementation review uses Spec Kit's templates, code4me consumes the same artifacts rather than fragmenting the review surface.
- **Larger features where the spec deserves its own artifact.** Spec Kit's spec.md is a more substantial document than code4me's Conversation Note or Milestone Spec; for features that warrant that level of pre-work, it's the right shape.

## When NOT to use Spec Kit interop

- **Conversation Mode work.** Spec Kit is overkill for a "change the button colour" task. The interop is a no-op there anyway (no spec.md exists).
- **Tech debt / refactor where the spec doesn't exist.** Spec Kit assumes forward-going feature work; refactors don't fit its frame. Use code4me's canonical flow without Spec Kit.
- **Specs you don't trust.** If the team produced a `spec.md` you suspect doesn't reflect actual intent, surface it as `NEEDS_PRODUCT_CLARIFICATION` at intake rather than letting code4me silently consume a wrong spec.

## Audit trail integration

Every dispatch log entry for a Spec-Kit-interop milestone carries `spec_kit_interop: true`. The audit tool surfaces the prevalence:

```
/code4me-audit
```

In the resulting markdown report, look for the `spec_kit_interop` count — it tells you how many dispatches in your log used Spec Kit inputs. Useful for tracking adoption across the project.

## Backward compatibility

Projects that don't use Spec Kit see no behaviour change. Projects that adopt Spec Kit gain the interop the first time `specs/<feature>/spec.md` appears at intake. No setup required beyond the Spec Kit installation itself.
