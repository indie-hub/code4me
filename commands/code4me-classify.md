---
description: Run code4me intake + classification on a task without dispatching. Returns the kind, weight, auto-escalation status, and proposed team — but does not invoke any subagent. Useful for sanity-checking how the orchestrator would classify a request before committing to the dispatch.
argument-hint: <task description>
---

Run the code4me orchestrator's intake and classification flow on the following request, but **stop before any Task-tool dispatch**. Specifically:

1. Load the `code4me` skill (`skills/code4me/SKILL.md` and `ETHOS.md`).
2. Consult Basic Memory if its MCP tools are configured.
3. Run the **intake** step: understand intent and stakes; ask clarifying questions only if necessary to classify.
4. Run **classification**: kind (Bug Fix / Tech Debt / Spike / Incident / Scope Change / product), weight (Conversation / Light / Standard / Critical).
5. Apply **auto-escalation override**: check the symptom-class list in `references/auto-escalation.md`. If any apply, raise the weight to at least Standard and record the trigger.
6. Decide the **team** for this task per `references/team-templates.md` and the hard floors in `SKILL.md`.
7. If cross-vendor pairing is enabled for the milestone (check intake; default off), apply the alternation rule from `references/cross-vendor-policy.md` and resolve per-role vendor.
8. Resolve the **tier** per role from `references/model-selection.yaml` → resolve concrete model via `references/vendor-models.yaml`.
9. **Emit the Team Transparency announcement** in the format from `references/playbook.md` ("Transparency announcement format") — with `(vendor:tier)` annotations and the pairing summary when applicable.
10. **Do NOT** call the Task tool. **Do NOT** persist to `.code4me/`. **Do NOT** write any artifacts.

This is read-only classification. After the announcement, surface a one-line note: *"Classification only — no dispatch performed. Re-run without `/code4me-classify` or invoke `/code4me-dispatch <weight>` to execute."*

Request to classify:

$ARGUMENTS
