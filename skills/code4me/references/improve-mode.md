# Supervised Improve Mode

`/code4me-improve` is an outer evaluation loop for Code4Me itself. Normal
`/code4me` work may produce evidence, but only improve mode may propose a
candidate change to Code4Me's skills, prompts, routing, hooks, or probe harness.

## Invariants

- Work from a clean temporary Git worktree at the caller repository's exact
  `HEAD`. Never edit the caller's worktree.
- Freeze an immutable manifest before baseline evaluation: baseline commit,
  probe scope, each probe hash, judge backend, provider, model, effort, runner
  hash, and held-out probe identifiers/hashes.
- Run the baseline before proposing a change.
- Present exactly one measurable hypothesis and one bounded candidate change.
- Require explicit user approval before any candidate edit or commit.
- Apply the approved change through normal Code4Me workflow rules in the
  temporary worktree. Existing vendor opt-in gates remain authoritative.
- Make at most one candidate commit, then rerun the exact frozen manifest.
- Keep held-out probes outside the candidate worktree and candidate-author
  context. Do not reveal their expectations or results until after the commit.
- Present raw before/after outcomes, regressions, cost/config differences, and
  the candidate diff. Require explicit `keep` or `revert`.

## Lifecycle

1. Record `baseline_commit=$(git rev-parse HEAD)`. If uncommitted caller changes
   are intended to be part of the experiment, stop and ask the user to commit
   them; never stash or absorb them automatically.
2. Create a detached temporary worktree from that commit with `git worktree add
   --detach <temp-path> <baseline_commit>`. Confirm `git status --porcelain` is
   empty inside it.
3. Require `--held-out-manifest PATH`. Resolve it to an absolute path outside
   the candidate worktree and validate it before baseline execution. Write the
   frozen control manifest and all evidence outside both worktrees.
4. Run public and held-out baselines with the exact commands below. Store all
   results directly in the external evidence directory.
5. Present one hypothesis tied to baseline evidence, the smallest candidate
   change, affected files, and success/regression criteria. Pause for explicit
   approval.
6. On approval, dispatch the normal Code4Me workflow in the temporary worktree.
   The candidate author receives public failures and the approved hypothesis,
   never held-out expectations/results.
7. Create one candidate commit. Confirm the control manifest, runner, public
   probes, held-out manifest, and held-out probes are unchanged, then rerun the
   identical public and held-out scope/config to separate result files.
8. Present before/after results and ask for `keep` or `revert`.

## Held-out manifest

The external manifest uses
`skills/code4me/schemas/held-out-manifest.schema.json`:

```json
{
  "schema_version": 1,
  "probes": [
    {
      "path": "/absolute/controller-only/probes/held-out-01.md",
      "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    }
  ]
}
```

Windows manifests use an absolute drive path such as
`C:/code4me-evidence/held-out-01.md`. The runner rejects relative paths,
unknown fields, unreadable probes, malformed hashes, hash mismatches, manifests
inside the candidate worktree, and held-out output inside that worktree. It
uses `sha256sum`, or `shasum -a 256` where `sha256sum` is unavailable.

Only the improve-mode controller receives the manifest path and executes the
held-out runs. The candidate author receives the public baseline evidence and
approved hypothesis only. Do not place the held-out manifest, probe content,
judge prompt, or pre-commit held-out result in candidate-agent context.

## Exact evaluation commands

Set absolute controller-owned paths before candidate dispatch:

```bash
baseline_commit=$(git rev-parse HEAD)
git worktree add --detach "$candidate_dir" "$baseline_commit"
public_scope=${public_scope:-.}
judge_backend=${judge_backend:-anthropic-api}
judge_model=${judge_model:?resolve and freeze the backend model before baseline}
judge_args=(--judge-backend="$judge_backend" --judge-model="$judge_model")
[ -z "${judge_provider:-}" ] || judge_args+=(--judge-provider="$judge_provider")
[ -z "${judge_effort:-}" ] || judge_args+=(--judge-effort="$judge_effort")

bash "$candidate_dir/bin/code4me-probe-run" \
  "${judge_args[@]}" --no-budget \
  --output "$evidence_dir/public-baseline.jsonl" "$public_scope"
bash "$candidate_dir/bin/code4me-probe-run" \
  "${judge_args[@]}" --no-budget \
  --manifest "$held_out_manifest" \
  --output "$evidence_dir/held-out-baseline.jsonl"
```

Freeze the baseline commit, public scope and hashes, runner hash, resolved judge
backend/provider/model/effort, held-out manifest hash, and held-out probe hashes
in the external control manifest. After explicit approval, the one candidate
change, and the candidate commit, verify those hashes and run:

```bash
bash "$candidate_dir/bin/code4me-probe-run" \
  "${judge_args[@]}" --no-budget \
  --output "$evidence_dir/public-candidate.jsonl" "$public_scope"
bash "$candidate_dir/bin/code4me-probe-run" \
  "${judge_args[@]}" --no-budget \
  --manifest "$held_out_manifest" \
  --output "$evidence_dir/held-out-candidate.jsonl"
```

The four commands, inputs, and judge configuration are fixed before baseline.
`--output` prevents result files from dirtying the candidate worktree. A failed
hash check blocks evaluation; it does not authorize a retry or manifest update.

## Judge backends

`anthropic-api` remains the default and uses `ANTHROPIC_API_KEY`. `claude-p`
uses the interactive Claude subscription wrapper, `codex` uses the signed-in
Codex CLI, and `reasonix` uses its configured DeepSeek provider. The runner
never falls back between them. `--judge-effort` is supported by `claude-p` and
`codex`; Anthropic API and Reasonix reject it rather than silently ignoring it.

Backend defaults are `claude-sonnet-5` for Anthropic API and `claude-p`, and
`gpt-5.6-terra` for Codex. Reasonix defaults to provider `deepseek-pro` mapped
to concrete model `deepseek-v4-pro`; `reasonix doctor --json` must confirm that
identity. Improve mode resolves these defaults before baseline and then passes
the exact backend/provider/model/effort combination to all four evaluation
commands.

## Terminal decisions

- `keep`: preserve the candidate commit on a clearly named branch and remove
  the temporary worktree. Do not merge, push, update baselines, or publish.
- `revert`: remove the temporary worktree and candidate ref; retain the external
  manifest/results report.
- abort, timeout, failed probe, or regression without an explicit `keep`:
  default to cleanup as `revert`, retain evidence, and make no retry.

No automatic iteration, baseline update, merge, retry, vendor enablement,
vendor escalation, or installed-plugin mutation is allowed.

## Suitable use

Use improve mode for repeated, measurable workflow weaknesses: routing drift,
decomposition failures, recurring reviewer misses, or release-time benchmark
evaluation. Do not use it for a single ordinary product bug or when the probe
scope/objective is still changing.
