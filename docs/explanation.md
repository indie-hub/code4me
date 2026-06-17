# Explanation

The design-decision rationale behind code4me. Useful for understanding *why* the framework is shaped the way it is — particularly when you're tempted to change something and want to know what invariant you'd be breaking.

## Why four workflow weights, not two or eight?

Two weights (light / heavy) underfit real work: there are reversible quick changes that don't warrant architects, and there are full-team Standard milestones that don't warrant the extra Critical scrutiny. Eight or more weights overfit: the user spends more energy classifying than the framework saves on dispatch.

Four covers the actual signal:

- **Conversation** for reversible work where the cost of "wrong" is low because rollback is cheap.
- **Light** for pattern-following work where an architect's notify is enough to keep architecture consistent without slowing the loop.
- **Standard** as the default — the full canonical workflow.
- **Critical** for high-stakes work where the cost of "wrong" is high enough to warrant extra QA and explicit user sign-off.

The four weights pair cleanly with the model tier defaults (`low` / `mid` / `mid+high architects` / `high`) so the cost surface scales with the stakes. If a Conversation task seems to want `high`, the weight is probably wrong — escalate the weight, don't overpower the model. That consistency check is one of the framework's strongest invariants.

## Why the auto-escalation override?

The user can be wrong about stakes. They can declare Conversation on a change that touches authentication, or Light on a change that introduces a new public interface. The blast radius of these mis-classifications is the entire point of the canonical workflow.

The auto-escalation override flips the failure mode from "user under-classified and bypassed the gates" to "framework escalated above the user's declared weight." The user sees the escalation; the audit log records it; the team that runs is appropriate to the actual stakes. The user can object, but the override is non-negotiable — the symptom-class list at `references/auto-escalation.md` is the load-bearing safety net.

The symptom classes are intentionally narrow: authentication, sensitive-data, new-external-dependency, data-migration, cross-cutting concerns, new-public-interface. Each one represents work whose blast radius routinely exceeds the user's intuition.

## Why Co-Approval on architecture?

Two architects make architectural mistakes less likely than one — but only if they're forced to disagree. A single architect can converge on a flawed design and never have it pressure-tested. The Co-Approval Rule (both Lead and Challenger return `approved: true` on the same Tech Spec version) makes that pressure-test structural rather than optional.

The Challenger's Mandatory Critique + Named Alternative rules amplify the dialectic: the Challenger isn't allowed to just rubber-stamp; it must examine five named areas and propose at least one named alternative (or explicitly state that classes of alternative were ruled out). The structure forces the Challenger to do real architectural work, not just signal approval.

Cross-vendor pairing (v0.7+) extends this: same-vendor architects can share distribution biases that lead them to similar blind spots. Different-vendor architects break that symmetry. The Co-Approval Rule still applies; the dialectic is just structurally stronger.

## Why the Producer-as-orchestrator pattern?

The orchestrator is a coordination role, not a doer role. The Producer's job is classification, dispatch, persistence, routing, and escalation — not implementation, architecture, verification, or QA. Each of those is its own role with its own contract.

The pattern matters because role-boundary discipline is what makes the audit trail readable. When an architectural mistake surfaces in QA, you can trace it back to the Lead Architect's Tech Spec, the Challenger's review, and the Co-Approval. When a test integrity violation surfaces, you can trace it to the Spec-to-Test handoff and the Developer's response. The dispatch log + the canonical artifacts + the structured return payloads together form a trace that survives across sessions.

Collapsing the orchestrator into "Claude does everything" loses the trace. The framework's value isn't the model; it's the protocol the model operates within.

## Why solo mode, when the Producer pattern says "coordinate, don't do"? (v0.13+)

Solo mode looks like a contradiction of the previous section. It isn't — it's an honest concession plus a careful boundary.

The concession: for small-to-medium, well-understood tasks, a single capable agent in a tight implement-test-fix loop beats the dispatch pipeline on speed and cost. The handoffs that make the trace readable also lose information and burn tokens. Forcing every two-file change through Developer + reviewer dispatch is process for its own sake — exactly what the weight system exists to avoid.

The boundary: solo keeps the two controls that a pure loop structurally cannot provide. First, **author ≠ reviewer** — every solo diff meets one fresh-context gate (Combined Reviewer, or Verification for Standard) that didn't write the code and doesn't share its blind spots. Second, **mechanical self-binding** — the PreToolUse hooks fire on the orchestrator's own edits, so in Standard solo the orchestrator writes the test gate and `protected-tests.txt` *before* implementing, and is then ask-gated by its own hook against weakening it. The most insidious failure mode of looped agents — quietly gaming their own tests — stays structurally blocked.

Solo is also explicit-entry only (the same opt-in discipline as cross-vendor pairing) and never available for Critical. The trace survives in reduced form: solo entries log with `subagent: "orchestrator-inline (solo)"`, a mandatory `solo_requested_via`, and the gate's structured return. You trade trace richness for loop speed, knowingly, on the work where the trade is favourable — and the audit tool watches the solo share and gate-FAIL rate to catch the cases where it wasn't.

## Why declarative `context_queries` instead of imperative Context Pack assembly?

v0.5 had one imperative list (in the playbook) for what every dispatch needed: task ID, spec, modules, model parameter, MCP inventory, language guidance, tooling reminder. Same shape every time, regardless of which subagent.

Declarative `context_queries:` (v0.6+) moves the requirements per-agent. Each agent declares what *it* needs; the orchestrator resolves and assembles. The wins:

- **Audit trail.** When a dispatch goes wrong, the orchestrator's transparency announcement lists what was in the Context Pack and what was skipped (with reasons). The declarative form makes that traceable.
- **Mode and weight awareness.** Codex shims have mode-specific context needs; Conversation Mode developers need forbidden-conditions but Standard developers don't. `when:` conditions make these explicit without branch-heavy orchestrator code.
- **Provenance (v0.8+).** Each resolved query records the artifact + SHA that answered it. "Why did the developer not see the latest amendment?" is now a `jq` query against the dispatch log, not a transcript dig.

The cost is one block of YAML per agent file. The benefit is that the Context Pack is inspectable, declarative, and version-controlled with the agent that needs it.

## Why slim SKILL.md + playbook + references?

A single monolithic skill file has two failure modes: it bloats over time (every new rule wants to be at the top), and it forces the model to load the whole thing on every session.

The slim contract pattern (v0.6+) splits the skill into three layers:

- **`SKILL.md`** — the contract. What the orchestrator must do. Short and stable.
- **`references/playbook.md`** — the elaboration. How the orchestrator decides when the contract doesn't pre-decide. Read at decision time, not preloaded.
- **`references/*.md`** — specific topics. Read on demand by reference from the playbook or SKILL.md.

This is Anthropic's progressive disclosure pattern applied to plugin design itself. The skill description loads on every session; everything else loads when needed. The contract stays auditable; the elaboration stays maintainable.

## Why the Test Protection Rule?

Tests are an executable spec. Once Spec-to-Test has produced them, modifying them changes what "works" means — and that's a workflow-level decision, not an implementation decision. The Developer's job is to make the implementation pass the tests; not to make the tests pass the implementation.

The rule is enforced at three layers:

- **Prompt-level** in the Developer subagent's directive: "Tests produced by Spec-to-Test are protected artifacts. Your job is to make the implementation pass the tests, not the tests pass the implementation."
- **Runtime** via the `check-test-protection.sh` hook, which ask-gates Edit/Write tool calls targeting paths in `.code4me/protected-tests.txt`.
- **Shim** via the codex-developer's implement-mode validation, which BLOCKs with `test_protection_violation` if Codex's `files_touched` contains a protected path.

If the Developer thinks a test is wrong, the protocol is to return `outcome: TEST_QUESTION` — route the question through the orchestrator to Spec-to-Test. The hook firing is the structural enforcement of that protocol; if it ask-gates an Edit, the right response is `TEST_QUESTION`, not "approve past."

## Why cross-vendor pairing is opt-in per milestone

The cost surface is real: a Critical milestone with full pairing has the same dispatch count but split across two providers, each with their own billing. For some milestones the cross-vendor dialectic is worth that cost (auth code, payment flows, anything where the blast radius of a missed issue is high). For others it's overhead.

Per-milestone opt-in lets the user make that call when they have the most context. Project-wide "always cross-vendor" would either over-spend on small Standard milestones or be turned off and forgotten on Critical ones. Per-milestone keeps the decision active.

Auto-escalation does NOT force cross-vendor on. Critical milestones still default to single-vendor unless the user opts in. This is intentional: cross-vendor is the kind of safety that benefits from user awareness; making it implicit makes the cost surprise.

## Why the runtime hooks ask, never deny

Three reasons:

1. **Graceful degradation.** A misconfigured hook should warn, never block. If the orchestrator wrote a malformed state file, the user shouldn't be locked out of edits — they should see the warning and decide.
2. **User override is sometimes correct.** There are legitimate cases where the user has context the hook doesn't (a test that genuinely needs to be modified after authorisation; a Conversation Mode forbidden condition tripped by a path that's actually safe in this context). `ask` preserves the user's authority; `deny` would force a workaround.
3. **The hook is part of a protocol, not a security boundary.** The protocol is: hook fires → developer maps to typed outcome → orchestrator routes appropriately. The hook is one step in that chain, not the enforcement boundary. The actual enforcement is in the subagent's typed return + the orchestrator's routing.

If you want a hard deny on certain paths (e.g., production secrets), use a separate mechanism (gitignore + .gitleaks; CI guardrails). The code4me hooks are workflow gates, not security gates.

## Why probes instead of unit tests

Probes are diagnostic prompts for orchestrator decisions, not assertions about code. They answer "did the framework make the right team-composition decision for this input?" — a question about the orchestrator's behaviour, not its output.

A unit test framework doesn't fit because:

- The output is a transparency announcement that's natural-language. There's no "expected output string"; there's "expected kind, weight, team, ordering" that map to a fuzzy match.
- The orchestrator's behaviour depends on prompt content. A probe is a paired (input, expected) prompt; a regression is when the orchestrator's response to the same input drifts from the expected.

The LLM-as-judge probe runner (v0.8+) automates the fuzzy matching. The regression budget (`probes/budget.toml` + `--max-flips`) absorbs LLM variance while flagging real movement. Together they're an evals discipline applied to the framework itself, in Hamel Husain's frame — probes are the "spend 30 minutes reading 20-50 traces every meaningful change" practice automated.

## Why so many references in `references/`

Each file documents a single decision-time concern. The orchestrator loads what it needs at decision time, not preloaded. The result: the playbook stays short, the references stay focused, and the user can read any single reference standalone.

The cost is more files. The benefit is that each file is reviewable in isolation: a change to `model-selection.md` doesn't risk breaking unrelated rules in the auto-escalation list.

## Why no `codex-qa` or `codex-researcher`

QA's value is exploratory creativity (finding edge cases the spec didn't name). Researcher's value is desk-research synthesis (comparing approaches, finding prior art). Both benefit from prompt strategies more than from vendor diversity — the wins from cross-vendor are smaller here than at the gates (architect / spec-to-test / developer / reviewer / verifier / security).

The framework can run cross-vendor on the high-leverage pairs and stay single-vendor on QA + Researcher without losing meaningful dialectic. Adding `codex-qa` and `codex-researcher` was on the original v0.9 plan as "Tier-3 reassessment pending live-test signal" but has been explicitly closed by user decision: QA and Researcher stay Claude-only.

## Why the orchestrator runs on Opus

The orchestrator's classification, dispatch, escalation, and routing decisions propagate through the entire team. A cheap orchestrator misclassification cascades: wrong weight → wrong team → wrong tier → wrong models → wrong gates. Opus on the orchestrator is small relative to the cost of running a misassembled team on Sonnet.

This is a recommendation, not a hard requirement — the user picks their session model. The README states the recommendation prominently. If you choose a lower tier for the orchestrator, expect more classification errors (and a noisier dispatch log).

## What changes if you remove `ETHOS.md`?

The ETHOS file documents the shared operating principles every subagent inherits: pacing (wrong work is more expensive than paused work), simplicity (prefer simple designs, verifiable work), role boundaries (orchestrator dispatches; subagents execute; PO decides), context (OpenWolf first, then LSP, then MCPs, then fallbacks), fidelity (surface BLOCKED with typed reasons rather than reformatting), project guidance (project CLAUDE.md authoritatively overrides), user authority (PO is final on product behaviour), INSIGHT emission (route learnings upstream).

Each individual subagent's role-specific directive sits on top of the ETHOS. If you remove ETHOS, every subagent file would need to re-encode those principles independently, and they'd drift. The shared file is the load-bearing consistency mechanism.

## Why the framework still ships at 0.x

Because **no real milestone has run through it.** Every cut from v0.6.1 to v0.9.0-dev has been structural — the framework is theoretically excellent and empirically untested. The dispatch log is empty across all versions; the tier defaults are theory; the alternation degrade-fallback hasn't been exercised under load.

The 1.0 release is the moment after the first Standard milestone (with cross-vendor enabled) and the first Critical milestone (with the full hook set) have run end-to-end. At that point the framework will have empirical signal to defend the choices it makes; until then it's a well-reasoned plan.

This is intentional. Bumping to 1.0 before live-testing would be premature certainty.
