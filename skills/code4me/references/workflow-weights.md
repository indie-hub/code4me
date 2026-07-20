# Workflow Weights

The Product Owner (the user) declares a workflow weight at intake. The weight tunes how much process the work earns — it does not replace the kind classifications (Bug Fix, Tech Debt, Spike, Incident, Scope Change), which are determined by their own triggers and override the weight.

## The five tiers

| Weight | When to use | Maps to |
|--------|-------------|---------|
| **Trivial** *(v0.10.4+)* | tiny, single-file, no behaviour change — typo, version bump, string value swap, comment, single import, formatting, feature-flag toggle (config-only) | Inline orchestrator work; no subagent dispatch (see `trivial-classification.md` for the bounded whitelist + justification requirement) |
| **Conversation** | small, well-understood, reversible work — historically a quick PO/Developer chat | Conversation Mode (`conversation-mode.md`) |
| **Light** | small but pattern-following — a new endpoint mirroring an existing one, an additive validator, a config option that follows the existing pattern | Minor Change Workflow |
| **Standard** | default; non-trivial work, new interfaces, new data flow, cross-cutting concerns | Canonical Workflow |
| **Critical** | high-stakes work where being wrong is expensive — auth, payments, privacy, data integrity, public APIs | Critical Mode |

**Trivial is structurally different from the other four.** Conversation through Critical all dispatch at least one subagent through the `Task` tool (Conversation: Developer + Combined Reviewer; Light: + architect-notify; Standard: full crew; Critical: full crew with extra QA + user sign-off). **Trivial does NOT dispatch.** The orchestrator does the edit inline, bounded by the whitelist in `trivial-classification.md` and a mandatory one-line justification recorded in the transparency announcement and the dispatch log. Trivial bypasses the Quality Gate Loop, the `PROVISIONAL` tag, the smoke test, and the Combined Reviewer — it's a deliberate carve-out from the STRICT ORCHESTRATOR PROTOCOL's hard success condition, used only when the dispatch overhead would structurally exceed the change's value. When in doubt between Trivial and Conversation, escalate to Conversation.

## Solo execution mode (v0.13+) — orthogonal to weight

Solo is **not a sixth weight** — it's an execution mode that composes with Conversation, Light, and Standard (never Critical, never inferred). The weight's semantics are unchanged; the orchestrator implements inline instead of dispatching a Developer, and exactly one fresh-context gate is always dispatched (combined-reviewer, or verification for Standard). Entry is explicit only: the user says "solo", passes `--solo` on `/code4me-dispatch`, or sets an `AGENTS.md`/`CLAUDE.md` project default. Full rules, per-weight procedure, abort conditions, and log shape: `solo-mode.md`.

## How the user declares

The user declares the weight at intake. You may suggest a weight based on stakes the user describes; the user confirms or overrides. If the user does not declare and the work is product engineering, default to Standard.

If the user is uncertain between two tiers, recommend the heavier one. You can always escalate later; you cannot retroactively un-do work that proceeded under a too-light weight.

## Producer escalation rights

You may escalate the weight (Conversation → Light, Light → Standard, Standard → Critical) at any point if classification proves wrong. You may **not** de-escalate without the user's explicit consent.

If you escalate mid-task, reissue the Context Pack at the new weight and the task re-enters the appropriate quality loop. Work already completed under the lighter weight is not retroactively re-gated unless the escalation reveals a defect.

## Auto-escalation override

The auto-escalation symptom classes (see `auto-escalation.md`) override the declared weight unconditionally. You escalate to at least Standard when those triggers apply, and you notify the user rather than asking permission.

This is not a failure of the user's judgment — it is the safety net working. Frame it that way when you notify.

## Order of evaluation

When a request arrives, evaluate in this order:

1. Is there an active problem with unknown cause? → Incident
2. Is there a known defect, failing test, or regression? → Bug Fix
3. Is this a feasibility question that needs hands-on prototyping? → Spike
4. Does the task change observable user behaviour? → No → tech-debt or refactoring → Tech Debt
5. **Does the task match the Trivial whitelist** (single-file string/comment/typo/version/import/formatting/flag-toggle, no behaviour change, no auto-escalation symptom)? → Trivial (v0.10.4+; see `trivial-classification.md`)
6. The task is product work. Apply the user's declared weight (with auto-escalation override).

Default to Standard for product work without a declared weight. Default to Conversation (not Trivial) when in doubt — the Trivial carve-out is narrow by design.
