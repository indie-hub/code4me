# Probes

Probes are small, paste-ready markdown scenarios used to detect regressions in the code4me Producer-orchestrator's behaviour. Each probe is a single request that exercises one decision point — classification (kind + weight), team composition, or the auto-escalation override — and pairs that request with the expected orchestrator response.

They are **not** unit tests. They are diagnostic prompts whose answers a human compares against a recorded baseline. If the orchestrator's transparency announcement diverges from the `Expected` block, something in `SKILL.md`, `references/`, or an agent file has shifted the behaviour and the change should be understood (and either rolled back or absorbed into a new baseline).

## How to use a probe

1. Open a fresh Claude Code session with the code4me plugin enabled. Do not let the session carry context from previous probes or tasks.
2. Copy the `Input prompt` block from the probe file and paste it as the first user message.
3. Read the orchestrator's reply — specifically its **team transparency announcement** (kind, weight, subagent list, auto-escalation note if any).
4. Compare each line of the orchestrator's announcement against the probe's `Expected` block. The probe passes when the kind, weight, auto-escalation status, and announced team match.

## File-naming convention

- Numeric prefix to fix ordering: `01-`, `02-`, ...
- Kebab-case slug describing the scenario: `01-conversation-cosmetic.md`, `07-conversation-touches-auth.md`.
- Lives in one of three subdirectories matching `Subject`: `classification/`, `team-composition/`, `auto-escalation/`.

## When to re-run

Re-run the full probe suite after any change to:

- `skills/code4me/SKILL.md`
- any file under `skills/code4me/references/`
- any subagent definition under `agents/`

A change that does not move probe outputs is safe; a change that moves them needs a fresh baseline and a one-line note about why the new behaviour is correct.

## Baselines

After running a probe suite, the user records the actual orchestrator output in `probes/baseline-{YYYY-MM-DD}.md` (manual approach) or, with the v0.8 programmatic runner, the runner writes results to `probes/results-{stamp}.jsonl` and compares against `probes/baseline.jsonl`. Baselines are personal artefacts of a verification run and are **not** shipped with the plugin distribution — they are gitignored so a downstream consumer of the plugin sees only the probes and their expectations, not a particular run's transcript.

**For the v0.8+ programmatic runner workflow** — when to capture a new baseline, how the runner detects flips, how to tune the regression budget — see `docs/probe-baselines.md`. The short version:

1. Run `bin/code4me-probe-run` — interactive; each probe is pasted into a fresh Claude Code session, the response is captured on stdin, the LLM-as-judge compares against the Expected block, and a `results-{stamp}.jsonl` is written.
2. The runner compares results against `probes/baseline.jsonl` and reports flips (probes whose outcome differs from the baseline). The configurable threshold `max_flips` in `probes/budget.toml` is the budget; exceeded → non-zero exit code.
3. When the framework changes and you've verified the new behaviour is correct, run `bin/code4me-probe-run --update-baseline` to promote the latest results to the new baseline. The flag is skipped if any probe errored (a broken environment can't accidentally become the reference).

Baselines should be re-captured after intentional framework changes, after upgrading the judge model, and at major version bumps. Don't re-baseline to silence an unexpected regression — investigate the flip first.
