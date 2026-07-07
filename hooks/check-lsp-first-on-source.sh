#!/usr/bin/env bash
# Compatibility wrapper. New installs use check-structural-first-on-source.sh.
HOOK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec bash "$HOOK_DIR/check-structural-first-on-source.sh"
