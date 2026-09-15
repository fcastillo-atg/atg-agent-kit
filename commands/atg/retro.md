---
description: Post-merge retrospective — mine the story's artifacts and PRs for durable patterns, present them, write only what the user picks
---

# Retro

After a story's last PR is merged, mine its artifacts for patterns that would recur, present
them, and stop. Nothing is written until the user says which ones to keep. Paths and As-built
rules: **atg-story-artifacts**. Convention baseline: **atg-service-rules**.

## Usage

```bash
/atg:retro {TICKET}
```

Run after the final PR merges (or right after `/atg:qa-comment`). Do not run mid-story.

## Steps

1. **Locate artifacts**: the story directory's `{TICKET}-story.md`, `implementation-plan.md`,
   and `testing/`.

2. **Load the dedup baseline.** Read `wavebid-a2o-service/CLAUDE.md` and the numbered docs under
   `wavebid-a2o-service/.claude/rules/`. Never suggest a pattern already captured there.

3. **Mine PR comments.** `gh pr list --search "{TICKET}" --state merged --json number`, then
   `gh pr view {N} --comments` and `gh api repos/{owner}/{repo}/pulls/{N}/comments`. Keep only
   comments that were acted on. Drop bot boilerplate, resolved-without-action, and praise.

4. **Mine the plan for scope surprises.** Compare `## As-built` against `## Branch strategy` and
   `## Story analysis`: components added late, LOC estimates off by more than 50%, dependencies
   discovered mid-implementation. If `## As-built` is still a placeholder, offer once to draft it
   from the merged diff before continuing.

5. **Scan commits** on the merged branches for `fix(detekt)`, `fix(codenarc)`, or repeated
   fix attempts. Recurring lint themes are candidates.

6. **Filter candidates** with the "would this happen again?" test: recurred or general enough
   to recur, not already documented, concrete and actionable. Exclude one-off domain decisions,
   reviewer preferences that contradict codebase conventions, and comments later retracted.

   Suggested targets (the user decides):

   | Pattern | Target |
   |---|---|
   | Kotlin style, Detekt | `.claude/rules/002-kotlin.md` or `403-detekt-extra-violations.md` |
   | Spock style, CodeNarc, fixtures | `.claude/rules/101-test-patterns.md` or `103-tests.md` |
   | Coverage gaps | `.claude/rules/402-backend-quality-checks.md` |
   | Feature flags, Spring gotchas | `.claude/rules/303-feature-flags.md`, `302-spring-boot.md` |
   | Migrations | `.claude/rules/202-postgresql-migrations.md`, `203-liquibase-formatting.md` |
   | Recurring reviewer themes | `wavebid-a2o-service/CLAUDE.md` |

   A learning about the `/atg:*` commands themselves goes into a kit skill
   (atg-story-artifacts, atg-lifecycle, atg-testing-guide, atg-service-rules) or at most one
   line in the relevant command's steps. Never append procedure text, examples, or emphasis to
   a command file. Kit edits land in `~/ATG/atg-agent-kit/` followed by `link.sh`.

7. **Present and stop.** Write nothing.

   ```
   Retro — {TICKET}
   Mined: plan {N} scope note(s) · PR comments {N} acted on · lint {summary|none recurring}

   Pattern 1 of N — target: {file}   source: {PR comment | commit | plan delta}
   {ready-to-paste text as it would appear in the target}

   Pattern 2 of N — ...

   Nothing written. Say "add pattern 1", "add all", or "skip 2, add the rest".
   ```

8. **Apply only on instruction.** Append the exact suggested text to the target's relevant
   section. Never rewrite existing content. Confirm what was appended and where.

9. **Offer one commit** once the user is done, skipped if nothing was written:
   `chore(retro): capture learnings from {TICKET} [YYYY-MM-DD]`.

**Next:** next story: `/atg:scout {TICKET}` or `/atg:brief {TICKET}`.
