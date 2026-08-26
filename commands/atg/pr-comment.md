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

### Step 1: Resolve target and position

```bash
OWNER_REPO=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
COMMIT_SHA=$(gh api repos/$OWNER_REPO/pulls/{PR_NUMBER}/commits --jq '.[-1].sha')
```

Confirm `{FILE}:{LINE}` falls inside the PR diff's added/context lines (`RIGHT` side). If the line
isn't part of the diff hunk, the GitHub API rejects the comment — check with:

```bash
gh api repos/$OWNER_REPO/pulls/{PR_NUMBER}/files --jq '.[] | select(.filename=="{FILE}") | .patch'
```

### Step 2: Post

```bash
gh api repos/$OWNER_REPO/pulls/{PR_NUMBER}/comments \
  -f commit_id="$COMMIT_SHA" \
  -f path="{FILE}" \
  -F line={LINE} \
  -f side=RIGHT \
  -f body="{comment body per style above}"
```

### Step 3: Confirm

Print the returned `html_url` so the user can open the thread directly. Do not paginate or fetch
the full comment list back — the create response has everything needed.

## Notes

- One comment per invocation. For multiple findings, call this once per finding (or prefer
  `/code-review {level} {target} --comment` when reviewing a whole PR — it batches this same
  posting step per finding it confirms).
- Never bulk-post via `gh pr comment` (that's a top-level issue comment, not inline) — inline
  requires the `pulls/{PR_NUMBER}/comments` endpoint with `path`/`line`/`commit_id`.
- Requires PR authorization already established in the session (i.e. this is a visible, one-way
  action on a shared PR — don't post without the user having asked for it, per the session's
  default confirm-before-external-action rule).
