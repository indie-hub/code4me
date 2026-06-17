# Probe: Bridge post-validation diff scan (Layer C) catches protected-test edits

**Subject:** cross-vendor / bridge protection
**Coverage:** Verifies `bin/code4me-bridge-diff-scan.sh` correctly identifies violations from a hypothetical codex/reasonix subprocess that modified files it shouldn't have. The helper is what `codex-bridge` and `deepseek-bridge` call after `codex exec` / `reasonix run` returns; this probe exercises it directly without spinning up a real bridge dispatch.

## Setup note

Directly executable via bash. No Claude session required. The probe sets up a synthetic project, fabricates protected-tests / critical-allowlist / forbidden-conditions files, modifies tracked or untracked files to simulate subprocess behavior, runs the helper, and asserts on the JSON output.

## Programmatic verification

Run all six scenarios. All six must print `PASS`. The probe also confirms graceful degradation when git is unavailable (Scenario 6).

```bash
PLUGIN_ROOT=<path-to-code4me-plugin>
WORKDIR=$(mktemp -d)
cd "$WORKDIR"
git init -q
git config user.email t@t.t
git config user.name t
mkdir -p tests/protected src .code4me
echo "tests/protected/**" > .code4me/protected-tests.txt
echo "src/**"             > .code4me/critical-allowlist.txt
echo '{"forbidden_globs":["tests/**/*new_test*"]}' > .code4me/forbidden-conditions.json
echo "original" > tests/protected/auth_test.cs
echo "original" > src/foo.cs
git add -A && git commit -qm initial
```

### Scenario 1 — clean working tree → ok

```bash
OUT=$(bash "$PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh" \
  --project-dir "$WORKDIR" --weight standard --mode read-write --vendor codex)
[ "$(echo "$OUT" | jq -r .ok)" = "true" ] \
  && [ "$(echo "$OUT" | jq -r '.violations | length')" = "0" ] \
  && echo "PASS 1" || echo "FAIL 1"
```

### Scenario 2 — protected test modified → test_protection_violation

```bash
echo "modified" >> tests/protected/auth_test.cs
OUT=$(bash "$PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh" \
  --project-dir "$WORKDIR" --weight standard --mode read-write --vendor codex)
[ "$(echo "$OUT" | jq -r .ok)" = "false" ] \
  && [ "$(echo "$OUT" | jq -r '.violations[0].type')" = "test_protection_violation" ] \
  && echo "PASS 2" || echo "FAIL 2"
git checkout -- tests/protected/auth_test.cs
```

### Scenario 3 — Critical mode, file outside allowlist → out_of_scope_target

```bash
mkdir -p docs && echo "doc" > docs/api.md
OUT=$(bash "$PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh" \
  --project-dir "$WORKDIR" --weight critical --mode read-write --vendor deepseek)
[ "$(echo "$OUT" | jq -r .ok)" = "false" ] \
  && echo "$OUT" | jq -e '.violations | map(select(.type == "out_of_scope_target")) | length >= 1' >/dev/null \
  && echo "PASS 3" || echo "FAIL 3"
rm -rf docs
```

### Scenario 4 — Conversation mode, forbidden new test file → forbidden_condition_violation

```bash
echo "new" > tests/foo_new_test.cs
OUT=$(bash "$PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh" \
  --project-dir "$WORKDIR" --weight conversation --mode read-write --vendor codex)
[ "$(echo "$OUT" | jq -r .ok)" = "false" ] \
  && [ "$(echo "$OUT" | jq -r '.violations[0].type')" = "forbidden_condition_violation" ] \
  && echo "PASS 4" || echo "FAIL 4"
rm -f tests/foo_new_test.cs
```

### Scenario 5 — read-only role modified a file → unexpected_modification

```bash
echo "modified" >> src/foo.cs
OUT=$(bash "$PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh" \
  --project-dir "$WORKDIR" --weight standard --mode read-only --vendor codex)
[ "$(echo "$OUT" | jq -r .ok)" = "false" ] \
  && [ "$(echo "$OUT" | jq -r '.violations[0].type')" = "unexpected_modification" ] \
  && echo "PASS 5" || echo "FAIL 5"
git checkout -- src/foo.cs
```

### Scenario 6 — not a git repo → skipped: true, no false-positive violations

```bash
NONREPO=$(mktemp -d)
OUT=$(bash "$PLUGIN_ROOT/bin/code4me-bridge-diff-scan.sh" \
  --project-dir "$NONREPO" --weight standard --mode read-write --vendor codex)
[ "$(echo "$OUT" | jq -r .skipped)" = "true" ] \
  && [ "$(echo "$OUT" | jq -r .ok)" = "true" ] \
  && echo "PASS 6" || echo "FAIL 6"
rm -rf "$NONREPO"
```

### Cleanup

```bash
rm -rf "$WORKDIR"
```

## Expected

Six `PASS` lines printed in order. No `FAIL` lines.

## Pass criterion

Six `PASS` lines and no `FAIL` lines.

## Failure modes this catches

- **Glob matching regresses.** A future refactor of the regex polyfill in `bin/code4me-bridge-diff-scan.sh` breaks `**/` zero-or-more handling; Scenario 4 (which uses `tests/**/*new_test*` against a file at depth 1) catches this. This is exactly the bug found during the v0.13.0-dev Layer C implementation — the file deliberately exercises the case bash's native `[[ == ]]` glob mis-handles.
- **`.code4me/` files leak into the scan.** The helper excludes paths starting with `.code4me/` (bridge bookkeeping is expected to change). If that exclusion is removed, every dispatch produces spurious `unexpected_modification` violations.
- **Critical-mode allowlist disabled for non-Critical weights.** The allowlist check only fires when `--weight critical`. If a future refactor accidentally applies it to all weights, Scenario 3's pattern would also trip Scenarios 1 / 2 / 4 / 5 (which use non-critical weights).
- **Forbidden-conditions check applied to existing files.** The check fires only on NEW (untracked) files matching the forbidden globs. Modifying an existing file matching the glob should NOT fire (the existing-file edit is governed by protected-tests / allowlist, not forbidden-conditions). If a refactor removes the new-file gate, Scenario 2 might double-fire.
- **Graceful skip on no-git.** Scenario 6 confirms the helper degrades to `ok: true, skipped: true` rather than crashing or returning `ok: false` — this is the contract the bridges rely on.

## Why this lives in `probes/cross-vendor/`

Same category as probes 01-08 — verifies cross-vendor pairing behaviors. The helper is shared between `codex-bridge` and `deepseek-bridge`; the probe exercises the helper directly so any regression in the shared logic is caught regardless of which vendor's bridge surfaces it.

## Relationship to Layer A / Layer B

This probe covers **Layer C** only (post-validation diff scan). Layers A (Claude-side PreToolUse hooks) and B (codex/reasonix native PreToolUse hooks) have their own probes:

- Layer A: `probes/hooks/01-test-protection-hook-fires.md`, `02-forbidden-conditions-...`, `03-critical-write-allowlist-...`
- Layer B: not yet ear-tagged with a probe; will land when Layer B does (per `docs/roadmap.md` §"Vendor-side hooks").

Together the three layers form defense-in-depth across vendors.
