#!/usr/bin/env bash

set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
FAIL=0

while IFS= read -r file; do
    for section in 'Subject:' 'Coverage:'; do
        grep -q "$section" "$file" || { printf "MISSING '%s' in %s\n" "$section" "$file"; FAIL=1; }
    done
    if ! grep -q '## Programmatic verification' "$file"; then
        for section in '## Input prompt' '## Expected' '## Pass criterion'; do
            grep -q "$section" "$file" || { printf "MISSING '%s' in %s\n" "$section" "$file"; FAIL=1; }
        done
    fi
done < <(find "$ROOT/probes" -type f -name '*.md' ! -path '*/fixture-skeleton/*' ! -name 'README.md')

if [ "$FAIL" -eq 0 ]; then printf 'probe structure: ok\n'; fi
exit "$FAIL"
