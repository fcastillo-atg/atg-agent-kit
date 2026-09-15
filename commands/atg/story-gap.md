---
description: Verify every acceptance criterion from the story is addressed in the diff before shipping (blocks on a missing AC)
---

# Story gap: AC coverage

Check that every acceptance criterion has code and, ideally, a test in the diff. Blocks
`/atg:ship` when any AC is missing.

## Usage

```bash
/atg:story-gap {TICKET}
/atg:story-gap {TICKET} --branch N
```

Ticket, story directory, diff base, and `--branch` scoping: atg-story-artifacts skill.

## Steps

1. Read the ACs from `{TICKET}-story.md`, or fetch from Jira per the jira-cli skill when the
   file is missing. ACs appear as numbered items under "Acceptance Criteria", `- [ ]`
   checkboxes, or a "Definition of Done" list.
2. Read `implementation-plan.md` for planned scope to cross-reference against.
3. Get the diff (`--name-only` and full).
4. Classify each AC:

| Status | Criteria |
|---|---|
| ✅ Implemented + tested | Relevant code change and a spec covering the behaviour, both in the diff |
| ⚠️ Implemented, no test | Relevant code change, no matching test |
| ❌ Missing | Nothing in the diff addresses it |

Evidence heuristics:

| AC mentions | Look for |
|---|---|
| endpoint, API | controller or route change |
| service, business logic | service class change |
| persist, store, database | repository or entity change |
| validate | validator or `@Valid` |
| flag | `*FeatureFlag.kt` |
| migration, schema | `db/changelog/` file |
| event, publish | RabbitMQ publisher or listener |
| test | `*Spec.groovy` or `*Test.kt` |

When an AC is ambiguous and any plausible file is in the diff, lean to ⚠️ rather than ❌.

5. Print the table and verdict.

```
Story Gap Analysis — {TICKET}
Diff: origin/main...HEAD ({N} files changed)

| # | Acceptance Criterion | Status | Evidence |
|---|----------------------|--------|----------|
| 1 | {AC} | ✅ Implemented + tested | `LotService.kt:45`, `LotServiceSpec.groovy:89` |
| 2 | {AC} | ❌ Missing | — |

Coverage: {X}/{N} addressed | {Y} tested | {Z} missing
```

- No ❌: `Story gap check passed.` Note how many are ⚠️ for review.
- Any ❌: `Story gap check FAILED — do not ship.` List each missing AC with a one-line guess at
  what it needs. Never invoke `/atg:ship` from here.

**Next:** last branch: fill `## As-built` then `/atg:testing-doc {TICKET}`; otherwise `/atg:ship {TICKET} --branch N`
