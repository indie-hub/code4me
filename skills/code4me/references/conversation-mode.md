# Conversation Mode

Conversation Mode applies when the user declares Conversation weight at intake.

## When it applies

The work is small, well-understood, and reversible. Formal architecture and Spec-to-Test would cost more than they protect against.

## Forbidden conditions

Conversation Mode must **not** be used when any of the following are true:

- the change introduces a new public interface
- the change introduces a new schema, data flow, or persistence path
- the change touches a cross-cutting concern (auth, logging, observability, error handling)
- the change introduces a new external dependency
- the change requires data migration or feature-flagged rollout
- the change is to security-, privacy-, or payment-sensitive code
- any auto-escalation symptom class applies (see `auto-escalation.md`)

If any forbidden condition becomes true mid-flight, escalate the weight to at least Light and reissue the Context Pack.

## The path

1. **Conversation Note.** Ask the user (or distill from the request) for: what is being changed, why, and how to know it worked. Persist as `.code4me/conversation-notes/{task_id}.md` using `templates/conversation_note.md`.
2. **Confirm with the user.** Show the Conversation Note and ask for confirmation before dispatching. This is the user's last chance to escalate or cancel.
3. **Dispatch the Developer.** Use the Task tool to invoke the `developer` subagent. Pass: the Conversation Note content, references to the modules involved, and the explicit instruction to write a smoke test that captures the "how to know it worked" criterion before implementing.
4. **Receive the Developer's completion.** Verify the return contract: smoke test exists and passes, change implemented, files touched listed, any forbidden condition encountered (if so, escalate).
5. **Dispatch the Combined Reviewer.** Use the Task tool to invoke the `combined-reviewer` subagent. Pass: the Conversation Note, the Developer's completion summary, and the files touched. The combined reviewer returns ACCEPT, ACCEPT WITH CHANGES, or REWORK REQUIRED. The combined reviewer must be a different invocation than the Developer.
6. **Handle review outcome.**
   - ACCEPT → proceed to step 7
   - ACCEPT WITH CHANGES → forward changes to Developer; re-dispatch the combined reviewer; loop until ACCEPT
   - REWORK REQUIRED → if review identified a forbidden condition, escalate the weight; otherwise re-dispatch Developer with the combined reviewer's findings
7. **Mark provisional.** Tag the change as **provisional** in the changelog: `PROVISIONAL — promote-or-revert by {date}` where date is the lesser of (next milestone boundary) and (today + 14 days).
8. **Schedule promote-or-revert.** Persist the deadline in the Milestone Status Tracker so the framework reminds the user when the deadline arrives.
9. **Return to user.** Summarize: what shipped, where, the smoke test name, the promote-or-revert deadline.

## Forbidden artifacts

Conversation Mode does **not** produce a Tech Spec, an Architecture Discussion Record, an Execution Dependency Plan, a Test Spec, a Verification Report, a Code Review Report, a QA Report, technical documentation, or user documentation. Producing them defeats the purpose. The Conversation Note + smoke test + combined review are the only artifacts.

## The promote-or-revert rule

Provisional changes do not become permanent automatically. At the deadline, prompt the user with a one-line decision:

> Conversation-mode change `{task_id}` ({summary}) is at its promote-or-revert deadline. Promote to trunk, revert, or extend the deadline?

If the user does not respond, the change does not auto-promote. Track unresolved promote-or-revert prompts in the Milestone Status Tracker.

If the user requests an extension, record the new deadline and a one-line reason. Do not allow indefinite extension; if the same provisional change is extended more than twice, it has stopped being provisional in spirit and should be promoted or reverted now.

## Track with suffix `-CONV`

Task IDs for Conversation Mode work use the `-CONV` suffix: `M03-T07-CONV`.

## Glob patterns for the forbidden-conditions hook

The abstract forbidden-conditions list above is the *semantic* contract — the conceptual categories the Conversation Mode work must not touch. The `check-forbidden-conditions.sh` PreToolUse hook needs a concrete *file-pattern* contract. The two contracts overlap but are not identical: a file pattern is a necessary signal, not the whole story (a "new public interface" may not introduce a new file at all — it may extend an existing one).

When the orchestrator enters Conversation Mode dispatch, it writes `.code4me/forbidden-conditions.json` with a starting set of glob patterns drawn from the table below. The hook guards any `Write` of a new file whose path matches one of these globs. Existing-file `Edit` is not gated by this hook — the orchestrator's prompt-level Conversation Mode forbidden-conditions handling covers the rest.

| Forbidden condition (semantic) | Starting glob patterns (file-level) |
|---|---|
| new persistence path / new schema or data flow | `**/migrations/**`, `**/migration/**`, `**/schema/**`, `**/*-migration.*`, `**/*_migration.*`, `**/*.sql` (new files only) |
| data migration | covered by the above; also `**/seed/**`, `**/seeds/**`, `**/fixtures/**/*-prod.*` |
| feature flag | `**/feature-flags/**`, `**/feature_flags/**`, `**/flags/**/*.json`, `**/flags/**/*.yaml` |
| sensitive-data handling | `**/secrets/**`, `**/credentials/**`, `**/.env`, `**/.env.*`, `**/keystore*`, `**/*-secrets.*` |
| new external dependency | (not file-pattern-detectable; covered by the orchestrator's prompt-level escalation, not the hook) |
| new public interface | (not reliably file-pattern-detectable; same caveat) |
| cross-cutting concern | (not reliably file-pattern-detectable; same caveat) |
| new persistence path (separate from schema) | `**/db/**/*-new.*`, `**/storage/**/new-*` |

Format:

```json
{
  "forbidden_globs": [
    "**/migrations/**",
    "**/schema/**",
    "**/feature-flags/**",
    "**/secrets/**",
    "**/.env",
    "**/.env.*"
  ]
}
```

**Project-specific tuning is expected.** The patterns above are starting defaults — adjust per project. The user (or the orchestrator on the user's behalf) can edit `.code4me/forbidden-conditions.json` directly. The hook re-reads the file on every invocation, so changes take effect immediately. Empty `forbidden_globs` or a missing file means the hook passes through silently.

**The hook is part of the required runtime wiring.** Claude projects receive it through `bin/code4me-install`; Codex loads it from the trusted plugin bundle. The Developer subagent's prompt-level handling remains a second layer.
