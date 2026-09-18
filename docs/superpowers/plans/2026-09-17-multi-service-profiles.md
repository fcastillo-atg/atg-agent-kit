# Multi-Service Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `/atg:*` kit run against `invoices-service` (.NET) as well as `wavebid-a2o` (Kotlin), by moving every service-specific fact out of commands and into one profile file per service.

**Architecture:** The kit already separates thin command procedures from knowledge-bearing skills. This plan adds one more layer at the bottom: a `atg-repo-profile` skill whose `profiles/<id>.md` reference files carry the per-service values (gate commands, paths, branch pattern, PR template, whether changesets and feature flags exist). Commands and skills stop naming a service and instead say "resolve X per atg-repo-profile". Profiles live in the kit, not in the consuming repo, so they stay version-controlled and survive `git clean -xfd`.

**Tech Stack:** Markdown (commands + skills), Bash (`link.sh`, `check.sh`), .NET 10 / CSharpier / xUnit (the new target service), Gradle / Detekt / CodeNarc / Kover (the existing one).

**Spec:** Inline — see `## Problem`, `## Design`, and `## Non-goals` below. No separate spec doc exists; this plan is self-contained.

## Global Constraints

- Two profiles only: `wavebid-a2o` and `invoices-service`. No plugin system, no third service speculatively supported.
- Behaviour against `wavebid-a2o` must not change. Every wavebid value in a profile is copied **verbatim** from the file it came from.
- A command file stays under 150 lines; over 250 means knowledge leaked in that belongs in a skill (kit README, `## Contributing`).
- Every command keeps its existing skeleton: frontmatter `description`, title, one-sentence purpose, `## Usage`, numbered `## Steps`, optional `## Failures`, single `**Next:**` line.
- `link.sh` refuses to deploy unless the kit has a clean commit (`assert_backup_ready`, link.sh:215). Commit each task before running a deploy.
- `dotnet` is **not** on `PATH` on this machine. It lives at `/usr/local/share/dotnet/dotnet`. Every .NET gate command in a profile must work when `PATH` does not include it.
- Ticket prefixes stay `WBPR-*` and `SP2-*`.

---

## Problem

`atg-agent-kit` hardcodes `wavebid-a2o` in 23 of its 31 command and skill files. Deploying it to `invoices-service` fails at four levels:

1. **`link.sh` refuses outright.** `link_checkout()` (link.sh:239) requires `wavebid-a2o-service` and `wavebid-a2o-ui` as sibling directories. `find_wavebid_root()` (link.sh:264) applies the same test walking up from `$PWD`.
2. **`.claude/` is tracked in `invoices-service`.** In wavebid it is gitignored, so the deploy is invisible to git. Here it is not, and the unmerged `feature/claude-code-rules` branch deliberately commits `.claude/rules/` plus `CLAUDE.md`. A deploy would add 20 untracked command copies and 10 **absolute-path symlinks** pointing into `/Users/fcastilloatg/ATG/atg-agent-kit` — broken for every other clone if committed.
3. **The quality gates do not exist.** `verify` runs `./gradlew test detektMain detektTest codenarcTest koverVerify`. `invoices-service` has `dotnet build`, `dotnet test`, `dotnet csharpier check`, and a separate `pnpm lint` for the Playwright suite.
4. **Two lifecycle stages have no counterpart.** There is no `.changeset/` infrastructure (this is a standalone repo, not the monorepo) and no feature-flag mechanism at all (`grep -ril 'featureflag\|LaunchDarkly\|Unleash' src tests` returns nothing).

Fixing this by forking the kit means maintaining two copies of a 20-command lifecycle forever.

## Design

Add `skills/atg-repo-profile/` with:

```
skills/atg-repo-profile/
├── SKILL.md                      detection table + the key contract
└── profiles/
    ├── wavebid-a2o.md            values copied verbatim from today's files
    └── invoices-service.md       values verified against the live repo
```

Detection is by marker file at the git toplevel, checked in order. A command that needs a service-specific value reads the profile instead of carrying the value. Skills are deployed as whole-directory symlinks (`link_skills_to`, link.sh), so `profiles/` rides along with no `link.sh` change.

Language-specific convention skills stay separate rather than becoming profile data, because Claude Code auto-loads skills by matching their `description` against the work in hand — `.cs` files and `.kt` files want different descriptions, which a single skill cannot express.

## Non-goals

- Supporting a third service. Two profiles prove the seam; a third is a new profile file and nothing else.
- Porting `wavebid-a2o`'s numbered rule docs to `invoices-service`. That repo gets `atg-conventions-csharp` (portable essentials) and points at its own `.claude/rules/`.
- Changing anything about how Cursor or omp deploys work (`link_user`, link.sh:185).
- Running the .NET integration suite in `verify`. Playwright needs a live service; that stays `/atg:test-run`.

## Prerequisite (not a task)

Branch `feature/claude-code-rules` (commit `e1379e5`) adds `CLAUDE.md` and `.claude/rules/*.md` to `invoices-service`. Task 9 points `atg-service-rules` at those six rule docs by name.

**Merge it before starting Task 9.** If it will not merge, Task 9's pointer table degrades to the `.cursor/rules/*.mdc` equivalents, which exist on `main` today — the task notes both paths.

## Assumptions to confirm during execution

- **Jira project key.** Every commit in `invoices-service` uses `WBPR-*`, but `.github/workflows/ci.yml:33` declares `jira-team-keys: MTGAP`. The profile assumes `WBPR-*`/`SP2-*` matching the commit history. Task 12 confirms against a real ticket.
- **No coverage gate.** `invoices-service` declares `coverage-exclusions` in CI but no threshold anywhere in the repo. The profile declares no coverage gate rather than inventing one.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `skills/atg-repo-profile/SKILL.md` | Detection order, the key contract, how a command resolves a value |
| `skills/atg-repo-profile/profiles/wavebid-a2o.md` | Today's wavebid values, verbatim |
| `skills/atg-repo-profile/profiles/invoices-service.md` | .NET gate table, paths, "no changeset", "no feature flag" |
| `skills/atg-conventions-csharp/SKILL.md` | C#/xUnit/MediatR conventions, the `.cs` twin of `atg-conventions-guard` |
| `skills/atg-cross-cutting-csharp/SKILL.md` | .NET cross-cutting checklist (middleware order, error contract, marketplace resolution, RabbitMQ) |
| `check.sh` | Invariant test: no service-specific token outside `profiles/` |

**Modified:**

| Path | Change |
|---|---|
| `link.sh:230-287` | Profile-driven checkout guard replaces the wavebid hard-guard |
| `commands/atg/verify.md` | Gate table comes from the profile |
| `commands/atg/ship.md:43-49` | PR template path + changeset gate from the profile |
| `commands/atg/changeset.md` | No-ops when the profile declares no changeset system |
| `commands/atg/feature-flag.md` | Stops when the profile declares no flag mechanism |
| `commands/atg/pattern-check.md:21-31,61` | Anchor globs from the profile |
| `commands/atg/review-feedback.md:54-56,77,107` | Gate names from the profile |
| `commands/atg/retro.md:24-25,36,47-52` | Rule-doc paths from the profile |
| `commands/atg/test-run.md:34-35` | Service-start command from the profile |
| `commands/atg/story-impl.md:68,78,84-86` | Gate + plans path from the profile |
| `commands/atg/story-plan.md:100,143` | Flag section conditional; plans path from the profile |
| `commands/atg/story-view.md:49,52,69,71` | Flag + changeset rows conditional |
| `commands/atg/story-auto-run.md:47,53,63-68,84` | Skip changeset/flag steps when absent |
| `commands/atg/explain.md:31,42` | Layer table from the profile |
| `skills/atg-story-artifacts/SKILL.md:13-15,37,46` | Branch pattern, story root, plans path from the profile |
| `skills/atg-service-rules/SKILL.md` | Becomes a dispatcher into the profile's `rules-dir` |
| `skills/atg-lifecycle/SKILL.md:22` | Changeset row marked profile-conditional |
| `skills/atg-pr-self-review/SKILL.md:26,36` | Changeset check profile-conditional |
| `skills/dynatrace-mcp/SKILL.md:60-65` | Container and cluster from the profile |
| `README.md` | New skills in the table; a `## Supported services` section |
| `<invoices-service>/.gitignore` | Ignore the deployed `.claude/commands/atg/` and kit skill symlinks |

---

### Task 1: Profile skill and the invariant test

The foundation. Nothing else can be de-hardcoded until there is somewhere for the values to go and a test that proves they got there.

**Files:**
- Create: `check.sh`
- Create: `skills/atg-repo-profile/SKILL.md`
- Create: `skills/atg-repo-profile/profiles/wavebid-a2o.md`
- Create: `skills/atg-repo-profile/profiles/invoices-service.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the profile key names every later task reads — `id`, `detect`, `code-root`, `branch-pattern`, `story-root`, `plans-path`, `rules-dir`, `pr-template`, `pr-body-anchor`, `changeset`, `feature-flag`, `source-ext`, `conventions-skill`, `cross-cutting-skill`, `dynatrace-container`, `dynatrace-cluster`, `service-start`, plus the `## Quality gates` table with columns `Step | Gate | Command | Working dir | On failure`. Later tasks must use these exact key spellings.

- [ ] **Step 1: Write the failing test**

Create `check.sh`:

```bash
#!/usr/bin/env bash
# Invariant tests for atg-agent-kit. Run before every commit.
#   ./check.sh
# Exits non-zero on the first violated invariant, listing every offending line.
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
cross-cutting-skill dynatrace-container dynatrace-cluster service-start'
for p in "$KIT"/skills/atg-repo-profile/profiles/*.md; do
    for key in $required; do
        if ! grep -q "\`$key\`" "$p"; then
            echo "FAIL invariant 2: $(basename "$p") is missing key '$key'" >&2
            fail=1
        fi
    done
done
[ "$fail" -eq 0 ] && echo "ok  invariant 2: all profiles declare every contract key"

# Invariant 3: every profile has a quality-gate table verify can read.
for p in "$KIT"/skills/atg-repo-profile/profiles/*.md; do
    if ! grep -q '^## Quality gates' "$p"; then
        echo "FAIL invariant 3: $(basename "$p") has no '## Quality gates' section" >&2
        fail=1
    fi
done
[ "$fail" -eq 0 ] && echo "ok  invariant 3: all profiles declare quality gates"

exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x check.sh && ./check.sh
```

Expected: `FAIL invariant 1` listing ~48 lines across 19 files (`wavebid`, `gradlew`, `detekt`, `codenarc`, `kover`, `.changeset` in commands and skills), and invariant 2 silent because `profiles/` does not exist yet.

- [ ] **Step 3: Write `skills/atg-repo-profile/SKILL.md`**

```markdown
---
name: atg-repo-profile
description: Use at the start of every /atg:* command, and whenever a command needs a build command, a repo path, a branch-name pattern, a PR template location, or needs to know whether this service has changesets or feature flags. The one place per-service values are defined.
---

# ATG repo profile

Commands are the same everywhere; the values they plug in are not. This skill resolves
which service you are in and where to read its values.

## Detect

From the git toplevel (`git rev-parse --show-toplevel`), first match wins:

| Marker at toplevel | Profile |
|---|---|
| `wavebid-a2o-service/` and `wavebid-a2o-ui/` | `profiles/wavebid-a2o.md` |
| `invoices-service.sln` | `profiles/invoices-service.md` |

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
| `detect` | The marker that selects this profile |
| `code-root` | Directory the build runs from, relative to the git toplevel |
| `branch-pattern` | How a branch name encodes the ticket |
| `story-root` | Where `bin/stories/`-style scratch lives |
| `plans-path` | The one repo-visible condensed plan, or `none` |
| `rules-dir` | Directory of numbered/named convention docs, or `none` |
| `pr-template` | Path to the PR template, relative to the git toplevel |
| `pr-body-anchor` | Heading the ATG summary block is inserted above |
| `changeset` | The changeset procedure, or `none` |
| `feature-flag` | The flag mechanism, or `none` |
| `source-ext` | Production source extensions |
| `conventions-skill` | Which conventions skill applies |
| `cross-cutting-skill` | Which cross-cutting checklist applies |
| `dynatrace-container` | `k8s.container.name` for log queries |
| `dynatrace-cluster` | `k8s.cluster.name` for log queries |
| `service-start` | How to start the service locally for `/atg:test-run` |

Each profile also carries a `## Quality gates` table (`Step | Gate | Command | Working dir |
On failure`) that `/atg:verify` runs in order, and a `## Notes` section for footguns.

## Adding a service

Add `profiles/<id>.md` with every key above, add a detection row, run `./check.sh`. No command
or skill file changes.
```

- [ ] **Step 4: Write `skills/atg-repo-profile/profiles/wavebid-a2o.md`**

Values copied verbatim from `verify.md`, `atg-service-rules/SKILL.md`, `atg-story-artifacts/SKILL.md`, `ship.md:43-49`, `changeset.md`, `feature-flag.md`, and `dynatrace-mcp/SKILL.md:60-65`. Do not restate them from memory — open each file and copy.

```markdown
# Profile: wavebid-a2o

| Key | Value |
|---|---|
| `id` | `wavebid-a2o` |
| `detect` | `wavebid-a2o-service/` and `wavebid-a2o-ui/` at the git toplevel |
| `code-root` | `wavebid-a2o-service/` |
| `branch-pattern` | `fc/{TICKET}-{slug}` |
| `story-root` | `bin/stories/` — under `wavebid-a2o-service/` or the monorepo root; check both |
| `plans-path` | `wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md` |
| `rules-dir` | `wavebid-a2o-service/.claude/rules/` |
| `pr-template` | `pull_request_template.md` at the monorepo root |
| `pr-body-anchor` | `#### Requirements` |
| `changeset` | `.changeset/*.md` required when the diff touches `wavebid-a2o-service/` or `wavebid-a2o-ui/`, unless the PR carries `skip-changelog`. Cursor: `/gsd/changeset-wavebid-a2o`. Elsewhere: `.cursor/commands/gsd/changeset-wavebid-a2o.md` |
| `feature-flag` | Single-file Kotlin pattern (interface + Noop + Enabled + ProxyFactory); see `/atg:feature-flag` |
| `source-ext` | `.kt`, `.groovy` |
| `conventions-skill` | `atg-conventions-guard` |
| `cross-cutting-skill` | `atg-cross-cutting-spotter` |
| `dynatrace-container` | `wavebid-a2o-service` |
| `dynatrace-cluster` | `a2o-dev` |
| `service-start` | `cd wavebid-a2o-service && ./gradlew bootRun`, poll `/actuator/health` every 5s up to 120s |

## Quality gates

| Step | Gate | Command | Working dir | On failure |
|---|---|---|---|---|
| 0 | Liquibase preflight (only when the tree touches `src/main/resources/db/changelog/`) | `./gradlew liquibaseUpdate` | `wavebid-a2o-service/` | Postgres unreachable: stop, ask the user to start it (`infra/init-dependencies.sh`) |
| 1 | Tests | `./gradlew test` | `wavebid-a2o-service/` | Schema-like signals (`PSQLException`, `BadSqlGrammarException`, `does not exist`, `relation`, `undefined_column`, `42P01`, `42703`) or mass unrelated failures: run `liquibaseUpdate` once, re-run, then fix normally |
| 2 | Kotlin static analysis | `./gradlew detektMain detektTest` | `wavebid-a2o-service/` | Fix per the rule docs (`403-detekt-extra-violations.md`) |
| 3 | Groovy static analysis | `./gradlew codenarcTest` | `wavebid-a2o-service/` | Fix per `101-test-patterns.md` |
| 4 | Coverage | `./gradlew koverVerify` | `wavebid-a2o-service/` | Add tests for uncovered branches and lines; exclude only genuine infrastructure |

Coverage thresholds: ≥85% branch, ≥95% line.

## Notes

- Never pass `--no-daemon` to Gradle.
- `bin/` is gitignored under the service but not at the monorepo root, so the never-commit rule is behavioural.
- Default to re-running `koverVerify`; coverage drifts silently.
```

- [ ] **Step 5: Write `skills/atg-repo-profile/profiles/invoices-service.md`**

Every command below was run against the live repo. `dotnet csharpier check .` and `format .` are subcommands confirmed with `dotnet csharpier --help` at CSharpier 1.3.0 (`src/.config/dotnet-tools.json`).

```markdown
# Profile: invoices-service

| Key | Value |
|---|---|
| `id` | `invoices-service` |
| `detect` | `invoices-service.sln` at the git toplevel |
| `code-root` | `src/` |
| `branch-pattern` | `{TICKET}` or `{TICKET}-{slug}`, no author prefix (e.g. `WBPR-4963`, `WBPR-4536-sales-order-client`) |
| `story-root` | `bin/stories/` at the git toplevel — already ignored by `.gitignore:38` (`**/[Bb]in/*`) |
| `plans-path` | `.claude/plans/{TICKET}-{slug}.md` |
| `rules-dir` | `.claude/rules/` |
| `pr-template` | `.github/pull_request_template.md` |
| `pr-body-anchor` | `## AI Usage Declaration` |
| `changeset` | `none` — standalone repo, no `.changeset/` infrastructure |
| `feature-flag` | `none` — no flag mechanism exists in this service |
| `source-ext` | `.cs`; integration tests are `.ts` under `tests/` |
| `conventions-skill` | `atg-conventions-csharp` |
| `cross-cutting-skill` | `atg-cross-cutting-csharp` |
| `dynatrace-container` | `invoices-service` |
| `dynatrace-cluster` | `a2o-dev` |
| `service-start` | `cd src && dotnet run --project InvoicesService`, poll `http://localhost:5099/health` every 5s up to 120s |

## Quality gates

| Step | Gate | Command | Working dir | On failure |
|---|---|---|---|---|
| 1 | Format | `dotnet csharpier check .` | `src/` | Run `dotnet csharpier format .`, re-check. CI fails on unformatted C# (`enable-csharpier: true`) |
| 2 | Build | `dotnet build` | `src/` | `NETSDK1045` means a .NET 9 SDK is active; .NET 10 is required |
| 3 | Unit tests | `dotnet test` | `src/` | Fix normally. `[Trait("Category", "Live")]` tests no-op without `AtgPay:MarketplaceToken` and prove nothing |
| 4 | TypeScript lint (only when the diff touches `tests/`) | `pnpm lint` | `tests/` | Run `pnpm lint-fix`, re-check |

No coverage gate. CI declares `coverage-exclusions` but no threshold, so `/atg:verify` does not
invent one. Do not add a coverage step without agreeing a number first.

## Notes

- **`dotnet` is not on `PATH` on the current machine.** It is at `/usr/local/share/dotnet`. Prefix
  gate commands with `export PATH="/usr/local/share/dotnet:$PATH"` when `command -v dotnet` fails.
- Run `dotnet tool restore` in `src/` once per machine before the format gate; CSharpier is a local
  tool (`src/.config/dotnet-tools.json`).
- `pnpm test` in `tests/` is a decoy that exits 1 by design. The integration entry point is
  `pnpm test:int`, and it needs a reachable service — that is `/atg:test-run`, not `/atg:verify`.
- Git hooks already cover part of this: pre-commit formats staged files, pre-push runs
  `dotnet build` + `dotnet test` in `src/`. Gates 2 and 3 duplicate pre-push deliberately, because
  `/atg:verify` must not depend on a hook having run.
- The infrastructure project is spelled `InvoicesService.Infraestructure` throughout. Match it.
- `src/InvoicesService/WeatherForecast.cs`, `Controllers/WeatherForecastController.cs`,
  `src/InvoicesService.Core/Class1.cs` and the `UnitTest1.cs` files are untouched `dotnet new`
  scaffolding. Never cite them as a pattern.
```

- [ ] **Step 6: Run the test to verify invariants 2 and 3 pass**

```bash
./check.sh
```

Expected: `ok invariant 2`, `ok invariant 3`. Invariant 1 still fails — that is Tasks 4 through 11.

- [ ] **Step 7: Commit**

```bash
git add check.sh skills/atg-repo-profile
git commit -m "Add atg-repo-profile skill and kit invariant test

Commands hardcode wavebid-a2o in 23 of 31 files, so the kit cannot deploy
anywhere else. Introduce one profile file per service carrying the values
commands plug in, and check.sh to prove no service-specific token survives
outside profiles/. Invariant 1 fails until the de-hardcoding tasks land."
```

---

### Task 2: Profile-driven deploy in `link.sh`

**Files:**
- Modify: `link.sh:230-287` (`link_checkout`, `find_wavebid_root`, the dispatch block)

**Interfaces:**
- Consumes: the `detect` markers from Task 1's profiles.
- Produces: `find_repo_root()` replacing `find_wavebid_root()`; `link_checkout <root>` accepting either repo shape.

- [ ] **Step 1: Add the failing assertion to `check.sh`**

Append before the final `exit`:

```bash
# Invariant 4: link.sh accepts every profile's repo shape.
for p in "$KIT"/skills/atg-repo-profile/profiles/*.md; do
    id=$(basename "$p" .md)
    if ! grep -q "$id" "$KIT/link.sh"; then
        echo "FAIL invariant 4: link.sh does not know profile '$id'" >&2
        fail=1
    fi
done
[ "$fail" -eq 0 ] && echo "ok  invariant 4: link.sh knows every profile"
```

- [ ] **Step 2: Run it to verify it fails**

```bash
./check.sh
```

Expected: `FAIL invariant 4: link.sh does not know profile 'invoices-service'`.

- [ ] **Step 3: Replace the guard in `link.sh`**

Replace the `[[ -d "$root/wavebid-a2o-service" && ... ]]` guard at link.sh:239-240 with:

```bash
    # Guard on a known profile's marker, NOT $root/.claude — .claude may be
    # absent (a fresh `git worktree add`) or tracked (invoices-service), and
    # neither tells us whether this is a repo the kit supports.
    local profile=""
    if [[ -d "$root/wavebid-a2o-service" && -d "$root/wavebid-a2o-ui" ]]; then
        profile="wavebid-a2o"
    elif [[ -f "$root/invoices-service.sln" ]]; then
        profile="invoices-service"
    fi
    [[ -n "$profile" ]] \
        || { echo "no atg profile matches: $root (expected wavebid-a2o-service + wavebid-a2o-ui, or invoices-service.sln)" >&2; exit 1; }
```

Replace the `for sub in "" "wavebid-a2o-service" "wavebid-a2o-ui"` loop at link.sh:245 with a profile-aware list, so the stale-`.cursor` prune does not reach into directories that do not exist:

```bash
    local subs=("")
    [[ "$profile" == "wavebid-a2o" ]] && subs+=("wavebid-a2o-service" "wavebid-a2o-ui")
    local sub
    for sub in "${subs[@]}"; do
        rm -rf "$root/$sub/.cursor/commands/atg"
    done
```

Change the final echo to name the profile:

```bash
    echo "  deployed $root [$profile]: $n cmd copies + $m per-skill symlinks (.claude, project scope only)"
```

- [ ] **Step 4: Rename and extend the root finder**

Replace `find_wavebid_root()` (link.sh:264-276) with:

```bash
# Walk up from $PWD looking for a root matching any profile's marker (the same
# tests link_checkout applies). Lets `--checkout` with no path work from
# anywhere inside a checkout, e.g. cwd is wavebid-a2o-service or src/.
find_repo_root() {
    local dir="$PWD"
    while true; do
        if [[ -d "$dir/wavebid-a2o-service" && -d "$dir/wavebid-a2o-ui" ]]; then
            echo "$dir"; return 0
        fi
        if [[ -f "$dir/invoices-service.sln" ]]; then
            echo "$dir"; return 0
        fi
        [[ "$dir" == "/" ]] && break
        dir="$(dirname "$dir")"
    done
    echo "not inside a repo with an atg profile (no ancestor of $PWD has wavebid-a2o-service + wavebid-a2o-ui, or invoices-service.sln)" >&2
    return 1
}
```

Update the dispatch at link.sh:282 from `root="$(find_wavebid_root)"` to `root="$(find_repo_root)"`. Update the two header comments at link.sh:7 and link.sh:230 to say "a supported checkout/worktree" instead of "a wavebid checkout".

- [ ] **Step 5: Run the test to verify it passes**

```bash
./check.sh && bash -n link.sh && echo "syntax ok"
```

Expected: `ok invariant 4` and `syntax ok`.

- [ ] **Step 6: Verify the guard still rejects an unknown repo**

```bash
./link.sh --checkout /tmp 2>&1 | head -2
```

Expected: `no atg profile matches: /tmp (expected wavebid-a2o-service + wavebid-a2o-ui, or invoices-service.sln)`, exit non-zero.

- [ ] **Step 7: Commit**

```bash
git add link.sh check.sh
git commit -m "Accept any profiled repo shape in link.sh --checkout

link_checkout and find_wavebid_root both hard-guarded on wavebid-a2o-service
plus wavebid-a2o-ui as siblings, so --checkout refused every other repo. Test
each profile's marker instead, and scope the stale-.cursor prune to the
subdirectories that profile actually has."
```

---

### Task 3: Make the deploy invisible to git in `invoices-service`

Unlike wavebid, this repo tracks `.claude/`. Without this task, a deploy leaves 20 untracked command copies and 10 symlinks holding the absolute path `/Users/fcastilloatg/ATG/atg-agent-kit` — which break for every other clone if anyone commits them.

**Files:**
- Modify: `/Users/fcastilloatg/ATG/invoices-service/.gitignore`

**Interfaces:**
- Consumes: the deploy layout from `link_checkout` — `.claude/commands/atg/` (real file copies) and `.claude/skills/<name>` (directory symlinks).
- Produces: nothing other tasks read.

- [ ] **Step 1: Prove the problem**

```bash
cd /Users/fcastilloatg/ATG/atg-agent-kit && ./link.sh --checkout /Users/fcastilloatg/ATG/invoices-service
cd /Users/fcastilloatg/ATG/invoices-service && git status --short | head -20
```

Expected: a wall of `?? .claude/commands/atg/` and `?? .claude/skills/` entries.

- [ ] **Step 2: Add the ignore rules**

Append to `/Users/fcastilloatg/ATG/invoices-service/.gitignore`:

```gitignore
# atg-agent-kit deploys (see ~/ATG/atg-agent-kit/link.sh --checkout).
# Command copies and skill symlinks are generated per machine and point at an
# absolute kit path; .claude/rules/ and CLAUDE.md are hand-written and tracked.
.claude/commands/atg/
.claude/skills/
.claude/plans/
```

- [ ] **Step 3: Verify git is clean again**

```bash
cd /Users/fcastilloatg/ATG/invoices-service && git status --short
git check-ignore -v .claude/skills/atg-repo-profile
git check-ignore -v bin/stories
```

Expected: `git status --short` shows only the `.gitignore` edit. Both `check-ignore` calls print a matching rule.

- [ ] **Step 4: Verify the tracked rules still load**

```bash
ls .claude/rules/ 2>/dev/null || echo "not merged yet — see Prerequisite"
git check-ignore -v .claude/rules/api-request-headers.md || echo "correctly NOT ignored"
```

Expected: `correctly NOT ignored`. If `.claude/rules/` is missing, `feature/claude-code-rules` has not merged; that blocks Task 9 only.

- [ ] **Step 5: Commit (in `invoices-service`, on a branch)**

```bash
cd /Users/fcastilloatg/ATG/invoices-service
git checkout -b chore/ignore-atg-kit-deploys
git add .gitignore
git commit -m "Ignore atg-agent-kit deploy artifacts

link.sh --checkout writes command copies to .claude/commands/atg/ and
symlinks each kit skill into .claude/skills/. The symlinks hold an absolute
path to the kit, so committing them would break every other clone. .claude/rules/
and CLAUDE.md stay tracked."
```

---

### Task 4: Story artifacts read the profile

**Files:**
- Modify: `skills/atg-story-artifacts/SKILL.md:13-15,37,46`

**Interfaces:**
- Consumes: `branch-pattern`, `story-root`, `plans-path` from Task 1.
- Produces: the phrase later tasks cite — "resolve per atg-story-artifacts".

- [ ] **Step 1: Run the invariant test to see the current failures**

```bash
./check.sh 2>&1 | grep atg-story-artifacts
```

Expected: three lines (13-15's `WBPR` context is fine; the failures are `wavebid-a2o-service` at :37 and :46).

- [ ] **Step 2: Replace the ticket-resolution paragraph (lines 11-15)**

```markdown
## Resolve the ticket

In order: explicit argument, then the current branch, then a scan of the story root. Branch
naming and the story root both come from the **atg-repo-profile** skill — read `branch-pattern`
and `story-root` before matching, because they differ per service (`fc/WBPR-1234-slug` in one,
bare `WBPR-4963` in another). Extract the first `WBPR-` or `SP2-` token from the branch name
regardless of what surrounds it. If nothing resolves, ask once.
```

- [ ] **Step 3: Replace the story-root line (line 37)**

Replace `` `bin/stories/` may sit under `wavebid-a2o-service/` or the monorepo root. Check both. `` with:

```markdown
The story root is the profile's `story-root`. Some services list two candidate locations; check
each in the order the profile gives.
```

- [ ] **Step 4: Replace the plans paragraph (lines 44-47)**

```markdown
The one repo-visible planning artifact is the profile's `plans-path` (condensed, ~100 lines,
links back to the full plan). It is committed on the implementation branch, never on `main`
alone. A profile whose `plans-path` is `none` has no such artifact; skip it silently.
```

- [ ] **Step 5: Verify**

```bash
./check.sh 2>&1 | grep atg-story-artifacts || echo "clean"
```

Expected: `clean`.

- [ ] **Step 6: Commit**

```bash
git add skills/atg-story-artifacts/SKILL.md
git commit -m "Resolve story paths and branch pattern through the profile

Ticket resolution assumed fc/WBPR-1234-slug branches and a bin/stories under
wavebid-a2o-service. invoices-service uses bare WBPR-4963 branches and a
toplevel bin/stories, so both facts move into atg-repo-profile."
```

---

### Task 5: `verify` runs the profile's gate table

The largest single behaviour change. `verify.md` is 70 lines today and hardcodes Gradle in 13 of them.

**Files:**
- Modify: `commands/atg/verify.md` (full rewrite of `## Gates, in order` and `## Steps`)

**Interfaces:**
- Consumes: the `## Quality gates` table and `code-root` from Task 1.
- Produces: the report format `/atg:review-feedback` reproduces in Task 10.

- [ ] **Step 1: Run the invariant test**

```bash
./check.sh 2>&1 | grep 'commands/atg/verify'
```

Expected: 13 lines.

- [ ] **Step 2: Replace frontmatter, purpose, and `## Gates, in order`**

```markdown
---
description: Run this service's quality gates in order and auto-fix violations — the gate before /atg:ship
---

# Verify: quality gates

Run the service's quality gates in order, fix what fails, and stop only when every gate is green.
Start immediately; do not wait for confirmation.

## Usage

```bash
/atg:verify
```

## Gates

Read the `## Quality gates` table from the **atg-repo-profile** skill. It gives, per gate: step
number, name, command, working directory, and what to do on failure. Run them in the order
listed. Each gate's working directory is relative to the git toplevel.

Sequential. Do not start a gate until the previous one passes. 15-minute timeout per command.
Never invent a gate the profile does not list — in particular, never add a coverage gate to a
service whose profile declares none.
```

- [ ] **Step 3: Replace `## Steps` 1-3 with profile-driven equivalents**

```markdown
## Steps

1. **Resolve the profile.** Per **atg-repo-profile**. Print the profile `id` and the gate list
   you are about to run, one line, before starting. No profile matches: stop and say so.

2. **Freshness check, per gate.** Skip a gate only when both hold: you personally ran that exact
   command earlier in this conversation and saw it pass, and `git status --short` shows nothing
   changed under the profile's `code-root` since that run. Any change, even one unrelated-looking
   file, means re-run. Never carry a result across sessions; a fresh session runs everything.
   When unsure, re-run.

3. **Conditional gates.** A gate whose row names a condition ("only when the diff touches X")
   runs only when `git status --short` or the branch diff shows a matching path. Otherwise print
   it as `SKIPPED (not applicable)` and move on.

4. **Run each gate.** On failure, apply that row's **On failure** guidance, fix, and re-run that
   gate, max 3 cycles. Do not move on until it passes. Apply a row's recovery procedure at most
   once per verify session; never loop it.

5. **Report.** After all gates pass, print the summary below, one line per gate from the profile
   table. Mark a skipped gate as `PASSED (cached — no changes since last run in this session)`
   with 0s duration.

```
Verification complete  [{profile id}]

Step {n} {gate name}  ✅ PASSED ({detail}, {t}s)
...

Total: {t}s. All quality gates passed. Ready to commit.
```

On a gate that does not converge after 3 cycles, stop, print which gate failed with the
remaining violations or failures, and ask for guidance.
```

- [ ] **Step 4: Replace `## Failures`**

```markdown
## Failures

| Situation | Action |
|---|---|
| No profile matches this repo | Stop. Do not guess a build command |
| A gate's tool is missing from `PATH` | Check the profile's `## Notes` for its location before reporting it absent |
| Tests pass in CI but fail locally | Suspect seed data or ordering; report as flaky candidate |
| Gate cannot be auto-fixed | Stop after 3 cycles and report |
```

- [ ] **Step 5: Verify the file is clean and still within budget**

```bash
./check.sh 2>&1 | grep 'commands/atg/verify' || echo "clean"
wc -l commands/atg/verify.md
```

Expected: `clean`, and under 150 lines.

- [ ] **Step 6: Run the real gates once, by hand, to prove the invoices-service table is correct**

```bash
export PATH="/usr/local/share/dotnet:$PATH"
cd /Users/fcastilloatg/ATG/invoices-service/src
dotnet tool restore && dotnet csharpier check . && dotnet build && dotnet test
```

Expected: all four succeed on a clean `main`. Any failure means the profile's gate table is
wrong — fix the profile, not the command.

- [ ] **Step 7: Commit**

```bash
git add commands/atg/verify.md
git commit -m "Drive /atg:verify from the profile's gate table

The four gates were hardcoded Gradle invocations, so verify could only run
against wavebid-a2o. Read the gate list, working directories and recovery
steps from atg-repo-profile instead, and forbid inventing a coverage gate
where the profile declares none."
```

---

### Task 6: Changeset becomes profile-conditional

Six files assume a `.changeset/` directory that `invoices-service` does not have.

**Files:**
- Modify: `commands/atg/changeset.md` (rewrite)
- Modify: `skills/atg-lifecycle/SKILL.md:22`
- Modify: `skills/atg-pr-self-review/SKILL.md:26,36`
- Modify: `commands/atg/story-auto-run.md:53,63-68,84`
- Modify: `commands/atg/story-impl.md:68`
- Modify: `commands/atg/explain.md:31`
- Modify: `commands/atg/story-view.md:52,71`

**Interfaces:**
- Consumes: `changeset` from Task 1 (`none` for invoices-service).
- Produces: the rule later tasks follow — a `none` value means one line and move on.

- [ ] **Step 1: Run the invariant test**

```bash
./check.sh 2>&1 | grep -c changeset
```

Expected: 9 or more lines.

- [ ] **Step 2: Rewrite `commands/atg/changeset.md` body**

```markdown
# Changeset (pointer)

Some services require a changelog entry on every PR; some have no changeset system at all.
This command does not duplicate either procedure.

## Usage

```bash
/atg:changeset
```

## What to do

1. Read `changeset` from the **atg-repo-profile** skill.
2. Value `none`: print "This service has no changeset system — nothing to do." and stop.
3. Otherwise follow the procedure the profile gives, exactly. Never run an interactive
   changeset CLI from an agent session.

`/atg:ship` runs the same pre-flight and stops without a changeset where one is required.

**Next:** `/atg:ship {TICKET} [--branch N]`
```

- [ ] **Step 3: Update the lifecycle row (`skills/atg-lifecycle/SKILL.md:22`)**

```markdown
| Quality gate | `changeset` | Conditional. Required when the profile's `changeset` value is not `none` and the diff touches its declared paths. No-ops otherwise |
```

- [ ] **Step 4: Update `skills/atg-pr-self-review/SKILL.md`**

Line 26 becomes:

```markdown
   - If the profile's `changeset` is not `none` and the diff touches its declared paths, ensure a changeset file exists or the user confirms the skip label
```

Line 36 becomes:

```markdown
  - the profile's changeset procedure, or `/atg:changeset`, for a missing changeset
```

- [ ] **Step 5: Update the four remaining call sites**

- `story-auto-run.md:63-68` — replace the wavebid path test and the `/gsd/` pointer with: "Read `changeset` from **atg-repo-profile**. `none`: skip this step entirely and say so in the report. Otherwise follow the profile's procedure; scope from the diff, never run an interactive CLI."
- `story-auto-run.md:53` and `:84` — keep the step name, drop the assumption it always runs.
- `story-impl.md:68` — `- [ ] Changeset when the profile requires one, see /atg:changeset`
- `explain.md:31` — `Also the branch changeset when the profile declares one (exclude its README).`
- `story-view.md:52` and `:71` — mark the Changeset row "omit when the profile's `changeset` is `none`".

- [ ] **Step 6: Verify**

```bash
./check.sh 2>&1 | grep changeset || echo "clean"
```

Expected: `clean`.

- [ ] **Step 7: Commit**

```bash
git add commands skills
git commit -m "Make the changeset stage conditional on the profile

invoices-service is a standalone repo with no .changeset/ infrastructure, but
six files treated the monorepo procedure as universal. Gate every call site on
the profile's changeset value and no-op cleanly when it is none."
```

---

### Task 7: `ship` reads the PR template from the profile

**Files:**
- Modify: `commands/atg/ship.md:43-49` (steps 5 and 6) and the body-building step 7

**Interfaces:**
- Consumes: `pr-template`, `pr-body-anchor`, `changeset` from Task 1.
- Produces: nothing other tasks read.

- [ ] **Step 1: Confirm both templates, so the anchor values are real**

```bash
grep -n '####\|##' /Users/fcastilloatg/ATG/invoices-service/.github/pull_request_template.md
```

Expected: `## Description` and `## AI Usage Declaration`. Note there is no `#### Requirements`
heading and no `LINK_TO_JIRA` placeholder — both of which wavebid's template has.

- [ ] **Step 2: Replace step 5 (changeset pre-flight)**

```markdown
5. **Changeset pre-flight.** Read `changeset` from **atg-repo-profile**. `none`: skip. Otherwise
   apply the profile's rule — if the diff touches its declared paths and no changeset file is on
   the branch or in the working tree, stop before push until the user adds one (`/atg:changeset`)
   or explicitly confirms the skip label. Under `--dry-run`, report the gate result.
```

- [ ] **Step 3: Replace step 6 (template read)**

```markdown
6. **Read the template.** The profile's `pr-template`, relative to the git toplevel. Missing:
   abort, never write a free-form body.
```

- [ ] **Step 4: Adjust step 7 (body building)**

```markdown
7. **Build the body.** Insert the ATG block above the profile's `pr-body-anchor` heading. Keep
   every template checklist item intact, including any AI-usage declaration — tick the
   AI-assisted option, since an `/atg:*` session is AI assistance. Write the prose per the
   **unslop** skill. Replace a `LINK_TO_JIRA` placeholder if the template has one; if it does
   not, put the ticket link in the ATG block's first line instead.
```

- [ ] **Step 5: Verify**

```bash
./check.sh 2>&1 | grep 'commands/atg/ship' || echo "clean"
wc -l commands/atg/ship.md
```

Expected: `clean`, under 150 lines.

- [ ] **Step 6: Dry-run against a real branch**

```bash
cd /Users/fcastilloatg/ATG/invoices-service && git log --oneline -1 origin/WBPR-4963
```

Then run `/atg:ship WBPR-4963 --dry-run` in a session rooted at `invoices-service` and read the
printed body. Expected: the ATG block sits above `## AI Usage Declaration`, both checklist
options survive, the AI-assisted box is ticked, and the Jira link appears despite the template
having no placeholder.

- [ ] **Step 7: Commit**

```bash
git add commands/atg/ship.md
git commit -m "Read the PR template and its anchor from the profile

ship aborted on invoices-service: it looked for pull_request_template.md at a
monorepo root and inserted above a #### Requirements heading that template does
not have. Both come from the profile now, and the AI-usage checklist item is
handled explicitly."
```

---

### Task 8: `feature-flag` stops cleanly where no mechanism exists

**Files:**
- Modify: `commands/atg/feature-flag.md` (add a guard step; leave the Kotlin recipe as the wavebid path)
- Modify: `commands/atg/story-plan.md:100` (flag section conditional)
- Modify: `commands/atg/story-view.md:49,69`
- Modify: `commands/atg/story-auto-run.md:47`
- Modify: `commands/atg/pattern-check.md:31`

**Interfaces:**
- Consumes: `feature-flag` from Task 1 (`none` for invoices-service).
- Produces: nothing other tasks read.

- [ ] **Step 1: Confirm the absence is real, not a search miss**

```bash
cd /Users/fcastilloatg/ATG/invoices-service && grep -ril 'featureflag\|feature_flag\|LaunchDarkly\|Unleash\|IFeatureManager' src tests | head
```

Expected: no output. If anything appears, stop — the profile's `feature-flag: none` is wrong and
must be corrected before this task proceeds.

- [ ] **Step 2: Add the guard as step 0 of `feature-flag.md`**

Insert immediately after `Requirements: $ARGUMENTS`:

```markdown
## Steps

0. **Check the mechanism exists.** Read `feature-flag` from **atg-repo-profile**. Value `none`:
   print "This service has no feature-flag mechanism. Gate the behaviour another way (config,
   a query parameter, or a separate deploy) or add a mechanism as its own story." and stop.
   Do not invent a flag pattern. Otherwise follow the profile's mechanism — the recipe below is
   the `wavebid-a2o` one.
```

Renumber the existing steps 1-N to 1-N after the inserted step 0 (they are already 1-based, so
only the heading line moves).

- [ ] **Step 3: Make the four downstream references conditional**

- `story-plan.md:100` — prefix the `## Feature flag` section guidance with "Omit this section entirely when the profile's `feature-flag` is `none`."
- `story-view.md:49` and `:69` — the Feature Flag row's detection glob comes from the profile; omit the row when `feature-flag` is `none`.
- `story-auto-run.md:47` — "If the plan has a `## Feature flag` section and the profile declares a mechanism, run `/atg:feature-flag`; otherwise skip the step."
- `pattern-check.md:31` — the Feature flag anchor row is omitted when `feature-flag` is `none`.

- [ ] **Step 4: Verify**

```bash
./check.sh 2>&1 | grep -E 'feature-flag|story-plan|story-view|story-auto-run' || echo "clean"
```

Expected: `clean`.

- [ ] **Step 5: Commit**

```bash
git add commands/atg
git commit -m "Stop /atg:feature-flag where no mechanism exists

invoices-service has no feature-flag infrastructure, so the Kotlin single-file
recipe would have invented one. Guard on the profile and stop with an
explanation instead, and omit the flag row from plan, view, auto-run and
pattern-check when the profile declares none."
```

---

### Task 9: C# conventions and the rules dispatcher

**Prerequisite:** `feature/claude-code-rules` merged into `invoices-service` `main`. If it has not
merged, use the `.cursor/rules/*.mdc` filenames instead — they exist on `main` today and carry the
same six conventions minus `codacy.mdc`.

**Files:**
- Create: `skills/atg-conventions-csharp/SKILL.md`
- Create: `skills/atg-cross-cutting-csharp/SKILL.md`
- Modify: `skills/atg-service-rules/SKILL.md` (becomes a dispatcher)

**Interfaces:**
- Consumes: `rules-dir`, `conventions-skill`, `cross-cutting-skill` from Task 1.
- Produces: two skill names the profiles already reference.

- [ ] **Step 1: Confirm the rule docs are present**

```bash
cd /Users/fcastilloatg/ATG/invoices-service && ls .claude/rules/
```

Expected: `api-request-headers.md`, `legacy-sync-messaging.md`, `marketplace-resolution.md`,
`new-platform-domain-events.md`, `playwright-integration-tests.md`, `rabbitmq-event-categories.md`.

- [ ] **Step 2: Rewrite `skills/atg-service-rules/SKILL.md` as a dispatcher**

```markdown
---
name: atg-service-rules
description: Use before editing or reviewing any source file in a service the kit supports, and before an /atg:* command applies a code fix. Points at the service's own rule docs instead of restating them.
---

# ATG service rules

Conventions live in each service repo, not in this kit. Read `rules-dir` from the
**atg-repo-profile** skill, read the relevant docs there before writing code, and cite them by
name when flagging a divergence. A profile whose `rules-dir` is `none` has no rule docs; fall
back to the profile's `conventions-skill`.

## wavebid-a2o

`wavebid-a2o-service/CLAUDE.md` plus the numbered docs under its `rules-dir`.

| Touching | Read |
|---|---|
| Any Kotlin | `002-kotlin.md`, `401-guardrails.md`, `403-detekt-extra-violations.md` |
| Any Groovy/Spock test | `101-test-patterns.md`, `102-groovy-kotlin-interop.md`, `103-tests.md` |
| Controller | `304-api-input-models.md`, `306-api-documentation.md`, `104-controller-test-auth.md` |
| Service | `301-error-handling.md`, `302-spring-boot.md` |
| Repository / entity | `201-database-architecture.md` |
| Migration | `202-postgresql-migrations.md`, `203-liquibase-formatting.md` |
| Feature flag | `303-feature-flags.md` |
| Events | `307-messaging-eventing.md` |
| Changeset | `406-changesets.md` |
| Plan file location | `405-plans-location.md` |

## invoices-service

`CLAUDE.md` at the repo root plus the docs under its `rules-dir`.

| Touching | Read |
|---|---|
| Any controller or endpoint | `api-request-headers.md`, `playwright-integration-tests.md` |
| Anything marketplace-aware | `marketplace-resolution.md` |
| Publishing an event | `rabbitmq-event-categories.md` |
| A Core/Messaging domain event | `new-platform-domain-events.md` |
| A PXB legacy-sync message | `legacy-sync-messaging.md` |

## When the rule docs are not loaded

Some harnesses do not read a repo's rules directory. Sibling skills carry the essentials so the
conventions still travel with the kit — the profile's `conventions-skill` and
`cross-cutting-skill` name which pair applies. They are deliberately short. The rule docs stay
the authority; when both are available, the rule docs win.
```

- [ ] **Step 3: Write `skills/atg-conventions-csharp/SKILL.md`**

Content drawn from the repo's own `CLAUDE.md` and verified against `src/`.

```markdown
---
name: atg-conventions-csharp
description: Use when editing .cs files in invoices-service, after generating C# code, and before committing C# changes. Portable copy of the C#, ASP.NET Core, MediatR and xUnit conventions for harnesses that do not load the repo's rules directory.
---

# C# conventions guard

## Use when

- Working in `.cs` files in a service whose profile names this skill
- Reviewing generated C# before it is committed

## Layering

Three projects, each with a `*.Tests` twin. The infrastructure project is spelled
`InvoicesService.Infraestructure` — a consistent misspelling. Match it; never "correct" it.

| Project | Owns |
|---|---|
| `InvoicesService` | Controllers, middleware, filters, Serilog and OpenAPI wiring |
| `InvoicesService.Core` | MediatR queries and handlers, ports under `Application/Abstractions/`, `Guard`, business rules |
| `InvoicesService.Infraestructure` | All I/O: HTTP clients, RabbitMQ publisher, marketplace facades |

A controller calls `mediator.Send(query)`. It does not reach into Infraestructure.

## Error contract

`ExceptionFilterHandler`, registered globally in `Program.cs`, is the only place that shapes
errors, and it maps by exception **type**:

- `ArgumentException` and subtypes → **400**, with `exception.Message` returned verbatim
- everything else → **500**, generic message, real exception logged server-side only

So `Core/Guards/Guard` throws `ArgumentException` with a fully-formed, caller-ready message
rather than a parameter name — that message becomes the response body. Validate caller input
with `Guard.*` in handlers, or `InvoiceQueryRules.GuardPaging`/`GuardSort`. Use
`InvalidOperationException` for configuration and upstream failures that should surface as 500.

## Tests

- xUnit, Moq, FluentAssertions for unit tests; one `*.Tests` project per production project.
- `[Trait("Category", "Live")]` tests hit a real environment and silently no-op without
  `AtgPay:MarketplaceToken`. They prove nothing in CI by design — never cite one as coverage.
- Integration coverage is Playwright in TypeScript under `tests/`, not another xUnit project.

## Hygiene

- CSharpier is enforced in CI and by the pre-commit hook. Run `dotnet csharpier format .` from
  `src/` before committing; unformatted C# fails the build.
- Never imitate `WeatherForecast.cs`, `WeatherForecastController.cs`, `Class1.cs` or the
  `UnitTest1.cs` placeholders — untouched `dotnet new` scaffolding. Use `HealthController` +
  `GetHealthQuery`, or the `Invoices` slice.
- Scan for leftover `TODO`, `FIXME`, `Console.WriteLine`, `Debug.WriteLine` before shipping.
```

- [ ] **Step 4: Write `skills/atg-cross-cutting-csharp/SKILL.md`**

```markdown
---
name: atg-cross-cutting-csharp
description: Use when adding an endpoint, a handler, a marketplace-aware code path, an outbound HTTP call, or a published message in invoices-service — the things whose blast radius reaches past the file being edited.
---

# C# cross-cutting spotter

Walk this list before calling a change done. Each item is something that bites outside the file
you edited.

| Adding | Check |
|---|---|
| A controller endpoint | The marketplace header set is already handled globally by `CallerContextMiddleware` and `MarketplaceHeadersAuthorizationFilter`. Do not re-parse headers with `[FromHeader]`. Health-style endpoints opt out with `[SkipMarketplaceHeaders]` |
| Any endpoint | Playwright integration coverage under `tests/` is required per endpoint, not optional |
| Marketplace-aware logic | Marketplace never defaults to PXB. `MarketplaceResolver` holds it as ambient scoped state set by `MarketplaceMiddleware`; the `"default"` fallback matches no registered facade and throws `InvalidOperationException` → 500 |
| Marketplace-specific I/O | It belongs in an Infraestructure facade, not in a handler |
| An outbound Sales Order call | `SalesOrderRequestHandler` already adds the bearer token, `platformCode=SP` and `marketplaceCode` as **query parameters**, the `invoices-service` user agent, and the correlation id. Do not add them again |
| A published message | Which layer publishes decides the kind: handler-published domain events versus Infraestructure-published legacy-sync messages. They are not interchangeable |
| New middleware | Order matters — correlation id → marketplace → caller context → authorization filter → controller. Inserting out of order silently breaks the ones after it |
| New configuration | `AtgPay:MarketplaceToken` has no default and is absent from every `appsettings*.json`. Anything depending on it fails with a 500 locally until user secrets are set |
| A money value | Confirm the serialized shape. Invoice money fields are returned as JSON **strings**, unset ones default to empty (commits `8a9942e`, `abc5198`) |
```

- [ ] **Step 5: Verify**

```bash
./check.sh
```

Expected: every invariant `ok` except any still-pending file from Tasks 10-11.

- [ ] **Step 6: Commit**

```bash
git add skills/atg-service-rules skills/atg-conventions-csharp skills/atg-cross-cutting-csharp
git commit -m "Add C# convention skills and dispatch rules through the profile

atg-service-rules pointed only at wavebid-a2o-service/.claude/rules/. Turn it
into a per-service dispatcher and add the .cs twins of the two portable
convention skills, so the conventions still travel to harnesses that do not
load a repo's rules directory."
```

---

### Task 10: Remaining command references

The long tail: four commands still name Gradle tasks, Kotlin globs, or wavebid paths.

**Files:**
- Modify: `commands/atg/pattern-check.md:21-31,50,61`
- Modify: `commands/atg/review-feedback.md:54-56,64-65,77,107`
- Modify: `commands/atg/retro.md:24-25,36,47-52`
- Modify: `commands/atg/test-run.md:34-35`
- Modify: `commands/atg/story-impl.md:78,84-86`
- Modify: `commands/atg/story-plan.md:143`
- Modify: `commands/atg/explain.md:9,42`
- Modify: `commands/atg/story-view.md:8`
- Modify: `commands/atg/scout.md:74-75`

**Interfaces:**
- Consumes: `source-ext`, `plans-path`, `service-start`, `rules-dir`, and the gate table from Task 1.
- Produces: nothing other tasks read.

- [ ] **Step 1: Run the invariant test for the full remaining list**

```bash
./check.sh 2>&1 | grep FAIL -A100 | grep 'commands/atg'
```

Expected: the lines enumerated above and nothing else.

- [ ] **Step 2: `pattern-check.md` — anchors from the profile**

Replace the hardcoded anchor table (lines 27-31) with:

```markdown
| Change kind | Anchor |
|---|---|
| Controller endpoint | The profile's controller convention — a new route-mapped action on a controller type |
| Handler / service method | A new public method on a handler or service type |
| Repository / entity | A new persistence type or field |
| Mapper | A mapping type |
| Feature flag | The profile's flag file pattern; omit this row when `feature-flag` is `none` |

Match by the profile's `source-ext`, not by a fixed extension.
```

Line 21's test-file exclusion globs and line 50's example both become profile-neutral; line 61
becomes "Skip stylistic nits the profile's static-analysis gates already cover; that is verify's job."

- [ ] **Step 3: `review-feedback.md` — gate names from the profile**

Lines 54-56's accept/reject examples become profile-neutral phrasing ("a documented pattern
exception", "a build-DSL exception"). Line 77 becomes "Running one static-analysis gate alone is
not done — run the full profile gate list. Max 2 iterations." Line 107's summary line becomes:

```
Verify:   {one ✅|❌ per gate in the profile's table}
```

Lines 64-65's worked example keeps its file names; they are illustrative, so rewrite them to
neutral `Foo:42` / `Bar:10` form to keep `check.sh` green.

- [ ] **Step 4: `retro.md` — rule paths from the profile**

Lines 24-25 become: "Read the service's `CLAUDE.md` and the docs under the profile's `rules-dir`.
Never suggest a pattern already captured there." Line 36's commit scan becomes "scan for commits
fixing a static-analysis gate named in the profile". Lines 47-52's destination table keys on the
profile's rules-dir rather than naming wavebid files.

- [ ] **Step 5: `test-run.md` — service start from the profile**

Lines 34-35 become:

```markdown
- Not reachable: run the profile's `service-start` command and poll its health endpoint on the
  interval the profile gives, then fail with the last lines of output if it never comes up.
```

- [ ] **Step 6: `story-impl.md`, `story-plan.md`, `explain.md`, `story-view.md`, `scout.md`**

- `story-impl.md:78` — "Run the profile's targeted test command for the affected module."
- `story-impl.md:84-86` — the As-built sentence names "the profile's quality gates"; the plans path becomes the profile's `plans-path`.
- `story-plan.md:143` — "Always write the profile's `plans-path` (path relative to the git toplevel)."
- `explain.md:9` and `story-view.md:8` — "Never runs a build, commits, or writes to Jira."
- `explain.md:42` — the layer table rows come from the profile's project layout.
- `scout.md:74-75` — keep the `[BE]`/`[IS]`/`[SP]`/`[FE]` tags (they name sibling services deliberately, which is cross-service scouting, not a hardcoded build assumption). Add `profiles` to `check.sh`'s exclusion only if this trips invariant 1 — otherwise rephrase to drop the literal `wavebid-a2o-service` spelling in favour of `[BE] the backend monorepo service`.

- [ ] **Step 7: Verify**

```bash
./check.sh
```

Expected: all four invariants `ok`.

- [ ] **Step 8: Commit**

```bash
git add commands/atg
git commit -m "Resolve the remaining command references through the profile

pattern-check, review-feedback, retro, test-run, story-impl, story-plan,
explain, story-view and scout still named Gradle tasks, Kotlin globs or
wavebid paths. Take anchors, gate names, rule paths, plans path and the local
start command from the profile instead."
```

---

### Task 11: Dynatrace and the README

**Files:**
- Modify: `skills/dynatrace-mcp/SKILL.md:60-65`
- Modify: `README.md` (skill table, a `## Supported services` section, the install instructions)

**Interfaces:**
- Consumes: `dynatrace-container`, `dynatrace-cluster` from Task 1.
- Produces: the documentation a teammate follows to add service three.

- [ ] **Step 1: Replace the query pattern (`dynatrace-mcp/SKILL.md:60-65`)**

```markdown
## Standard log query pattern

Take `dynatrace-cluster` and `dynatrace-container` from the **atg-repo-profile** skill:

```
| filter k8s.cluster.name == "{dynatrace-cluster}"
| filter k8s.container.name == "{dynatrace-container}"
```
```

Update the skill's `description` to drop the service name.

- [ ] **Step 2: Update `README.md`**

- Add `atg-repo-profile`, `atg-conventions-csharp` and `atg-cross-cutting-csharp` rows to the skill table, and amend the `atg-service-rules` row to "Dispatcher into each service's own rule docs".
- Add after `## How the kit is organised`:

```markdown
## Supported services

| Service | Detected by | Profile |
|---|---|---|
| `wavebid-a2o` (Kotlin, Gradle, monorepo) | `wavebid-a2o-service/` + `wavebid-a2o-ui/` | `skills/atg-repo-profile/profiles/wavebid-a2o.md` |
| `invoices-service` (.NET 10, standalone) | `invoices-service.sln` | `skills/atg-repo-profile/profiles/invoices-service.md` |

Per-service values — build commands, paths, branch pattern, PR template, whether the service has
changesets or feature flags — live only in those profile files. `./check.sh` fails the build if
a service-specific token appears anywhere else. Adding a third service is a new profile file, a
detection row in `atg-repo-profile`, and a marker test in `link.sh`.
```

- Amend `## Point a wavebid checkout or worktree at the kit` to `## Point a checkout or worktree at the kit`, and note `--checkout` now accepts either repo shape.
- Amend `## Contributing` to add: "Run `./check.sh` before every commit."

- [ ] **Step 3: Verify**

```bash
./check.sh && grep -c 'atg-repo-profile' README.md
```

Expected: all invariants `ok`, and `README.md` mentions the profile skill at least twice.

- [ ] **Step 4: Commit**

```bash
git add skills/dynatrace-mcp README.md
git commit -m "Take Dynatrace coordinates from the profile; document the seam

Log queries hardcoded the wavebid container name. Read both coordinates from
the profile, and document in the README what a third service would take:
a profile file, a detection row, and a link.sh marker test."
```

---

### Task 12: End-to-end dry run against a real ticket

Nothing above proves the kit actually works in `invoices-service`. This task does.

**Files:**
- No source changes expected. Any defect found is fixed in the profile, not in a command.

**Interfaces:**
- Consumes: everything.
- Produces: a confirmed-working deploy.

- [ ] **Step 1: Deploy**

```bash
cd /Users/fcastilloatg/ATG/atg-agent-kit && git status --short   # must be clean
./link.sh --checkout /Users/fcastilloatg/ATG/invoices-service
cd /Users/fcastilloatg/ATG/invoices-service && git status --short
```

Expected: the deploy reports `[invoices-service]` with 20 command copies and 13 skill symlinks;
`git status --short` is clean because of Task 3.

- [ ] **Step 2: Confirm the Jira key assumption**

```bash
export PATH="$PATH"; acli jira workitem view WBPR-4963 --fields status,summary
```

Expected: the ticket resolves. If it does not, the project key is `MTGAP` and both profiles plus
the `jira-cli` skill need their prefix list corrected before continuing.

- [ ] **Step 3: Read-only commands, in a session rooted at `invoices-service`**

Run each and confirm it resolves the profile and does not mention Gradle, Detekt, Kover or a
changeset:

```
/atg:status WBPR-4963
/atg:scout WBPR-4963
/atg:explain WBPR-4963
```

- [ ] **Step 4: The gate**

```
/atg:verify
```

Expected: prints `[invoices-service]` and the four-gate list, runs CSharpier check → build →
test, skips the TypeScript lint gate when the diff does not touch `tests/`, and never mentions
coverage.

- [ ] **Step 5: The two conditional stages**

```
/atg:changeset
/atg:feature-flag add a kill switch for the invoice detail endpoint
```

Expected: both stop in one line — "no changeset system", "no feature-flag mechanism" — and
neither invents a substitute.

- [ ] **Step 6: The ship dry run**

```
/atg:ship WBPR-4963 --dry-run
```

Expected: reads `.github/pull_request_template.md`, inserts the ATG block above
`## AI Usage Declaration`, ticks the AI-assisted option, includes the Jira link, and pushes nothing.

- [ ] **Step 7: Confirm wavebid still works**

```bash
cd /Users/fcastilloatg/ATG/atg-agent-kit && ./link.sh --checkout <wavebid root>
```

Then run `/atg:verify` in a wavebid session. Expected: the same four Gradle gates as before this
plan, in the same order, with the same coverage thresholds. Any difference is a regression in
the wavebid profile — fix the profile.

- [ ] **Step 8: Commit any profile corrections**

```bash
git add skills/atg-repo-profile/profiles
git commit -m "Correct profile values found by the end-to-end dry run"
```

---

## Self-Review

**Spec coverage.** Each numbered problem maps to a task: (1) `link.sh` → Task 2; (2) tracked
`.claude/` → Task 3; (3) gates → Tasks 1 and 5; (4) missing stages → Tasks 6 and 8. The design's
three created files land in Tasks 1 and 9. Every file in the File Structure table appears in
exactly one task's `**Files:**` block.

**Placeholder scan.** No TBDs. Every gate command was executed against the live repo before being
written down (`dotnet csharpier check .` and `format .` confirmed against CSharpier 1.3.0;
`dotnet` confirmed absent from `PATH` and present at `/usr/local/share/dotnet`). Every wavebid
value is marked "copy verbatim from the named file" rather than restated from memory. The one
open item — the `MTGAP` versus `WBPR` project key — is listed as an assumption with a concrete
confirmation step (Task 12, Step 2) and a named fallback.

**Type consistency.** The 17 profile keys are spelled identically in `check.sh`'s `required` list
(Task 1), the contract table in `SKILL.md` (Task 1), both profile files (Task 1), and every
consuming task. `## Quality gates` is the exact heading `check.sh` greps for and `verify.md`
reads. `find_repo_root` replaces `find_wavebid_root` at both its definition and its one call site.

**One risk worth naming.** `check.sh` invariant 1 is a blunt grep. It will flag legitimate prose —
`scout.md`'s deliberate cross-service tags are the known case, handled in Task 10, Step 6. If a
second false positive appears, narrow the pattern rather than widening the exclusion list; an
exclusion hides real leaks.

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-09-17-multi-service-profiles.md`.
