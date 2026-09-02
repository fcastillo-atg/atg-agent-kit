---
description: Execute the story-plan for the current branch — align git state, build a work queue from implementation-plan.md
---

# Story impl: Execute Story Plan (Current Branch)

**Purpose:** Bridge `/atg:story-plan` artifacts to hands-on coding. Reads `implementation-plan.md` (including `## Branch strategy` and `### Branch N:` sections), confirms the git branch matches the planned slice, produces an ordered work queue for **this branch only**, then **implements that queue in the same session** (code + tests) unless the user explicitly asks for a checklist only (e.g. `--queue-only` or “just the work queue”). After implementation, run **`/atg:verify`** (or targeted `./gradlew test`) — this command does not replace the full verify gate.

## Usage

```bash
/atg:story-impl                    # infer {TICKET} from branch or bin/stories
/atg:story-impl WBPR-4032          # explicit ticket
/atg:story-impl WBPR-4032 --branch 2   # which planned branch you are implementing
```

## Arguments

- `{TICKET}` — optional if inferrable from `fc/{TICKET}-*` or `bin/stories/**/*{TICKET}*`
- `--branch N` — which branch number from `## Branch strategy` in `implementation-plan.md` (default: 1 if single-branch story)
- `--queue-only` — print the checklist only; do **not** edit source (for human-driven implementation)

## Execution Steps

### Step 1: Resolve ticket and story directory

1. If `{TICKET}` not provided:
   - `git branch --show-current` — extract `WBPR-NNNN` from patterns like `fc/WBPR-4032-feature-name`
   - Or search: `find bin/stories -type d -name '*WBPR-*' | head -5` and pick the directory matching active work
2. Locate the story folder: `bin/stories/{year}/{month}/{TICKET}-{slug}/`
   - If multiple matches, prefer the one containing `implementation-plan.md`

### Step 2: Load artifacts

Read (in order):

1. `implementation-plan.md` — full plan (including `## Pre-Analysis` if present from `/atg:brief`), **`## Branch strategy`** with per-branch `### Branch N:` sections, testing, merge strategy, summary
2. `{TICKET}-story.md` — acceptance criteria (for cross-check while implementing)

**Gate:** If `implementation-plan.md` is missing, stop and tell the user to run `/atg:story-plan {TICKET}` first.

**Legacy:** If only `branch-strategy.md` exists (old folders) and `implementation-plan.md` is absent, tell the user to merge content into `implementation-plan.md` or re-run `/atg:story-plan {TICKET}` — do not rely on `branch-strategy.md` alone for new work.

### Step 3: Align git branch with the plan

1. Current branch: `git branch --show-current`
2. From `implementation-plan.md`, under `## Branch strategy`, find the **`### Branch N:`** section for the requested `N` and read the **planned** git branch name (e.g. `` `fc/WBPR-4032-lot-address-flag` `` in the heading or body).
3. For **single-branch** stories (no `## Branch strategy` or only one `### Branch 1:`), use that branch name or infer from the plan title and current work.
4. If they differ:
   - Print: expected vs actual
   - Instruct: `git checkout {planned-branch}` or create from main: `git checkout -b {planned-branch}` following team naming
5. If `origin/main` is behind, suggest: `git fetch origin` before comparing diffs

### Step 4: Build work queue (this branch only)

From `implementation-plan.md`, extract **only** the sections for branch `N`:

- The `### Branch N:` block under `## Branch strategy` (files, changes, testing, AC, PR template)
- Plus any global context from `## Feature flag`, `## Story analysis`, or `## Lines of code estimate` that applies to this slice
- Ordered list of files to add or change (with layer: api, service, repository, domain, feature flag, migration)
- Acceptance criteria that this branch must satisfy
- If branch 1 and a feature flag is required: **feature flag file and wiring first** (per story-plan safety rules)
- Testing notes: which specs or scenarios to add or extend
- A **suggested commit order** (see below)

**Always propose a suggested commit order.** A branch is a unit of review, not a unit of work: even
a small slice reviews better as a few commits that each tell one story. This matters most when a
branch lands above the ~500 LOC guideline, where it is the main thing keeping the PR reviewable,
but it is worth doing at any size.

Derive the order with these rules:

1. **Every commit compiles and passes its own tests.** A reviewer must be able to stop at any commit.
2. **Feature flag first**, disabled. Zero behaviour change.
3. **Additive before wiring.** New helpers, indexes, DTOs and pure functions land before anything
   calls them, so the commit that changes behaviour is small and obvious.
4. **Tests travel with their subject**, not batched into a trailing "add tests" commit.
5. **One behaviour change per commit.** Name the AC it satisfies.
6. **Pure-refactor commits stay separate** from behaviour commits, and say so in the message.

Where the plan has a `## Branch strategy` with a commit order already sketched, reuse it rather
than inventing a new one. Where a branch was deliberately kept whole instead of split, slice the
commit order along the seam the split would have used, so peeling it apart later stays cheap.

Output a **numbered checklist** the implementer can tick off:

```markdown
## Work queue — Branch {N} of {M} — {short title}

### Prerequisites
- [ ] On branch `{branch-name}`
- [ ] Dependencies from earlier branches merged (if N > 1)

### Suggested commit order
1. [ ] {commit subject} — {what lands, which AC, why it is safe to stop here}
2. [ ] ...

### Implementation
1. [ ] {file or task}
2. [ ] ...

### Verification (after code complete)
- [ ] `/atg:verify`
- [ ] If this PR changes user-visible behavior under `wavebid-a2o-service/` or `wavebid-a2o-ui/`: add a changeset (see Next Steps) or plan `skip-changelog` on the PR
- [ ] `/atg:story-gap {TICKET}`
- [ ] **If this is the last branch**: fill in `## As-built` in `implementation-plan.md` using the **pointer + delta pattern** — do not re-document layers that matched the plan:
  - **No deviations**: write `"Implemented as planned — see [Branch N: Changes](#branch-strategy). No deviations. Quality gates: ✅ tests, ✅ detekt, ✅ CodeNarc, ✅ koverVerify."`
  - **Deviations exist**: list only what changed from the plan (added file, dropped field, renamed method); leave unchanged layers undocumented.
  After filling, sync the repo-committed plan: overwrite `wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md` (and `.cursor/plans/{TICKET}.md` at the monorepo root if one exists for this ticket).
- [ ] `/atg:ship {TICKET} --branch {N}`
```

### Step 5: Execute (agent behavior)

Unless **`--queue-only`** (or the user asked only for the queue): **implement** every item in the checklist in order — create/modify production code and tests.

**Commit along the suggested commit order** rather than in one lump at the end. Do not stage
everything and split it retroactively; work to the order so each commit is genuinely self-contained.
If the real work diverges from the proposed order, say so and revise the order, do not silently
abandon it.

- Match existing codebase patterns (see `wavebid-a2o-service/CLAUDE.md` and the numbered rule docs in `wavebid-a2o-service/.claude/rules/`)
- Kotlin: expression bodies where appropriate, `OrThrow`/`OrNull`, `mu.KotlinLogging`
- Tests: Groovy/Spock only for new tests; follow CodeNarc rules
- Run **targeted** `./gradlew test --tests '…'` for the specs you touched when practical; full **`/atg:verify`** remains the pre-ship gate

## Changeset (do not duplicate full procedure)

PRs that touch `wavebid-a2o-service/` or `wavebid-a2o-ui/` need a `.changeset/*.md` file (CI) unless the PR will have the **`skip-changelog`** label.

- **Cursor:** run **`/gsd/changeset-wavebid-a2o`** — full procedure in monorepo `.cursor/commands/gsd/changeset-wavebid-a2o.md`
- **Claude Code / no Cursor:** run **`/atg:changeset`** (short pointer to the same rules) or open that file and follow it manually

Never run interactive `pnpm changeset` from an agent session without a TTY; the GSD command writes the file directly.

## Integration with Other Commands

| Command | Role |
|---------|------|
| `/atg:story-plan` | Produces the artifacts this command consumes |
| `/atg:feature-flag` | Use when branch 1 needs flag scaffolding |
| `/atg:verify` | Quality gates after implementation |
| `/gsd/changeset-wavebid-a2o` or `/atg:changeset` | Changelog file before ship (when in scope) |
| `/atg:story-gap` | AC coverage before PR |
| `/atg:ship` | Open PR (includes changeset pre-flight) |

## Next Steps

1. Complete the work queue for this branch
2. `/atg:verify`
3. When the diff includes user-visible service or UI changes: add changeset (`/gsd/changeset-wavebid-a2o` or `/atg:changeset`) or confirm **`skip-changelog`** on the upcoming PR
4. `/atg:story-gap {TICKET}`
5. **Last branch only:** fill in `## As-built` in `implementation-plan.md` using the pointer + delta pattern — one line if no deviations (`"Implemented as planned — see Branch N"`), or list only what changed. `/atg:testing-doc` falls through to `## Branch strategy` when As-built says "as planned". Sync the repo-committed plan: `wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md` (and `.cursor/plans/{TICKET}.md` at the monorepo root if one exists).
6. `/atg:ship {TICKET} --branch {N}`
