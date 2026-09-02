---
description: Post-merge retrospective — mine session artifacts and suggest durable patterns for the user to review and selectively add to the service CLAUDE.md and .claude/rules/
---

# Retro: Post-Merge Learning Capture

**Purpose:** After a story's PRs are all merged, mine the implementation artifacts for durable patterns and **present them for the user to review**. The user decides which ones to add and to which file — nothing is written automatically.

## Usage

```bash
/atg:retro {TICKET}
```

## When to Run

Run this command **after the last PR for a story is merged** into main.

Do NOT run mid-story (while branches are still open) — the full picture isn't available yet.

## Execution Steps

### Step 1: Locate story artifacts

Find all artifacts for `{TICKET}` under `bin/stories/{year}/{month}/{TICKET}-{slug}/`:

```
bin/stories/{year}/{month}/{TICKET}-{slug}/
├── {TICKET}-story.md           ← original requirements
├── implementation-plan.md      ← planned scope, `## Branch strategy`, testing, merge order
└── testing/                    ← manual test guide (+ optional scenarios/)
    └── TESTING-GUIDE.md
```

If the directory is not found, search `bin/stories/` recursively for `*{TICKET}*`.

### Step 2: Read deduplication baseline

Read the numbered rule docs in `wavebid-a2o-service/.claude/rules/` and `wavebid-a2o-service/CLAUDE.md` to understand what patterns are already documented. **Never suggest a pattern that is already captured** — duplicates reduce signal.

### Step 3: Mine PR comments

For each PR associated with this ticket:

```bash
gh pr list --search "{TICKET}" --state merged --json number,title | jq '.[].number'
```

For each PR number found:
```bash
gh pr view {PR_NUMBER} --comments
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments
```

Extract comments that were **acted on** (i.e., resulted in a code change or explicit acknowledgement). Filter out:
- Bot comments about file counts or generic checks
- Comments marked as resolved without action
- Praise-only comments with no technical content

### Step 4: Mine implementation plan for scope surprises

Read `implementation-plan.md` and note:
- Any component that was added **not** in the original plan
- Any LOC estimate that was significantly off (>50% variance)
- Any dependency that was discovered late (e.g., a missing Liquibase migration, an unexpected MapStruct mapping)

**If `## As-built` section is present:** use it as the authoritative "what actually shipped" reference. Compare it against `## Branch strategy` / `## Story analysis` to spot the delta between plan and reality — this is the most reliable way to find scope surprises without re-reading the full PR diff.

**If `## As-built` section is missing:** note it as a housekeeping item and offer to fill it in now (while the diff is fresh) before proceeding. Prompt the user:

```
⚠️  implementation-plan.md has no ## As-built section.
    This section documents the final state of every changed layer so future
    commands (/atg:testing-doc, next team member, etc.) have an accurate picture.

    Fill it in now? (Recommended — the diff is fresh.)
    Layers to document: DB, entity/model, API response, repository, service/handler, Liquibase.
```

If the user agrees, draft and write the `## As-built` section based on the merged PR diff before continuing.

### Step 5: Check Detekt / CodeNarc patterns

Look at the diff across all merged PRs:

```bash
gh pr list --search "{TICKET}" --state merged --json headRefName | jq -r '.[].headRefName' | while read branch; do
  git log --oneline origin/main..origin/$branch 2>/dev/null
done
```

Look for patterns in commit messages like `fix(detekt)`, `fix(codenarc)`, or multi-attempt fixes — these suggest a recurring style issue worth suggesting.

### Step 6: Extract pattern candidates

Apply the "would this happen again?" test to every candidate. Only include patterns that:
- Occurred in this story AND are general enough to recur in future stories
- Are NOT already in `wavebid-a2o-service/CLAUDE.md` or `wavebid-a2o-service/.claude/rules/`
- Are concrete and actionable (not vague advice)

For each candidate, note the suggested target file (for reference — the user decides):

All rule docs live under `wavebid-a2o-service/.claude/rules/` (numbered by topic) — there is no
root-level `CLAUDE.md` or `service-patterns.md` in this monorepo.

| Pattern category | Suggested target file |
|-----------------|----------------------|
| Kotlin style, Detekt violations | `wavebid-a2o-service/.claude/rules/002-kotlin.md` or `403-detekt-extra-violations.md` |
| Groovy/Spock style, CodeNarc violations, test fixtures | `wavebid-a2o-service/.claude/rules/101-test-patterns.md` or `103-tests.md` |
| Coverage gaps (missed branch/line patterns) | `wavebid-a2o-service/.claude/rules/402-backend-quality-checks.md` |
| Feature flag patterns | `wavebid-a2o-service/.claude/rules/303-feature-flags.md` |
| ATG-specific Spring/Kotlin gotchas | `wavebid-a2o-service/.claude/rules/302-spring-boot.md` |
| Recurring reviewer feedback themes | `wavebid-a2o-service/CLAUDE.md` |
| Liquibase/migration gotchas | `wavebid-a2o-service/.claude/rules/202-postgresql-migrations.md` or `203-liquibase-formatting.md` |

A pattern that belongs to the `/atg:*` commands themselves (not the codebase) goes in the kit
instead: edit the command in `~/ATG/atg-agent-kit/commands/atg/` and re-run `link.sh`.

### Step 7: Present patterns for review — STOP and wait

**Do NOT write anything to `CLAUDE.md`, a rule doc, or any other file.**

Print the full pattern report and stop. The user will decide what to add:

```
🔍 Retro complete for {TICKET}

=== Mining summary ===
  ✓ Implementation plan: {N} scope note(s)
  ✓ PR comments: {N} acted on ({breakdown})
  ✓ Detekt/CodeNarc: {pattern summary or "none recurring"}

=== Suggested patterns ({N} candidates) ===

──────────────────────────────────────────────────────────────
Pattern 1 of N — suggested target: {file}
Source: {PR comment / commit / plan delta}

{Full ready-to-paste text for the pattern, formatted as it
 would appear in the target file — bullet, code block, etc.}
──────────────────────────────────────────────────────────────
Pattern 2 of N — suggested target: {file}
Source: {PR comment / commit / plan delta}

{Full ready-to-paste text}
──────────────────────────────────────────────────────────────
... (repeat for all candidates)

=== To apply ===
Review the patterns above and add the ones you want to keep:
  - Copy the text and paste into the suggested file, or
  - Tell me "add pattern 1 to 002-kotlin.md" and I'll do it for you.

Nothing has been written yet.
```

**Stop here.** Do not commit anything. Wait for the user to confirm which patterns (if any) to write.

### Step 8: Apply on user instruction only

Only write to a target file when the user explicitly says so (e.g., "add pattern 1", "add all", "skip 2 and add the rest"). Then:

- **Append** the exact suggested text to the relevant section of the target file
- **Never rewrite** existing content — append only
- Show a brief confirmation of what was appended and where

### Step 9: Commit only when user is done

After the user has accepted or rejected all patterns, ask once:

```
Commit the changes to {file(s)}?
  git add {files}
  git commit -m "chore(retro): capture learnings from {TICKET} [$(date +%Y-%m-%d)]"
```

**Skip the commit** if no patterns were written.

---

## What NOT to Suggest

Do not suggest a pattern for:
- One-off decisions specific to this story's domain
- Patterns already in `wavebid-a2o-service/CLAUDE.md` or a rule doc under `wavebid-a2o-service/.claude/rules/`
- Reviewer preferences that contradict the codebase's established conventions
- Changes made to satisfy a single reviewer who later retracted the comment

## Example Output

```
🔍 Retro complete for WBPR-4032

=== Mining summary ===
  ✓ Implementation plan: 1 scope note — Liquibase migration missing from initial estimate
  ✓ PR comments: 3 acted on (1 Kotlin null-handling, 1 Spock fixture, 1 Kover exclusion)
  ✓ CodeNarc: ExpressionBodySyntax recurred in 2 files across 2 branches

=== Suggested patterns (2 candidates) ===

──────────────────────────────────────────────────────────────
Pattern 1 of 2 — suggested target: wavebid-a2o-service/.claude/rules/002-kotlin.md
Source: PR #451 reviewer comment (acted on in commit a2b77e4)

- When a service method returns `null` for not-found, always log before returning:
  `LOG.info { "Entity $id not found" }; return null` — otherwise Detekt's `EmptyFunctionBlock`
  rule may fire on the logger-less path and CodeNarc can miss implicit null returns in Groovy specs.
──────────────────────────────────────────────────────────────
Pattern 2 of 2 — suggested target: wavebid-a2o-service/CLAUDE.md
Source: Implementation plan delta — Liquibase migration added late (not in original LOC estimate)

- Liquibase migrations must be included in the LOC estimate during story-plan. Forgetting them
  adds ~60–90 LOC and typically requires revisiting branch N+1. Use the cross-cutting checklist
  in /atg:brief to catch this before planning.
──────────────────────────────────────────────────────────────

=== To apply ===
Review the patterns above and add the ones you want to keep:
  - Copy the text and paste into the suggested file, or
  - Tell me "add pattern 1 to 002-kotlin.md" and I'll do it for you.

Nothing has been written yet.
```

## Next Steps

1. Review suggested patterns and tell me which ones to add (and to which file)
2. Once done: commit the changes
3. Start next story: `/atg:story-plan {NEXT-TICKET}`
4. Or run `/atg:brief {NEXT-TICKET}` for complex/risky stories before planning
