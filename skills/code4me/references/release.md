# Release

Rules that govern milestone closure: when a milestone is production-ready, who confirms what, and what artifacts must exist before the user signs off.

## Zero Failing Tests Rule

The codebase must have zero failing tests at release time.

This applies to **all** tests in the repository, not only those related to the current milestone. A milestone may not be released if any test is failing, regardless of its origin, age, or scope.

If a failing test is discovered outside the current milestone scope:

1. The Verification subagent flags it in its report (Verification is the designated owner of full-suite confirmation)
2. The orchestrator triages immediately — either fix as a blocking issue before release, or escalate to the user for explicit acceptance as a known exception (with a tracked record in the Milestone Status Tracker)
3. Silent acceptance of failing tests is a workflow violation; every red test at release time has either been fixed or explicitly accepted

The orchestrator must not send `MILESTONE_READY` to the user while any test is red without an explicit user-approved exception.

## Documentation Rule

Required documentation must exist before release. Two kinds:

- **Technical documentation** — produced by the Developer subagent during/after implementation. Explains implementation, integration, and maintenance for developers and maintainers. Lives at `.code4me/docs/technical/{task_id}.md` (or the project's standard docs location).
- **User documentation** — produced by the Documentation Writer subagent. Explains how the feature, tool, or workflow is used from the user perspective. Lives at `.code4me/docs/user/{milestone_id}.md` (or the project's standard docs location).

Both types must exist for a Standard or Critical milestone to be release-complete. Skipping documentation requires explicit user consent at intake (per the team-flexibility rules in `team-templates.md`) and is recorded as a deviation in the Status Tracker.

For Conversation, Light, Bug Fix, and Refactor workflows, documentation requirements are workflow-specific:

- **Conversation Mode** — no documentation required (smoke test + Conversation Note are the artifacts)
- **Light** — changelog entry only
- **Bug Fix** — changelog entry; technical documentation only if the fix changes integration shape
- **Refactor** — changelog entry; technical documentation if module structure, internal interfaces, or configuration changed

## Release Rule

A milestone is production-ready when **all** of the following hold:

- All tasks in the Milestone Status Tracker are GREEN (per `canonical-workflow.md` §Quality Gate Loop)
- Zero failing tests in the repository (Zero Failing Tests Rule)
- Required documentation exists (Documentation Rule)
- For Critical milestones: Human Director sign-off is recorded
- All required release artifacts are assembled — changelog updated, version bumped if applicable, release notes drafted

When all hold, the orchestrator sends a `MILESTONE_READY` notification to the user. The user reviews the outcome against the Milestone Spec and either approves the release or returns it for changes.

The user owns the release announcement. The orchestrator does not announce releases on the user's behalf — the user authorship is part of the release semantics.

## Critical-Mode addition

For Critical-weight milestones, the Release Rule extends:

- A pre-release exploratory QA pass plus a **post-release shadow or canary observation period** of at least one production cycle
- The QA subagent files a Post-Release QA Note before the milestone is closed
- Human Director sign-off is recorded as a structured field in the Status Tracker (`human_director_signoff: true` plus a date) — silence does not count
- Tech Spec amendments during implementation required dual architect approval (not just one); the post-implementation review confirms no amendments bypassed this

These additions exist because Critical-weight work has higher consequences for being wrong. The post-release observation period is the safety net for issues that pass QA but only manifest under production load or scale.

## What "release" means in practice

The plugin doesn't define what "release" looks like for your codebase — that's project-shape-dependent. For a library it might mean publishing to npm; for a service it might mean deployment to production; for a Unity game it might mean shipping a build to a store. The Release Rule governs the *gate*: whether the orchestrator considers the milestone ready, regardless of how the project actually distributes its output.

The user's project's `CLAUDE.md` should document what "release" means in their context — the actual deployment steps, version management conventions, etc. The plugin's role is gating, not deployment.

## Recording the release

When a milestone closes, the orchestrator updates the Milestone Status Tracker with:

- Final state: `RELEASED` (or `CANCELLED` / `DEFERRED` if applicable)
- Release date
- User sign-off reference
- For Critical: Human Director sign-off reference
- Pointer to release artifact (changelog entry, deployment record, etc.)
- Any deviations recorded during the milestone (skipped subagents, model deviations, weight escalations)

This record is the input to the Post-Milestone Retrospective. Patterns of deviation across milestones — recurring skips of the same subagent, repeated model upgrades for the same task type, frequent auto-escalations on a particular kind of work — are the signal for tuning the framework's defaults.
