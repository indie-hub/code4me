# Probe baselines

The v0.8 regression budget (`probes/budget.toml`) compares each probe run's outcomes against a baseline JSONL file. This document covers when to capture a new baseline, how the runner compares against it, and how to interpret flip output.

## What a baseline is

A baseline is a `results-*.jsonl` file (one line per probe with the probe path + outcome) that the runner uses as the comparison point for subsequent runs. By default, `bin/code4me-probe-run` writes results to `probes/results-{stamp}.jsonl` and compares against `probes/baseline.jsonl` (configurable in `probes/budget.toml`).

Use `--output PATH` to write directly to an existing external evidence
directory. Supervised improve mode also uses `--manifest PATH` for its required,
hash-verified held-out probe set; manifest runs require external `--output` and
do not write evidence into the candidate worktree.

Baselines are personal artifacts of a verification run — they reflect the orchestrator's behaviour at a specific commit, with a specific judge model, on a specific machine. They're **gitignored** (the plugin's `.gitignore` excludes `probes/results-*.jsonl` and `probes/baseline.jsonl`) so a downstream consumer of the plugin sees only the probes and their expectations, not a particular run's transcript.

## When to capture a new baseline

Three cases warrant a re-baseline:

### 1. After framework changes that are intentional and verified

You've shipped a cut (a new agent, a SKILL.md edit, a tier-defaults update). After running the full probe suite cleanly, you accept the new behaviour as the reference:

```
bin/code4me-probe-run --update-baseline
```

The runner promotes the current `results-{stamp}.jsonl` to `probes/baseline.jsonl`. **The flag is skipped if any probe errored** — you have to fix errors before re-baselining, so a broken environment can't accidentally become the new reference.

### 2. After upgrading the judge model

The LLM-as-judge call uses the model specified by `--judge-model=...` or `CODE4ME_JUDGE_MODEL` (default `claude-sonnet-5`). When you upgrade the judge — switching to a newer Sonnet, switching to Opus for higher fidelity — the judge's interpretation of "match" can shift even when nothing about the framework has changed.

Re-baseline after the upgrade. Note in your run log that the baseline shift is judge-driven, not framework-driven.

### 3. After a major version bump

When you bump `plugin.json` from `0.X.Y` to `0.(X+1).0-dev`, the baseline likely needs updating because the framework's expected behaviour has changed (new probes added, existing probes updated). The version bump is the natural moment to capture a new reference.

## When NOT to re-baseline

- **When the budget tripped on a regression you didn't intend.** The flip is the signal; don't silence it by re-baselining. Investigate first, fix, then re-baseline once the behaviour matches your intent.
- **When the framework is broken.** A baseline taken against a broken framework just shifts the broken behaviour into the reference. Fix the framework before re-baselining.
- **Per run, "just to clear the diff."** The whole point of the baseline is to catch drift over time; re-baselining every run defeats the purpose.

## How flip detection works

After the main probe loop, the runner reads the baseline JSONL and the current results JSONL. For each probe in the current results:

1. Look up the matching baseline entry by `probe` field (the probe's path).
2. If no baseline entry exists, it's a **new probe** (printed as `+ (new) <path> → <outcome>`). New probes are not flips.
3. If the baseline outcome matches the current outcome, no flip.
4. If they differ, it's a flip (printed as `~ <path>: <baseline> → <current>`).

Skips and errors are handled per `budget.toml`:

- `count_skips = false` (default) — probes whose current outcome is `skip` don't count as flips
- `count_errors = false` (default) — probes whose current outcome is `error` don't count as flips

Set either to `true` if you want the budget to penalise skipped/errored runs.

## Reading the output

A clean run inside budget:

```
Flip check (baseline: /path/to/probes/baseline.jsonl):
  Flips: 1 (budget: 3)
  ~ probes/classification/05-bug-fix-reproduce-first.md: pass → partial
  Within budget.
```

A run that exceeds the budget:

```
Flip check (baseline: /path/to/probes/baseline.jsonl):
  Flips: 5 (budget: 3)
  ~ probes/classification/05-bug-fix-reproduce-first.md: pass → fail
  ~ probes/team-composition/04-architecture-introducing.md: pass → partial
  ~ probes/auto-escalation/07-conversation-touches-auth.md: pass → fail
  ~ probes/cross-vendor/01-pairing-fires-on-standard.md: pass → partial
  ~ probes/cross-vendor/03-pairing-degrades-when-shim-missing.md: pass → fail

  BUDGET EXCEEDED: 5 flips > 3 allowed
```

The runner exits non-zero when the budget is exceeded; CI can use that for halt-and-look gating.

## Tuning the budget

`probes/budget.toml`'s `max_flips` is project-specific. The Husain-style rule applies:

- **Always 0 flips:** the budget is too generous. Tighten until it occasionally trips on noise.
- **Trips every run:** the budget is too tight, or the framework is genuinely unstable. Investigate (read the flip details), and only widen the budget once the cause is understood.
- **Trips on real changes:** the budget is in the sweet spot. The flag is the signal to read the flipped probes carefully — either you intended the behaviour change (re-baseline) or you didn't (fix).

The default `max_flips = 3` is calibrated for a moderately-sized suite (~30 probes) with LLM-as-judge variance. Adjust for your suite size and judge model.

## Putting it together

Recommended workflow:

1. **Make a framework change.** Edit SKILL.md, add a probe, update a YAML, whatever.
2. **Run the probe suite.** `/code4me-probe-run` (or `bin/code4me-probe-run` directly).
3. **Read the flip detail.** If flips ≤ budget, look at the flipped probes anyway — a flip within budget is still a flip and might be unintended.
4. **Decide.** For each flip: was the change intentional and the new behaviour correct?
   - If yes: re-baseline with `--update-baseline` after the run completes cleanly.
   - If no: fix the framework, re-run the suite (no re-baseline), confirm the flip is gone.
5. **Commit.** Framework changes go in commits; baselines do not (they're gitignored).
6. **Next session:** the new baseline is the comparison point for subsequent runs.

This is the eval discipline operationalised: the probes catch decision-level regressions; the budget absorbs LLM variance; the re-baseline workflow makes intentional drift explicit.

## CI integration

The runner's non-zero exit on `fail_count > 0` or `error_count > 0` or `budget_failed` makes it CI-integratable. A minimal CI step:

```yaml
- name: Run code4me probe suite
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    bash <PLUGIN_DIR>/bin/code4me-probe-run --no-budget
```

The `--no-budget` flag in CI is deliberate — CI is non-interactive and can't paste orchestrator responses, so the probe runner will skip every probe (each requires user input). To run probes in CI, you'd need either headless Claude Code invocations (which the runner doesn't currently do) or a recorded-response file feature (planned for v0.9.1+).

For now, the probe suite is a manual ritual the developer runs after framework changes — the runner automates the LLM-as-judge step and the regression-budget check, but the probe execution itself stays interactive.
