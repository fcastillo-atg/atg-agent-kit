---
description: Post a concise inline PR review comment (finding + proposed fix) on GitHub
---

# Post an inline PR comment

Posts **one** finding as an inline, file/line-anchored comment on a GitHub PR — the format used
when reporting a code-review finding (e.g. from `/code-review` or a manual read): a concise
statement of the problem followed by a proposed fix.

This is for **posting a new finding**, not for replying to existing review threads — use
`/atg:review-feedback` for that.

## Usage

```bash
/atg:pr-comment {PR_NUMBER} {FILE}:{LINE} "{finding}"
/atg:pr-comment {PR_NUMBER} {FILE}:{LINE} "{finding}" --fix "{proposed fix}"
```

- `{PR_NUMBER}` — GitHub PR number
- `{FILE}:{LINE}` — path (repo-relative) and line in the PR's **new** file version
- `{finding}` — one or two sentences: what's wrong and the concrete failure scenario
- `--fix` — optional; a short proposed solution, code fence if it's code. If omitted and a fix is
  obvious, still propose one — don't post a bare complaint.

If invoked without explicit args (e.g. "add this as an inline comment" right after discussing a
finding in chat), infer `{PR_NUMBER}`, `{FILE}:{LINE}`, and the finding from the conversation
instead of asking — only ask if genuinely ambiguous (e.g. multiple PRs discussed, or no clear line
anchor).

## Comment style (mandatory)

Match the tone used in prior sessions — terse, no preamble, no em dash:

- 1–3 sentences stating the defect and its concrete consequence (not just "this looks wrong").
- Quote identifiers in single quotes (`'sanitize()'`), not backticks-in-prose-then-backticks-again.
- A blank line, then the proposed fix — a short code block if it's a code change, one line if it's
  not.
- Optional closing line on why the fix is low-cost / low-risk (e.g. "costs nothing if X already
  holds").
- No headers, no bullet lists, no "Summary:" / "Suggestion:" labels — plain prose + one code block
  is enough for a single-finding inline comment.

## Execution steps

### Step 1: Resolve target

```bash
OWNER_REPO=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
COMMIT_SHA=$(gh api repos/$OWNER_REPO/pulls/{PR_NUMBER}/commits --jq '.[-1].sha')
```

### Step 2: Dedup check (mandatory, before posting anything)

Fetch every existing comment on the PR — inline review comments and top-level issue comments,
from bots and humans alike:

```bash
gh api repos/$OWNER_REPO/pulls/{PR_NUMBER}/comments \
  --jq '.[] | {path, line, user: .user.login, body, html_url}'
gh api repos/$OWNER_REPO/issues/{PR_NUMBER}/comments \
  --jq '.[] | {user: .user.login, body, html_url}'
```

For each candidate finding, check existing **inline** comments whose `path` matches the finding's
`{FILE}` and whose `line` is within **3 lines** of the finding's `{LINE}`. A candidate is a
duplicate only if such a comment exists **and** it's about the same root cause (read the body —
same defect, not just nearby code). Line-proximity alone is not enough; two different bugs can sit
three lines apart.

For every finding that is a duplicate:

- **Skip posting it.**
- Tell the user: which finding was skipped, who already flagged it, and the existing comment's
  `html_url`.

Do not ask for confirmation per duplicate — filter silently and report the filtering in one
summary line, then proceed straight to posting the remaining unique findings. Only stop and ask if
literally every candidate finding turns out to be a duplicate (nothing left to post).

### Step 3: Post remaining unique findings

For each finding that survived Step 2, confirm `{FILE}:{LINE}` falls inside the PR diff's
added/context lines (`RIGHT` side) — if the line isn't part of the diff hunk, the GitHub API
rejects the comment:

```bash
gh api repos/$OWNER_REPO/pulls/{PR_NUMBER}/files --jq '.[] | select(.filename=="{FILE}") | .patch'
```

Then post:

```bash
gh api repos/$OWNER_REPO/pulls/{PR_NUMBER}/comments \
  -f commit_id="$COMMIT_SHA" \
  -f path="{FILE}" \
  -F line={LINE} \
  -f side=RIGHT \
  -f body="{comment body per style above}"
```

One `gh api` call per finding — never batch multiple findings into one comment body.

### Step 4: Confirm

Print a short summary: how many posted, how many skipped as duplicates (with who/where), and the
`html_url` of each newly posted comment so the user can open the threads directly. Do not paginate
or re-fetch the full comment list — the create response has everything needed.

## Notes

- Can be invoked with one finding or a batch (e.g. all findings from a prior `/code-review` run
  still in context) — the dedup check and posting loop both operate per-finding regardless.
- Never bulk-post via `gh pr comment` (that's a top-level issue comment, not inline) — inline
  requires the `pulls/{PR_NUMBER}/comments` endpoint with `path`/`line`/`commit_id`, one call per
  finding.
- Requires PR authorization already established in the session (i.e. this is a visible, one-way
  action on a shared PR — don't post without the user having asked for it, per the session's
  default confirm-before-external-action rule).
