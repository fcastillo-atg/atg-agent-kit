#!/usr/bin/env bash
# Invariant tests for atg-agent-kit. Run before every commit.
#   ./check.sh
# Exits non-zero on any violated invariant, listing every offending line.
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

# Invariant 1: service-specific tokens live in the profile mechanism and nowhere
# else. Commands and every other skill must resolve these through atg-repo-profile.
#
# A file may name a service only when it IS a per-service asset - something the
# profile selects rather than something every service shares:
#   skills/atg-repo-profile/         detection table, profiles, recipes
#   skills/atg-service-rules/        per-service rule-doc pointer tables
#   skills/atg-conventions-*/        one language's conventions, named by a profile
#   skills/atg-cross-cutting-*/      one stack's cross-cutting checklist, ditto
#   skills/dynatrace-mcp/reference.md  one service's log field map and gotchas
# Everything else is shared and must name a profile KEY, never a service. Adding
# to this list hides real leaks, so narrow the pattern first and add only a file
# whose whole purpose is one service.
leak=$(grep -rniE 'wavebid-a2o|gradlew|detekt|codenarc|kover|build\.gradle|\.changeset' \
    "$KIT/commands" "$KIT/skills" \
    --exclude-dir=atg-repo-profile --exclude-dir=atg-service-rules \
    --exclude-dir='atg-conventions-*' --exclude-dir='atg-cross-cutting-*' \
    --exclude=reference.md 2>/dev/null)
if [ -n "$leak" ]; then
    echo "FAIL invariant 1: service-specific token outside profiles/" >&2
    echo "$leak" >&2
    fail=1
else
    echo "ok  invariant 1: no service-specific tokens in shared files"
fi

# Invariant 1b: Jira key prefixes are a profile value, not a constant. Declaring
# one (`ABC-*`) in a shared file breaks any service on a different Jira project.
# Case-sensitive on purpose: -i would match `atg-*.md` and every other lowercase
# glob in the docs.
EXEMPT_DIRS="--exclude-dir=atg-repo-profile --exclude-dir=atg-service-rules"
prefixleak=$(grep -rnE '[A-Z]{2,}-\*' \
    "$KIT/commands" "$KIT/skills" \
    $EXEMPT_DIRS --exclude=reference.md 2>/dev/null)
if [ -n "$prefixleak" ]; then
    echo "FAIL invariant 1b: ticket-prefix declaration outside a profile" >&2
    echo "$prefixleak" >&2
    fail=1
else
    echo "ok  invariant 1b: ticket prefixes come from the profile"
fi

# Invariant 2: every profile declares every contract key.
required='id detect detect-paths code-root branch-pattern story-root plans-path rules-dir
pr-template pr-body-anchor changeset feature-flag migrations-path source-ext conventions-skill
cross-cutting-skill dynatrace-container dynatrace-cluster dynatrace-filters
service-start ticket-prefixes'
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

# Invariant 4: detection is data, not code. link.sh reads each profile's
# detect-paths row, so it must not name a profile itself - a hardcoded id means
# adding a service needs a code change again.
inv4=0
for p in "$KIT"/skills/atg-repo-profile/profiles/*.md; do
    [ -e "$p" ] || continue
    id=$(basename "$p" .md)
    if grep -q "$id" "$KIT/link.sh"; then
        echo "FAIL invariant 4: link.sh hardcodes profile '$id'; detection belongs in its detect-paths row" >&2
        inv4=1
    fi
    if ! grep -q '^| `detect-paths` |' "$p"; then
        echo "FAIL invariant 4: $(basename "$p") has no detect-paths row for link.sh to read" >&2
        inv4=1
    fi
done
if [ "$inv4" -eq 0 ]; then
    echo "ok  invariant 4: detection is data; link.sh names no profile"
else
    fail=1
fi

exit "$fail"
