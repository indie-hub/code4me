#!/usr/bin/env bash
# code4me-bridge-diff-scan.sh — post-validation diff scan for cross-vendor bridges.
#
# Invoked by codex-bridge and deepseek-bridge skills after `codex exec` /
# `reasonix run` returns. Enumerates files modified by the subprocess and
# cross-references them against:
#
#   * .code4me/protected-tests.txt    → test_protection_violation
#   * .code4me/critical-allowlist.txt → out_of_scope_target (Critical Mode only)
#   * .code4me/forbidden-conditions.json → forbidden_condition_violation
#                                           (Conversation Mode only — new files)
#   * --mode read-only                → unexpected_modification (any diff)
#
# Emits one JSON object on stdout. Exit code is non-zero only for usage/setup
# errors; detected violations come back as ok=false in the JSON, NOT a non-zero
# exit — the bridge needs to consume violations as structured data, not infer
# from exit code.
#
# Usage:
#   bin/code4me-bridge-diff-scan.sh \
#       --project-dir <path> \
#       --weight <trivial|conversation|light|standard|critical> \
#       --mode <read-only|read-write> \
#       --vendor <codex|deepseek>
#
# Required: bash, git. Optional: jq (for JSON output formatting).
# When git is missing OR the project isn't a git repo, the scan SKIPS with
# `skipped: true` and `skip_reason: ...` — the bridge logs the skip and proceeds
# (Layer C requires git; without git, this layer is a no-op).

set -u

# ─── Argument parsing ──────────────────────────────────────────────────────
PROJECT_DIR=""
WEIGHT=""
MODE=""
VENDOR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
        --weight)      WEIGHT="${2:-}";      shift 2 ;;
        --mode)        MODE="${2:-}";        shift 2 ;;
        --vendor)      VENDOR="${2:-}";      shift 2 ;;
        --help|-h)
            sed -n '/^# /p' "$0" | sed 's/^# //; s/^#//' | head -25
            exit 0 ;;
        *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
done

[ -n "$PROJECT_DIR" ] || { echo "ERROR: --project-dir required" >&2; exit 2; }
[ -n "$WEIGHT" ]      || { echo "ERROR: --weight required" >&2; exit 2; }
[ -n "$MODE" ]        || { echo "ERROR: --mode required" >&2; exit 2; }
[ -n "$VENDOR" ]      || { echo "ERROR: --vendor required" >&2; exit 2; }

case "$MODE" in
    read-only|read-write) ;;
    *) echo "ERROR: --mode must be read-only or read-write" >&2; exit 2 ;;
esac
case "$WEIGHT" in
    trivial|conversation|light|standard|critical) ;;
    *) echo "ERROR: --weight must be one of trivial|conversation|light|standard|critical" >&2; exit 2 ;;
esac
case "$VENDOR" in
    codex|deepseek) ;;
    *) echo "ERROR: --vendor must be codex or deepseek" >&2; exit 2 ;;
esac

# ─── JSON emit helpers ─────────────────────────────────────────────────────
emit_skip() {
    local reason="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg r "$reason" --arg v "$VENDOR" \
            '{ok: true, vendor: $v, violations: [], files_changed: [], skipped: true, skip_reason: $r}'
    else
        printf '{"ok":true,"vendor":"%s","violations":[],"files_changed":[],"skipped":true,"skip_reason":"%s"}' \
            "$VENDOR" "$reason"
    fi
    exit 0
}

# ─── Pre-flight: git availability + repo presence ──────────────────────────
if ! command -v git >/dev/null 2>&1; then
    emit_skip "git not installed — Layer C diff scan unavailable"
fi

cd "$PROJECT_DIR" 2>/dev/null || { echo "ERROR: cannot cd into $PROJECT_DIR" >&2; exit 2; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    emit_skip "project is not a git repo — Layer C diff scan unavailable"
fi

# ─── Enumerate changed files ───────────────────────────────────────────────
# git status --porcelain covers BOTH modified files AND newly-created untracked
# files. We exclude .code4me/ from the scan because the bridge's own bookkeeping
# (dispatch log, etc.) lands there and is expected to change.
#
# Output line shape:
#   XY path           (modified/added/etc)
#   ?? path           (untracked)
#   R  old -> new     (rename — take the "new" side)
PORCELAIN="$(git status --porcelain 2>/dev/null || true)"

# Parse into a clean list of paths.
CHANGED_FILES=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Drop the XY status prefix (first 3 chars).
    path="${line:3}"
    # Handle renames: "old -> new" — take the "new" side.
    case "$path" in
        *' -> '*) path="${path##* -> }" ;;
    esac
    # Exclude .code4me/ (bridge bookkeeping) and .git/.
    case "$path" in
        .code4me/*|.git/*) continue ;;
    esac
    CHANGED_FILES="${CHANGED_FILES}${path}"$'\n'
done <<< "$PORCELAIN"

# Strip trailing newline.
CHANGED_FILES="${CHANGED_FILES%$'\n'}"

# Track which paths are NEW (untracked) — needed for forbidden-conditions
# (which only fires on new artifact creation).
NEW_FILES=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
        '?? '*)
            path="${line:3}"
            case "$path" in
                .code4me/*|.git/*) continue ;;
            esac
            NEW_FILES="${NEW_FILES}${path}"$'\n'
            ;;
    esac
done <<< "$PORCELAIN"
NEW_FILES="${NEW_FILES%$'\n'}"

# ─── Glob matching ─────────────────────────────────────────────────────────
# Always use the regex polyfill rather than bash's native `[[ == ]]` glob.
# Reason: bash's `[[ == ]]` treats `**` as `* *` (two single-segment wildcards
# concatenated), NOT as "zero or more directory components". That breaks
# patterns like `tests/**/*test*` which should match `tests/foo_test.cs` at
# depth 1. The regex polyfill correctly translates `**/` to `(.*/)?` (the `?`
# makes it zero-or-more components).
USE_NATIVE_GLOB=0

glob_to_regex() {
    printf '%s' "$1" | sed \
        -e 's|\\|\\\\|g' \
        -e 's|\.|\\.|g' \
        -e 's|\*\*/|<<DSTAR_S>>|g' \
        -e 's|/\*\*|<<S_DSTAR>>|g' \
        -e 's|\*\*|<<DSTAR>>|g' \
        -e 's|\*|[^/]*|g' \
        -e 's|?|[^/]|g' \
        -e 's|<<DSTAR_S>>|(.*/)?|g' \
        -e 's|<<S_DSTAR>>|/.*|g' \
        -e 's|<<DSTAR>>|.*|g'
}

matches_glob() {
    local target="$1" pattern="$2"
    if [ "$USE_NATIVE_GLOB" -eq 1 ]; then
        # shellcheck disable=SC2053
        [[ "$target" == $pattern ]]
    else
        local regex
        regex="$(glob_to_regex "$pattern")"
        [[ "$target" =~ ^${regex}$ ]]
    fi
}

# Returns 0 if $1 matches ANY pattern in the file at $2.
matches_any_in_file() {
    local target="$1" patterns_file="$2"
    [ -r "$patterns_file" ] || return 1
    while IFS= read -r PATTERN || [ -n "$PATTERN" ]; do
        case "$PATTERN" in ''|'#'*) continue ;; esac
        PATTERN="${PATTERN#"${PATTERN%%[![:space:]]*}"}"
        PATTERN="${PATTERN%"${PATTERN##*[![:space:]]}"}"
        [ -n "$PATTERN" ] || continue
        if matches_glob "$target" "$PATTERN"; then
            return 0
        fi
    done < "$patterns_file"
    return 1
}

# ─── Build violations array ────────────────────────────────────────────────
# violations is collected as a JSONL-ish list of "type|file|detail" lines,
# then assembled into the final JSON at emit time.
VIOLATIONS=""

add_violation() {
    local vtype="$1" file="$2" detail="$3"
    VIOLATIONS="${VIOLATIONS}${vtype}|${file}|${detail}"$'\n'
}

# ── Read-only mode: any modification is a violation ─────────────────────────
if [ "$MODE" = "read-only" ] && [ -n "$CHANGED_FILES" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        add_violation "unexpected_modification" "$f" \
            "Role was dispatched read-only; subprocess modified file unexpectedly"
    done <<< "$CHANGED_FILES"
fi

# ── Test protection (always-active when protected-tests.txt exists) ────────
PROTECTED_FILE=".code4me/protected-tests.txt"
if [ -n "$CHANGED_FILES" ] && [ -r "$PROTECTED_FILE" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        if matches_any_in_file "$f" "$PROTECTED_FILE"; then
            add_violation "test_protection_violation" "$f" \
                "Subprocess modified a file in .code4me/protected-tests.txt"
        fi
    done <<< "$CHANGED_FILES"
fi

# ── Critical-mode allowlist (only when weight=critical) ────────────────────
ALLOWLIST_FILE=".code4me/critical-allowlist.txt"
if [ "$WEIGHT" = "critical" ] && [ -n "$CHANGED_FILES" ] && [ -r "$ALLOWLIST_FILE" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        if matches_any_in_file "$f" "$ALLOWLIST_FILE"; then
            : # allowed
        else
            add_violation "out_of_scope_target" "$f" \
                "Subprocess modified a file outside the Critical-mode allowlist"
        fi
    done <<< "$CHANGED_FILES"
fi

# ── Forbidden conditions (only when weight=conversation; new files only) ───
# NOTE: this check needs jq to parse forbidden-conditions.json. If jq is
# missing while the state file is present, we must NOT skip silently — that
# would degrade a safety gate without anyone noticing. We record a structured
# warning (surfaced in the output JSON and on stderr) so the bridge can relay
# the degradation to the orchestrator.
SCAN_WARNINGS=""
add_warning() {
    SCAN_WARNINGS="${SCAN_WARNINGS}$1"$'\n'
    echo "WARN: $1" >&2
}

FORBIDDEN_FILE=".code4me/forbidden-conditions.json"
if [ "$WEIGHT" = "conversation" ] && [ -n "$NEW_FILES" ] && [ -r "$FORBIDDEN_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
        # Extract forbidden_globs array from the JSON.
        GLOBS="$(jq -r '.forbidden_globs[]?' "$FORBIDDEN_FILE" 2>/dev/null || true)"
        if [ -n "$GLOBS" ]; then
            while IFS= read -r f; do
                [ -z "$f" ] && continue
                while IFS= read -r PATTERN; do
                    [ -z "$PATTERN" ] && continue
                    if matches_glob "$f" "$PATTERN"; then
                        add_violation "forbidden_condition_violation" "$f" \
                            "Subprocess created a new file matching forbidden glob: $PATTERN"
                    fi
                done <<< "$GLOBS"
            done <<< "$NEW_FILES"
        fi
    else
        add_warning "forbidden-conditions check SKIPPED: jq not installed but ${FORBIDDEN_FILE} is present and the subprocess created new files — Conversation-Mode new-file gating could not run. Install jq, or review the new files manually."
    fi
fi

# ─── Emit the final JSON ───────────────────────────────────────────────────
emit_result() {
    local ok="true"
    [ -n "$VIOLATIONS" ] && ok="false"

    if command -v jq >/dev/null 2>&1; then
        # Build violations JSON array from the pipe-delimited list.
        local viol_json="[]"
        if [ -n "$VIOLATIONS" ]; then
            viol_json="$(printf '%s' "$VIOLATIONS" | jq -R -s '
                split("\n")
                | map(select(length > 0))
                | map(split("|"))
                | map({type: .[0], file: .[1], detail: .[2]})
            ')"
        fi

        # Build files_changed array.
        local files_json="[]"
        if [ -n "$CHANGED_FILES" ]; then
            files_json="$(printf '%s' "$CHANGED_FILES" | jq -R -s '
                split("\n") | map(select(length > 0))
            ')"
        fi

        # Build warnings array (degraded-check notices, e.g. jq missing).
        local warn_json="[]"
        if [ -n "$SCAN_WARNINGS" ]; then
            warn_json="$(printf '%s' "$SCAN_WARNINGS" | jq -R -s '
                split("\n") | map(select(length > 0))
            ')"
        fi

        jq -n \
            --argjson ok "$ok" \
            --arg vendor "$VENDOR" \
            --arg weight "$WEIGHT" \
            --arg mode "$MODE" \
            --argjson violations "$viol_json" \
            --argjson files_changed "$files_json" \
            --argjson warnings "$warn_json" \
            '{
                ok: $ok,
                vendor: $vendor,
                weight: $weight,
                mode: $mode,
                violations: $violations,
                files_changed: $files_changed,
                warnings: $warnings
            }'
    else
        # jq-less fallback: minimal JSON without violation detail arrays.
        printf '{"ok":%s,"vendor":"%s","weight":"%s","mode":"%s","violations_present":%s,"warnings_present":%s,"files_changed_count":%d,"note":"install jq for structured output"}\n' \
            "$ok" "$VENDOR" "$WEIGHT" "$MODE" \
            "$([ -n "$VIOLATIONS" ] && echo true || echo false)" \
            "$([ -n "$SCAN_WARNINGS" ] && echo true || echo false)" \
            "$(printf '%s' "$CHANGED_FILES" | grep -c . || echo 0)"
    fi
}

emit_result
exit 0
