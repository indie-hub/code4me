<!--
Thanks for contributing to code4me. Fill out the sections below.
For full conventions, read CONTRIBUTING.md.
-->

## What this PR does

<!-- One paragraph. What changed and why. -->

## Type of change

- [ ] Bug fix (probe-coverable regression)
- [ ] New subagent
- [ ] New bridge / new vendor
- [ ] New PreToolUse hook
- [ ] New probe(s)
- [ ] Documentation
- [ ] Internal refactor (no user-visible behaviour change)
- [ ] Breaking change (major version bump warranted)
- [ ] Other:

## Convention checklist

- [ ] CHANGELOG entry added under the current `-dev` version (`X.Y.Z-dev`)
- [ ] Version in `.claude-plugin/plugin.json` bumped if this is a minor/major change
- [ ] No hardcoded user-specific paths (grep for `/Users/`, `/home/`, `C:/Users/`, personal usernames)
- [ ] No first-person voice in user-facing prose ("my", "I built", etc.)
- [ ] If a subagent file: `context_queries:` frontmatter present and follows the schema
- [ ] If a bridge: STRICT BRIDGE PROTOCOL block included; dispatch gate added to orchestrator SKILL.md
- [ ] If a hook: returns `permissionDecision: ask` (never `deny`); silent pass-through on missing inputs
- [ ] If a probe: explicit Pass criterion + Failure modes sections

## Probe coverage

<!-- Required if this PR changes behaviour. Cite the probe(s) that catch this change or that you added/updated. -->

- [ ] New probe added at `probes/...`
- [ ] Existing probe updated at `probes/...`
- [ ] No probe coverage (justify):

## Verification

<!-- What did you actually run / check? -->

- [ ] `bin/code4me-preflight` passes
- [ ] `bin/code4me-probe-run <changed-subject>` passes locally
- [ ] `bin/code4me-audit-dispatch-log` runs cleanly on a small fixture
- [ ] If a hook changed: `bash -n hooks/<hook>.sh` and a manual smoke test of ask-gate + pass-through
- [ ] If `.claude-plugin/plugin.json` or `hooks/hooks.json` changed: JSON validates
- [ ] If `references/vendor-models.yaml` changed: YAML parses

## Documentation

- [ ] User-facing change reflected in `docs/howto-*.md`
- [ ] User-facing change reflected in README
- [ ] Reference doc updated (if a schema, contract, or canonical artifact changed)
- [ ] None of the above — pure internal change

## Cross-platform

- [ ] Tested on Linux
- [ ] Tested on macOS
- [ ] Tested on Windows (Git Bash or WSL)
- [ ] Not platform-sensitive (pure markdown / YAML / JSON change)

## Breaking changes

<!-- If "Breaking change" is checked above, list them explicitly. -->

- [ ] None
- [ ] Yes — listed below, with migration notes:

## Related issues

<!-- Link any related Issues, Discussions, or other PRs. -->

Closes #
