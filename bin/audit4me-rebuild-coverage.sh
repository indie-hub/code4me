#!/usr/bin/env bash
# audit4me-rebuild-coverage.sh — reconstruct audit-coverage.json from the
# append-only audit-events.jsonl. The events log is the source of truth; the
# coverage projection is a cache. If coverage is lost or corrupted, this
# rebuilds it deterministically from history.
#
# Usage:
#   audit4me-rebuild-coverage.sh <events_jsonl> <output_coverage_json> [config_json]
#
# config_json (optional) supplies vendors_available so coverage_level can
# distinguish agreement-covered from full-covered. Without it, full-covered is
# never emitted (>=2 vendors => agreement-covered).
#
# Pure bash + jq. Only completed events contribute; skipped/failed are ignored.

set -u
die() { printf 'audit4me-rebuild-coverage: %s\n' "$*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq is required"

EVENTS="${1:?usage: rebuild-coverage <events_jsonl> <output_coverage_json> [config_json]}"
OUT="${2:?missing output coverage path}"
CONFIG="${3:-}"
[ -r "$EVENTS" ] || die "events log not readable: $EVENTS"

VENDOR_COUNT=0
if [ -n "$CONFIG" ] && [ -r "$CONFIG" ]; then
    VENDOR_COUNT="$(jq -r '.vendors_available | length' "$CONFIG" 2>/dev/null || echo 0)"
fi

# Reduce the event stream into a coverage object. For each file: per-vendor,
# keep only events at that vendor's most-recent content_hash; union categories,
# sum findings, take max ts. File content_hash = hash of the most-recent event
# overall. coverage_level from how many vendors are current at that hash.
jq -s --argjson vendor_count "$VENDOR_COUNT" '
  map(select(.outcome == "completed"))
  | group_by(.file)
  | map(
      ( .[0].file ) as $file
      | ( max_by(.ts) ) as $latest
      | ( $latest.content_hash ) as $file_hash
      | ( group_by(.vendor)
          | map(
              ( max_by(.ts) ) as $vlatest
              | ( $vlatest.content_hash ) as $vhash
              | ( map(select(.content_hash == $vhash)) ) as $cur
              | {
                  key: $vlatest.vendor,
                  value: {
                    audited_at: ($cur | max_by(.ts) | .ts),
                    audited_hash: $vhash,
                    categories_covered: ($cur | map(.category) | unique),
                    findings_count: ($cur | map(.findings // 0) | add),
                    model: $vlatest.model
                  }
                }
            )
          | from_entries
        ) as $vendors
      | ( [ $vendors | to_entries[] | select(.value.audited_hash == $file_hash) ] | length ) as $current_vendors
      | {
          key: $file,
          value: {
            content_hash: $file_hash,
            vendors: $vendors,
            rules_version_at_audit: $latest.rules_version,
            coverage_level: (
              if $current_vendors == 0 then "uncovered"
              elif $current_vendors == 1 then "single-vendor"
              elif ($vendor_count > 0 and $current_vendors >= $vendor_count) then "full-covered"
              else "agreement-covered" end
            ),
            last_updated: ($vendors | [ .[].audited_at ] | max)
          }
        }
    )
  | from_entries
' "$EVENTS" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT" || { rm -f "$OUT.tmp"; die "rebuild failed"; }

printf 'rebuilt %s from %s (%s files)\n' "$OUT" "$EVENTS" "$(jq 'length' "$OUT")"
