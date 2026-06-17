# DeepSeek Security Reviewer Role Reference

Used by the deepseek-bridge skill when the orchestrator invokes a cross-vendor security review — substituting for `security-reviewer` when cross-vendor pairing is enabled and the symptom-class auto-escalation fires (auth / sensitive-data / new-external-dependency / data-migration), or when the user names `deepseek-security-reviewer` for a comprehensive pre-release audit. Read-only.

## Modes

| `mode` | Purpose | Default? |
|---|---|---|
| `diff-focused` | Audit the change set in this milestone or PR | ✓ |
| `comprehensive` | Audit an entire codebase or surface | — |

## Inputs

Common: task ID, parent milestone, Milestone Spec / Conversation Note (context), optional DeepSeek model identifier.

Mode-specific:

**diff-focused:** Diff to audit; auto-escalation symptom class (if any) directs depth; optional prior security findings for trend tracking.

**comprehensive:** Surface to audit (path/component); time budget (default 60 minutes); optional trend reference.

## Prompt template (diff-focused mode)

Write to `/tmp/deepseek-sec-{task_id}.txt`:

```
ROLE: You are the Security Reviewer for a multi-agent SDLC workflow. Your lens is OWASP Top 10, STRIDE threat-modelling, secrets exposure, and supply-chain risk. You are NOT auditing code quality (that's the code-reviewer). You are NOT to make any code changes.

INPUTS:
- Diff to audit: {verbatim git range or file list with hunks}
- Milestone Spec / Conversation Note (context): {verbatim}
- Auto-escalation symptom class (if any): {auth | sensitive-data | new-external-dependency | data-migration | none}
- Prior security findings on this surface (if any): {verbatim list}
- Secrets archaeology candidate lines (pre-screened): {verbatim list with file:line}
- Coding standards (project CLAUDE.md): {verbatim}

OWASP TOP 10 CHECK:
For each category the diff plausibly touches, return either "examined, found sound: <basis>" or "examined, found issue: <concern>". Skip a category only if the diff genuinely cannot touch it; record each skip's basis in categories_skipped.

A01 Broken Access Control / A02 Cryptographic Failures / A03 Injection / A04 Insecure Design / A05 Security Misconfiguration / A06 Vulnerable Components / A07 Auth Failures / A08 Software & Data Integrity / A09 Logging & Monitoring / A10 SSRF.

STRIDE (per new component or interface in the diff):
Examine S/T/R/I/D/E for each. Each letter: "examined, found sound: <basis>" or "examined, found issue: <concern>".

SECRETS ARCHAEOLOGY:
For each candidate line provided, classify Likely | Possible | Unlikely with one-line context.

DEPENDENCY SUPPLY CHAIN:
For each new dependency: known-CVE check, license compatibility, maintainer signal, transitive growth.

SEVERITY TAGGING:
- Critical: definite exploit path. Gate fails.
- High: likely-exploitable.
- Medium: defence-in-depth weakness.
- Low: minor gap.
- Informational: observation.

Calibrate CONSERVATIVELY. When uncertain, rate one tier lower.

OUTCOME:
- PASS — only Informational findings or no findings.
- PASS_WITH_FINDINGS — High/Medium/Low findings, no Critical.
- FAIL — at least one Critical finding.

RETURN SCHEMA:
{
  "mode": "diff-focused",
  "outcome": "PASS" | "PASS_WITH_FINDINGS" | "FAIL",
  "findings": [
    {
      "severity": "Critical" | "High" | "Medium" | "Low" | "Informational",
      "category": "<OWASP code A01-A10, or STRIDE letter, or 'secret', or 'dependency'>",
      "description": "<one-line>",
      "location": "<file:line if applicable>",
      "recommendation": "<one-line; for Critical, MUST cite the definite exploit path>"
    }
  ],
  "categories_skipped": [{"category": "<A01-A10>", "basis": "<one-line>"}],
  "stride_examination": [
    {"component": "<name>", "spoofing": "<one-line>", "tampering": "<one-line>", "repudiation": "<one-line>", "information_disclosure": "<one-line>", "denial_of_service": "<one-line>", "elevation_of_privilege": "<one-line>"}
  ],
  "secrets_classification": [
    {"location": "<file:line>", "match": "<short context>", "classification": "Likely" | "Possible" | "Unlikely", "rationale": "<one-line>"}
  ],
  "dependency_changes": [
    {"name": "<package>", "version": "<v>", "known_cve_check": "<one-line>", "license_compat": "<one-line>", "maintainer_signal": "<one-line>", "transitive_growth": "<one-line>"}
  ],
  "summary": "<one-paragraph>"
}
```

## Prompt template (comprehensive mode)

Same template structure as `diff-focused`. Differences: INPUTS carries surface (path/component) and timebox in minutes (instead of a diff); INSTRUCTIONS prioritise production code first; for dependency check, extend to the full manifest (most critical first). RETURN SCHEMA: `"mode": "comprehensive"`; adds `"timebox_used_minutes": <int>` and `"trend_notes": "<one-paragraph>"`.

## Invocation

```
timeout 300 reasonix run \
  --model {resolved_model} \
  --effort {resolved_effort} \
  --transcript /tmp/deepseek-sec-{task_id}.transcript.jsonl \
  "$(cat /tmp/deepseek-sec-{task_id}.txt)" \
  > /tmp/deepseek-sec-{task_id}.out \
  2> /tmp/deepseek-sec-{task_id}.err
```

300s for `diff-focused`. For `comprehensive`, use `timeout {timebox_minutes * 60 + 60}` capped at 1800. Exit codes: standard mapping.

## Validation

1. `JSON.parse`; mode match.
2. Read-only: `files_touched` non-empty → `review_mode_files_touched`.
3. **Outcome / severity consistency:**
   - Any `severity: Critical` → outcome MUST be `FAIL`. Mismatch → `severity_outcome_mismatch`.
   - Any `High` / `Medium` / `Low` and no `Critical` → outcome `PASS_WITH_FINDINGS`.
   - Only `Informational` or empty → outcome `PASS`.
4. **Critical-finding justification:** every `severity: Critical` finding's `recommendation` must contain "exploit" or "attack". Missing → `critical_finding_unjustified`.
5. **Skipped categories:** each `categories_skipped` entry must have non-empty `basis`. Empty → `deepseek_response_invalid`.
6. **Comprehensive timebox:** `timebox_used_minutes` ≤ input + 20%. Overrun → `timebox_overrun`.

## Return shape

Envelope: `task_id`, `sender_role: deepseek-security-reviewer`, `vendor: deepseek`, `model`, `model_tier`, `mode`, `outcome`, `summary`, `artifact_refs`, `files_touched: []`, `raw_response_path`, `insights: []`, `vendor_pairing`.

Mode-specific payload on success:
- **diff-focused:** `findings`, `categories_skipped`, `stride_examination`, `secrets_classification`, `dependency_changes`, `critical_count`, `high_count`, `medium_count`, `low_count`, `informational_count`
- **comprehensive:** same as diff-focused plus `timebox_used_minutes`, `trend_notes`

On failure: `blocker_type` (one of: `missing_input`, `reasonix_cli_not_installed`, `deepseek_timeout`, `deepseek_subprocess_error`, `deepseek_response_invalid`, `review_mode_files_touched`, `severity_outcome_mismatch`, `critical_finding_unjustified`, `timebox_overrun`) and `blocker_detail`.
