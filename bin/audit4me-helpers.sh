#!/usr/bin/env bash
# audit4me-helpers.sh — deterministic bash helpers for the audit4me outer loop.
#
# audit4me is skill-shaped: the SKILL.md drives the loop and calls these helpers
# for the mechanical bookkeeping (scope resolution, hashing, work-set computation,
# atomic coverage updates, events-log append, finding-id allocation, run-id mint).
# The judgment-heavy per-file auditing happens in the code4me-audit-orchestrator
# subagent; nothing in this file calls an LLM.
#
# Pure bash + jq. No python, no node — same dependency floor as the hooks so it
# runs under WSL / Git Bash on Windows. Requires: jq, and sha256sum or shasum.
#
# Usage:
#   audit4me-helpers.sh hash-file <path>
#   audit4me-helpers.sh resolve-scope <config_json>
#   audit4me-helpers.sh work-set <config_json> <coverage_json> [--vendor V] [--category C] [--paths GLOB] [--changed-since Nh] [--force]
#   audit4me-helpers.sh coverage-update <coverage_json> <file_path> <entry_json>
#   audit4me-helpers.sh event-append <events_jsonl> <event_json>
#   audit4me-helpers.sh alloc-finding-id <findings_dir>
#   audit4me-helpers.sh new-run-id
#
# All paths are project-relative and resolved against $PWD (the project root),
# which is where /audit4me-run runs from. Windows path normalisation is not the
# concern here — these run inside the project tree via find, not via tool-passed
# absolute paths.

set -u

die() { printf 'audit4me-helpers: %s\n' "$*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required"

# ---- hashing ----

_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" 2>/dev/null | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
    else
        die "need sha256sum or shasum"
    fi
}

cmd_hash_file() {
    local path="$1"
    [ -f "$path" ] || die "no such file: $path"
    local h; h="$(_sha256 "$path")"
    [ -n "$h" ] || die "hash failed: $path"
    printf 'sha256:%s' "$h"
}

# ---- glob matching (same polyfill idiom as the hooks) ----

_glob_to_regex() {
    printf '%s' "$1" | sed \
        -e 's|[.[\$()+^]|\\&|g' \
        -e 's|\*\*/|<<DSTAR_S>>|g' \
        -e 's|/\*\*|<<S_DSTAR>>|g' \
        -e 's|\*\*|<<DSTAR>>|g' \
        -e 's|\*|[^/]*|g' \
        -e 's|?|[^/]|g' \
        -e 's|<<DSTAR_S>>|(.*/)?|g' \
        -e 's|<<S_DSTAR>>|/.*|g' \
        -e 's|<<DSTAR>>|.*|g'
}

_glob_match() { # <path> <pattern>
    local re; re="$(_glob_to_regex "$2")"
    [[ "$1" =~ ^${re}$ ]]
}

# ---- scope resolution ----
# Enumerate every file under the project root, keep those matching ANY include
# pattern and NO exclude pattern. Project-relative paths, no leading ./.

cmd_resolve_scope() {
    local config="$1"
    [ -r "$config" ] || die "config not readable: $config"
    # Read include/exclude into arrays without mapfile (bash 3.2 / macOS compat).
    local includes=() excludes=() line
    while IFS= read -r line; do includes+=("$line"); done < <(jq -r '.scope.include[]?' "$config")
    while IFS= read -r line; do excludes+=("$line"); done < <(jq -r '.scope.exclude[]?' "$config")
    [ "${#includes[@]}" -gt 0 ] || die "scope.include is empty in $config"

    local f inc exc matched
    while IFS= read -r f; do
        f="${f#./}"
        matched=0
        for inc in "${includes[@]}"; do
            if _glob_match "$f" "$inc"; then matched=1; break; fi
        done
        [ "$matched" -eq 1 ] || continue
        for exc in "${excludes[@]}"; do
            if _glob_match "$f" "$exc"; then matched=0; break; fi
        done
        [ "$matched" -eq 1 ] && printf '%s\n' "$f"
    done < <(find . -type f -not -path './.git/*' 2>/dev/null | sort)
}

# ---- work-set computation ----
# A file enters the work set when, for the target vendor + category, ANY
# re-audit trigger fires: uncovered, content change, rules-version change,
# refresh interval elapsed, category not yet covered, or --force.

cmd_work_set() {
    local config="$1" coverage="$2"; shift 2
    local vendor="anthropic" category="bugs" paths_glob="" changed_since="" force=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --vendor)        vendor="$2"; shift 2 ;;
            --category)      category="$2"; shift 2 ;;
            --paths)         paths_glob="$2"; shift 2 ;;
            --changed-since) changed_since="$2"; shift 2 ;;
            --force)         force=1; shift ;;
            *) die "work-set: unknown arg $1" ;;
        esac
    done
    [ -r "$config" ] || die "config not readable: $config"
    local rules_version refresh_days
    rules_version="$(jq -r '.rules_version' "$config")"
    refresh_days="$(jq -r '.refresh_interval_days // 90' "$config")"

    # changed-since cutoff (epoch seconds), if requested.
    local changed_cutoff=0
    if [ -n "$changed_since" ]; then
        local num unit secs
        num="${changed_since%[smhd]}"; unit="${changed_since##*[0-9]}"
        case "$unit" in
            s) secs=$num ;; m) secs=$((num*60)) ;;
            h) secs=$((num*3600)) ;; d) secs=$((num*86400)) ;;
            *) die "bad --changed-since: $changed_since (use Ns/Nm/Nh/Nd)" ;;
        esac
        changed_cutoff=$(( $(date -u +%s) - secs ))
    fi

    local now_epoch; now_epoch="$(date -u +%s)"
    local refresh_cutoff=$(( now_epoch - refresh_days*86400 ))

    local f cur_hash entry reason
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        # --paths filter
        if [ -n "$paths_glob" ] && ! _glob_match "$f" "$paths_glob"; then continue; fi
        # --changed-since filter (file mtime)
        if [ -n "$changed_since" ]; then
            local mtime; mtime="$(date -u -r "$f" +%s 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
            [ "$mtime" -ge "$changed_cutoff" ] || continue
        fi

        cur_hash="$(cmd_hash_file "$f")"
        entry="$(jq -c --arg p "$f" '.[$p] // null' "$coverage" 2>/dev/null || echo null)"

        reason=""
        if [ "$force" -eq 1 ]; then
            reason="forced"
        elif [ "$entry" = "null" ]; then
            reason="uncovered"
        else
            local v_entry v_hash v_cats r_at last_upd last_epoch
            v_entry="$(printf '%s' "$entry" | jq -c --arg v "$vendor" '.vendors[$v] // null')"
            r_at="$(printf '%s' "$entry" | jq -r '.rules_version_at_audit // ""')"
            if [ "$v_entry" = "null" ]; then
                reason="vendor-uncovered"
            else
                v_hash="$(printf '%s' "$v_entry" | jq -r '.audited_hash // ""')"
                v_cats="$(printf '%s' "$v_entry" | jq -r '.categories_covered // [] | index("'"$category"'") // "no"')"
                last_upd="$(printf '%s' "$entry" | jq -r '.last_updated // ""')"
                last_epoch="$(date -u -d "$last_upd" +%s 2>/dev/null || echo 0)"
                if [ "$v_hash" != "$cur_hash" ]; then reason="content-change"
                elif [ "$r_at" != "$rules_version" ]; then reason="rules-version-change"
                elif [ "$v_cats" = "no" ]; then reason="category-uncovered"
                elif [ "$last_epoch" -ne 0 ] && [ "$last_epoch" -lt "$refresh_cutoff" ]; then reason="refresh-stale"
                fi
            fi
        fi

        [ -n "$reason" ] || continue
        jq -cn --arg f "$f" --arg h "$cur_hash" --argjson e "$entry" \
               --arg vendor "$vendor" --arg cat "$category" --arg reason "$reason" \
            '{file:$f, content_hash:$h, coverage_entry:$e, vendor:$vendor, category:$cat, reason:$reason}'
    done < <(cmd_resolve_scope "$config")
}

# ---- atomic coverage update ----

cmd_coverage_update() {
    local coverage="$1" path="$2" entry="$3"
    [ -f "$coverage" ] || printf '{}' > "$coverage"
    printf '%s' "$entry" | jq empty 2>/dev/null || die "entry is not valid JSON"
    local tmp; tmp="$(mktemp "${coverage}.XXXX")"
    jq --arg p "$path" --argjson e "$entry" '.[$p] = $e' "$coverage" > "$tmp" \
        && mv "$tmp" "$coverage" || { rm -f "$tmp"; die "coverage update failed"; }
}

# ---- events log append ----

cmd_event_append() {
    local events="$1" event="$2"
    printf '%s' "$event" | jq empty 2>/dev/null || die "event is not valid JSON"
    # Force single-line (compact) so the file stays valid JSONL.
    printf '%s\n' "$(printf '%s' "$event" | jq -c .)" >> "$events"
}

# ---- finding id allocation (per-day sequence) ----

cmd_alloc_finding_id() {
    local dir="$1"
    local today; today="$(date -u +%Y-%m-%d)"
    local n=0
    if [ -d "$dir" ]; then
        n="$(find "$dir" -maxdepth 1 -name "F-${today}-*.md" 2>/dev/null | wc -l | tr -d ' ')"
    fi
    printf 'F-%s-%04d' "$today" "$((n+1))"
}

# ---- run id ----

cmd_new_run_id() {
    local ts suffix
    ts="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
    suffix="$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 4)"
    [ "${#suffix}" -eq 4 ] || suffix="$(printf '%04x' $((RANDOM % 65536)))"
    printf 'run-%s-%s' "$ts" "$suffix"
}

# ---- dispatch ----

[ "$#" -ge 1 ] || die "usage: audit4me-helpers.sh <subcommand> [args]"
sub="$1"; shift
case "$sub" in
    hash-file)        cmd_hash_file "$@" ;;
    resolve-scope)    cmd_resolve_scope "$@" ;;
    work-set)         cmd_work_set "$@" ;;
    coverage-update)  cmd_coverage_update "$@" ;;
    event-append)     cmd_event_append "$@" ;;
    alloc-finding-id) cmd_alloc_finding_id "$@" ;;
    new-run-id)       cmd_new_run_id "$@" ;;
    *) die "unknown subcommand: $sub" ;;
esac
