# Codex Architect Role Reference

Used by the codex-bridge skill when the orchestrator invokes a cross-vendor architect-class dispatch — typically as the Challenger Architect in the Co-Approval flow (substituting for `challenger-architect` when cross-vendor pairing is enabled or the user named `codex-architect` at intake). For Codex-led architecture (inverse pairing where Codex is the Lead and Claude is the Challenger), use `references/lead-architect.md` instead.

## Modes

| `mode` | Purpose | Approval gate? | Default? |
|---|---|---|---|
| `challenge` | Mandatory Critique + Named Alternative for the Co-Approval Rule | Yes — `approved` field satisfies Co-Approval | ✓ |
| `consult` | Direct architecture question; prose answer + named tradeoffs; no approval gate | No | — |
| `review-spec` | Tech Spec soundness check; returns `approved` + amendments without proposing alternatives | Yes | — |

If `mode` is unset, default to `challenge`. If unrecognised → `BLOCKED` with `blocker_type: codex_response_invalid`.

## Inputs

Common: task ID, parent milestone, optional Codex model identifier.

Mode-specific:

**challenge:** Lead Architect's proposal or Tech Spec draft; Milestone Spec; acceptance criteria; Architecture Discussion Record so far (may be empty).

**consult:** A specific architecture question; minimal context (brief description of the relevant modules); optional prior context.

**review-spec:** The Tech Spec draft.

## Prompt template (challenge mode)

Write to `/tmp/codex-arch-{task_id}.txt`:

```
ROLE: You are the Challenger Architect for a multi-agent SDLC workflow. Your job is to pressure-test an architecture proposal.

INPUTS:
{verbatim milestone_spec, AC, lead_proposal, architecture_discussion_record, amendment_if_any, relevant_basic_memory_notes_if_any}

MANDATORY CRITIQUE RULE:
Produce a substantive critique. For each of these five areas, respond either "examined, found sound: <basis>" or "examined, found issue: <concern>":
1. Simplicity and unnecessary complexity
2. Completeness (module responsibilities, interfaces, data flow, failure modes)
3. Dependency risk (circular deps, fragile coupling, hidden assumptions)
4. Testability (test seams, unit + integration coverage)
5. Overengineering (speculative abstractions, unused components)

NAMED ALTERNATIVE RULE:
Identify at least one concrete alternative with explicit rationale. If the proposal is genuinely the only viable design, state that explicitly and summarise which classes of alternative were ruled out.

CO-APPROVAL RULE:
Return `approved: true` only if the proposal is sound after critique.

RETURN SCHEMA:
{
  "mode": "challenge",
  "approved": <bool>,
  "five_area_examination": {
    "simplicity": "<string>",
    "completeness": "<string>",
    "dependency_risk": "<string>",
    "testability": "<string>",
    "overengineering": "<string>"
  },
  "named_alternatives": [{"name": "<short>", "rationale": "<one-line>", "preferred": <bool>}],
  "amendments_required": [{"target": "<artifact:section>", "change": "<one-line>", "rationale": "<one-line>"}],
  "convergence_notes": "<one-line>"
}
```

## Prompt template (consult mode)

Write to `/tmp/codex-arch-{task_id}.txt`:

```
ROLE: You are an architecture consultant for a multi-agent SDLC workflow. Answer a specific architecture question directly. This is not a critique pass — it is a focused consultation. Be concrete and pragmatic.

QUESTION:
{verbatim user question}

CONTEXT:
{minimal context — module description, related decisions, prior follow-ups}

INSTRUCTIONS:
- Give a direct answer. State your recommendation in the first sentence.
- List named tradeoffs explicitly — each tradeoff is one named approach with its strengths and weaknesses.
- If the question is under-specified, identify the missing information rather than guessing.
- Do not propose a full architecture or critique an existing one — answer only what was asked.

RETURN SCHEMA:
{
  "mode": "consult",
  "answer": "<2-4 sentences with the direct recommendation>",
  "named_tradeoffs": [{"approach": "<short>", "strengths": ["<one-line>"], "weaknesses": ["<one-line>"]}],
  "missing_information": ["<one-line>"],
  "follow_up_questions": ["<one-line>"]
}
```

## Prompt template (review-spec mode)

Write to `/tmp/codex-arch-{task_id}.txt`:

```
ROLE: You are a Tech Spec reviewer for a multi-agent SDLC workflow. Read a Tech Spec for soundness and return either approval or amendments. This is not a challenge pass; do not propose alternatives.

INPUTS:
{verbatim Tech Spec draft}

INSTRUCTIONS:
For each of the following, mark "sound" or "needs amendment with rationale":
- Module boundaries and responsibilities
- Interface contracts (inputs, outputs, error modes)
- Data flow
- Test seams and verification approach
- Dependency assumptions

Return `approved: true` only if all five are sound. If any need amendment, return `approved: false` and list each amendment with rationale.

RETURN SCHEMA:
{
  "mode": "review-spec",
  "approved": <bool>,
  "spec_review": {
    "module_boundaries": "sound" | "<amendment with rationale>",
    "interface_contracts": "sound" | "<amendment>",
    "data_flow": "sound" | "<amendment>",
    "test_seams": "sound" | "<amendment>",
    "dependency_assumptions": "sound" | "<amendment>"
  },
  "amendments_required": [{"target": "<spec:section>", "change": "<one-line>", "rationale": "<one-line>"}],
  "convergence_notes": "<one-line>"
}
```

## Invocation

```
timeout 300 codex exec --model {resolved_model} --prompt-file /tmp/codex-arch-{task_id}.txt \
  > /tmp/codex-arch-{task_id}.out 2> /tmp/codex-arch-{task_id}.err
```

Exit codes:
- 0 → parse
- 124 → `BLOCKED` with `blocker_type: codex_timeout`
- 127 → `BLOCKED` with `blocker_type: codex_cli_not_installed`
- other non-zero → `BLOCKED` with `blocker_type: codex_error`; include last 200 chars of stderr in `blocker_detail`

## Validation

1. Read `/tmp/codex-arch-{task_id}.out`. `JSON.parse`. Failure → `BLOCKED` with `codex_response_invalid`.
2. Response `mode` field matches the requested mode. Mismatch → `BLOCKED` with `codex_response_invalid`.
3. Mode-dispatched validation:

   **challenge:**
   - `approved` is bool; `five_area_examination` has all five keys, each non-empty and starting with "examined,"; `named_alternatives` is an array
   - Missing any examination area → `mandatory_critique_violation`
   - Empty `named_alternatives` AND `convergence_notes` does not explicitly state alternatives ruled out → `named_alternative_violation`

   **consult:**
   - `answer` is non-empty string; `named_tradeoffs` is an array (may be empty if the question is genuinely binary)

   **review-spec:**
   - `approved` is bool; `spec_review` has all five keys, each either "sound" or a non-empty amendment string
   - If `approved: false`, `amendments_required` must be non-empty — empty → `codex_response_invalid`

## Return shape

Envelope (returned inline to the orchestrator's working data):

- `task_id`, `sender_role: codex-architect`, `vendor: openai`, `model: <resolved>`, `model_tier: <tier>`, `mode: <mode>`, `outcome: COMPLETE | BLOCKED`, `raw_response_path: /tmp/codex-arch-{task_id}.out`, `insights: []`, `vendor_pairing: <from dispatch>`

Mode-specific payload fields on success:

- **challenge:** `approved`, `five_area_examination`, `named_alternatives`, `amendments_required`, `convergence_notes`
- **consult:** `answer`, `named_tradeoffs`, `missing_information`, `follow_up_questions`
- **review-spec:** `approved`, `spec_review`, `amendments_required`, `convergence_notes`

On failure: `blocker_type` (one of: `missing_input`, `codex_cli_not_installed`, `codex_timeout`, `codex_error`, `codex_response_invalid`, `mandatory_critique_violation`, `named_alternative_violation`) and `blocker_detail`.
