---
description: Post one concise inline PR review comment (finding plus proposed fix) on GitHub, deduplicating against existing threads
---

# PR comment: post an inline finding

Post one code-review finding as a file/line-anchored comment on a GitHub PR. For new findings
only; replying to existing threads is `/atg:review-feedback`. This posts to a shared PR, so
only run it when the user has asked for the comment.

## Usage

```bash
/atg:pr-comment {PR} {FILE}:{LINE} "{finding}"
/atg:pr-comment {PR} {FILE}:{LINE} "{finding}" --fix "{proposed fix}"
```

`{FILE}:{LINE}` is repo-relative in the PR's new file version. `--fix` is optional; if omitted
and a fix is obvious, propose one anyway. Invoked without args right after discussing a finding,
infer PR, anchor, and finding from the conversation; ask only if genuinely ambiguous. Works for
one finding or a batch (all findings from a prior `/code-review` still in context); every step
below runs per finding.

## Comment style

Apply the **unslop** skill, then these rules:

- Start the body with a `[{Area}] {emoji} {Severity}:` prefix, matching this repo's review-bot
  convention. Area is one of `Backend`, `Frontend`, `DevOps`, `QA` — infer it from the finding's
  file path (`wavebid-a2o-service` → Backend, `wavebid-a2o-ui` → Frontend, `scripts/`, `.github/`
  → DevOps, a missing/weak test → QA). Severity is `🔴 Must fix` for something that breaks
  behavior or a build gate, `🟡 Should fix` for a real but non-blocking defect, or `🔵 Nitpick` for
  a style, naming, or cleanup suggestion with no functional consequence. Every finding gets one of
  these three; there is no non-blocking "note" tier — if it's worth posting, it's at least a
  nitpick.
- One to three sentences after the prefix: the defect and its concrete consequence, not "this
  looks wrong".
- Quote identifiers in single quotes (`'sanitize()'`).
- Blank line, then the fix: a short code block if code, one line otherwise. Optional closing line
  on why the fix is cheap.
- No headers, bullets, preamble, or praise beyond the one `[Area] emoji Severity:` prefix.

## Steps

1. **Resolve target.**

   ```bash
   OWNER_REPO=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
   COMMIT_SHA=$(gh api repos/$OWNER_REPO/pulls/{PR}/commits --jq '.[-1].sha')
   ```

2. **Dedup.** Fetch all existing comments, bot and human:

   ```bash
   gh api repos/$OWNER_REPO/pulls/{PR}/comments --jq '.[] | {path, line, user: .user.login, body, html_url}'
   gh api repos/$OWNER_REPO/issues/{PR}/comments --jq '.[] | {user: .user.login, body, html_url}'
   ```

   A finding is a duplicate when an inline comment has the same `path`, a `line` within 3 of the
   finding's, and the body describes the same root cause. Proximity alone is not enough. Skip
   duplicates silently and report them in one summary line (who flagged it, `html_url`). Stop to
   ask only if every finding is a duplicate.

3. **Check the anchor.** The line must be on the RIGHT side of the diff hunk or GitHub rejects it:

   ```bash
   gh api repos/$OWNER_REPO/pulls/{PR}/files --jq '.[] | select(.filename=="{FILE}") | .patch'
   ```

4. **Post**, one call per finding, never batched into one body and never via `gh pr comment`
   (that is a top-level issue comment):

   ```bash
   gh api repos/$OWNER_REPO/pulls/{PR}/comments \
     -f commit_id="$COMMIT_SHA" -f path="{FILE}" -F line={LINE} -f side=RIGHT \
     -f body="{comment body}"
   ```

5. **Confirm.** Print posted count, skipped duplicates, and each new comment's `html_url` from
   the create response. Do not re-fetch the comment list.

**Next:** `/atg:review-feedback {PR}` when the author responds.
