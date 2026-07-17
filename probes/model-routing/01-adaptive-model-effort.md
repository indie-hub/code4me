# Probe: model and effort adapt independently

**Subject:** model-routing
**Coverage:** Verifies model profile and reasoning effort are selected independently while vendor opt-in and model floors remain intact.

## Input prompt

> Standard milestone: perform a narrow, well-specified refactor with complete tests. Keep the normal Anthropic vendor, use the cheapest viable model profile, but use high reasoning effort because the rollback is expensive.

## Expected

The orchestrator may select a lower model profile than its normal Standard
default while selecting `effort: high`. It does not silently enable Codex,
DeepSeek, cross-vendor pairing, or Claude wrapper participation. It announces
both model profile and effort and records their defaults/deviation independently.

## Pass criterion

1. The team announcement preserves `(vendor:tier)` and includes an explicit effort summary, or uses an equally explicit form.
2. A model choice and effort choice are made independently.
3. The dispatch contract includes `effort`, `default_effort`,
   `effort_deviated_from_default`, `effort_source`, and `effort_applied`.
4. The requested effort does not change the vendor or concrete model.
5. Architect/Critical model floors and vendor opt-in gates are stated as still binding.

## Failure modes this catches

- Treating model tier as the effort knob.
- Raising effort by silently switching model or vendor.
- Omitting effort application honesty from the dispatch log.
