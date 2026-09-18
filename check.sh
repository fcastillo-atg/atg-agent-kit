#!/usr/bin/env bash
# Invariant tests for atg-agent-kit. Run before every commit.
#   ./check.sh
# Exits non-zero on any violated invariant, listing every offending line.
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

# Invariant 1: service-specific tokens live in profiles/ and nowhere else.
# Commands and skills must resolve these through atg-repo-profile.
leak=$(grep -rniE 'wavebid-a2o|gradlew|detekt|codenarc|kover|build\.gradle|\.changeset' \
    "$KIT/commands" "$KIT/skills" \
    --exclude-dir=profiles 2>/dev/null)
if [ -n "$leak" ]; then
    echo "FAIL invariant 1: service-specific token outside profiles/" >&2
    echo "$leak" >&2
    fail=1
else
    echo "ok  invariant 1: no service-specific tokens outside profiles/"
fi

# Invariant 2: every profile declares every contract key.
required='id detect code-root branch-pattern story-root plans-path rules-dir
pr-template pr-body-anchor changeset feature-flag source-ext conventions-skill
cross-cutting-skill dynatrace-container dynatrace-cluster dynatrace-filters
service-start'
inv2=0
for p in "$KIT"/skills/atg-repo-profile/profiles/*.md; do
    [ -e "$p" ] || continue
    for key in $required; do
        if ! grep -q "\`$key\`" "$p"; then
            echo "FAIL invariant 2: $(basename "$p") is missing key '$key'" >&2
            inv2=1
        fi
    done
done
if [ "$inv2" -eq 0 ]; then
    echo "ok  invariant 2: all profiles declare every contract key"
else
    fail=1
fi

# Invariant 3: every profile has a quality-gate table verify can read.
inv3=0
for p in "$KIT"/skills/atg-repo-profile/profiles/*.md; do
    [ -e "$p" ] || continue
    if ! grep -q '^## Quality gates' "$p"; then
        echo "FAIL invariant 3: $(basename "$p") has no '## Quality gates' section" >&2
        inv3=1
    fi
done
if [ "$inv3" -eq 0 ]; then
    echo "ok  invariant 3: all profiles declare quality gates"
else
    fail=1
fi

exit "$fail"
