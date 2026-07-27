---
description: Unified PR comment classifier and resolver — handles both human reviewer comments and bot comments in one flow
---

# Review Feedback: Classify and Resolve PR Comments

**Purpose:** Retrieve all comments on a PR (human reviewers + bots), classify each one, present a **review matrix** first, then — **only after the user confirms** — apply code fixes, and — **only after a second confirmation** — post replies on GitHub (one thread per comment, never one bulk PR comment).

## Workflow (human-in-the-loop)

The agent must follow this order unless the user passes flags that explicitly skip a step (see [Usage](#usage)).

| Step | What happens | Stops for user? |
|------|----------------|-----------------|
| **1. Fetch** | Load PR metadata, inline review comments, issue/timeline comments, diff file list | No |
| **2. Classify** | Label each comment (valid fix / valid answer / stale / skip) | No |
| **3. Review matrix** | Print the [classification table](#classification-table-format) | **Yes — wait for confirmation** |
| **4. Apply fixes** | Implement `VALID — fix` items only after the user confirms they want to address them | Only if step 3 confirmed |
| **5. Verify (quality gates)** | **Suggest** [`/atg:verify`](verify.md) (or run it in-session) so tests, Detekt, CodeNarc, and Kover run in order; that command also fixes violations when possible. Do not treat a quick `detektMain` alone as “done.” | No (but user may run verify in a follow-up turn) |
| **6. PR replies (optional)** | **Ask** whether to post drafted replies to GitHub. Post only if the user agrees. | **Yes — default is ask** |
| **7. Commit / push** | **Ask** (or use `--push` if documented) before `git commit` + `git push` | Prefer ask unless `--push` |

**Never** skip step 3 (the table) or step 6’s question unless the user explicitly opts in with flags.

## Classification table format

After classifying, print a **single markdown table** (and optionally a short summary line). Every comment row must be accounted for.

Suggested columns:

| # | Author | Where | Valid? | Proposed action |
|---|--------|--------|--------|------------------|
| 1 | `@alice` | `Foo.kt:42` | ✅ fix | Rename `findById` → `findByIdOrNull`; add null check. |
| 2 | `@bob` | `Bar.kt:10` (review) | ✅ answer | Reply: project uses UUIDv7 for index locality (see CLAUDE.md). |
| 3 | `@alice` | `SecurityConfig.kt:1` | ⚠️ stale | Reply: not in this PR’s diff; pre-existing / feature-flagged. |
| 4 | `codacy-bot` | issue comment | ❌ skip | Boilerplate metrics; dismiss in UI. |

**Valid?** values:

- **✅ fix** — Actionable code change; file in scope for this PR.
- **✅ answer** — No code change; needs a **draft reply** in the Proposed action column.
- **⚠️ stale** — Intentional pattern, out-of-diff, or false alarm; optional short reply in Proposed action.
- **❌ skip** — Bot noise / template; no reply.

**After the table**, print one line:

`Proceed with fixes for {N} ✅ fix row(s)? (and later: post replies for ✅ answer / ⚠️ stale?)`

**Stop.** Do not edit files or call `gh` to post replies until the user confirms (or passes `--apply-fixes` / `--post-replies` as documented below).

## Reply placement (mandatory)

When the user **does** authorize posting replies:

- **Do not** post a single `gh pr comment` that batches answers to multiple threads.
- **Do** post **one reply per top-level review comment**, in-thread.
- **Inline review comments** (file/line):

```bash
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments/{PARENT_COMMENT_ID}/replies \
  --method POST \
  -f body="$REPLY_BODY"
```

See [Create a reply for a pull request review comment](https://docs.github.com/en/rest/pulls/comments#create-a-reply-for-a-pull-request-review-comment).

- **Issue / timeline comments** (not on a file diff):

```bash
gh api repos/{owner}/{repo}/issues/comments/{COMMENT_ID}/replies \
  --method POST \
  -f body="$REPLY_BODY"
```

- If the API fails, give the user the exact command and body — still **one reply per comment**, never a rollup.

## Verification after code changes

After **any** review-driven code edits (Phase 4), **always suggest** running **`/atg:verify`** (same as `/atg:verify` in chat — see [`verify.md`](verify.md)) before posting PR replies or pushing. That command:

- Runs the full gate sequence: tests → Detekt → CodeNarc → Kover (and Liquibase preflight when `db/changelog/` changed).
- Is the right place to **catch and fix** failures introduced by review fixes.

If this session does not execute verify end-to-end, print a clear one-liner for the user, for example:

> Review fixes are in. Run **`/atg:verify`** next to run tests, static analysis, and coverage; fix anything it reports before you commit or re-request review.

## Usage

```bash
/atg:review-feedback {PR_NUMBER}                    # default: table + stop for confirm → then fixes → then ask for PR replies
/atg:review-feedback {PR_NUMBER} --dry-run          # classify + table only; no edits, no gh posts, no commit
/atg:review-feedback {PR_NUMBER} --apply-fixes     # apply code fixes after table without waiting (use sparingly)
/atg:review-feedback {PR_NUMBER} --post-replies    # after fixes, post drafted replies without asking (use sparingly)
/atg:review-feedback {PR_NUMBER} --push            # after fixes + replies (if any), commit and push without asking (use sparingly)
/atg:review-feedback {PR_NUMBER} --human-only      # skip bot comments
/atg:review-feedback {PR_NUMBER} --bot-only        # skip human reviewer comments
```

Combine flags only when the user clearly wants a non-interactive run (e.g. `--dry-run` alone is always safe).

**Recommended default:** Run **without** `--apply-fixes` / `--post-replies` / `--push` so the matrix prints first and the user can say “yes, fix the ✅ fix rows” and later “yes, post those replies.”

## Arguments

- `{PR_NUMBER}` — GitHub PR number (e.g. `456`)
- `--dry-run` — Fetch + classification table only; no file changes, no `gh` replies, no commit/push
- `--apply-fixes` — After showing the table, **do not** wait: apply `VALID — fix` changes (still ask about replies unless `--post-replies`)
- `--post-replies` — After fixes, post drafted replies in-thread without asking
- `--push` — Commit and push after successful verification (implies user wants automation; still show table first unless `--dry-run`)
- `--human-only` — Process only human reviewer comments
- `--bot-only` — Process only automated/bot comments

Adjust `--apply-fixes` / `--post-replies` / `--push` semantics if the team prefers a single `--yes` flag; document clearly in this file.

## Execution steps (detailed)

### Phase 1: Fetch all comments

```bash
# PR metadata (title, head branch, linked ticket)
gh pr view {PR_NUMBER} --json title,headRefName,body,state

# Inline review comments (on specific lines/files)
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments

# Timeline comments (general PR comments)
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments

# Review threads (resolved/unresolved status)
gh pr view {PR_NUMBER} --json reviews,reviewThreads
```

Extract `{owner}` and `{repo}` from `git remote get-url origin`.

Also get the list of files changed by this PR:

```bash
git diff origin/main...HEAD --name-only
```

### Phase 2: Classify every comment

| Classification | Criteria | Proposed action column |
|---------------|----------|-------------------------|
| ✅ Valid — fix | References a file IN the diff; the issue is real and actionable | Short description of the code change |
| ✅ Valid — answer | Question or clarification; no code change | Draft reply text (or bullet summary) |
| ⚠️ Stale / false alarm | File NOT in diff, or known intentional pattern | Draft reply or “no reply” |
| ❌ Generic / template | Bot boilerplate, out-of-scope | “Dismiss / skip” |

**Known intentional patterns — classify as ⚠️ Stale:**

| Pattern | Reason |
|---------|--------|
| "Authentication disabled" in `SecurityConfig` | Feature flag controlled; intentional |
| Missing `@Param` on repository queries | Spring Boot 3.x `-parameters` flag handles this |
| `@KoverIgnore` on ProxyFactory | Documented pattern; factory has its own tests |
| `enabled = false` instead of delete | Soft-delete pattern; documented in CLAUDE.md |
| Wildcard imports flagged in `build.gradle` | Gradle DSL exception to import rules |

**Bot comment detection:** Comments from users matching `bot`, `cursor-bot`, `github-actions`, or automated review tools (Codacy, SonarQube) are treated as bot comments.

### Phase 3: Print the classification table (mandatory)

Output the [Classification table format](#classification-table-format). Include comment IDs (`review comment id` or `issue comment id`) in the **Where** or a hidden column so later `gh api` calls are unambiguous.

If `--dry-run`, **stop here**.

Otherwise **stop and wait** for the user to confirm (unless `--apply-fixes`):

- “Proceed with the proposed code fixes?”
- If there are no ✅ fix rows, say so and skip to Phase 6 question (replies only).

### Phase 4: Resolve valid — fix comments

Run only after **user confirmation** or `--apply-fixes`.

For each `VALID — fix` comment:

1. Read the referenced file and surrounding context
2. Make the fix following Kotlin/Spock/Groovy conventions:
   - Kotlin style: expression body, named args (>3 params), `OrThrow`/`OrNull` suffixes
   - Groovy/Spock: single quotes, concrete types (no `def`), `ClassEndsWithBlankLine`
   - No `--no-daemon` in any Gradle commands
3. Show a brief diff of the change inline in the output

After **all** fixes are applied, **suggest** (or run) **`/atg:verify`** per [Verification after code changes](#verification-after-code-changes). If you only run a subset locally, still remind the user to run the full verify before merge. Resolve any failures verify surfaces (max 2 iterations per tool family).

### Phase 5: Ask before posting PR replies

After fixes are done (or if there were no fixes), **ask the user explicitly**:

> “Post the drafted replies to GitHub in-thread (✅ answer + any ⚠️ stale you listed)? Reply yes/no, or which comment IDs to include.”

If **no** → skip posting; output the draft text for manual copy-paste if useful.

If **yes** or `--post-replies` → for each row that needs a reply, post **one** in-thread reply per [Reply placement](#reply-placement-mandatory). Log: `✅ Posted reply for comment id {id}`.

Do **not** use `gh pr comment` to answer multiple review threads at once.

### Phase 6: Pre-push validation

Before commit/push, quality gates should be green. Prefer **`/atg:verify`** (see [`verify.md`](verify.md)) so Step 0 (Liquibase when changelogs changed) and Kover are not skipped.

Only commit and push if verify passes (or the user explicitly accepts risk) and the user agrees (or `--push`).

If verify fails:

- Fix failures per verify’s remediation loop (max 3 iterations per step in verify)
- If unresolvable, stop and report — do not push broken code

### Phase 7: Commit and push

Only after user confirmation or `--push`:

```bash
git add -A
git commit -m "fix(review): address PR #{PR_NUMBER} feedback"
git push
```

### Phase 8: Final summary

```
✅ PR #{PR_NUMBER} feedback session complete

Fixed:        {X} code issues
Replies:      {Y} posted in-thread (or skipped per user)
Skipped:      {W} generic / no-action comments

Verification:
  Tests:    ✅ or ❌
  Detekt:   ✅ or ❌
  CodeNarc: ✅ or ❌

Pushed: {yes/no}
```

## ATG-Specific Fix Conventions

When making fixes from reviewer feedback, always follow:

- **Kotlin:** expression body for single-return functions; named args when >3 params; `OrThrow`/`OrNull` suffix for explicit null behavior; `mu.KotlinLogging` for logging
- **Groovy/Spock:** single quotes unless string interpolation needed; concrete types (no `def`); blank line before closing `}` in all classes; space around map colons `[id : 123]`
- **No `@Param`** on repository methods (Spring Boot 3.x handles this)
- **Soft delete:** `enabled = false`, not actual deletion
- **No `--no-daemon`** in Gradle commands

## Error Handling

| Situation | Action |
|-----------|--------|
| Cannot fetch PR comments | Report error; ask user to paste comments manually |
| Fix introduces test failure | Fix the test; report if unresolvable after 2 attempts |
| Fix introduces Detekt/CodeNarc violation | Resolve before pushing |
| `gh` CLI not available | Print drafts and exact `gh` commands for the user |
| Comment references non-existent line | Note as stale (file may have changed) |

## Example session (interactive)

```
/atg:review-feedback 456

Phase 1–2: Fetched comments and classified.

PR #456 — WBPR-4032: Service layer
Branch: fc/WBPR-4032-service-layer

| # | Author | Where | Valid? | Proposed action |
|---|--------|--------|--------|-----------------|
| 1 | @alice | LotService.kt:45 | ✅ fix | Use findByIdOrNull + explicit check |
| 2 | @bob | Lot.kt:10 (review id 998877) | ✅ answer | Draft: UUIDv7 standard per CLAUDE.md |
| 3 | @alice | SecurityConfig.kt:1 | ⚠️ stale | Draft: not in diff; feature flag |
| 4 | cursor-bot | issue | ❌ skip | Template |

User: yes, apply fixes

Phase 4: … edits …
Agent: Run **`/atg:verify`** next (or runs it) — tests, detekt, codenarc, kover ✅

Agent: Post replies for rows 2 and 3 on GitHub?
User: yes — posted replies to comment ids 998877, …

User: yes, push (verify already green)

Phase 7: commit + push ✅
```

## Next Steps

1. If you have not already: **`/atg:verify`** — mandatory sanity check after review fixes.
2. Re-request review on GitHub (if replies were posted)
3. When approved and merged: `/atg:retro {TICKET}`
