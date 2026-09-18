---
description: Create a branch-split implementation plan for a story: LOC estimate, feature flag strategy, branch breakdown, As-built placeholder
---

# Story plan

Turn a story into `implementation-plan.md`: analysis, architecture, LOC estimate, feature flag
decision, and a branch split that keeps every PR near 500 LOC. Also writes the condensed
repo-committed plan under `.claude/plans/`.

## Usage

```bash
/atg:story-plan WBPR-3215
/atg:story-plan "Implement lot end time propagation optimization"   # description, no ticket
/atg:story-plan WBPR-3215 --refresh                                 # re-fetch Jira, overwrite the story snapshot
```

Story input: $ARGUMENTS

## Steps

### 1. Resolve the story

Resolve the ticket and story directory per the **atg-story-artifacts** skill.

- If `{TICKET}-story.md` exists and no refresh was asked for, use it. Note in the preamble that
  Jira comments were not re-fetched.
- Otherwise fetch summary, description, and comments per the **jira-cli** skill, then create or
  update `{TICKET}-story.md` with title, description, acceptance criteria, a
  `## Jira comments (summary)` section (or "none substantive"), and the browse URL.
- Review comments for scope changes, AC tweaks, blockers, and decisions not in the description.
  Treat material takeaways as part of the story.
- If Jira is unreachable and no file exists, ask the user to paste the fields and comments.

Preamble must record: ticket key and URL, story file path, source (file or Jira, and which
tier), and whether comments were reviewed.

If `## Pre-Analysis` already exists (from `/atg:brief`), skip Step 2's own analysis and use it
as input.

### 2. Analyze

Extract requirements, ACs, comment takeaways, user flows, performance needs, dependencies, and
testing needs. Investigate the codebase: related functionality, services and repositories to
touch, comparable patterns, recent git history. Be skeptical: confirm the feature does not
already exist before planning new code.

Write `## Story analysis` (requirements summary, current state with `file:line`, gap analysis).

### 3. Architecture design (required)

Write `## Architecture design` with:

- `### Component diagram`: Mermaid or ASCII. Event flow, service/repository/external
  interactions, queue names, transaction and listener boundaries where relevant.
- `### Key implementation details`: 4 to 8 focused snippets (repository query signature,
  service orchestration, listener flow, flag wiring, validation rule, DDL). For each, say why it
  exists and which risk or edge case it addresses.

Stories touching 2+ components get the full version. Single-file changes get one mini diagram
and two snippets.

### 4. Dependencies, open questions, performance

- `## Dependencies`: external (SLB, RabbitMQ, DB, index, cache) and internal (modules, stories).
- `## Open questions`: required when no `## Pre-Analysis` exists or new questions arose. If
  Pre-Analysis already lists unresolved questions, add one carry-forward line instead of
  duplicating. Otherwise `- None at planning time.`
- `## Performance considerations`: required when the story touches queries, batches, messaging,
  or large loops (baseline, expected impact, index/batch strategy). Otherwise one line:
  `Not performance-sensitive for current scope.`

### 5. Estimate LOC

Sum production, test, docs, and substantial config. Write `## Lines of code estimate` with a
per-file breakdown and subtotals.

| Component | LOC |
|---|---|
| Simple CRUD operation | 50–100 |
| Service method | 30–60 |
| Repository query | 10–20 |
| Unit tests per service method | 80–120 |
| Integration tests per endpoint | 100–150 |
| Event listener | 40–80 |
| Feature flag (single file) | 80–120 |

Do not underestimate tests.

### 6. Feature flag decision

Needed for new user-facing behaviour, gradual rollout, or rollback risk. Not for bug fixes,
refactors, or docs. When needed, write `## Feature flag` and put the flag in Branch 1:

Omit this section entirely when the profile's `feature-flag` is `none`.

```markdown
## Feature flag
**Feature name**: `{snake_case}`   **Cookie**: `FF_{snake_case}=true`
**Interface** `{DomainConcept}` / **Noop** `Noop{DomainConcept}` / **Enabled** `{Descriptive}{DomainConcept}`
**File**: `src/main/kotlin/com/{package}/{DomainConcept}FeatureFlag.kt` (~100 LOC)
Branch 1: enabled impl throws UnsupportedOperationException, flag off, wired into services, zero behaviour change.
Later branches: replace the throw with real logic, flag stays off.
```

Omit the section entirely when no flag is needed. Pattern details live in `/atg:feature-flag`.

### 7. Split into branches

Apply the rule strictly. `T` is total LOC.

- `T ≤ 500`: 1 branch. ~400–500 is the natural single-branch size; smaller stays one branch too.
- `500 < T < 1000`: 2 branches, each ≤500, split roughly in half.
- `T ≥ 1000`: `r = T mod 500`. If `0 < r < 100`, use `floor(T/500)` branches and absorb the tail
  into the last slice (it may land slightly over 500). Otherwise `ceil(T/500)`.

Examples: 450 → 1. 400 → 1. 700 → 2. 1050 → 2 (tail 50 absorbed). 1750 → 4.

Choose a progression pattern:

- **A, flag required**: Branch 1 flag infrastructure and wiring (zero production risk), Branch 2
  core logic behind the disabled flag, Branch 3 endpoints, events, integration tests. Mandatory
  whenever a flag is needed; never put the flag last.
- **B, no flag, new system**: Branch 1 repositories and service core with unit tests, Branch 2
  controllers and integration tests.
- **C, no flag, extending existing system**: vertical slices (create+read, then update+delete).

Each branch needs: name `fc/{TICKET}-{name}`, LOC, files with per-file LOC, goal, depends-on,
testing strategy, acceptance criteria, PR description template, and a suggested commit order.

### 8. Write `implementation-plan.md`

Use the canonical section order from **atg-story-artifacts**. Branch content goes under
`## Branch strategy` as `### Branch N: \`fc/{TICKET}-{name}\` (~XXX LOC)`. Also write
`## Testing strategy` (per branch), `## Merge strategy` (sequential order, what works after
each merge, rollback per branch), `## Summary` (table: branch, LOC, files, tests, focus,
duration; timeline; risk; performance impact), an `## As-built` placeholder, and the
`## Next ATG command` footer pointing at `/atg:story-impl {TICKET}` (replace any brief footer).

Never `git add` anything under `bin/`.

### 9. Write the repo plan file

Always write the profile's `plans-path` (path relative to the
service, see rule doc `405-plans-location.md`). Read the two or three newest files there and
match their shape. Condensed, ~100 lines, under 5K:

```markdown
# {TICKET}: {short title}
Full plan: `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md`
Story snapshot: `bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-story.md`

## Summary
{3–6 bullets: what changes and why; explicit out-of-scope items and which ticket owns them; flag / migration / event: needed or not}

## Branch
`fc/{TICKET}-{slug}` (~XXX LOC, N branch(es))

## Decisions (brief + story-plan)
{Numbered. Every choice a reviewer might question, with the reason. Which reading of an ambiguous ticket you took. Which decisions are cheap to reverse.}

## Risks (carry into PR description)
{Omit if none. Non-additive changes, inferred contracts, invariants that do not hold as a reader would assume.}

## Files (planned)
{Paths. Close with "do not touch X, {ticket} owns it" where a sibling owns adjacent code.}

## Status
{Planned / Implemented on {branch} / Merged. Next: `/atg:...`}
```

Leave it uncommitted. It lands in the implementation branch's first commit via
`/atg:story-impl`, never on `main` alone.

### 10. Report

Reply with the preamble facts, the summary table, and the same `## Next ATG command` block that
ends the plan file.

## When the story is unclear

Ask before finalising, using AskUserQuestion. Do not assume on unverified points. If the story
assumes code that does not exist, write a `## Critical findings` block (missing, impact,
recommendation) and adjust scope or propose prerequisite stories.

**Next:** `/atg:story-impl {TICKET}` (run `/atg:feature-flag` first if Branch 1 needs one).
