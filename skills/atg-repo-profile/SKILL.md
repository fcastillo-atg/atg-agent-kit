---
name: atg-repo-profile
description: Use at the start of every /atg:* command, and whenever a command needs a build command, a repo path, a branch-name pattern, a PR template location, or needs to know whether this service has changesets or feature flags. The one place per-service values are defined.
---

# ATG repo profile

Commands are the same everywhere; the values they plug in are not. This skill resolves
which service you are in and where to read its values.

## Detect

From the git toplevel (`git rev-parse --show-toplevel`), test each profile's `detect-paths`
row; first profile whose paths all exist wins. The profiles are the only list — there is no
second copy of the detection table to keep in sync, and `link.sh` reads the same rows.

No match: say so and stop. Never guess values, never fall back to another profile.

## Use

Read the matched profile once per command run. Take values from its key table by the exact
key name; take the gate list from its `## Quality gates` section in the order given.

A key whose value is `none` means the concept does not exist in this service. The command
says so in one line and moves to its `**Next:**` step. It does not improvise a substitute.

## Contract

Every profile declares these keys. A missing key is a bug in the profile, not a licence to guess.

| Key | Meaning |
|---|---|
| `id` | Profile name, matches the filename |
| `detect` | The marker that selects this profile, in prose |
| `detect-paths` | The same marker, machine-readable: space-separated paths that must all exist at the git toplevel. `link.sh` reads this row; a trailing `/` also marks a subrepo whose stale `.cursor/` deploy gets pruned |
| `code-root` | Directory the build runs from, relative to the git toplevel |
| `branch-pattern` | How a branch name encodes the ticket |
| `story-root` | Where `bin/stories/`-style scratch lives |
| `plans-path` | The one repo-visible condensed plan, or `none` |
| `rules-dir` | Directory of numbered/named convention docs, or `none` |
| `pr-template` | Path to the PR template, relative to the git toplevel |
| `pr-body-anchor` | Heading the ATG summary block is inserted above |
| `changeset` | The changeset procedure, or `none` |
| `feature-flag` | The flag mechanism, or `none` |
| `migrations-path` | Where schema-migration files live, or `none` |
| `source-ext` | Production source extensions |
| `conventions-skill` | Which conventions skill applies |
| `cross-cutting-skill` | Which cross-cutting checklist applies |
| `dynatrace-container` | `k8s.container.name` for log queries |
| `dynatrace-cluster` | `k8s.cluster.name` for log queries |
| `dynatrace-filters` | Extra DQL filter lines beyond cluster and container, or `none` |
| `service-start` | How to start the service locally for `/atg:test-run` |
| `ticket-prefixes` | The Jira key prefixes whose tickets this service's work uses |

Each profile also carries a `## Quality gates` table (`Step | Gate | Command | Working dir |
On failure`) that `/atg:verify` runs in order, and a `## Notes` section for footguns.

## Adding a service

Add `profiles/<id>.md` with every key above and run `./check.sh`. Detection follows from its
`detect-paths` row — nothing else to wire, and no command, skill or `link.sh` change. A service
on a stack the kit has not met yet also needs its own `conventions-skill` and
`cross-cutting-skill`; those hold real knowledge, not plumbing.
