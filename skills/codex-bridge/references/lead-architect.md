# Codex Lead Architect Role Reference

Used by the codex-bridge skill when the orchestrator invokes a Codex-led architecture dispatch — inverting the v0.7 default architect pairing direction so Codex drives the design and Claude (via `challenger-architect`) pressure-tests it under the Co-Approval Rule. Use when the user has named `codex-lead-architect` explicitly at intake.

## Modes

| `mode` | Purpose | Authors design content? | Default? |
|---|---|---|---|
| `propose` | Initial architecture proposal from Milestone Spec + AC list | Yes (structured proposal) | ✓ |
| `amend` | Integrate Challenger amendments into existing Tech Spec | Yes (updated draft) | — |

## Inputs

Common: task ID, parent milestone, Milestone Spec, acceptance criteria (numbered), workflow weight (Standard or Critical), coding standards, plugin language guidance, optional Codex model identifier.

Mode-specific:

**propose:** Prior architecture decisions (ADRs, prior Tech Specs in adjacent areas); architecture conventions and prior failure modes from Basic Memory if available.

**amend:** Current Tech Spec draft; Challenger's findings (`amendments_required`, `named_alternatives`, `five_area_examination`); Architecture Discussion Record so far.

## Prompt template (propose mode)

Write to `/tmp/codex-la-{task_id}.txt`:

```
ROLE: You are the Lead Architect for a multi-agent SDLC workflow. Your job is to produce an architecture proposal for a milestone. The Challenger Architect (on a different vendor) will pressure-test your proposal next under the Co-Approval Rule. You are NOT to write production code. You are NOT to define product behaviour or acceptance criteria — those are the user's domain. You are NOT to author the final Tech Spec; that happens after architectural convergence.

INPUTS:
- Milestone Spec: {verbatim}
- Acceptance Criteria (numbered list): {verbatim}
- Workflow weight: {Standard | Critical}
- Prior architecture decisions: {verbatim}
- Architecture conventions (from Basic Memory if available): {verbatim}
- Coding standards (project CLAUDE.md): {verbatim}
- Plugin language guidance: {verbatim}
- Prior failure modes worth considering (from Basic Memory if available): {verbatim}

PROCEDURE:
1. Read the Milestone Spec and AC list. If product questions are MATERIAL to the design, return outcome=NEEDS_PRODUCT_CLARIFICATION with the specific questions.
2. Otherwise, outline the design covering: system components, module responsibilities, data flow, external dependencies, key interfaces, performance considerations, error-handling strategy.
3. Explicitly identify AT LEAST TWO named alternatives you considered. For each: a one-line description and the reason you rejected it.
4. List key risks the design carries.

MANDATORY ALTERNATIVES RULE:
- At least two entries in named_alternatives.
- If the design is genuinely the only viable approach, state that in convergence_notes and list which classes of alternative were ruled out.

RETURN SCHEMA:
{
  "mode": "propose",
  "outcome": "PROPOSED" | "NEEDS_PRODUCT_CLARIFICATION" | "BLOCKED",
  "summary": "<one-paragraph>",
  "proposal": {
    "system_components": [{"name": "<short>", "responsibility": "<one-line>"}],
    "module_responsibilities": [{"module": "<name>", "responsibility": "<one-line>"}],
    "data_flow": "<one-paragraph or bullet list>",
    "external_dependencies": [{"name": "<short>", "purpose": "<one-line>", "version_pin": "<optional>"}],
    "key_interfaces": [{"name": "<short>", "shape": "<one-line>"}],
    "performance_considerations": "<one-paragraph>",
    "error_handling_strategy": "<one-paragraph>"
  },
  "named_alternatives": [{"name": "<short>", "description": "<one-line>", "rejected_because": "<one-line>"}],
  "open_product_questions": [{"question": "<one-line>", "affects_decision": "<which design decision>", "interpretation_assumed": "<your assumed answer>"}],
  "key_risks": [{"area": "security | performance | dependency | scope | integration", "risk": "<one-line>"}],
  "convergence_notes": "<one-line>"
}
```

## Prompt template (amend mode)

Write to `/tmp/codex-la-{task_id}.txt`:

```
ROLE: You are the Lead Architect responding to a Challenger Architect's review of your previous proposal or Tech Spec draft. You will integrate accepted amendments, push back on disputed ones with rationale, escalate unresolvable ones, and produce an updated Tech Spec draft.

INPUTS:
- Current Tech Spec draft: {verbatim}
- Challenger's findings: {verbatim}
- Architecture Discussion Record so far: {verbatim}
- Acceptance Criteria (numbered list): {verbatim}

PROCEDURE:
1. For each amendment the Challenger requested:
   - If correct: integrate it. Update the spec content. Record under changes_integrated.
   - If disputed: do not integrate. Explain why in items_disputed.
   - If unresolvable: tag for user escalation under items_for_user_escalation.
2. Update the Tech Spec draft. Full markdown goes in updated_tech_spec_content.
3. Decide outcome:
   - APPROVED: every amendment is either integrated or has recorded rationale. Spec is ready for Co-Approval. Set approved=true.
   - REWORK: amendments integrated but disputed items remain OR user escalations exist. Set approved=false.
   - BLOCKED: required input missing or amendments unparseable.

CO-APPROVAL RULE: Set approved=true ONLY when items_disputed AND items_for_user_escalation are BOTH empty.

RETURN SCHEMA:
{
  "mode": "amend",
  "outcome": "REWORK" | "APPROVED" | "BLOCKED",
  "summary": "<one-line>",
  "changes_integrated": [{"target": "<spec section>", "amendment": "<one-line>", "change": "<one-line>"}],
  "items_disputed": [{"target": "<spec section>", "challenger_position": "<one-line>", "lead_response": "<one-line>", "rationale": "<one-paragraph>"}],
  "items_for_user_escalation": [{"question": "<one-line>", "options": ["<one-line>"], "recommended": "<which option, optional>"}],
  "updated_tech_spec_content": "<full updated Tech Spec markdown>",
  "approved": <bool>,
  "approval_rationale": "<one-line, if approved>",
  "convergence_notes": "<one-line>"
}
```

## Invocation

```
codex exec --model {resolved_model} -c 'model_reasoning_effort="{resolved_effort}"' - \
  < /tmp/codex-la-{task_id}.txt \
  > /tmp/codex-la-{task_id}.out 2> /tmp/codex-la-{task_id}.err
```

Use a 300s host tool/process timeout. Do not depend on GNU `timeout`.

## Validation

1. `JSON.parse`; mode match.
2. **propose:**
   - `outcome` is one of `PROPOSED`, `NEEDS_PRODUCT_CLARIFICATION`, `BLOCKED`.
   - When `PROPOSED`: `proposal` has all seven fields. Missing → `codex_response_invalid` with missing field name.
   - **Mandatory alternatives check:** `named_alternatives` ≥ 2 entries OR `convergence_notes` contains "ruled out" with rationale. Failure → `mandatory_alternatives_violation`.
   - Each `named_alternatives` entry has non-empty `name`, `description`, `rejected_because`.
   - When `NEEDS_PRODUCT_CLARIFICATION`: `open_product_questions` non-empty.
3. **amend:**
   - `outcome` is one of `REWORK`, `APPROVED`, `BLOCKED`.
   - `updated_tech_spec_content` non-empty for REWORK / APPROVED.
   - **Co-Approval consistency:** `approved: true` → `items_disputed` empty AND `items_for_user_escalation` empty. Violation → `co_approval_violation`.
   - `approved: true` → outcome MUST be `APPROVED`.

## Return shape

Envelope: `task_id`, `sender_role: codex-lead-architect`, `vendor: openai`, `model`, `model_tier`, `mode`, `outcome`, `summary`, `artifact_refs`, `files_touched: []`, `raw_response_path`, `insights: []`, `vendor_pairing`.

Mode-specific payload on success:
- **propose:** `proposal`, `named_alternatives`, `open_product_questions`, `key_risks`, `convergence_notes`
- **amend:** `changes_integrated`, `items_disputed`, `items_for_user_escalation`, `updated_tech_spec_content`, `approved`, `approval_rationale`, `convergence_notes`

On failure: `blocker_type` (one of: `missing_input`, `codex_cli_not_installed`, `codex_timeout`, `codex_error`, `codex_response_invalid`, `mandatory_alternatives_violation`, `co_approval_violation`) and `blocker_detail`.
