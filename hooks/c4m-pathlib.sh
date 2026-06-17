#!/usr/bin/env bash
# Code4Me hook path helpers — shared by the path-matching PreToolUse hooks
# (check-test-protection, check-forbidden-conditions, check-critical-write-
# allowlist).
#
# Centralises Windows path normalisation. Under Git Bash / MSYS, Claude Code
# passes Windows-style paths (C:\Users\... or C:/Users/...). The previous
# POSIX-only absolute-path test `case "$p" in /*)` mis-classified those as
# RELATIVE, so the project dir was wrongly prepended and no allowlist /
# protected / forbidden pattern could ever match. For the critical-write
# allowlist that meant every Edit/Write ask-gated ("all files protected");
# for test-protection it meant protected tests were silently editable.
#
# This file is meant to be SOURCED, not executed. It defines functions only
# and has no side effects.

# True when running under a Windows bash (Git Bash / MSYS / Cygwin), or when
# C4M_FORCE_WINDOWS=1 is set — the latter lets the test harness exercise the
# case-insensitive path on a Linux CI runner.
c4m_is_windows_bash() {
    [ "${C4M_FORCE_WINDOWS:-0}" = "1" ] && return 0
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

# Echo the argument with backslashes converted to forward slashes.
c4m_slashify() {
    printf '%s' "${1//\\//}"
}

# Return 0 if the (forward-slash) path is absolute: POSIX (/foo) or a
# Windows drive-letter path (C:/foo, or a bare drive C:).
c4m_is_abs() {
    case "$1" in
        /*)          return 0 ;;
        [A-Za-z]:/*) return 0 ;;
        [A-Za-z]:)   return 0 ;;
        *)           return 1 ;;
    esac
}

# Resolve $1 (target or pattern) against project dir $2, returning an
# absolute, forward-slash path. Absolute inputs are returned slashified,
# unchanged otherwise. Trailing slash on the base is trimmed.
c4m_resolve() {
    local p base
    p="$(c4m_slashify "$1")"
    base="$(c4m_slashify "$2")"
    if c4m_is_abs "$p"; then
        printf '%s' "$p"
    else
        printf '%s/%s' "${base%/}" "$p"
    fi
}

# Fold a path for comparison on case-insensitive filesystems (Windows).
# Identity on POSIX, so Linux/macOS case-sensitivity is preserved.
c4m_fold() {
    if c4m_is_windows_bash; then
        printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
    else
        printf '%s' "$1"
    fi
}
