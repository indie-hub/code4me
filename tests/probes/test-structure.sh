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

REMOVED_INTEGRATION_PATTERN='spec([ -]?)'"kit"'|spec_'"kit"
if rg -i "$REMOVED_INTEGRATION_PATTERN" "$ROOT" --hidden --glob '!.git/**' >/dev/null; then
    printf 'REMOVED integration references found\n'
    FAIL=1
fi

for contract in \
    'README.md:codex plugin marketplace add indie-hub/code4me' \
    'README.md:claude plugin marketplace add indie-hub/code4me' \
    'docs/explanation.md:Why five workflow weights' \
    'docs/howto-run-with-codex.md:codex plugin add code4me@code4me-marketplace'
do
    file=${contract%%:*}
    pattern=${contract#*:}
    if ! grep -Fq "$pattern" "$ROOT/$file"; then
        printf 'documentation contract missing: %s in %s\n' "$pattern" "$file"
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then printf 'probe structure: ok\n'; fi
exit "$FAIL"
