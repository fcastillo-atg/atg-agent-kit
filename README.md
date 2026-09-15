# atg-agent-kit

`atg` slash commands and skills for Claude Code and Cursor. Git-tracked source of truth;
`link.sh` deploys them into each runtime's native format so they load from any cwd or worktree.

## How the kit is organised

**Commands are thin procedures. Skills carry the shared knowledge.** A command file is a
numbered list of steps plus one output template, and it delegates every cross-cutting rule to a
skill by name. When you learn something about how the workflow should behave, it goes into a
skill, never into a command's procedure text. See [Contributing](#contributing).

| Skill | Owns |
|---|---|
| `atg-story-artifacts` | Ticket resolution, the `bin/stories/` directory layout, every file's role, the canonical `implementation-plan.md` sections, `## As-built` semantics, the never-commit-`bin/` rule, diff base and `--branch` scoping |
| `atg-lifecycle` | The command graph: order, which steps block, which are advisory, which stay manual, and what runs next after each |
| `atg-testing-guide` | Scenario-versus-step vocabulary, variable conventions for guide, test-run and Jira, and the `TESTING-GUIDE.md` template (`template.md`) |
| `atg-service-rules` | Pointer table into `wavebid-a2o-service/.claude/rules/` by what you are touching, plus the Gradle and coverage rules |
| `atg-conventions-guard` | Portable copy of the Kotlin, Spring/JPA, Spock and feature-flag conventions, for harnesses that do not load `.claude/rules/` |
| `atg-cross-cutting-spotter` | Portable cross-cutting checklist: migration, UUIDv7, MapStruct, soft delete, `@Transactional`, flags, events, money, downstream rewrites |
| `atg-pr-self-review` | Pre-ship sanity pass: clean tree, slice alignment, leftover `TODO`/`println`, changeset gate |
| `unslop` | Writing rules for anything a person reads (PR bodies, Jira comments, replies, briefs). Vendored from `cursor/plugins` so consumers need no separate install |
| `jira-cli` | Jira via `acli` with `mcp-atlassian` fallback, token-efficient field selection, the ADF comment recipe |
| `dynatrace-mcp` | Dynatrace log and metric queries via the `dynatrace-mcp` MCP server, with `reference.md` for accumulated gotchas |

Skills load automatically when their description matches. Commands are invoked by name.
The three portable convention skills overlap the service rule docs on purpose: rule docs are
the authority in Claude Code, and the skills keep the conventions available in harnesses that
only load skills. When editing a convention, update the rule doc first, then the skill.

## Commands

20 `/atg:*` commands. Most support one story's life cycle end to end; a handful are
cross-cutting tools you can reach for at any point.

### Life-cycle commands

| Command | Stage | What it does |
|---|---|---|
| `/atg:scout` | Groom | Audits a ticket against the codebase before pointing it. Read-only; returns pointable/blocked with evidence |
| `/atg:brief` | Plan (optional) | Socratic pre-story analysis; surfaces ambiguities and cross-cutting concerns before `story-plan` |
| `/atg:story-plan` | Plan | Branch-split implementation plan: LOC estimate, feature-flag strategy, branch breakdown, As-built placeholder |
| `/atg:story-impl` | Implement | Executes one branch of the plan as an ordered, commit-by-commit work queue |
| `/atg:feature-flag` | Implement (conditional) | Single-file feature flag (interface + Noop + Enabled + ProxyFactory) wired into the service |
| `/atg:verify` | Quality gate | Tests, Detekt, CodeNarc, Kover with auto-fix. The gate before `ship` |
| `/atg:pattern-check` | Quality gate | Diff versus comparable existing code and rule docs. Advisory only |
| `/atg:changeset` | Quality gate (conditional) | Pointer to the monorepo changeset procedure |
| `/atg:story-gap` | Pre-ship | Every acceptance criterion accounted for in the diff. Blocks on a missing AC |
| `/atg:testing-doc` | Pre-ship | Writes `TESTING-GUIDE.md` (optionally `scenarios/*.sh`) |
| `/atg:test-run` | Pre-ship (optional) | Executes the guide via curl, asserts, writes `TESTING-PROGRESS.md` |
| `/atg:ship` | Ship (manual) | Creates the PR from the monorepo template, transitions Jira |
| `/atg:qa-comment` | Post-merge (manual) | Drafts and posts a Postman-style QA comment to Jira after approval |
| `/atg:retro` | Wrap-up | Mines the story for durable patterns; writes only what you pick |
| `/atg:story-auto-run` | Orchestrator | Chains brief through testing-doc for one branch, unattended. `ship` and `qa-comment` stay manual |

### Cross-cutting commands

| Command | What it does |
|---|---|
| `/atg:status` | Text table of branch, PR, CI and Jira state for a story |
| `/atg:story-view` | Read-only lifecycle dashboard published as an Artifact page |
| `/atg:explain` | Plain-language "what am I about to merge" with before/after examples |
| `/atg:review-feedback` | Classify PR comments, fix, reply in-thread, push, with confirmation gates |
| `/atg:pr-comment` | Post one inline review finding on a PR |

### Workflow

The authoritative graph, successor table and gate semantics live in the `atg-lifecycle` skill.
Summary:

```mermaid
flowchart TD
    subgraph autorun["/atg:story-auto-run (unattended)"]
        direction TB
        brief["brief (optional)"] --> storyplan["story-plan"]
        storyplan --> storyimpl["story-impl"]
        storyimpl --> featureflag["feature-flag (conditional)"]
        featureflag --> verify["verify"]
        verify --> patterncheck["pattern-check"]
        patterncheck --> changeset["changeset (conditional)"]
        changeset --> storygap["story-gap"]
        storygap --> testingdoc["testing-doc"]
    end
    testingdoc -. optional .-> testrun["test-run"]
    testingdoc --> ship["ship (manual)"]
    testrun --> ship
    ship --> reviewfeedback["review-feedback"]
    reviewfeedback -. loops back .-> verify
    ship --> qacomment["qa-comment (manual)"]
    qacomment --> retro["retro"]
    scout["scout"] -. before pointing .-> brief
```

[`docs/example-story-walkthrough.md`](docs/example-story-walkthrough.md) follows one story
through the whole timeline with abbreviated output at each step.

## Install (user-level, any machine)

```bash
~/ATG/atg-agent-kit/link.sh
```

Deploys Cursor commands to `~/.cursor/commands/atg-*.md` as real file copies, flat, with YAML
frontmatter stripped and the description hoisted to line 1 (Cursor's picker uses line 1 and has
no `ns:cmd` syntax, so they appear as `/atg-brief`). Claude Code commands and skills are
project-scope only and are not deployed here; a user-level copy would show every command twice.

Real copies rather than symlinks: re-run `link.sh` after editing a command. Safe to re-run; it
prunes only its own prior outputs. Restart Cursor after the first install.

## Point a wavebid checkout or worktree at the kit

```bash
~/ATG/atg-agent-kit/link.sh --checkout /path/to/wavebid-a2o
```

Copies commands into `<root>/.claude/commands/atg/` and symlinks each `skills/<name>/` directory
into `<root>/.claude/skills/`. Refuses to run unless the kit has a clean commit.

## Install for teammates

```bash
cd ~/ATG   # or wherever you keep wavebid-a2o
git clone https://github.com/fcastillo-atg/atg-agent-kit.git
```

Then run the user-level install once and `--checkout` once per checkout or worktree. Re-run both
after pulling kit updates.

## Contributing

Every command follows one skeleton: frontmatter `description`, title, one-sentence purpose,
`## Usage`, numbered `## Steps`, one output template where the shape matters, an optional
`## Failures` table, and a single `**Next:**` line taken from `atg-lifecycle`. Target under 150
lines; over 250 means knowledge has leaked in that belongs in a skill.

Adding a command: create `commands/atg/<name>.md`, add a row to the table above and to the
`atg-lifecycle` successor table, run `link.sh` and `link.sh --checkout`.

Adding knowledge: if two or more commands need the same rule, it goes in a skill. If it is a
codebase convention, it belongs in `wavebid-a2o-service/.claude/rules/`, and the kit only points
at it.

## Why this exists

The content previously lived as untracked directories inside the gitignored `wavebid-a2o/.claude/`
tree: invisible to git, destroyed by `git clean -xfd`, and undiscoverable at their original
nesting depth. This kit gives it real history, cwd-independent deploys, and a flat skill layout.
