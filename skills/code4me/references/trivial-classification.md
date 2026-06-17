# Trivial Classification

The Trivial weight (v0.10.4+) is the fifth and smallest workflow weight. It permits **inline orchestrator work** — direct `Edit`/`Write` on production files — without subagent dispatch, bounded by a hard whitelist and a mandatory one-line justification. This document is the load-bearing reference: classification is *only* Trivial when the change fits the whitelist AND the orchestrator can articulate the justification in one line.

The Trivial carve-out exists because Conversation Mode's dispatch overhead (~3–5K tokens for a Developer subagent + a Combined Reviewer + a smoke test + a `PROVISIONAL` tag) is structurally excessive for changes where the entire diff is < 5 lines and the blast radius is essentially zero. For a typo fix or a config-value flip, paying that overhead is bad cost-benefit; Trivial is the safety valve.

## The whitelist

A change is eligible for Trivial classification **if and only if** it matches one of these patterns. The list is intentionally narrow and concrete.

1. **String literal value change in a single file.** No logic touched. The code does the same thing afterwards, just with a different value. Examples: `const COLOUR = "green"` → `"blue"`; `MAX_RETRIES = 3` → `5`. Counter-example: changing a regex pattern is NOT Trivial because the matching behaviour changes — that's Conversation.

2. **Comment or docstring edit.** Adding, removing, or refining inline comments, function docstrings, module-level prose. No executable code change.

3. **Typo fix in user-facing text.** `recieve` → `receive`; `accomodate` → `accommodate`; punctuation correction. Both source comments and user-facing strings (UI labels, error messages, log lines).

4. **Version number or date bump.** `version: "1.2.3"` → `"1.2.4"` in package.json / Cargo.toml / pyproject.toml. Bumping a `RELEASED_AT` constant. No semver implications are evaluated by the orchestrator — that's the user's call before classification.

5. **Single import add or remove.** Adding or removing exactly one import statement in exactly one file, where the addition has no downstream code referring to it that doesn't already exist, and the removal is structurally clean (no remaining usage that breaks).

6. **Whitespace, formatting, or lint-fix.** Trailing whitespace, indentation correction, quote-style unification, semicolon add/remove per project style. Purely cosmetic; the parsed AST is unchanged.

7. **Feature flag toggle (config-only).** Flipping `FEATURE_X_ENABLED: false` → `true` in a config file, where the underlying feature code already exists, is exercised by existing tests, and the flip is the only change. The feature code itself was added under a previous weight.

## What does NOT count as Trivial

If **any** of these conditions apply, the change is at minimum Conversation Mode — never Trivial:

- **Any behaviour change.** If the code does something observably different after the change (different output, different timing, different error path), it's not Trivial. A string value swap where the string itself is user-facing copy (an error message users react to, a CTA button label) is debatable — default to Conversation.
- **Any multi-file change.** Multi-file diffs are out of scope, even if each file's change individually would qualify. A rename that touches 3 files is Conversation; a one-file rename is still likely Conversation because of usage chains.
- **Any new function, type, class, struct, interface, trait, or component.** New code surface is never Trivial.
- **Any test change.** Tests are protected artefacts; the path is `TEST_QUESTION` to Spec-to-Test, not Trivial.
- **Any schema, migration, persistence-path, or data-model change.** Auto-escalation symptom; never Trivial.
- **Any authentication, authorisation, sensitive-data, secrets, or rate-limit change.** Auto-escalation symptom; never Trivial.
- **Any new external dependency.** Auto-escalation symptom; never Trivial.
- **Any CI / deployment / infrastructure-as-code change.** Blast radius is project-wide even if the diff is small; never Trivial.

The auto-escalation override (`references/auto-escalation.md`) applies to Trivial the same as to any other weight. Even if the literal change is one line, an auth-touching one line is at minimum Standard.

## The justification requirement

The orchestrator's transparency announcement for a Trivial-classified change **must** contain a `Justification:` line citing which whitelist item applies, with the specific change inline. Format:

> Task `{task_id}`: Classified Trivial — inline edit. Justification: {whitelist item}. {one-line description of the specific change}.

Acceptable:

- "Justification: typo fix in user-facing text. `recieve` → `receive` in `internal/profile/email.go` line 42."
- "Justification: version number bump. `package.json` version `1.4.2` → `1.4.3` for the patch release."
- "Justification: single import add. Adding `time` import to `internal/cache/expiry.go` for the `time.Duration` constant introduced in the previous task."
- "Justification: feature flag toggle. `EXPERIMENTAL_NEW_SEARCH` true → false in `config/flags.yaml` to disable while we investigate the regression."

Unacceptable (orchestrator should escalate to Conversation):

- "Simple change." (Not specific.)
- "Just renaming a function." (Renaming affects every caller — Conversation at minimum.)
- "Small refactor." (Refactor is never on the whitelist.)
- "Updating the config." (Which value? What's the blast radius? Escalate.)

Vague justifications are a signal that the classification is wrong. When in doubt, escalate to Conversation.

## Orchestrator behaviour in Trivial mode

When Trivial classification fires:

1. **Announce.** Transparency line per the format above.
2. **Make the edit.** Direct `Edit` / `Write` tool call. This is the explicit carve-out from the STRICT PROTOCOL's "no production-file writes outside `.code4me/` and `.wolf/`" rule, gated by the Trivial classification and the recorded justification.
3. **Log to dispatch-log.jsonl** with:
   ```jsonl
   {"ts": "...", "milestone": "...", "task": "...", "weight": "Trivial",
    "subagent": "orchestrator-inline (trivial)",
    "vendor": "anthropic", "model": "<orchestrator's session model>",
    "outcome": "COMPLETE",
    "trivial_justification": "<one-line justification, verbatim from transparency line>",
    "files_touched": ["<the one file>"]}
   ```
   The `subagent` value is the discriminator — the audit tool aggregates by this. The `trivial_justification` field is mandatory; entries lacking it are flagged by the audit tool as malformed.
4. **Update `.code4me/milestone-status-tracker.md`** — record the task at `weight: Trivial`, state `completed`. Trivial tasks complete in one step; there's no intermediate state.
5. **Update Trello (if configured)** via the `trello-sync` skill — create card in Inbox (intake), move directly to Done (after the edit). The card description includes the justification. No due date (Trivial is not `PROVISIONAL`).
6. **NO `PROVISIONAL` tag.** Trivial is not Conversation Mode; there's no promote-or-revert deadline because `git revert` is the trivial undo. The user can revert any Trivial change in seconds without needing a deadline.
7. **NO smoke test, NO Combined Reviewer, NO Quality Gate Loop.** The change is small enough that visual user inspection plus the existing test suite (run by the user, not the orchestrator) is sufficient.
8. **Report** to the user with explicit Trivial-mode disclaimer: *"Trivial mode — no subagent dispatched, no PROVISIONAL tag, no smoke test. Please verify visually and re-run your tests."*

## Abort conditions

If, during the edit, the orchestrator discovers that the change is more than Trivial — extra files need touching, a downstream usage needs updating, the change has behavioural implications — **abort immediately** and re-classify as Conversation. Don't stretch Trivial to cover scope creep.

Concretely: if as the orchestrator's `Edit` tool call returns, the orchestrator finds itself thinking *"and I also need to..."* that's the abort signal. Stop, surface what you learned as an INSIGHT (`impact_tier: required change before next similar task`), classify the broader task as Conversation, and dispatch.

## Anti-drift safeguards

Three structural protections so Trivial doesn't quietly absorb work that should be Conversation:

1. **The whitelist is concrete and short.** Seven items, each with examples. "Is my change like one of these?" should have a clear yes/no answer. If you're squinting to justify Trivial, escalate.

2. **Justification is mandatory and audited.** The dispatch log captures `trivial_justification`. The audit tool (`bin/code4me-audit-dispatch-log` v0.10.4+) surfaces a **Trivial dispatch rate** metric — Trivial entries as a percentage of total dispatches. If Trivial > ~20%, the audit flags potential classification drift in a "Trivial dispatch surveillance" section.

3. **Probe.** `probes/classification/10-trivial-vs-conversation.md` exercises edge cases — a 1-line change that crosses functions; a "typo fix" that's actually a meaningful word change; a string value swap that changes user-visible behaviour. Run after framework changes and check baseline diff.

## Composition with the rest of the framework

- **Auto-escalation override**: applies normally. Auth / migration / sensitive-data symptom classes lift Trivial to Standard immediately.
- **Hooks**: applicable. The orchestrator's `Edit` tool call passes through `check-test-protection.sh`, `check-forbidden-conditions.sh`, and `check-critical-write-allowlist.sh`. If a Trivial edit accidentally targets a protected test or a Critical-allowlist-violating path, the hook ask-gates and the orchestrator should re-classify.
- **OpenWolf cerebrum**: read first per the orchestrator's operating loop. Cerebrum may contain a Do-Not-Repeat entry that lifts the change above Trivial (e.g., "Don't bump versions without updating CHANGELOG.md too" → that's a multi-file rule; Trivial fails the whitelist).
- **Cross-vendor pairing**: not applicable. Trivial is inline orchestrator work; no subagent means no producer/verifier pair.
- **Spec Kit interop**: not applicable. Spec Kit produces specs for feature work; Trivial is below feature work.
- **Trello sync**: applies the same as other weights. Card created at intake, moved to Done after edit. The card body includes the justification.

## When NOT to add Trivial classification to a workflow

If 30%+ of your work is Trivial by these rules, you have a tooling gap, not a workflow problem. Persistent Trivial volume signals:

- A linting / formatting tool that should run on save (not through code4me).
- A renovate-style dependency-version bumper for routine updates.
- A template / generator for the repetitive pattern you keep hand-editing.

Trivial is the safety valve for occasional one-line edits, not a workflow for systematic small changes. Systematic Trivial use is a hint to automate the underlying need rather than route it through code4me.
