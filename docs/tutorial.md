# Tutorial: your first code4me milestone

A 10-minute walkthrough from "I just installed the plugin" to "I closed a Conversation Mode task." Assumes Claude Code or Codex is installed and code4me has been added through that client's plugin marketplace.

## What you'll do

1. Scaffold a fresh project for code4me (`/code4me-init`)
2. Run a tiny change through Conversation Mode
3. Read the dispatch log to see what happened
4. Promote the change (or revert it)

If everything goes well, you'll have a working `.code4me/` directory, one Conversation Note, one entry in the dispatch log, and one piece of changed code with the `PROVISIONAL` tag retired.

## Prereqs

- Claude Code or Codex installed with the code4me plugin enabled. In a client session, type `/code4me-` and confirm that commands autocomplete.
- A project directory you're comfortable making a small reversible edit in. A throwaway scratch repo is fine.
- Run `/code4me-preflight` first if you want a quick environment sanity check. Warnings are fine; FAIL is not.

## Step 1 — scaffold

In your project root:

```
/code4me-init
```

This previews the files it would create, asks you to confirm, then copies the starter templates:

- `AGENTS.md` in Codex or `CLAUDE.md` in Claude Code (project conventions — edit the placeholders later)
- `.code4me/` (runtime working directory: milestone-status-tracker, conversation-notes, milestone-specs, tech-specs)

After confirming, edit the created `AGENTS.md` or `CLAUDE.md` to replace the `PLACEHOLDER` sections with your actual project shape — at minimum the stack one-liner and the run/build/test commands. Init leaves hooks and MCP configuration to the installer commands shown in its final checklist.

## Step 2 — first Conversation

Pick a small reversible change. The classic is a string change, a config tweak, a styling adjustment. Then say it to the current orchestrator:

> Change the homepage CTA button colour from green to blue.

The orchestrator will:

1. Classify this as `kind=product, weight=Conversation` (it's small, reversible, and doesn't trip any auto-escalation symptom class).
2. Announce the team: `developer (claude:low)`, `combined-reviewer (claude:low)`. No architects, no spec-to-test, no doc-writer.
3. Write a Conversation Note at `.code4me/conversation-notes/{task_id}.md` capturing what's changing, why, and how to know it worked.
4. Dispatch the developer subagent, which writes a smoke test, then implements the change, then runs the smoke test.
5. Dispatch combined-reviewer to confirm spec compliance + code quality + runtime in one pass.
6. Tag the change `PROVISIONAL — promote-or-revert by {date+7 days}` in the changelog.
7. Return the outcome for your sign-off.

You can ask clarifying questions at any point — "why is doc-writer skipped?" — the orchestrator's transparency announcement is the audit trail and the conversation hook for those questions.

## Step 3 — read the dispatch log

After the task closes, run:

```
/code4me-audit
```

This wraps `bin/code4me-audit-dispatch-log` and prints a markdown summary: which subagents fired, weight distribution, tier distribution, vendor split, outcome distribution, and the cross-vendor and tier-deviation analytics. For a single-task run it'll be brief, but you'll see the shape of what the audit tool surfaces.

Also peek at `.code4me/dispatch-log.jsonl` directly — one line per Task-tool dispatch, with task ID, weight, subagent, vendor, tier, model, outcome, and (when present) vendor pairing and context provenance fields.

## Step 4 — promote or revert

The change was tagged `PROVISIONAL` with a deadline. To close the Conversation loop:

```
/code4me-promote-or-revert <task_id>
```

The command reads the Conversation Note, surfaces the original intent + smoke test + deadline, and asks you to choose:

- **promote** — mark stable, retire the `PROVISIONAL` tag from the changelog, close the task
- **revert** — `git revert` the task's commits, update the Conversation Note's status
- **extend by N days** — push the deadline forward
- **abandon** — close the task without action

For your tutorial run, **promote**. The changelog entry loses its `PROVISIONAL` prefix; the Conversation Note status becomes `promoted`.

## What you just exercised

In ten minutes, you've used:

- `/code4me-init` (scaffold)
- The orchestrator's intake + classification + dispatch loop
- The Conversation Mode workflow (developer + combined-reviewer + smoke test + `PROVISIONAL` tag)
- `/code4me-audit` (dispatch-log analytics)
- `/code4me-promote-or-revert` (Conversation Mode close)

Plus the runtime hooks installed during setup — though Conversation Mode work usually doesn't trip them. They'd fire on larger changes (`check-forbidden-conditions.sh` on schema/migration/auth changes; `check-test-protection.sh` on attempted protected-test edits in Standard mode; `check-critical-write-allowlist.sh` on out-of-scope edits during Critical milestones).

## What to try next

- **Light Mode** — a slightly larger change ("add a new constant to the config") will land as `Light`, adding an architect-notify step (non-blocking).
- **Standard Mode** — a feature with a new interface ("add a CSV export endpoint") will run the full canonical workflow: Lead + Challenger architects → Spec-to-Test → Developer → Verification → Code Reviewer → QA → Doc Writer.
- **Cross-vendor pairing** — invoke as `/code4me-dispatch Standard --cross-vendor <task>` to enable the alternation rule from `docs/howto-enable-cross-vendor.md`. Requires the Codex CLI setup from `docs/howto-enable-codex.md`.
- **Critical Mode** — high-stakes work (auth, payments, data migration) triggers auto-escalation; runs the full team plus extra QA and user sign-off; the `check-critical-write-allowlist.sh` hook constrains edits to the Tech Spec's declared scope.

Most of the docs from here on are reference and how-to. Start with `docs/reference.md` for the substantial reference content; `docs/explanation.md` for the design-decision rationales (why five weights, why Co-Approval, why orchestrator-as-skill).
