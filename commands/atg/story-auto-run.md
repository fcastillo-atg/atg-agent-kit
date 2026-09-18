---
description: Chain brief → story-plan → feature-flag → story-impl → verify → pattern-check → changeset → story-gap → testing-doc for one branch, unattended; ship and qa-comment stay manual
---

# Story auto-run

Run one branch of a story through the implementation chain without invoking each command by
hand. Autonomous: no pauses, stops only at a hard blocker. Never runs `/atg:ship` or
`/atg:qa-comment`. Order and gate semantics: **atg-lifecycle**. Paths: **atg-story-artifacts**.

Blast radius: this writes and auto-fixes production code, may scaffold a feature flag, and may
write a changeset, all without a checkpoint. For a review point before coding, run
`/atg:story-plan` yourself, review the plan, then invoke this with `--from story-impl`.

## Usage

```bash
/atg:story-auto-run {TICKET}                   # branch from current git branch, else 1
/atg:story-auto-run {TICKET} --branch N
/atg:story-auto-run {TICKET} --skip-brief      # no brief even when no plan exists
/atg:story-auto-run {TICKET} --from STEP       # resume at STEP
/atg:story-auto-run {TICKET} --with-scenarios  # passthrough to testing-doc
```

`STEP` ∈ `brief, story-plan, feature-flag, story-impl, verify, pattern-check, changeset,
story-gap, testing-doc`.

**Resume contract.** Re-running without `--from` restarts the whole chain, including
`story-impl`, which may re-apply changes over code you hand-fixed. After fixing a blocker by
hand, always resume with `--from verify`.

## Steps

0. **Preflight.** `git status --short`; if dirty, stop and ask for a commit or `git stash -u`.
   Resolve the ticket and story directory.

1. **Story-level resolution** (skip when `--from` is at or past `story-impl`).
   No `implementation-plan.md` and no `--skip-brief`: run `/atg:brief {TICKET} --auto`, then
   `/atg:story-plan {TICKET}`. Plan with only `## Pre-Analysis`: run story-plan only. Plan
   already complete: skip both. Carry every logged assumption into the final report.

2. **Align the branch.** `N` from `--branch`, else the current branch name, else 1. Read the
   planned name from `### Branch N:`. If the current branch differs, `git checkout` it,
   creating from `main` if needed.

3. **Feature flag** (conditional). If `## Feature flag` puts the flag on branch N and no
   `*FeatureFlag.kt` for it exists, run `/atg:feature-flag {description from the plan}`.
   Otherwise skip silently.

4. **Implement.** Run `/atg:story-impl {TICKET} --branch N`. Inside this chain, story-impl does
   implementation only: production code and tests from its work queue, including wiring an
   already-scaffolded flag. Its own Verification checklist is informational here; this command
   owns verify, pattern-check, changeset, story-gap, and As-built as separate steps, each once.
   `/atg:ship` must never fire as a side effect.

5. **Verify.** Run `/atg:verify`. Converges: continue. Does not converge after its own retry
   cap: stop, report the failing gate, and tell the user to resume with
   `--branch N --from verify`.

6. **Pattern-check.** Run `/atg:pattern-check {TICKET} --branch N`. Advisory; record findings,
   continue.

7. **Changeset** (conditional). Read `changeset` from **atg-repo-profile**. Value `none`: skip
   this step entirely and say so in the report. Otherwise, if the diff touches the paths the
   profile declares and no changeset file exists on the branch, follow the profile's procedure
   directly: scope from the diff, bump type from its heuristic table (breaking → major, new
   user-visible behaviour → minor, else patch), slug from the branch, one-sentence description
   from the plan. Auto-pick the bump without asking, then flag it loudly in the report. Existing
   changeset: leave it. Out of scope: skip.

8. **Story-gap.** Run `/atg:story-gap {TICKET} --branch N`. Any ❌ Missing AC: stop, print the
   table, tell the user to implement it and resume with `--from verify`.

9. **As-built** (last branch only). Fill `## As-built` in pointer or deviation form per
   atg-story-artifacts and sync the `.claude/plans/` copy. Earlier branches: note when it will run.

10. **Testing-doc** (last branch only). Run `/atg:testing-doc {TICKET}` with `--with-scenarios`
    when passed through.

11. **Report.** Run `/atg:status {TICKET}` and append: assumptions from brief (or "brief
    skipped"), pattern-check finding count, whether a flag was scaffolded,
    `⚠️ Changeset auto-picked ({bump}) for {packages} — confirm before merge` (or "existed" /
    "not needed"), story-gap coverage, and the manual steps below.

**Next:** `/atg:ship {TICKET} --branch N` (confirm the changeset bump first, where the profile
declares one); if `N < M`,
re-run with `--branch {N+1}` once this branch merges.
