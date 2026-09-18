---
description: Classify every PR comment (human and bot) into a review matrix, then fix, reply in-thread, and push, each step behind a confirmation
---

# Review feedback: classify and resolve PR comments

Fetch all comments on a PR, classify each, print a review matrix, and stop. Only after the user
confirms: apply fixes, verify, ask before posting one in-thread reply per comment, ask before
pushing. Code conventions come from the atg-service-rules skill.

## Usage

```bash
/atg:review-feedback {PR}                 # matrix, stop, then fixes, then ask about replies and push
/atg:review-feedback {PR} --dry-run       # matrix only; no edits, no gh posts, no push
/atg:review-feedback {PR} --apply-fixes   # skip the "proceed with fixes?" stop
/atg:review-feedback {PR} --post-replies  # post drafted replies without asking
/atg:review-feedback {PR} --push          # commit and push without asking
/atg:review-feedback {PR} --human-only    # ignore bot comments
/atg:review-feedback {PR} --bot-only      # ignore human comments
```

Default to no skip flags so the matrix prints first and the user approves each stage.
`--dry-run` alone is always safe.

## Steps

1. **Fetch.** `{owner}/{repo}` from `git remote get-url origin`.

   ```bash
   gh pr view {PR} --json title,headRefName,body,state,reviews,reviewThreads
   gh api repos/{owner}/{repo}/pulls/{PR}/comments      # inline review comments
   gh api repos/{owner}/{repo}/issues/{PR}/comments     # timeline comments
   git diff origin/main...HEAD --name-only              # files in this PR
   ```

   Bot authors: logins matching `bot`, `cursor-bot`, `github-actions`, Codacy, SonarQube.

2. **Classify** every comment:

   | Value | Criteria | Proposed action column |
   |---|---|---|
   | ✅ fix | File is in the diff and the issue is real | Short description of the code change |
   | ✅ answer | Question or clarification, no code change | Draft reply text (prose per the **unslop** skill) |
   | ⚠️ stale | File not in diff, known intentional pattern, or false alarm | Optional short reply |
   | ❌ skip | Bot boilerplate, template noise | None |

   Known intentional patterns, classify as ⚠️ stale:

   | Pattern | Reason |
   |---|---|
   | "Authentication disabled" in `SecurityConfig` | Feature-flag controlled |
   | Missing `@Param` on repository queries | Spring Boot 3.x `-parameters` handles it |
   | A coverage-exclusion annotation on a documented pattern | The pattern has its own tests |
   | `enabled = false` instead of delete | Soft-delete convention |
   | Wildcard imports in a build script | Build-DSL exception |

3. **Print the matrix and stop.** Every comment gets a row. Include the comment id so later
   `gh api` calls are unambiguous.

   ```
   | # | Author | Where (id) | Valid? | Proposed action |
   |---|--------|------------|--------|-----------------|
   | 1 | @alice | Foo.kt:42 (998877) | ✅ fix | Use findByIdOrNull and check |
   | 2 | @bob | Bar.kt:10 (998878) | ✅ answer | Reply: UUIDv7 per CLAUDE.md |

   Proceed with fixes for {N} ✅ fix row(s)?
   ```

   `--dry-run`: end here. Otherwise wait for confirmation unless `--apply-fixes`. With no
   ✅ fix rows, say so and go to step 6.

4. **Fix.** For each ✅ fix row read the file and context, apply the change per
   atg-service-rules, show a brief inline diff.

5. **Verify.** Run `/atg:verify` (or tell the user to) before any reply or push. A quick
   Running one static-analysis gate alone is not done. Resolve what verify surfaces, max 2
   iterations per gate.

6. **Ask about replies.** "Post the drafted replies in-thread (✅ answer and listed ⚠️ stale)?
   yes / no / which ids." No: print drafts for manual use. Yes or `--post-replies`: post **one
   reply per comment, in its thread**. Never one bundled `gh pr comment`.

   ```bash
   # inline review comment
   gh api repos/{owner}/{repo}/pulls/{PR}/comments/{PARENT_ID}/replies --method POST -f body="$BODY"
   # issue / timeline comment
   gh api repos/{owner}/{repo}/issues/comments/{COMMENT_ID}/replies --method POST -f body="$BODY"
   ```

   If the API fails, hand the user the exact command and body, still one per comment.

7. **Ask about push.** Only with verify green and user agreement (or `--push`):

   ```bash
   git add -A
   git commit -m "fix(review): address PR #{PR} feedback"
   git push
   ```

8. **Summary.**

   ```
   ✅ PR #{PR} feedback session complete
   Fixed:    {X} code issues
   Replies:  {Y} posted in-thread (or skipped)
   Skipped:  {W} generic / no-action
   Verify:   {one ✅|❌ per gate in the profile's quality-gate table}
   Pushed:   yes|no
   ```

## Failures

| Situation | Action |
|---|---|
| Cannot fetch comments | Report; ask the user to paste them |
| Fix breaks a test or lint gate | Fix; report if unresolved after 2 attempts, do not push |
| `gh` unavailable | Print drafts and exact commands |
| Comment points at a line that no longer exists | Classify ⚠️ stale |

**Next:** `/atg:verify` if code changed, then re-request review; when merged, `/atg:qa-comment {TICKET}`.
