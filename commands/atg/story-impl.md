---
description: Execute the story plan for the current branch: align git state, build a work queue from implementation-plan.md, implement it
---

# Story impl

Bridge `/atg:story-plan` to code. Read the `### Branch N:` slice, confirm the git branch matches,
emit an ordered work queue for this branch only, then implement it in the same session unless
`--queue-only`. Does not replace `/atg:verify`.

## Usage

```bash
/atg:story-impl                      # ticket inferred from branch or bin/stories
/atg:story-impl WBPR-4032
/atg:story-impl WBPR-4032 --branch 2 # which planned branch (default 1)
/atg:story-impl WBPR-4032 --queue-only   # print the checklist, edit nothing
```

## Steps

### 1. Load artifacts

Resolve the ticket and story directory per the **atg-story-artifacts** skill. Read
`implementation-plan.md` (Pre-Analysis, Branch strategy, testing, merge strategy) and
`{TICKET}-story.md` for ACs. If the plan is missing, stop: run `/atg:story-plan {TICKET}` first.

### 2. Align the git branch

Compare `git branch --show-current` with the planned name in `### Branch N:` (single-branch
stories: the one branch, or infer from the plan title). If they differ, print expected versus
actual and instruct `git checkout {planned}` or `git checkout -b {planned}` from main. Suggest
`git fetch origin` if `origin/main` may be behind.

### 3. Build the work queue

From the `### Branch N:` block plus global context (`## Feature flag`, `## Story analysis`, LOC
estimate) extract: ordered files to add or change with layer, the ACs this branch satisfies,
testing notes, and a suggested commit order. Feature flag file and wiring come first on Branch 1
when required.

A branch is a unit of review, so always propose a commit order, reusing one sketched in the plan
where present:

1. Every commit compiles and passes its own tests; a reviewer can stop anywhere.
2. Feature flag first, disabled, zero behaviour change.
3. Additive before wiring: helpers, indexes, DTOs, pure functions land before callers.
4. Tests travel with their subject, never a trailing "add tests" commit.
5. One behaviour change per commit, naming the AC.
6. Pure refactors stay separate and say so in the message.

Where a branch was kept whole instead of split, slice along the seam the split would have used.

```markdown
## Work queue — Branch {N} of {M} — {title}

### Prerequisites
- [ ] On branch `{name}`;  earlier branches merged (if N > 1)

### Suggested commit order
1. [ ] {subject} — {what lands, which AC, why it is safe to stop here}

### Implementation
1. [ ] {file or task}

### Verification (after code complete)
- [ ] `/atg:verify`, then `/atg:pattern-check {TICKET}` (advisory)
- [ ] Changeset when the profile requires one, see `/atg:changeset`
- [ ] `/atg:story-gap {TICKET}`
- [ ] Last branch only: fill `## As-built` (below), sync `.claude/plans/{TICKET}-{slug}.md`
- [ ] `/atg:ship {TICKET} --branch {N}`
```

### 4. Implement

Unless `--queue-only`, implement every Implementation item in order, committing along the
suggested order rather than in one lump. If the work diverges from the order, say so and revise
it. Follow the **atg-service-rules** skill. Run targeted `./gradlew test --tests '…'` for touched
specs when practical; the full gate is `/atg:verify`.

### 5. As-built (last branch only)

Fill `## As-built` with the pointer + delta pattern per **atg-story-artifacts**: no deviations →
`Implemented as planned — see Branch N: Changes. No deviations. Quality gates: tests, detekt,
CodeNarc, koverVerify.`; deviations → list only what changed. Then overwrite
`wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md` (and `.cursor/plans/{TICKET}.md` at the
monorepo root if one exists).

**Next:** `/atg:verify`
