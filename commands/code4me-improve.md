---
description: Run one supervised Code4Me improvement experiment against a frozen probe scope. Uses a clean temporary worktree, baseline-first evaluation, one approved candidate change, an identical rerun, and an explicit keep/revert decision.
argument-hint: --held-out-manifest PATH [--judge-backend=NAME] [--judge-provider=NAME] [--judge-model=MODEL] [--judge-effort=LEVEL] [public probe scope]
---

Load the `code4me` skill and
`skills/code4me/references/improve-mode.md`, then run exactly one supervised
improvement cycle for `$ARGUMENTS`. Reject the command unless it contains
`--held-out-manifest PATH`. Accept optional `--judge-backend`,
`--judge-provider`, `--judge-model`, and `--judge-effort` flags; the remaining
optional argument selects the public probe scope, defaulting to all public
probes. `--judge-provider` is valid only for Reasonix.

Required procedure:

1. Capture exact `HEAD`; create and verify a clean detached temporary Git
   worktree. Never edit the caller's worktree or include its uncommitted state.
2. Validate the held-out manifest against
   `skills/code4me/schemas/held-out-manifest.schema.json`. It must be outside
   the candidate worktree and contain absolute probe paths plus SHA-256 hashes.
   Resolve and freeze the public scope/hashes, runner hash, baseline commit,
   judge backend/provider/model/effort, and held-out manifest hash in external
   evidence.
3. Run public and held-out baselines with the same explicit judge backend,
   provider, model, and effort arguments. Run held-out probes with `--manifest PATH`.
   Both result paths must be in the external evidence directory. Never fall
   back to another judge backend.
4. Present exactly one evidence-backed hypothesis and smallest candidate
   change. Ask for explicit approval. Do not edit before approval.
5. After approval, apply the candidate through normal Code4Me workflow rules in
   the temporary worktree. Vendor bridges remain off unless already explicitly
   opted in. Make one candidate commit.
6. Verify the frozen hashes and rerun the identical public and held-out
   commands to new external result paths. The controller runs held-out probes;
   their manifest, expectations, and results are not available to the candidate
   author until after the candidate commit.
7. Present baseline vs candidate results, regressions, candidate diff/commit,
   and evidence path. Require explicit `keep` or `revert`.

Abort, failure, regression, or no explicit decision defaults to cleanup/revert
while retaining external evidence. Never iterate, retry, update a baseline,
merge, push, enable a vendor, escalate vendors, or mutate the installed plugin
automatically.

Arguments:

$ARGUMENTS
