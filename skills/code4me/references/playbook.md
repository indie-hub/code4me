# Producer Playbook

Decision-time elaboration on the orchestrator's contract. `SKILL.md` is the contract — what the orchestrator must do. This file is the *how* — the dispatch protocol details, the model-selection deviation rules, the team-composition reasoning beyond the hard floors, the transparency announcement format, and the rationale behind language-guidance injection.

Read this when you hit a decision point the `SKILL.md` contract doesn't already pre-decide. You are not expected to preload it.

## Dispatch protocol detail

As of v0.6, each agent declares its own Context Pack requirements in a `context_queries:` frontmatter block. See `references/context-queries-schema.md` for the schema. At dispatch time, the orchestrator:

1. **Reads the agent's `context_queries:`** — if present, resolve each query per the schema; if absent, fall back to the v0.5 imperative list below.
2. **Resolves queries** — fetch artifacts from `.code4me/`, query Basic Memory when its MCP tools are available, gather project-info from `AGENTS.md`/`CLAUDE.md` and project structure, emit declared dispatch reminders. Evaluate `when:` conditions against the dispatch's weight/mode to skip non-applicable queries.
3. **Assembles the Context Pack** from resolved results.
4. **Records provenance** for every resolved query in the dispatch-log line under `context_provenance` per `references/context-queries-schema.md` §Resolution provenance — `query_kind`, `query_descriptor`, `resolved_artifact`, `resolved_sha` (when in git), and `skipped` for queries that evaluated but resolved to no content. The audit tool reads this to answer "what was in the Context Pack for this dispatch?"
5. **Appends universal items** that every dispatch needs regardless of agent:
   - task ID and parent milestone
   - explicit completion expectations
   - the **chosen vendor** (`anthropic` | `openai`) — defaults to `anthropic`; set by `cross-vendor-policy.md` resolution when cross-vendor pairing is enabled
   - the **chosen tier** (`low` | `mid` | `high`) — resolved from `model-selection.yaml` defaults via the algorithm in `cross-vendor-policy.md` §Resolution algorithm
   - the **chosen model** for this dispatch — resolved from `vendor-models.yaml[vendor][tier]`; always explicit (never inherited)
   - the **`vendor_pairing` block** — `policy`, `pair_role`, `alternates_with`, `degraded` per `cross-vendor-policy.md`
   - the available MCP inventory for the project, with a one-line preference note per `mcp__*` tool
   - language guidance injected based on file types (see `SKILL.md` "Language guidance injection")
   - the transparency announcement (see "Transparency announcement format" below)
6. **Notes any skipped queries** in the transparency announcement — `Context queries skipped: <list with reasons>` is the audit trail for what was not available. Skipped queries also appear in `context_provenance` with `skipped: true`.

Each subagent returns a structured completion. Capture it, persist what's worth persisting, route per the operating loop.

> **Note (v0.7).** The v0.5 imperative-list fallback path that lived here previously is gone. Every shipped agent declares `context_queries:` explicitly. An agent without that frontmatter block is a bug — the orchestrator should not silently fall back to a hand-rolled list. Surface it as `BLOCKED` with `blocker_type: agent_definition_invalid` and `blocker_detail` naming the missing-frontmatter agent so the situation is visible rather than papered over.

## Milestone decomposition

**Standard and Critical milestones MUST be decomposed into tasks before the first dispatch (v0.12+).** A milestone is the user-facing unit ("ship CSV export"); a task is the orchestrator's dispatch unit ("implement the export endpoint", "write the tests for malformed-row rejection", "QA the encoding edge cases"). Decomposition produces the task list and the explicit AC↔task mapping that the rest of the workflow depends on.

### The decomposition rule

The minimum decomposition unit is **"one Verification can attest the AC is met"**. In practice:

- **One task per AC** when each AC corresponds to a distinct sub-deliverable (typical case).
- **Multiple tasks per AC** when implementation, test authorship, and verification can't all run in one task (typical when the AC requires a Tech Spec round, a Test Spec, and a separate Verification pass — i.e., Critical milestones often produce 3-5 tasks for a single AC).
- **One task covering multiple ACs** is allowed ONLY when the ACs are mechanically inseparable — same implementation, same test file, same verification check. Record the multi-AC mapping explicitly in the tracker; the AC↔task lookup should still resolve all touching tasks per AC.

### Recording the decomposition

Update `.code4me/milestone-status-tracker.md` with an `acceptance_criteria:` block (per-milestone) BEFORE the first dispatch:

```yaml
acceptance_criteria:
  AC1:
    summary: "User can export their profile as CSV"
    source: ".code4me/milestone-specs/M07.md#AC1"
    state: declared    # declared | in_progress | in_review | done | blocked
    tasks_touching: ["M07-T03-DEV", "M07-T04-VER", "M07-T05-QA"]
    last_verification_status: null   # PASS | PARTIAL | FAIL | NOT VERIFIED
    last_updated: "2026-06-02T14:35:00Z"
  AC2:
    summary: "CSV includes column headers"
    source: ".code4me/milestone-specs/M07.md#AC2"
    state: declared
    tasks_touching: ["M07-T03-DEV", "M07-T05-QA"]
    last_verification_status: null
    last_updated: "2026-06-02T14:35:00Z"
```

The `state` machine per AC: `declared` → `in_progress` (first touching task dispatches) → `in_review` (all touching tasks have returned, quality gates running) → `done` (verification report says PASS for this AC) OR `blocked` (PARTIAL/FAIL pending rework). Recompute on every dispatch return.

### When the decomposition is NOT required

- **Trivial weight (v0.10.4+)** — single-AC by definition; no decomposition; one card per milestone.
- **Conversation weight** — single AC (the "how to know it worked" criterion); one card per milestone.
- **Light weight** — typically one AC; one card per milestone unless the user declared multiple sub-deliverables at intake.

For these three weights, the tracker still records an `acceptance_criteria:` block with one entry, so the AC↔card mapping is uniform across weights. The trello-sync skill always reads from this block.

### Workflow-violation signals

The orchestrator has decomposition-violated if:

1. **Standard/Critical milestone has zero or one task** after intake. The decomposition step was skipped.
2. **`acceptance_criteria:` block is missing from the tracker** for a Standard/Critical milestone. The decomposition step ran but didn't persist.
3. **An AC has zero `tasks_touching`** after dispatch begins. The AC was declared but no task addresses it — verification will be unable to attest the AC.
4. **A task is dispatched but not listed in any AC's `tasks_touching`** array. The task has no AC association; verification won't trace it back to a requirement.

Surface 1 and 2 as `BLOCKED` with `blocker_type: milestone_not_decomposed` and `blocker_type: acceptance_criteria_block_missing` respectively. 3 and 4 are softer drift signals — log to the dispatch log and surface in the next transparency announcement so the user notices.

## Model and effort deviation rules

Model resolution is vendor-aware via the tier abstraction. Effort is an independent decision. Defaults live in `model-selection.yaml` (machine-readable) with prose in `model-selection.md`. Concrete model identifiers live in `vendor-models.yaml`.

Defaults summarised:

- **Conversation team** → usually `low` model / `low` effort
- **Light team** → mixed `low`/`mid` tier
- **Standard team** → `mid` tier with `high` for architects
- **Critical team** → `high` tier on load-bearing roles

Resolution: look up tier from `model-selection.yaml[role][weight]` → apply hard floors → apply deviation rules → resolve to concrete model via `vendor-models.yaml[vendor][tier]`. Cross-vendor pairing (which sets `vendor`) is independent of and composes with this tier resolution.

Deviation rules (vendor-agnostic):

- Deviate when complexity surprises you, when stakes change mid-flight, or when a previous dispatch at the default failed.
- Record model deviations as `tier_deviated_from_default: true`; record effort deviations independently with `default_effort`, `effort_deviated_from_default`, `effort_source`, and `effort_applied`.
- A failed attempt normally raises effort first. Change model only when capability is the problem.
- `xhigh` and `max` require explicit deviation and backend support. Unsupported backends keep the requested value as metadata and record `effort_applied: false`.
- **Never downgrade** Architect roles below tier `mid` (regardless of vendor).
- **Never downgrade** Critical work below tier `mid`.
- **Never downgrade** auto-escalated work below the resolved tier.
- **Cross-vendor pairing does not relax tier floors** — a Codex developer at Critical is still tier `high`.

Consistency check: if a Conversation request seems to need tier `high`, the workflow weight is probably wrong — escalate the weight, don't overpower the model.

## Team composition reasoning (beyond the hard floors)

Hard floors are listed in `SKILL.md`. Beyond the hard floors, choose what the task actually needs:

- **Spec-to-Test fires when** the implementation has a meaningful new test surface and existing test conventions don't make the test shape obvious. Pattern-following changes can have the Developer write tests inline; record the call.
- **Verification + Code Review + QA all fire when** the risk surface is broad enough to warrant separate gates. Small Standard tasks may compose them — for example, a single combined-reviewer pass instead of three separate gates. Critical always runs all three separately.
- **Doc Writer fires when** there's user-visible behaviour change. Internal-only changes may not need user docs; technical docs alone may suffice.
- **Researcher fires when** a domain question or prior-art investigation is on the critical path. Don't add for trivial questions.
- **Add specialists not in the templates** when the task warrants — security reviewer, performance specialist, etc. Record additions.

When to ask the user vs. when to dispatch is in `SKILL.md`; the elaboration is here:

Ask the user when intent is genuinely ambiguous and a clarifying question saves a wrong dispatch, when product behaviour is contested or undefined, when the auto-escalation override fires (notify, do not ask permission), when a subagent returns `NEEDS_DECISION` or `HUMAN_DIRECTOR_ESCALATION`, when an INSIGHT lands with impact tier *required change before next similar task*, when a Conversation Mode promote-or-revert deadline arrives, or when a circuit breaker trips (3+ rework on the same root cause; blocker stuck for 2+ follow-ups; >2 scope changes in a milestone).

Dispatch without asking when the request maps unambiguously to a workflow kind with a clear team, the user has already declared the weight and the auto-escalation override has been checked, a previous round-trip has set the context and you are continuing a known workflow, or the task is mechanical (record-keeping, register updates, status persistence).

## Transparency announcement format

At every dispatch, announce the team composition with reasoning **before** the first Task call. Format:

> Team for `{task_id}` ({weight}{, cross-vendor enabled if applicable}): {subagent list with `(vendor:tier)` annotations}. Effort: {per-role effort, highlighting deviations or unsupported application}. {Pairing notes if cross-vendor.} {Reason for the composition.} {Hard floors that applied.} {Non-default ordering, if any.}

`vendor` is `claude`, `codex`, or `deepseek`. `tier` is `low` / `mid` / `high`; effort is normally `low` / `medium` / `high` and is shown separately so existing `(vendor:tier)` consumers remain compatible. Concrete model IDs live in the dispatch log.

Example (single-vendor):

> Team for `M03-T07-DEV` (Standard): lead-architect (claude:high), challenger-architect (claude:high), spec-to-test (claude:mid), developer (claude:mid), verification (claude:mid), code-reviewer (claude:mid), qa (claude:mid). **Effort**: architects=high; remaining roles=medium. **Adding** researcher (domain question about Unity addressables). **Skipping** doc-writer (no user-visible behaviour change; you confirmed at intake on 2026-05-15). **Order**: verification and code-reviewer running in parallel after developer completion.

Example (cross-vendor enabled, Critical milestone — v0.10+ mechanism: Claude-side roles are Task subagents; codex-side roles are codex-bridge skill invocations):

> Team for `M07-T03-DEV` (Critical, cross-vendor enabled): lead-architect (claude:high), codex-bridge[architect] (codex:high, mode=challenge), codex-bridge[spec-to-test] (codex:mid), developer (claude:mid), codex-bridge[verification] (codex:mid), codex-bridge[code-reviewer] (codex:mid), qa (claude:mid), codex-bridge[security-reviewer] (codex:high), doc-writer (claude:mid). **Effort**: architects/developer/reviewer/security=high; remaining roles=medium. **Pairing**: architect Co-Approval (Claude / Codex); test author (Codex) ≠ implementer (Claude); implementer (Claude) ≠ reviewer/verifier/security (Codex). QA and docs single-vendor.

Example (Trivial classification — orchestrator-inline, v0.10.4+):

> Task `M07-T05-TRIV`: Classified **Trivial** — inline edit. Justification: typo fix in user-facing text. `recieve` → `receive` in `internal/profile/email.go` line 42. **No subagent dispatched.** Trivial mode — please verify visually.

The Trivial classification's transparency line has a fixed shape: classification label + verbatim whitelist item + concrete one-line description of the change. The dispatch log entry that follows records `subagent: "orchestrator-inline (trivial)"` and `trivial_justification: "<verbatim>"`. Vague justifications ("simple change", "small refactor") are a workflow violation — escalate to Conversation instead. See `references/trivial-classification.md`.

This single line is the orchestrator's decision audit trail — visible in the transcript, inspectable by probes, available for retrospective review. A team composition that goes silent is a workflow violation regardless of how good the actual choice was.

## Language-guidance injection rationale

The plugin injects language guidance explicitly rather than relying on the project's `AGENTS.md`/`CLAUDE.md` hierarchy because:

- Projects vary in project-instructions layout — flat, hierarchical, monorepo, atypical.
- Subagent-context propagation of project instructions across the Task-tool boundary isn't guaranteed.
- Plugin-shipped baseline plus orchestrator-side injection at dispatch ensures the subagent gets baseline language coverage regardless of project layout.

The project's own `AGENTS.md` or `CLAUDE.md` (root or hierarchical) layers on top via the current client's normal mechanisms, and project-specific guidance authoritatively overrides the plugin's generic content (the language files explicitly say so).

## Tooling preferences (orchestrator detail)

When Basic Memory is available, query it for durable prior decisions, recurring
fixes, and user preferences before classifying weight, picking a team, or making
architectural calls. Persist new durable lessons back through Basic Memory.

For source-code lookup, prefer codegraph for exact graph-shaped questions and
CocoIndex for semantic or fuzzy discovery. LSP is legacy optional. Use
context-mode for derived analysis and large non-source outputs after a code
index has narrowed the target. The canonical hierarchy lives in `tooling.md`;
the same preferences apply to every subagent you dispatch.

## Artifact persistence detail

Maintain a `.code4me/` working dir at the project root containing:

- `milestone-status-tracker.md` — one per active milestone, listing every task and its state
- `insight-register-{milestone_id}.md` — one per active milestone, accumulating INSIGHT messages
- `conversation-notes/` — Conversation Mode notes by task ID
- `milestone-specs/` — Milestone Specs by milestone ID
- `tech-specs/` — Tech Specs by spec ID (Standard and Critical work only)
- additional folders matching the legacy `/artifacts/` layout as workflows are added

Update the tracker on every state change. Persist artifacts before declaring a task complete.

If Basic Memory is configured, save durable decisions and recurring project
lessons there. `.code4me/` remains the local workflow source of truth; Basic
Memory is the cross-session knowledge layer.
