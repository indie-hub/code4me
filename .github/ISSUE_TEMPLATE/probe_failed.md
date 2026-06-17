---
name: Probe failed
about: A documented probe stopped passing (regression report)
title: "[probe] "
labels: bug, probe-regression
assignees: ""
---

## Failing probe

<!-- Path to the probe file, e.g., probes/classification/10-trivial-vs-conversation.md scenario 3 -->

`probes/.../...md`

<!-- If the probe has multiple scenarios, specify which one failed: -->

Scenario: `...`

## Last known passing version

<!-- The most recent version where this probe passed. Check CHANGELOG history or `bin/code4me-probe-run` output from prior runs. -->

`v0.X.Y`

## Current version

<!-- Where the regression is observed. -->

`v0.X.Y-dev` (commit `<sha>` if you're on a branch)

## Observed orchestrator behaviour

<!-- Paste the transparency announcement and tool calls from the failing run. Highlight the discrepancy against the probe's "Expected" section. -->

```

```

## Expected per the probe

<!-- Either quote the probe's expected behaviour, or describe the divergence. -->

## Suspected change that introduced the regression

<!-- Optional. If you ran `git bisect` or have a hunch about which recent change broke things, name it. -->

## Environment

- **OS**: macOS / Linux / Windows
- **Plugin version**: `0.X.Y-dev`
- **Claude Code version**: 
- **Vendor used in the failing run**: anthropic / openai / deepseek
- **Model tier resolved**: low / mid / high (from the dispatch log)

## Dispatch log (relevant excerpt)

```jsonl

```

## Reproduction steps

1. Run `bin/code4me-probe-run <probe-path>` (or describe the manual session that triggered it)
2. Compare against the probe's "Pass criterion"
3. The divergence is at: ...

## Audit-tool output (if applicable)

<!-- If the regression involves dispatch-log surveillance, paste the relevant section from /code4me-audit. -->

```

```

## Severity

- [ ] Cosmetic — output differs but functionality is fine
- [ ] Confusing — behaviour matches one valid interpretation but probe expected another; the probe may need updating, not the code
- [ ] Functional — actual orchestrator behaviour is wrong; needs code fix
- [ ] Blocker — affects core dispatch flow; should be top-of-queue
