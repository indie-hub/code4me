# Conversation Note

The smallest milestone artifact. Replaces the full Milestone Spec for Conversation-weight work.

## Metadata

- task_id:
- created_at:
- declared_weight: Conversation
- promote_or_revert_deadline:

---

## What is being changed

One paragraph. Describe the change in user-visible terms. Avoid implementation detail.

---

## Why

One paragraph. Why this change, why now, what value it delivers.

---

## How to know it worked

One concrete, observable criterion. The Developer will write a smoke test against this. Examples:

- *the homepage CTA button renders blue (`#1A73E8`) instead of green*
- *clicking "Forgot password" sends a reset email within 5 seconds*
- *the new `/api/health` endpoint returns 200 OK with body `{"status":"ok"}`*

If you cannot state a criterion concretely, the work probably should not be Conversation Mode.

---

## Modules involved

List the files or modules the Developer should touch. The orchestrator will pass these in the Developer's Context Pack.

---

## Forbidden conditions check (orchestrator fills this)

Confirm none apply before dispatching:

- [ ] no new public interface
- [ ] no new schema, data flow, or persistence path
- [ ] no cross-cutting concern (auth, logging, observability, error handling)
- [ ] no new external dependency
- [ ] no data migration or feature-flagged rollout
- [ ] not security-, privacy-, or payment-sensitive
- [ ] no auto-escalation symptom class applies

If any is unchecked, escalate the weight to at least Light and switch templates.
