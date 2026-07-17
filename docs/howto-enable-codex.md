# How to enable the Codex bridge

The `codex-bridge` skill runs seven Code4Me roles through `codex exec`. It is
opt-in per role or milestone; normal work remains on the orchestrator's default
vendor.

## Roles

| Bridge role | Modes |
|---|---|
| `architect` | challenge / consult / review-spec |
| `developer` | implement / review-diff / spike |
| `code-reviewer` | review-diff / review-files / review-spec-fit |
| `spec-to-test` | generate / review-test-spec |
| `security-reviewer` | diff-focused / comprehensive |
| `verification` | suite-run / ac-coverage |
| `lead-architect` | propose / amend |

## Setup

1. Install Codex and verify `command -v codex`.
2. Authenticate with `codex login` or `OPENAI_API_KEY`.
3. Run `/code4me-preflight`.

Enable one role by naming it at intake, or enable milestone-wide pairing with:

```text
/code4me-dispatch Standard --cross-vendor <task description>
```

Vendor participation remains explicit. Model/effort routing never turns the
bridge on by itself.

## Models and effort

| Profile | Model |
|---|---|
| `low` | `gpt-5.6-luna` |
| `mid` | `gpt-5.6-terra` |
| `high` | `gpt-5.6-sol` |

Effort is selected separately. The bridge sends the prompt on stdin and applies
effort through Codex configuration:

```bash
codex exec --model gpt-5.6-terra \
  -c 'model_reasoning_effort="high"' - \
  < /tmp/codex-dev-T01.txt
```

The bridge does not use `--prompt-file`. Apply time limits through the host
tool/process timeout; do not depend on GNU `timeout`. Successful invocations
record `effort_applied: true`.

## Failure and protection

- Missing CLI: `codex_cli_not_installed`.
- Host process limit: `codex_timeout`.
- Non-zero command: `codex_error` with a redacted stderr tail.
- Invalid structured result: `codex_response_invalid`.

After every invocation, `bin/code4me-bridge-diff-scan.sh` checks protected tests,
Critical allowlists, Conversation forbidden conditions, and read-only roles.
Vendor opt-in and all model floors remain active.
