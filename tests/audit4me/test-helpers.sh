#!/usr/bin/env bash
# Regression test for bin/audit4me-helpers.sh and bin/audit4me-rebuild-coverage.sh
# (audit4me Phase 1). Functional checks are pure bash + jq and always run. Schema
# validation of the produced artifacts runs only when python3 + jsonschema are
# available (CI installs jsonschema; locally it's skipped with a note).
#
# Exits non-zero on any functional failure.

set -u
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
H="$ROOT/bin/audit4me-helpers.sh"
REBUILD="$ROOT/bin/audit4me-rebuild-coverage.sh"
SCHEMAS="$ROOT/skills/audit4me/schemas"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got [$2] want [$3])"; fi; }
match() { if printf '%s' "$2" | grep -Eq "$3"; then ok "$1"; else bad "$1 (got [$2] !~ $3)"; fi; }

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 2; }

WORK="$(mktemp -d)"; cleanup() { rm -rf "$WORK"; }; trap cleanup EXIT
cd "$WORK" || exit 1
mkdir -p src/sub .code4me/audit4me/findings
cat > .code4me/audit4me-config.json <<'JSON'
{ "$schema":"audit4me-config-v1","vendors_available":["anthropic"],"default_categories":["bugs"],
  "max_files_per_run":50,"max_cost_usd_per_run":5.0,"max_runtime_per_run":"4h",
  "rules_version":"v0.1.0","refresh_interval_days":90,"concurrency_cap":3,
  "scope":{"include":["src/**"],"exclude":["**/*.min.js"]} }
JSON
CFG=.code4me/audit4me-config.json
COV=.code4me/audit4me/audit-coverage.json
EV=.code4me/audit4me/audit-events.jsonl
printf 'class A {}\n' > src/a.cs
printf 'class B {}\n' > src/sub/b.cs
printf 'min\n'        > src/c.min.js
printf '# readme\n'   > README.md

echo "== resolve-scope =="
SCOPE="$(bash "$H" resolve-scope "$CFG" | tr '\n' ' ')"
eq "scope = a.cs + sub/b.cs only" "$SCOPE" "src/a.cs src/sub/b.cs "

echo "== hash-file / ids =="
HASH="$(bash "$H" hash-file src/a.cs)"
match "hash-file format" "$HASH" '^sha256:[a-f0-9]{64}$'
RID="$(bash "$H" new-run-id)"
match "new-run-id format" "$RID" '^run-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z-[a-z0-9]{4}$'
FID="$(bash "$H" alloc-finding-id .code4me/audit4me/findings)"
match "alloc-finding-id format" "$FID" '^F-[0-9]{4}-[0-9]{2}-[0-9]{2}-0001$'
touch ".code4me/audit4me/findings/$FID.md"
FID2="$(bash "$H" alloc-finding-id .code4me/audit4me/findings)"
match "alloc-finding-id increments" "$FID2" '0002$'
rm -f ".code4me/audit4me/findings/$FID.md"

echo "== work-set triggers =="
N="$(bash "$H" work-set "$CFG" "$COV" | jq -rc '.reason' | grep -c uncovered || true)"
eq "uncovered: 2 files queued" "$N" "2"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkentry() { jq -cn --arg h "$1" --arg now "$NOW" --arg rv "$2" --argjson cats "$3" \
  '{content_hash:$h,vendors:{anthropic:{audited_at:$now,audited_hash:$h,categories_covered:$cats,findings_count:0,model:"claude-sonnet-4-6"}},rules_version_at_audit:$rv,coverage_level:"full-covered",last_updated:$now}'; }

HA="$(bash "$H" hash-file src/a.cs)"; HB="$(bash "$H" hash-file src/sub/b.cs)"
bash "$H" coverage-update "$COV" src/a.cs    "$(mkentry "$HA" v0.1.0 '["bugs"]')"
bash "$H" coverage-update "$COV" src/sub/b.cs "$(mkentry "$HB" v0.1.0 '["bugs"]')"
eq "fully covered -> empty work-set" "$(bash "$H" work-set "$CFG" "$COV" | wc -l | tr -d ' ')" "0"

printf 'class A { int x; }\n' > src/a.cs
eq "content change -> a.cs requeued (content-change)" \
   "$(bash "$H" work-set "$CFG" "$COV" | jq -rc '"\(.file):\(.reason)"')" \
   "src/a.cs:content-change"

HA2="$(bash "$H" hash-file src/a.cs)"
bash "$H" coverage-update "$COV" src/a.cs "$(mkentry "$HA2" v0.0.9 '["bugs"]')"
eq "old rules_version -> rules-version-change" \
   "$(bash "$H" work-set "$CFG" "$COV" | jq -rc '.reason')" "rules-version-change"

bash "$H" coverage-update "$COV" src/a.cs "$(mkentry "$HA2" v0.1.0 '["bugs"]')"
eq "category not covered -> category-uncovered" \
   "$(bash "$H" work-set "$CFG" "$COV" --category security | jq -rc 'select(.file=="src/a.cs").reason')" "category-uncovered"

echo "== event-append (valid JSONL) =="
EVT="$(jq -cn --arg ts "$NOW" --arg rid "$RID" --arg h "$HA2" '{ts:$ts,run_id:$rid,vendor:"anthropic",model:"claude-sonnet-4-6",file:"src/a.cs",content_hash:$h,category:"bugs",outcome:"completed",findings:0,rules_version:"v0.1.0"}')"
bash "$H" event-append "$EV" "$EVT"; bash "$H" event-append "$EV" "$EVT"
VALID="$(while IFS= read -r l; do printf '%s' "$l" | jq empty 2>/dev/null && echo ok; done < "$EV" | grep -c ok)"
eq "events.jsonl: 2 valid lines" "$VALID" "2"

echo "== rebuild-coverage from events =="
# Two vendors at same hash -> full-covered (vendors_available has 2 here).
RB="$(mktemp -d)"
cat > "$RB/cfg.json" <<'JSON'
{"$schema":"audit4me-config-v1","vendors_available":["anthropic","openai"],"default_categories":["bugs"],"rules_version":"v0.1.0","scope":{"include":["src/**"]}}
JSON
RH="sha256:$(printf '%064d' 7)"
{ jq -cn --arg h "$RH" '{ts:"2026-06-16T10:00:00Z",run_id:"run-2026-06-16T10-00-00Z-aaaa",vendor:"anthropic",model:"claude-sonnet-4-6",file:"src/x.cs",content_hash:$h,category:"bugs",outcome:"completed",findings:2,rules_version:"v0.1.0"}'
  jq -cn --arg h "$RH" '{ts:"2026-06-16T10:05:00Z",run_id:"run-2026-06-16T10-00-00Z-aaaa",vendor:"openai",model:"gpt-5.4",file:"src/x.cs",content_hash:$h,category:"bugs",outcome:"completed",findings:1,rules_version:"v0.1.0"}'
  jq -cn '{ts:"2026-06-16T10:06:00Z",run_id:"run-2026-06-16T10-00-00Z-aaaa",vendor:"openai",model:"gpt-5.4",file:"src/y.cs",content_hash:"sha256:'"$(printf '%064d' 8)"'",category:"bugs",outcome:"failed",failure_reason:"rate_limit",rules_version:"v0.1.0"}'
} > "$RB/ev.jsonl"
bash "$REBUILD" "$RB/ev.jsonl" "$RB/cov.json" "$RB/cfg.json" >/dev/null
eq "rebuild: only completed file present" "$(jq -r 'keys|join(",")' "$RB/cov.json")" "src/x.cs"
eq "rebuild: coverage_level full-covered (2/2 vendors)" "$(jq -r '."src/x.cs".coverage_level' "$RB/cov.json")" "full-covered"
eq "rebuild: findings summed per vendor" "$(jq -r '."src/x.cs".vendors.anthropic.findings_count' "$RB/cov.json")" "2"
rm -rf "$RB"

echo "== schema validation (optional) =="
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  SCHEMAS="$SCHEMAS" CFG="$CFG" COV="$COV" EV="$EV" HASH="$HA2" NOW="$NOW" FID="$FID" python3 - <<'PY'
import os, json
from jsonschema import Draft202012Validator
S=os.environ["SCHEMAS"]; load=lambda p: json.load(open(p))
fails=0
def v(name, sf, inst):
    global fails
    errs=list(Draft202012Validator(load(f"{S}/{sf}")).iter_errors(inst))
    print("  ok   schema:"+name if not errs else "  FAIL schema:"+name)
    for e in errs[:4]: print("     -", list(e.path), e.message); 
    fails += (1 if errs else 0)
v("config", "config.schema.json", load(os.environ["CFG"]))
v("coverage", "audit-coverage.schema.json", load(os.environ["COV"]))
for i,l in enumerate(open(os.environ["EV"])):
    if l.strip(): v(f"event[{i}]", "audit-event.schema.json", json.loads(l))
fm={"id":os.environ["FID"],"severity":"MAJOR","category":"bugs","file":"src/a.cs",
"line_range":"1","content_hash":os.environ["HASH"],"audited_at":os.environ["NOW"],
"vendors_agreed":["anthropic"],"confidence":"low","proposed_fix":False,
"rules_version":"v0.1.0","status":"open"}
v("finding-frontmatter", "finding-frontmatter.schema.json", fm)
import sys; sys.exit(1 if fails else 0)
PY
  if [ "$?" -eq 0 ]; then ok "all produced artifacts schema-valid"; else bad "schema validation"; fi
else
  echo "  skip schema validation (python3+jsonschema not available)"
fi

echo ""
echo "================================"
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
echo "================================"
[ "$FAIL" -eq 0 ]
