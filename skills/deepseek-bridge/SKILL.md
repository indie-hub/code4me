---
name: deepseek-bridge
description: Direct bridge from the orchestrator thread to Reasonix for opt-in DeepSeek architect, developer, code-reviewer, spec-to-test, security-reviewer, verification, and lead-architect roles. Verifies configured provider aliases, invokes reasonix run, validates the structured return, and preserves Code4Me vendor gates.
---

# DeepSeek Bridge

Invoke this skill only when the user named a DeepSeek role or explicitly enabled
cross-vendor pairing with DeepSeek in the vendor set. Never infer DeepSeek from
task shape, cost, or perceived benefit.

## Pre-flight and provider verification

Run:

```bash
command -v reasonix
reasonix doctor --json
```

Treat `reasonix doctor --json` as sensitive configuration output. Inspect only
the provider alias and concrete model; redact credentials, tokens, endpoints,
headers, and unrelated configuration from logs and user-visible output.

Resolve Code4Me's concrete model and provider alias from the merged vendor
configuration. Start with
`skills/code4me/references/vendor-models.yaml`; merge matching top-level vendor
tier and `reasonix_aliases` keys from `.code4me/vendor-models.local.yaml`, with
project-local values winning.

Built-in aliases are:

| Code4Me model | Required Reasonix alias |
|---|---|
| `deepseek-v4-flash` | `deepseek-flash` |
| `deepseek-v4-pro` | `deepseek-pro` |

For a concrete model not listed in `reasonix_aliases`, try a provider alias equal to the concrete model ID. This supports project-specific Reasonix
configuration without inventing a global alias. In every case, the redacted
doctor output must show that the selected alias exists and resolves exactly to
the selected concrete model. Otherwise return one of:

- `reasonix_cli_not_installed`
- `reasonix_provider_alias_missing`
- `reasonix_provider_model_mismatch`

Do not silently use another alias, provider, vendor, or model. Authentication
remains Reasonix's responsibility; invocation failures return
`deepseek_subprocess_error` with a redacted stderr tail.

## Invocation flow

1. Load `references/{role}.md` for `architect`, `developer`, `code-reviewer`,
   `spec-to-test`, `security-reviewer`, `verification`, or `lead-architect`.
2. Assemble the role prompt and write it to
   `/tmp/deepseek-{slug}-{task_id}.txt`.
3. Invoke Reasonix with the verified provider alias:

   ```bash
   reasonix run --model {reasonix_provider_alias} \
     "$(cat /tmp/deepseek-{slug}-{task_id}.txt)" \
     > /tmp/deepseek-{slug}-{task_id}.out \
     2> /tmp/deepseek-{slug}-{task_id}.err
   ```

   Apply the role time limit through the Bash/tool process timeout, not GNU
   `timeout`. Current Reasonix supports neither `--effort` nor `--transcript`;
   never pass those flags.
4. Extract and JSON-parse the final fenced `json` block from stdout, then apply
   the role reference's schema validation.
5. Run `bin/code4me-bridge-diff-scan.sh` with `--vendor deepseek` and the
   role-appropriate read-only/read-write mode. Its typed blockers override a
   claimed successful return.
6. Consume the validated result inline and append the dispatch log entry.

## Model and effort

Resolve `model_tier` and requested `effort` independently through
`skills/code4me/references/model-selection.yaml`, then resolve the DeepSeek
model and `reasonix_aliases` through the merged baseline/project-local vendor
configuration. Unlisted custom models use the concrete model ID as the
candidate alias, subject to the same doctor verification.

Reasonix cannot currently apply Code4Me's effort setting. Preserve it as honest
routing metadata:

```json
{
  "vendor": "deepseek",
  "model_tier": "mid",
  "model": "deepseek-v4-pro",
  "effort": "high",
  "default_effort": "medium",
  "effort_deviated_from_default": true,
  "effort_source": "explicit_deviation",
  "effort_applied": false,
  "reasonix_provider_alias": "deepseek-pro"
}
```

Effort metadata must not trigger a vendor or model change. Do not claim that
DeepSeek inference used the requested effort.

### Migration from the former `[1m]` value

`deepseek-v4-pro[1m]` was a synthetic model identifier and is not translated.
Remove it from project-local overrides and use `deepseek-v4-pro`. If a Reasonix
provider exposes a different real long-context model, set that concrete model
in the desired DeepSeek tier and add its exact alias under
`reasonix_aliases`. The bridge still blocks unless doctor confirms the alias
resolves to that concrete model.

## Failure modes

The bridge never retries or escalates vendors automatically:

- `reasonix_cli_not_installed`
- `reasonix_provider_alias_missing`
- `reasonix_provider_model_mismatch`
- `deepseek_timeout` when the host process limit expires
- `deepseek_subprocess_error` for non-zero invocation exit
- `deepseek_response_invalid` for missing/invalid structured output
- `deepseek_api_error` for a surfaced DeepSeek API failure

Role-specific validation blockers remain identical to Codex bridge equivalents.
Missing Reasonix or provider configuration blocks an explicitly requested
DeepSeek role; cross-vendor fallback follows only the existing opt-in policy.

## Dispatch log

Record the normal Code4Me fields plus independent effort fields,
`reasonix_provider_alias`, and layer-C status. There is no `transcript_path`
because current Reasonix has no transcript flag. Mixed historical logs remain
valid input to `bin/code4me-audit-dispatch-log`.

## References

- `references/architect.md`
- `references/developer.md`
- `references/code-reviewer.md`
- `references/spec-to-test.md`
- `references/security-reviewer.md`
- `references/verification.md`
- `references/lead-architect.md`
