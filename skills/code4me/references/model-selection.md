# Model and Effort Selection

The orchestrator makes two independent dispatch decisions:

1. `model_tier` selects a vendor-neutral model profile (`low`, `mid`, `high`).
2. `effort` selects reasoning depth (`low`, `medium`, `high`).

`model-selection.yaml` is authoritative for both defaults and rules.
`vendor-models.yaml` resolves `(vendor, model_tier)` to a concrete model. Project
overrides in `.code4me/vendor-models.local.yaml` still win over the baseline,
including project-local `reasonix_aliases` entries for DeepSeek models.

## Current model profiles

| Profile | Anthropic | OpenAI | DeepSeek |
|---|---|---|---|
| `low` | `claude-haiku-4-5` | `gpt-5.6-luna` | `deepseek-v4-flash` |
| `mid` | `claude-sonnet-5` | `gpt-5.6-terra` | `deepseek-v4-pro` |
| `high` | `claude-opus-4-8` | `gpt-5.6-sol` | `deepseek-v4-pro` |

Anthropic also exposes `frontier: claude-fable-5`. It is explicit-only: no
role or workflow weight selects it automatically.

The profile is a capability/cost default, not an effort alias. A dispatch may
use `model_tier: mid` with `effort: high` without changing the concrete model.

## Effort

Automatic effort values are `low`, `medium`, and `high`:

- `low`: narrow, mechanical, well-specified, cheaply verified work.
- `medium`: normal default; some judgment or multiple files involved.
- `high`: ambiguous, architectural, security-sensitive, cross-cutting,
  expensive to reverse, or following a poor attempt.

`xhigh` and `max` are allowed only as explicit deviations when the selected
backend supports them. Never claim an effort was applied when the backend
cannot apply it.

For legacy callers that omit effort, derive it from the model profile:
`low -> low`, `mid -> medium`, `high -> high`, and record
`effort_source: legacy_tier_fallback`.

## Choosing and deviating

Start with the role/weight defaults in `model-selection.yaml`, then use bounded
discretion:

- Change effort for ambiguity, novelty, blast radius, reversibility,
  verification difficulty, or a failed attempt.
- Change model profile when capability, context capacity, tool support, or a
  user cost preference requires it.
- After a poor result, raise effort first. Change model only when capability
  appears to be the problem.
- Vendor participation remains opt-in. Model/effort flexibility never enables
  Codex, DeepSeek, cross-vendor pairing, or Claude wrapper participation.
- Architect roles never use the `low` model profile. Critical work never uses
  the `low` model profile. Architecture, security-sensitive, and Critical
  load-bearing decisions never use `low` effort.

Every dispatch records both decisions and one-line reasons when either differs
from its default.

## Dispatch and transparency

The compact team announcement keeps the backward-compatible `(vendor:tier)`
tag and adds an effort summary:

> Team for `M03-T07-DEV` (Standard): `developer (claude:mid)`, `verification (claude:mid)`. Effort: developer=high (default medium); verification=medium.

The dispatch log records concrete details:

```json
{
  "model_tier": "mid",
  "default_tier": "mid",
  "tier_deviated_from_default": false,
  "model": "gpt-5.6-terra",
  "effort": "high",
  "default_effort": "medium",
  "effort_deviated_from_default": true,
  "effort_source": "explicit_deviation",
  "effort_applied": true
}
```

`effort_source` is `default`, `explicit_deviation`, or
`legacy_tier_fallback`. `effort_applied` states whether the backend actually
received the setting. Current Reasonix dispatches record `false`; requested
effort remains useful routing metadata but is not presented as an inference
control.

The audit tool surfaces persistent tier and effort deviations. Repeated
deviations are evidence that the defaults need tuning and are suitable input
for supervised `/code4me-improve` experiments.
