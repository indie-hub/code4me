# Canonical Artifacts

Required content for the artifacts produced during Standard and Critical workflows. Each subagent that produces one of these artifacts is responsible for the content sections listed here. The orchestrator validates that required sections are present before advancing the workflow.

Artifacts persist as markdown files under `.code4me/` (or under the project's existing artifact layout if one is established).

## Tech Spec

Authored by the Lead Architect, reviewed and approved by the Challenger Architect.

Persisted at `.code4me/tech-specs/{spec_id}.md`.

Required sections:

- **Metadata** — spec ID, related milestone, status (`draft` | `agreed`), authors (Lead + Challenger), last updated, references to the Architecture Discussion Record
- **Summary** — short description of the system component or feature; what problem this design solves
- **Scope** — what this Tech Spec covers (a service, a module, a subsystem, a feature)
- **Non-Goals** — explicitly what this design does NOT cover
- **Context** — how this component fits into the larger system; related components, external dependencies
- **Architecture Overview** — high-level design; major components, responsibilities, interactions
- **Component Responsibilities** — table mapping each component or module to its responsibility
- **Interfaces / Contracts** — inputs, outputs, method signatures or API shapes, error responses
- **Data Model** — key data structures or entities (only what's necessary for implementation clarity)
- **Data Flow** — how data moves through the system
- **Error Handling** — behaviour on invalid input, missing data, external failures, concurrency conflicts
- **Edge Cases** — known edge cases (extremely important input for Spec-to-Test and QA)
- **Performance Considerations** — latency targets, request volume, expensive operations, caching expectations (only if relevant)
- **Security Considerations** — authentication expectations, input validation, data exposure, sensitive operations (or explicit "not applicable")
- **Acceptance Criteria Mapping** — table linking AC IDs to system behaviour and implementation areas
- **Testability Notes** — unit test seams, dependency injection expectations, deterministic-behaviour requirements
- **Execution Dependencies** — important sequencing constraints (informs the Execution Dependency Plan)
- **Risks** — known performance, reliability, or correctness risks
- **Open Questions** — unresolved uncertainties; may trigger Research tasks

A Tech Spec without an Acceptance Criteria Mapping fails Verification later regardless of the rest. The mapping is what lets Verification produce its coverage table and what lets Spec-to-Test derive tests with traceability.

## Test Spec

Authored by the Spec-to-Test Engineer.

Persisted at `.code4me/test-specs/{spec_id}.md`.

Required sections:

- **Metadata** — task ID, related implementation task ID, milestone ID, Tech Spec reference, related AC IDs
- **Test Case Mapping** — canonical table; each row carries Test Case ID, Related AC, Given, When, Then, Notes
- **Planned Test Assets** — list of test files to be created with paths and one-line purpose
- **Open Ambiguities** — unresolved points requiring clarification or assumptions made to proceed; "None" if applicable

The Test Case Mapping is the canonical source for test intent. Test function names should reflect the Given/When/Then structure (`test_given_<ctx>_when_<action>_then_<outcome>` or the language-appropriate equivalent). The mapping should not be restated inside test bodies — function names plus the table are sufficient.

### Gate Scope Rule

The pre-implementation test gate is for giving the Developer a concrete target, not for exhaustive coverage:

- **One primary happy-path test per acceptance criterion** by default
- **A boundary, invalid-input, or failure test only when the AC explicitly names that behaviour** (e.g., "reject invalid emails with 400")
- Defer broader boundary, fuzzing, and runtime-risk coverage to QA

Test Specs that creep into exhaustive coverage at the gate stage cause the wrong things — they slow the loop and produce tests for behaviour not yet specified. Stay narrow at the gate; QA picks up the rest.

## Execution Dependency Plan

Authored by the Lead Architect, reviewed and confirmed by the Challenger Architect.

Persisted at `.code4me/execution-plans/{milestone_id}-edp.md`.

Required sections:

- **Summary** — brief description of the implementation effort, major workstreams, sequencing principles
- **Dependency Rules** — explicit rules for this milestone (e.g., "no implementation may begin before its paired Spec-to-Test task is complete")
- **Task Table** — for each task: task ID, type, description, depends-on, enables, parallelisable yes/no, risk, notes
- **Pairing Rules** — implementation tasks paired with Spec-to-Test tasks (`{task_id}-S2T` and `{task_id}-DEV`)
- **Parallelisation Notes** — which tasks may run in parallel and why
- **Risk Notes** — high-risk tasks, sequencing bottlenecks, tasks that unblock many others

The orchestrator uses this plan to drive dispatch order. Tasks not in the plan should not be dispatched without an amendment to the plan first. The Producer must not invent dependency ordering from prose; the plan is the source.

## Architecture Discussion Record

Co-produced by both architects.

Persisted at `.code4me/architecture-records/{record_id}.md`.

Required sections:

- **Metadata** — milestone or task reference, date, both architects' names
- **Initial Proposal** — Lead Architect's starting design, summarised
- **Challenges Raised** — every challenge from the Challenger, numbered, with the area examined (simplicity, completeness, dependency risk, testability, overengineering)
- **Lead Architect Responses** — for each challenge: response, design change made (or not, with reasoning), resolution status (resolved | accepted | escalated)
- **Named Alternatives Considered** — at least one concrete alternative design with rationale for acceptance or rejection (Named Alternative Rule — silence on alternatives is a workflow violation)
- **Final Agreed Design** — summary of what both architects converged on
- **Open Issues** — anything unresolved (must be empty for the Tech Spec to finalise; otherwise the Co-Approval Rule fails)

The record is the evidence that the Mandatory Critique Rule and the Named Alternative Rule were satisfied. A record that lists no challenges or no alternatives fails both rules regardless of whether it claims convergence.

## Context Pack (per task)

Assembled by the orchestrator (the Producer) for each subagent dispatch. Persisted briefly under `.code4me/context-packs/{task_id}.md` for audit; subagents receive the content via Task input rather than reading the file.

Required content (varies by workflow weight; see `team-templates.md`):

For canonical implementation tasks:

- Milestone ID, task ID, task type, parent and paired task IDs
- Tech Spec reference (path)
- Test Spec reference (path)
- Acceptance Criteria references (specific AC IDs the task targets)
- Coding standards reference
- Relevant modules
- Relevant test artifacts
- Non-goals
- Available MCPs (if any) and when to prefer each
- Tooling reminder (Basic Memory, codegraph, CocoIndex, MCPs, context-mode order, fallbacks)
- Dispatched model (per `model-selection.md`)

For documentation tasks, additionally:

- Intended audience
- Tone and register
- Documentation scope and boundaries

Context Packs are immutable per task. If task requirements change, the orchestrator issues a new Context Pack version rather than editing in place. Workers must rely on the Context Pack rather than reconstructing context independently — if the pack is incomplete, return `outcome: BLOCKED` with `blocker: incomplete_context_pack` rather than guessing.

## Verification Report

Produced by the Verification subagent. Persisted at `.code4me/reports/verification/{task_id}.md`.

Required sections:

- **Metadata** — task ID, milestone, Tech Spec reference, Test Spec reference, related AC IDs
- **Summary** — one-paragraph outcome
- **Test Suite Status** — `GREEN` or `RED`; if RED, list failing tests including any outside current task scope
- **AC Coverage** — table: AC ID | Requirement Summary | Evidence | Status (PASS | PARTIAL | FAIL | NOT VERIFIED) | Notes
- **Missing or Partial Items** — explicit list with locations
- **Test Integrity Findings** — any tests modified, weakened, removed, or skipped without authorisation
- **Final Decision** — `PASS` | `PASS WITH FIXES` | `FAIL`
- **Follow-Up Required** — what must happen next

## Code Review Report

Produced by the Code Reviewer subagent. Persisted at `.code4me/reports/review/{task_id}.md`.

Required sections:

- **Metadata** — task ID, PR/diff reference, Tech Spec reference, coding-standards reference
- **Summary** — one-paragraph outcome
- **Findings** — grouped by severity: BLOCKER, MAJOR, MINOR, NIT; each finding has location and recommended correction
- **Structural Boundary Notes** — dependency boundaries, forbidden coupling
- **Test Quality Notes** — G/W/T compliance, naming, fragility
- **Final Recommendation** — `ACCEPT` | `ACCEPT WITH CHANGES` | `REWORK REQUIRED`
- **Follow-Up Required** — what must happen next

## QA Report

Produced by the QA subagent. Persisted at `.code4me/reports/qa/{task_id}.md`.

Required sections:

- **Metadata** — task ID, milestone, Tech Spec reference, environment
- **Scope Tested** — what was exercised beyond the Test Spec
- **Bugs Found** — table: ID, severity, summary, repro steps, expected, actual
- **Edge Cases Checked** — list of explored boundaries
- **Final Decision** — `PASS` | `PASS WITH BUGS` | `FAIL`
- **Follow-Up Required**
