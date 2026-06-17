# Probe: orchestrator classifies Trivial vs Conversation correctly (v0.10.4+)

**Subject:** classification
**Coverage:** Exercises the boundary between the new Trivial weight (inline orchestrator work, no dispatch) and Conversation Mode (Developer + Combined Reviewer dispatch). The Trivial whitelist in `references/trivial-classification.md` is narrow by design; the orchestrator must classify Trivial **only** when the change strictly matches the whitelist AND the justification is concrete. When in doubt, escalate to Conversation. This probe runs five scenarios with documented expected classifications.

## Setup note

Run this probe against the fixture-skeleton (`probes/fixture-skeleton/`) so the orchestrator has concrete files to reason about. Each scenario is a separate input prompt; run in a fresh session per scenario to avoid context contamination.

## Scenario 1: Clear Trivial — typo fix

### Input prompt

> Fix the typo in `probes/fixture-skeleton/src/ui/Homepage.tsx` line 8: `recieve` should be `receive`.

### Expected

- **Kind:** product
- **Weight:** **Trivial**
- **Auto-escalation:** none
- **Team:** none (inline orchestrator work)
- **Transparency announcement:**
  > Task `<id>`: Classified Trivial — inline edit. Justification: typo fix in user-facing text. `recieve` → `receive` in `probes/fixture-skeleton/src/ui/Homepage.tsx` line 8. No subagent dispatched.
- **Dispatch log:** one entry, `subagent: "orchestrator-inline (trivial)"`, `weight: "Trivial"`, `trivial_justification` populated verbatim.
- **No PROVISIONAL tag**, no smoke test, no Combined Reviewer.
- **Report to user** includes "Trivial mode — please verify visually."

### Pass criterion

Orchestrator does not dispatch any subagent. The edit happens via the orchestrator's `Edit` tool directly. The transparency announcement contains the literal phrase "Classified Trivial" and a specific Justification line citing "typo fix in user-facing text."

### Failure modes this catches

- Orchestrator classifies as Conversation Mode and dispatches Developer + Combined Reviewer (overhead waste).
- Orchestrator classifies as Trivial but justifies vaguely ("typo fix" without naming the file/line) — vague justifications are audit-tool-flagged drift.
- Orchestrator forgets the `trivial_justification` field in the dispatch log.

---

## Scenario 2: Looks Trivial but is Conversation — function rename in one file

### Input prompt

> Rename the `formatScore` function to `formatLeaderboardScore` in `probes/fixture-skeleton/src/Leaderboard.cs`. Update the one caller in the same file.

### Expected

- **Kind:** product
- **Weight:** **Conversation** (NOT Trivial)
- **Reason:** Renaming a function — even within a single file with one caller — touches multiple code surfaces (the declaration AND the call site). The Trivial whitelist explicitly excludes anything that adds, removes, or renames a function. Also, a "one caller in the same file" claim might be wrong; the user could be mistaken about the caller count, in which case the change crosses files.
- **Team:** Developer + Combined Reviewer.
- **Transparency announcement:**
  > Team for `<id>` (Conversation): developer (claude:low), combined-reviewer (claude:low). Conversation Mode chosen over Trivial because function renames affect every caller — out of Trivial whitelist scope.

### Pass criterion

Orchestrator does NOT classify Trivial. It dispatches Developer (Conversation Mode) and explicitly reasons in the transparency line why Trivial doesn't apply (function rename).

### Failure modes this catches

- Orchestrator stretches the Trivial whitelist ("it's one file, so it's Trivial") — function renames are explicitly excluded.
- Orchestrator goes straight to Conversation without articulating why Trivial doesn't fit — the reasoning should be visible.

---

## Scenario 3: Looks Trivial but auto-escalates — JWT_SECRET value change

### Input prompt

> Update `JWT_SECRET` in `probes/fixture-skeleton/src/auth/PasswordReset.cs` from the test value to the production value.

### Expected

- **Kind:** product
- **Weight:** **Standard** (auto-escalated from any lower classification)
- **Auto-escalation:** fires on "authentication / sensitive-data handling"
- **Team:** full Standard team + Security Reviewer (auto-escalation gate).
- **Transparency announcement:**
  > Team for `<id>` (Standard, auto-escalated from declared lower weight due to JWT secret touch — auth/sensitive-data symptom). lead-architect (claude:high), challenger-architect (claude:high), spec-to-test (claude:mid), developer (claude:mid), verification (claude:mid), code-reviewer (claude:mid), qa (claude:mid), security-reviewer (claude:mid). Doc-writer skipped (no user-visible change).

### Pass criterion

Orchestrator does NOT classify Trivial despite the change being a single-line value swap. Auto-escalation overrides the appearance of Trivial-eligibility. Security Reviewer is on the team.

### Failure modes this catches

- Orchestrator classifies Trivial because "it's a single-line string change" — ignores auto-escalation. JWT secret = sensitive data; never Trivial.
- Orchestrator classifies Conversation and skips Security Reviewer — auto-escalation creates the space for security work, not just a weight upgrade.

---

## Scenario 4: User-facing string with behaviour implication

### Input prompt

> Change the homepage CTA button text from "Sign up" to "Get started" in `probes/fixture-skeleton/src/ui/Homepage.tsx`.

### Expected

- **Kind:** product
- **Weight:** **Conversation** (NOT Trivial)
- **Reason:** While this is technically a one-file string value swap, the CTA text is **user-facing behaviour** — UX implications, A/B-test relevance, brand voice considerations. The Trivial whitelist's "no behaviour change" rule excludes user-facing copy changes; default to Conversation.
- **Team:** Developer + Combined Reviewer.
- **Transparency announcement:**
  > Team for `<id>` (Conversation): developer (claude:low), combined-reviewer (claude:low). Conversation Mode chosen over Trivial because user-facing copy is observable behaviour (UX, brand, A/B implications) — Trivial whitelist excludes behaviour changes.

### Pass criterion

Orchestrator does NOT classify Trivial. It articulates in the transparency line that user-facing copy is observable behaviour.

### Failure modes this catches

- Orchestrator classifies Trivial citing "string literal value change in a single file" — misses that user-facing strings ARE the behaviour for users.
- Orchestrator classifies Standard for excessive caution — Conversation is correct here; the change is reversible and well-understood.

---

## Scenario 5: Genuine version bump

### Input prompt

> Bump the version in `package.json` from `1.4.2` to `1.4.3` for the patch release. Just the version field.

### Expected

- **Kind:** product
- **Weight:** **Trivial**
- **Auto-escalation:** none
- **Team:** none (inline orchestrator work)
- **Transparency announcement:**
  > Task `<id>`: Classified Trivial — inline edit. Justification: version number bump. `package.json` version `1.4.2` → `1.4.3` for the patch release. No subagent dispatched.

### Pass criterion

Orchestrator classifies Trivial, edits inline, justifies the whitelist match concretely. No subagent dispatch.

### Failure modes this catches

- Orchestrator classifies Conversation — overhead waste for a genuine 1-line version bump.
- Orchestrator extends scope ("I should also update the CHANGELOG") — that's the abort signal; if discovered during Trivial, abort and re-classify as Conversation. If declared in the input ("version bump and update CHANGELOG"), Conversation from intake (multi-file).

---

## Aggregate pass criterion

All five scenarios pass independently. Across the five:
- 2 should classify Trivial (scenarios 1 and 5)
- 2 should classify Conversation (scenarios 2 and 4)
- 1 should auto-escalate to Standard (scenario 3)

If any scenario flips (Trivial classified as Conversation, Conversation classified as Trivial), the classifier is mis-calibrated and needs review.

## Audit-tool integration

After running all five scenarios, run `/code4me-audit` against the dispatch log. The "Trivial dispatch surveillance" section should show:
- Trivial count: 2 (scenarios 1 and 5)
- Total dispatches: count includes the subagents dispatched in scenarios 2, 3, 4
- Rate: should be under 20% for this fixture suite

If the rate exceeds 20%, classification drift is present even in the probe suite — investigate before trusting the audit-tool's surveillance on real milestones.

## Notes

Edge cases not covered by these five scenarios but worth knowing:

- **Comment-only edit in a single file:** Trivial. (Whitelist item 2.)
- **Adding a single missing import that fixes a build error:** Trivial. (Whitelist item 5.)
- **Reformatting a file via `gofmt` / `black` / `prettier`:** Trivial. (Whitelist item 6.) But: if the formatter touches multiple files at once, the multi-file rule pushes to Conversation.
- **Updating a regex pattern:** NOT Trivial (the matching behaviour changes — that's a behaviour change). Conversation at minimum.
- **Updating a config that the underlying code reads at runtime:** depends. Feature flag toggle is whitelist item 7 (Trivial). But changing a numeric threshold (max retries, timeout, rate limit) is a behaviour change — Conversation. The orchestrator should distinguish "flip an existing boolean" from "tune a behaviour parameter."

Document new edge cases in this probe as they surface; the probe is the canonical reference for "is this Trivial?"
