---
description: Verify all acceptance criteria from the story are addressed before shipping
---

# Story Gap: AC Coverage Check

**Purpose:** After implementation, check that every acceptance criterion from the Jira story is addressed in code and tests before running `/atg:ship`. Blocks shipping if any AC is missing.

## Usage

```bash
/atg:story-gap {TICKET}              # check current branch against main
/atg:story-gap {TICKET} --branch N  # scope check to branch N's changes only
```

## Arguments

- `{TICKET}` — Jira ticket key (e.g. `WBPR-4032`)
- `--branch N` — restrict diff to files changed in branch N (uses `implementation-plan.md` → `## Branch strategy` → `### Branch N:` to determine base)

## Execution Steps

### Step 1: Read the story

Look for the story file at `bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-story.md`.

If the file exists, read it. If not, fetch the story from Jira per the **jira-cli** skill: `acli jira workitem view {TICKET} --fields summary,description,comment --json` first, falling back to `mcp__mcp-atlassian__jira_get_issue`.

Extract all acceptance criteria — typically listed as:
- Numbered items under an "Acceptance Criteria" heading
- Checkbox items (`- [ ]`)
- Items under a "Definition of Done" section

### Step 2: Read the implementation plan

Look for `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md`.

If found, extract the planned ACs / technical scope — use this to cross-reference against the story ACs.

### Step 3: Get the diff

```bash
git diff origin/main...HEAD --name-only     # files changed
git diff origin/main...HEAD                 # full diff for evidence matching
```

If `--branch N` is provided, read `implementation-plan.md` (`## Merge strategy` / `### Branch N:`) to infer the base branch for branch N and scope the diff accordingly. If the plan does not spell out bases, fall back to comparing against `origin/main` and note the limitation.

### Step 4: Evaluate each AC

For each acceptance criterion, look for implementation evidence in:
- **Files changed** — is there a file that could implement this AC?
- **Diff content** — are there code additions relevant to this AC?
- **Test files** — is there a Spock spec or test that covers this AC?

Classify each AC as:

| Status | Criteria | Indicator |
|--------|----------|-----------|
| ✅ Implemented + tested | Code change exists AND a test covers this behavior | File + test both in diff |
| ⚠️ Implemented, no test | Code change exists but no test covers this path | File in diff, no matching test |
| ❌ Missing | No code change found that addresses this AC | Absent from diff |

### Step 5: Output coverage table

Print the full AC coverage table:

```
Story Gap Analysis — {TICKET}
Diff: origin/main...HEAD  ({N} files changed)

| # | Acceptance Criterion | Status | Evidence |
|---|----------------------|--------|----------|
| 1 | {AC text} | ✅ Implemented + tested | `src/.../LotService.kt:45`, `LotServiceSpec.groovy:89` |
| 2 | {AC text} | ⚠️ Implemented, no test  | `src/.../Controller.kt:12` |
| 3 | {AC text} | ❌ Missing               | — |

Coverage: {X}/{N} ACs addressed  |  {Y} tested  |  {Z} missing
```

### Step 6: Verdict

**If all ACs are ✅ or ⚠️** (no ❌ Missing):
```
✅ Story gap check passed — all {N} ACs are addressed.
   {Y} ACs have test coverage; {Z} have code but no test (review recommended).

Proceed to: /atg:ship {TICKET} [--branch N]
```

**If any AC is ❌ Missing:**
```
❌ Story gap check FAILED — {Z} AC(s) missing from diff.

Blocked: do NOT ship until missing ACs are addressed.
Run /atg:verify after fixing, then re-run /atg:story-gap {TICKET}.
```

In the blocked case, do **not** invoke `/atg:ship` automatically.

## Evidence Matching Heuristics

Use these rules when matching diff content to ACs:

| AC keyword | Look for in diff |
|-----------|-----------------|
| "endpoint" / "API" | Controller or route change |
| "service" / "business logic" | Service class change |
| "database" / "persist" / "store" | Repository or entity change |
| "validate" / "validation" | Validator class or `@Valid` annotation |
| "flag" / "feature flag" | `*FeatureFlag.kt` file |
| "migration" / "schema" | `src/main/resources/db/changelog/` file |
| "event" / "publish" | RabbitMQ or event publisher change |
| "test" | `*Spec.groovy` or `*Test.kt` in diff |

When an AC is ambiguous, lean toward ⚠️ (implemented, no test) rather than ❌ (missing) if there is *any* plausible file in the diff.

## Example Session

```
/atg:story-gap WBPR-4032

📖 Reading story from bin/stories/2026/04/WBPR-4032-lot-address/WBPR-4032-story.md...
   Found 5 acceptance criteria.

📋 Reading implementation plan...
   3 planned components confirmed.

🔍 Diff: origin/main...HEAD (12 files changed)

Story Gap Analysis — WBPR-4032
==============================

| # | Acceptance Criterion                                  | Status                    | Evidence                                                  |
|---|-------------------------------------------------------|---------------------------|-----------------------------------------------------------|
| 1 | Lot inherits address from auction when null           | ✅ Implemented + tested    | LotService.kt:45, LotServiceSpec.groovy:89                |
| 2 | Lot retains custom address when explicitly set        | ✅ Implemented + tested    | LotService.kt:52, LotAddressSpec.groovy:112               |
| 3 | Feature flag FF_lot_address_inheritance controls gate | ✅ Implemented + tested    | LotAddressInheritanceFeatureFlag.kt, FeatureFlagSpec.groovy |
| 4 | PUT /lots/{id} updates inherited address on update    | ⚠️ Implemented, no test    | LotController.kt:78                                       |
| 5 | Existing lots not affected by migration               | ❌ Missing                  | —                                                         |

Coverage: 4/5 ACs addressed  |  3 tested  |  1 missing

❌ Story gap check FAILED — 1 AC missing from diff.

Missing:
  AC 5: "Existing lots not affected by migration"
  → Likely needs a Liquibase migration with data preservation check and a repository integration test.

Blocked: do NOT ship until missing ACs are addressed.
```

## Next Steps

1. Fix any Missing ACs, re-run `/atg:verify`
2. Re-run `/atg:story-gap {TICKET}` to refresh the coverage table
3. When all ACs are ✅ or ⚠️: `/atg:ship {TICKET} --branch {N}`
