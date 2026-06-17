# Trace review discipline

Hamel Husain's highest-ROI evals advice is "spend 30 minutes reading 20–50 traces every meaningful change." This document operationalises that practice for code4me — what to look for, when to do it, and how to use the v0.8 audit-tool output to find traces worth reading.

## When to do a trace review

- **After any framework change.** A SKILL.md edit, a new agent, a probe baseline update — read traces of the next 5-10 dispatches and confirm the orchestrator's behaviour matches your intent.
- **After 10-20 real milestones.** Even when nothing's changed, the dispatch log accumulates patterns. Read traces from a recent week's worth of work to surface tier-deviation patterns, persistent breaker firings, or pairing degradations that haven't tripped a threshold but are trending.
- **When a milestone goes wrong.** Failed verification, unexpected scope-expansion, a circuit-breaker firing — read the trace from the start, not just the failure point. The signal is usually upstream of where the visible problem surfaced.
- **Before bumping to 1.0.** The framework's first major version warrants a deliberate trace-review pass to confirm the empirical record matches the structural intent.

## What to look for

### Tier 1 — required, every review

1. **Transparency announcement matches the dispatched team.** Open the milestone's first dispatch in the log; cross-reference with the orchestrator's announced team. Mismatches mean either the announcement is stale or the orchestrator dispatched off-script. Both are framework bugs.
2. **Return outcomes are typed correctly.** Every dispatch's `outcome` should be one of the enum values for that subagent. Untyped or paraphrased outcomes mean the subagent didn't follow its contract — surface as an INSIGHT or a probe addition.
3. **Hook gates map to expected typed outcomes.** When a hook fires (visible in the transcript), the developer's return should map to `TEST_QUESTION` / `FORBIDDEN_CONDITION_ENCOUNTERED` / `OUT_OF_SCOPE_TARGET` per the hook. A `BLOCKED` outcome with a vague blocker is the bug.
4. **Context Pack provenance** (`context_provenance` field, v0.8+) shows the expected artifacts. For a Standard dispatch, you should see the Tech Spec, the Test Spec, the relevant cerebrum sections (if OpenWolf), and the language guidance for affected file types. Missing items mean a `context_queries:` block isn't resolving what it should.

### Tier 2 — when the milestone surprised you

5. **Tier-deviation rationale.** When `tier_deviated_from_default: true`, check whether the deviation was a one-off (complexity surprise) or persistent (the default for that (subagent, weight) combo is wrong). The audit tool's "Tier deviation (v0.7+)" section auto-surfaces >50% rates; below that threshold, eyeball the pattern.
6. **Pairing degradation reasons.** `vendor_pairing.degraded` values (`shim_unavailable`, `user_override`, etc.) tell you whether the alternation rule fired cleanly or had to fall back. Persistent `shim_unavailable` means the user enabled cross-vendor but didn't complete the Codex setup; the dispatches are running same-vendor by default, defeating the opt-in.
7. **Auto-escalation triggers vs. user's declared weight.** When `escalation_trigger` is non-null, the user declared a lower weight than the work warranted. Repeated escalations of the same kind mean the user is consistently underestimating — either improve the auto-escalation symptom list or train the user.
8. **Spec Kit interop** (`spec_kit_interop: true`, v0.9+). Confirms when Spec Kit inputs were consumed. Compare against the actual `specs/<feature>/spec.md` content; mismatches mean the orchestrator picked up a stale spec.

### Tier 3 — periodically, every few months

9. **Slowest dispatches.** Sort the dispatch log by elapsed time per dispatch (if you've added that field; v0.8's default schema doesn't include it — consider adding for v0.9.1). Persistent slow dispatches at a specific (subagent, weight) combo mean the prompt has bloated or the tier is too low.
10. **INSIGHT register volume per milestone.** Look at `.code4me/insight-register-*.md` files. A milestone with > ~5 INSIGHTs is either covering genuinely novel ground (good) or being noisy (bad — likely means a recurring observation isn't being absorbed into the framework).
11. **Circuit-breaker firings.** Rework Limit, Blocker Dwell, Scope Change. The Milestone Status Tracker records these. Patterns of repeated firings across milestones for the same kind of issue are signal that the limits need tuning, the workflow weight is wrong, or the underlying domain has a structural problem the framework hasn't named yet.

## How to find traces worth reading

The audit tool (`/code4me-audit` or `bin/code4me-audit-dispatch-log`) is the entry point. Run it after a milestone closes:

```
/code4me-audit
```

Look for:

- **Outliers in the "Outcome distribution" table.** A spike of `REWORK` or `FAIL` outcomes for one (subagent, weight) combo is the first trace to read.
- **The "Tier deviation (v0.7+)" pattern-detection table.** Any combo listed there is a candidate for a default-tier update — read 2-3 traces to confirm before changing the YAML.
- **The "Cross-vendor pairing (v0.7+)" section's degradation list.** Persistent reasons mean a setup gap; one-off reasons mean the user changed their mind mid-milestone (rare).
- **The "Weight × outcome" heatmap.** Cells with FAIL/REWORK clusters at a specific weight mean the gates need tuning OR the weight is being mis-classified at intake.

Then `jq` the log directly for the specific dispatches you want to read:

```bash
# Most recent FAIL on verification
jq -c 'select(.subagent == "verification" and .outcome == "FAIL")' .code4me/dispatch-log.jsonl | tail -1

# All dispatches in milestone M07 with their tier deviations
jq -c 'select(.milestone == "M07")' .code4me/dispatch-log.jsonl

# Dispatches that hit a circuit breaker
jq -c 'select(.escalation_trigger != null)' .code4me/dispatch-log.jsonl
```

Each line of output is a trace to read — open the corresponding session transcript, walk through the dispatch, verify against the Tier 1 / Tier 2 / Tier 3 checklist.

## How long this actually takes

Husain's 30-minute number is realistic if you're reading active milestones. For traces from a week's worth of work, plan on:

- 5 minutes running the audit tool and identifying which traces matter
- 20 minutes reading 5-10 specific dispatches (the ones the audit tool flagged)
- 5 minutes writing up observations as INSIGHTs (for cerebrum or the insight register) or as proposed changes to the framework

The biggest mistake is reading every trace in the log — that's hours, low signal. Read the ones the audit tool flagged.

## What to do with what you find

Three outputs:

1. **Cerebrum updates** (if OpenWolf is configured). When a pattern is a project-specific preference ("we prefer the table-driven pattern for these tests"; "this module's auth flow is non-obvious"), record it in `.wolf/cerebrum.md` so the next dispatch picks it up.
2. **INSIGHT register entries.** For workflow-level observations ("Spec-to-Test consistently under-specifies failure paths for AC #X"), append to the milestone's insight-register file with `impact_tier: suggested change` or `required change before next similar task`.
3. **Framework changes.** When a pattern is the framework itself ("Architects deviate to high on Critical 90% of the time → bump the default tier in model-selection.yaml"), the trace-review surfaces it; the change goes in a new cut.

The audit tool helps you find the traces. The trace-review is where you decide what's worth changing.

## Anti-patterns to avoid

- **Reading traces with no question in mind.** Trace review is investigative, not exploratory. Start with the audit tool's signals; don't browse.
- **Reading too many traces.** 50 is Husain's upper bound for a reason — past that you're scanning, not reading. Pick 5-15 carefully and read them fully.
- **Treating every observation as actionable.** Many traces will look reasonable. The point of the discipline is to surface the actually-wrong ones, not to find something to change in every one.
- **Skipping when nothing's broken.** The highest-leverage trace review is the one before things break — patterns surface earliest there. If you wait until a milestone explicitly fails, you've already eaten the cost.

## Integration with the rest of v0.8 observability

Trace review composes with:

- **The regression budget** (`probes/budget.toml`) — probe-level signal that the framework's *decisions* haven't drifted.
- **The audit tool** — milestone-level signal that the framework's *executions* are healthy.
- **The dispatch-log JSONL** — primary source for any specific trace.
- **The provenance field** — answers "what did the dispatch see?" without re-running the workflow.

Together, these are the framework's eval discipline. The probes catch decision-level regressions; the audit catches execution patterns; the trace review catches the things neither of those can automate.
