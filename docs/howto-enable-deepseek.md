# How to enable DeepSeek bridging

The `deepseek-bridge` skill runs the same seven bridge roles through Reasonix.
DeepSeek is opt-in: name a DeepSeek role, or explicitly include DeepSeek in a
cross-vendor milestone.

## Setup

1. Install Reasonix: `npm install -g reasonix`.
2. Authenticate through `DEEPSEEK_API_KEY` or Reasonix configuration.
3. Configure and verify these built-in provider aliases with
   `reasonix doctor --json`:

| Code4Me model | Reasonix alias |
|---|---|
| `deepseek-v4-flash` | `deepseek-flash` |
| `deepseek-v4-pro` | `deepseek-pro` |

Doctor output may contain sensitive configuration. Log only the alias and
resolved model; redact credentials, headers, endpoints, and unrelated settings.

Missing aliases return `reasonix_provider_alias_missing`. An alias resolving to
the wrong model returns `reasonix_provider_model_mismatch`. The bridge never
silently substitutes another alias, model, or vendor.

Project-local `.code4me/vendor-models.local.yaml` files may override DeepSeek
tiers and add or override `reasonix_aliases`; local keys win over the plugin
baseline. For an unlisted custom model, the bridge tries a provider alias equal
to the concrete model ID. It still dispatches only when redacted doctor output
confirms that alias resolves exactly to the concrete model.

Example:

```yaml
deepseek:
  high: my-deepseek-model
reasonix_aliases:
  my-deepseek-model: team-deepseek-high
```

## Models and effort

| Profile | Model | Reasonix alias |
|---|---|---|
| `low` | `deepseek-v4-flash` | `deepseek-flash` |
| `mid` | `deepseek-v4-pro` | `deepseek-pro` |
| `high` | `deepseek-v4-pro` | `deepseek-pro` |

Code4Me still selects and logs requested effort independently. Current Reasonix
cannot apply it: the bridge passes neither `--effort` nor `--transcript`, and
records `effort_applied: false`.

```bash
reasonix run --model deepseek-pro \
  "$(cat /tmp/deepseek-dev-T01.txt)"
```

Apply time limits through the host tool/process timeout, not GNU `timeout`.

### Migrating the former `[1m]` override

`deepseek-v4-pro[1m]` was not a valid concrete model identifier. Replace it
with `deepseek-v4-pro`. For another real long-context model, configure its exact
concrete ID in the DeepSeek tier and its verified Reasonix alias under
`reasonix_aliases`; no `[1m]` value is translated automatically.

## Usage and failure behavior

Use a single role by naming it at intake, or enable milestone-wide pairing and
include DeepSeek in the vendor set. Existing vendor gates remain authoritative.

- Missing CLI: `reasonix_cli_not_installed`.
- Missing/mismatched provider: typed blockers above.
- Host process limit: `deepseek_timeout`.
- Non-zero invocation: `deepseek_subprocess_error` with redacted detail.
- Invalid structured result: `deepseek_response_invalid`.

The bridge performs the same post-invocation diff scan as Codex. It never
retries, enables another vendor, or claims unsupported effort was applied.
