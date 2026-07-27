---
description: Chain brief → story-plan → story-impl → (feature-flag) → verify → review-codebase → (changeset) → story-gap → testing-doc for one branch, fully autonomous, stopping only at a hard blocker. ship and qa-comment stay manual.
---

# Story Auto-Run: Chained Implementation (One Branch)

**Purpose:** Run the full implementation lifecycle for **one branch** of a story without manually invoking each `/atg:*` command in turn. Fully autonomous: no pause between steps except the one explicit exception below. Stops only on a genuine hard blocker. **Never invokes `/atg:ship` or `/atg:qa-comment`** — both stay manual.

**Blast radius:** this command writes and auto-fixes production code, may scaffold a feature flag, and may write a changeset file — all without a human checkpoint, except confirming the changeset bump type is flagged (not paused) for your review afterward. If you want a review checkpoint before implementation starts, run `/atg:story-plan` yourself first and review `implementation-plan.md`, then invoke this command with `--from story-impl`.

## Usage

```bash
/atg:story-auto-run {TICKET}                    # branch inferred from current git branch, or defaults to 1
/atg:story-auto-run {TICKET} --branch N         # explicit target branch
/atg:story-auto-run {TICKET} --skip-brief       # bypass brief even when no plan exists yet
/atg:story-auto-run {TICKET} --from STEP        # resume the chain at STEP, skipping everything before it
/atg:story-auto-run {TICKET} --with-scenarios   # passthrough to testing-doc's own flag
```

## Arguments

- `{TICKET}` — Jira ticket key (e.g. `WBPR-4032`)
- `--branch N` — which plan branch to execute (default: inferred from current branch name `fc/{TICKET}-*`, else `1`)
- `--skip-brief` — bypass `/atg:brief` even when no plan exists yet
- `--from STEP` — resume starting at `STEP`, skipping everything before it. `STEP` ∈ `{brief, story-plan, feature-flag, story-impl, verify, review-codebase, changeset, story-gap, testing-doc}`
- `--with-scenarios` — passthrough to `/atg:testing-doc`'s own flag

## Resume contract (read this before re-running)

Re-invoking this command **without `--from`** restarts the **entire chain from the top** for that branch — including `story-impl`, which is not `--queue-only` and may re-apply or duplicate changes on code you already hand-fixed after a blocker. **Always use `--from {step}`** to resume after manually fixing something:
- Fixed a failing test/lint/coverage issue by hand → `--from verify`
- Added code for a missing AC → `--from verify` (re-verify before re-checking gap)

## Execution Steps

### Step 0: Preflight safety

1. `git status --short` — **if the working tree is dirty**, stop and tell the user to commit or `git stash -u` first. Do not proceed to branch-switching over uncommitted work.
2. Resolve `{TICKET}` and the story directory: `bin/stories/{year}/{month}/{TICKET}-{slug}/` (same convention as every other atg command).

### Step 1: Story-level resolution (skip if `--from` is at or past `story-impl`)

- `implementation-plan.md` **missing entirely** and `--skip-brief` not passed: run `/atg:brief {TICKET} --auto` (auto mode — logs assumptions instead of asking questions, required to keep this chain autonomous), then `/atg:story-plan {TICKET}` (it detects `## Pre-Analysis` and skips its own duplicate analysis).
- `implementation-plan.md` **exists with `## Branch strategy` or `## Lines of code estimate`** (plan already complete): skip both brief and story-plan — go to Step 2.
- `implementation-plan.md` **exists with only `## Pre-Analysis`**: skip brief, run `story-plan` only.
- **Carry forward every assumption brief logged** — surface them prominently in the final report (Step 11). A silently-logged assumption in an autonomous run is exactly what derails an implementation unnoticed.

### Step 2: Resolve target branch N and align git branch

1. `N` from `--branch`, else inferred from the current branch name, else default `1`.
2. Read `implementation-plan.md` → `## Branch strategy` → `### Branch N:` for the planned branch name.
3. If current branch ≠ planned branch (only after Step 0's dirty-check passed clean): `git checkout {planned-branch}`, creating it from `main` with `git checkout -b` if it doesn't exist yet.

### Step 3: Feature flag — conditional (skip if `--from` is past `feature-flag`)

If `implementation-plan.md`'s `## Feature flag` section indicates branch `N` is where the flag is introduced, **and** the corresponding `*FeatureFlag.kt` file doesn't already exist in the codebase: run `/atg:feature-flag {description derived from the ## Feature flag section}` to scaffold the single-file interface/Noop/Enabled/ProxyFactory pattern.

If no feature flag applies to this branch, skip silently — do not mention it in the report.

### Step 4: Implementation (skip if `--from` is past `story-impl`)

Run `/atg:story-impl {TICKET} --branch N`.

**Critical boundary:** story-impl here does **implementation only** — production code + tests from the work queue's "Implementation" section, including wiring an already-scaffolded feature flag (Step 3) into services/controllers, but **not** regenerating the flag file itself. story-impl's own doc says to "implement every item in the checklist in order," which is ambiguous about whether that includes the checklist's **Verification** section (`/atg:verify`, `/atg:story-gap`, `/atg:ship`). **When invoked from this chain, treat that Verification section as informational only — do not act on any of those items here.** `story-auto-run` owns invoking verify/review-codebase/changeset/story-gap/as-built as its own separate steps below, in order, exactly once. `/atg:ship` must never fire as a side effect of this chain, full stop.

### Step 5: Verify (skip if `--from` is past `verify`)

Run `/atg:verify`. It has its own internal max-3-cycles auto-fix loop per gate (tests → Detekt → CodeNarc → Kover).

- **Converges** (all gates green): continue to Step 6.
- **Does not converge** after its own retry cap: **STOP.** Report which gate failed and why. Tell the user to fix manually, then resume with `/atg:story-auto-run {TICKET} --branch N --from verify`.

### Step 6: Review-codebase (skip if `--from` is past `review-codebase`)

Run `/atg:review-codebase {TICKET} --branch N`. Advisory only, per its own doc — **never blocks**. Include findings in the final report; continue regardless.

### Step 7: Changeset — conditional (skip if `--from` is past `changeset`)

If `git diff origin/main...HEAD --name-only` touches `wavebid-a2o-service/` or `wavebid-a2o-ui/`, **and** no `.changeset/*.md` (excluding `README.md`) already exists on the branch: follow the procedure in `.cursor/commands/gsd/changeset-wavebid-a2o.md` **directly** — `/atg:changeset` itself is only a pointer and does not write the file.

1. Determine scope (which package(s) changed) from the diff.
2. Determine bump type from the heuristic table (breaking change → major, new user-visible feature/endpoint → minor, fix/refactor/style/DX → patch). **Auto-pick — do not ask for confirmation.** This intentionally overrides that procedure's own "never skip it" instruction for bump-type confirmation, in favor of staying fully autonomous; the trade-off is loud visibility in the final report instead of a pause.
3. Generate the slug from the branch name; draft the one-sentence description from the plan's brief description or the latest commit subject.
4. Write `.changeset/[slug].md` with the exact frontmatter format (single-quoted package names) and `git add` it.
5. Record for the final report: `⚠️ Changeset auto-picked ({bump type}) for {package(s)} — confirm before merge.`

If a changeset already exists on the branch: leave it alone, note it exists, do not overwrite. If out of scope (no service/ui files changed): skip silently.

### Step 8: Story-gap (skip if `--from` is past `story-gap`)

Run `/atg:story-gap {TICKET} --branch N`.

- **All ACs ✅/⚠️**: continue to Step 9.
- **Any AC ❌ Missing**: **STOP.** Print the gap table. Tell the user to implement the missing AC(s), then resume with `/atg:story-auto-run {TICKET} --branch N --from verify` (re-verify before re-checking gap, since new code was added). Do **not** proceed to Step 9/10 in this case.

### Step 9: As-built fill — last branch only

If `N == M` (last or only branch): fill `## As-built` in `implementation-plan.md` using the pointer + delta pattern from `story-impl.md` — `"Implemented as planned — see Branch N. No deviations."` one-liner if nothing changed from the plan, or a list of only what changed. This has to happen here because `/atg:ship` — which normally reminds about this — is excluded from this chain. Sync both copies: `.claude/plans/{TICKET}-{slug}.md` and `../.cursor/plans/{TICKET}.md`.

If `N < M`: skip; note in the report that As-built and testing-doc will run once the final branch reaches this point.

### Step 10: Testing-doc — last branch only (skip if `--from` is past `testing-doc`, or if `N < M`)

Run `/atg:testing-doc {TICKET}` (append `--with-scenarios` if that flag was passed to this command).

### Step 11: Final report

Run `/atg:status {TICKET}` to produce the branch/Jira overview — reuse its existing output rather than inventing a new summary format. Then append, prominently:

- Any assumptions brief logged this run (or "brief skipped — plan already existed")
- review-codebase finding count (advisory, non-blocking) — link to the findings table above
- Whether a feature flag was scaffolded this run
- Whether a changeset was auto-created, with its **auto-picked bump type flagged for confirmation** (or "changeset already existed — left as-is", or "no changeset needed — diff out of scope")
- story-gap coverage summary
- **Next manual steps:**
  - `/atg:ship {TICKET} --branch N` — and if a changeset was auto-created, confirm/adjust the bump type before merging
  - If `N < M`: `re-run /atg:story-auto-run {TICKET} --branch {N+1} once this branch is merged`

## Error Handling

| Situation | Action |
|-----------|--------|
| Working tree dirty at Step 0 | Stop; ask user to commit or `git stash -u` |
| `implementation-plan.md` missing, `--skip-brief` not passed | Run brief `--auto` then story-plan |
| `implementation-plan.md` already complete | Skip brief + story-plan |
| Branch mismatch (tree clean) | `git checkout` (create if needed), then proceed |
| No feature flag needed for this branch | Skip Step 3 silently |
| `verify` doesn't converge (after its own 3 cycles) | Stop; report; resume via `--from verify` after manual fix |
| `review-codebase` findings | Never blocks; included in report only |
| Diff out of changeset scope, or changeset already exists | Skip Step 7 silently / leave existing file alone |
| `story-gap` finds ❌ Missing AC | Stop; report; resume via `--from verify` after manual fix |
| Not the last branch | Skip As-built fill + testing-doc; note when they'll run |

## Next Steps

1. `/atg:ship {TICKET} --branch N` (manual — confirm/adjust changeset bump type first if one was auto-created)
2. If this story has more branches: repeat this command with `--branch {N+1}` after the current branch is merged
3. After all branches are merged: `/atg:review-feedback` per PR as comments arrive, then `/atg:retro {TICKET}`
