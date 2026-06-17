---
description: Close the Conversation Mode loop on a specific task — either promote the change (mark stable, retire the PROVISIONAL changelog tag) or revert it. Reads the Conversation Note for the task ID, surfaces the original intent + smoke test + deadline, and asks for a decision. Always interactive — never auto-promotes or auto-reverts.
argument-hint: <task_id>
---

Close the Conversation Mode loop for the given task. The plugin's Conversation Mode tags changes as `PROVISIONAL — promote-or-revert by {date}` so the user retains a decision point. This command operationalises that decision.

Procedure:

1. **Validate the task_id.** It must match a Conversation Note at `.code4me/conversation-notes/{task_id}.md`. If not found, surface: *"No Conversation Note found for `{task_id}` at `.code4me/conversation-notes/{task_id}.md`. Run `/code4me-status` to list active Conversation Mode tasks."* and stop.

2. **Read the Conversation Note.** Surface the relevant fields to the user:
   - The original intent (what was being changed, why)
   - The smoke test that captured the "how to know it worked" criterion
   - The files touched
   - The PROVISIONAL changelog tag
   - The promote-or-revert deadline
   - Time elapsed since the change was applied

3. **Ask the user explicitly:**

   > Promote, revert, or extend the deadline for `{task_id}`?
   >
   > - **promote** → mark the change stable; retire the `PROVISIONAL` tag in the changelog; update the Conversation Note's `status: promoted` field; close the task.
   > - **revert** → run `git revert <commit-range-for-this-task>` (after confirming the user is comfortable with the diff); update the Conversation Note's `status: reverted`; close the task.
   > - **extend by <N> days** → push the deadline forward by N days; update the Conversation Note. Useful when the change is still soaking but more time is needed.
   > - **abandon** → close the task without action; rare, but appropriate when the task became moot.

4. **On the user's decision, execute:**
   - **promote**: update the changelog entry (replace `PROVISIONAL — promote-or-revert by {date}` with the bare entry text); update the Conversation Note's frontmatter or status section.
   - **revert**: show the diff (`git log --oneline -- <files_touched>`), confirm with the user, run `git revert` for the relevant commits, update the Conversation Note.
   - **extend**: update the deadline date in the Conversation Note and in the changelog tag.
   - **abandon**: mark the Conversation Note `status: abandoned` with a one-line reason from the user.

5. **Update `.code4me/milestone-status-tracker.md`** to reflect the closed-or-extended state of the task.

6. **Surface a one-line summary** of what was done.

This command is **always interactive**. Never promote or revert without an explicit user decision.

Argument:

$ARGUMENTS
