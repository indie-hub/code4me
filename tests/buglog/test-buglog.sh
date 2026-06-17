#!/usr/bin/env bash
# Regression test for bin/code4me-buglog. Pure bash + python3 (no node, no extra
# deps). Builds a small synthetic buglog (with a deliberate duplicate id) and
# exercises search / get / stats / add / dedup / update / doctor / --fix-ids and
# the ambiguous-id guard. Exits non-zero on any failure.

set -u
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
TOOL="$ROOT/bin/code4me-buglog"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got [$2] want [$3])"; fi; }

command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 2; }
python3 -m py_compile "$TOOL" || { echo "tool does not compile"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
BL="$WORK/buglog.json"
# Synthetic log: bug-001, bug-002, and a duplicate bug-002 (different content).
cat > "$BL" <<'JSON'
{
  "version": 1,
  "bugs": [
    {"id":"bug-001","timestamp":"2026-06-01T10:00:00Z","error_message":"NullReferenceException in Foo.Update","file":"src/Foo.cs","root_cause":"ran before init","fix":"guard","tags":["cs","null-safety"],"related_bugs":[],"occurrences":1,"last_seen":"2026-06-01T10:00:00Z"},
    {"id":"bug-002","timestamp":"2026-06-02T10:00:00Z","error_message":"off by one in Bar.loop","file":"src/Bar.cpp","root_cause":"<=","fix":"<","tags":["cpp"],"related_bugs":[],"occurrences":3,"last_seen":"2026-06-02T10:00:00Z"},
    {"id":"bug-002","timestamp":"2026-06-03T10:00:00Z","error_message":"different bug sharing an id","file":"src/Baz.cs","root_cause":"x","fix":"y","tags":["cs"],"related_bugs":[],"occurrences":1,"last_seen":"2026-06-03T10:00:00Z"}
  ]
}
JSON
run() { python3 "$TOOL" --buglog "$BL" --no-backup "$@"; }

echo "== search / get / stats =="
eq "search --tag cpp --count" "$(run search --tag cpp --count)" "1"
eq "search --error 'null' finds bug-001" "$(run search --error null --oneline | awk '{print $1}')" "bug-001"
eq "get --field returns scalar" "$(run get bug-001 --field file)" "src/Foo.cs"
eq "stats entry count line" "$(run stats | sed -n '1p')" "entries: 3"

echo "== ambiguous id guard =="
run get bug-002 >/dev/null 2>&1; eq "get on dup id exits 1" "$?" "1"
run update bug-002 --touch >/dev/null 2>&1; eq "update on dup id exits 1" "$?" "1"

echo "== add (new + dedup) =="
eq "add new -> bug-003" "$(run add --error 'brand new crash' --file src/New.cs --tag cs | grep -o 'bug-003')" "bug-003"
# dedup: same file + near-identical error as bug-001
run add --error "NullReferenceException in Foo.Update!" --file src/Foo.cs --tag dup-tag >/dev/null
eq "dedup bumped bug-001 occurrences" "$(run get bug-001 --field occurrences)" "2"
eq "dedup merged the new tag" "$(run get bug-001 --field tags | grep -c dup-tag)" "1"

echo "== update by id =="
run update bug-001 --resolution "fixed" --add-related bug-003 --bump >/dev/null
eq "update set resolution" "$(run get bug-001 --field resolution)" "fixed"
eq "update bumped occurrences" "$(run get bug-001 --field occurrences)" "3"

echo "== doctor =="
eq "doctor reports 1 duplicate id" "$(run doctor | sed -n '2p')" "duplicate ids: 1"
run doctor --fix-ids >/dev/null
eq "after fix-ids: 0 duplicate ids" "$(run doctor | sed -n '2p')" "duplicate ids: 0"
run update bug-002 --touch >/dev/null 2>&1; eq "update bug-002 works after fix-ids" "$?" "0"

echo "== canonical OpenWolf format (file == json.dumps(indent=2, ensure_ascii=False)) =="
python3 - "$BL" <<'PY'
import json,sys
raw=open(sys.argv[1],encoding='utf-8').read()
canon=json.dumps(json.loads(raw),indent=2,ensure_ascii=False)
sys.exit(0 if raw==canon else 1)
PY
eq "written file is canonical (no trailing newline, indent=2, utf-8)" "$?" "0"

echo ""
echo "================================"
printf 'PASS: %d   FAIL: %d\n' "$PASS" "$FAIL"
echo "================================"
[ "$FAIL" -eq 0 ]
