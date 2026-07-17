#!/usr/bin/env bash

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
SCRIPT="$ROOT/bin/code4me-audit-dispatch-log"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOG="$WORK/dispatch-log.jsonl"
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has() {
    if printf '%s' "$OUT" | grep -Fq "$2"; then ok "$1"; else bad "$1 (missing [$2])"; fi
}

cat > "$LOG" <<'JSONL'
{"task":"old","subagent":"developer","weight":"Standard","vendor":"anthropic","model_tier":"mid","outcome":"COMPLETE"}
{"task":"codex","subagent":"code-reviewer","weight":"Standard","vendor":"openai","model_tier":"mid","effort":"high","default_effort":"medium","effort_deviated_from_default":true,"effort_source":"explicit_deviation","effort_applied":true,"outcome":"COMPLETE"}
{"task":"reasonix","subagent":"verification","weight":"Standard","vendor":"deepseek","model_tier":"mid","effort":"medium","default_effort":"medium","effort_deviated_from_default":false,"effort_source":"default","effort_applied":false,"outcome":"COMPLETE"}
JSONL

OUT="$(bash "$SCRIPT" "$LOG")"
RC=$?
[ "$RC" -eq 0 ] && ok "mixed log exits 0" || bad "mixed log exits $RC"
has "reports effort distribution" "## Effort distribution"
has "keeps legacy entries visible" "legacy/unspecified"
has "reports application" "## Effort application"
has "reports applied backend" "| applied | 1 |"
has "reports unsupported backend" "| not applied | 1 |"
has "reports recorded count" 'Recorded effort: **2 of 3** dispatches'
has "reports deviation count" 'deviated from default: **1**'

printf '\nPASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
