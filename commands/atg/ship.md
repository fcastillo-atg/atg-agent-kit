---
description: Create a PR after verify passes. Extends this service's PR template with an ATG summary block and transitions the Jira ticket
---

# Ship: create pull request

Open the PR for one branch of a story once `/atg:verify` is green. Reads the service's PR
template, inserts an ATG summary block, pushes, creates the PR, and moves the Jira ticket to
Code Review (non-draft only). Story paths, diff base, and the `bin/` rules come from the
atg-story-artifacts skill; the template path and changeset rule come from atg-repo-profile.

## Usage

```bash
/atg:ship {TICKET}              # single-branch story
/atg:ship {TICKET} --branch N   # which branch of a multi-branch story this PR covers
/atg:ship {TICKET} --draft      # draft PR; Jira is not transitioned
/atg:ship {TICKET} --dry-run    # print title and body; no push, no PR
```

## Steps

1. **Confirm verify.** If the full gate suite has not passed on the current tree this session,
   warn and suggest `/atg:verify`. Proceed only if it has, or the user explicitly continues.

2. **Clean tree.** `git status --short`. Any uncommitted change: stop and ask the user to commit.

3. **Branch context.** `git branch --show-current`. Read `implementation-plan.md`
   `## Branch strategy`, take total count `M` and the `### Branch N:` description (N from
   `--branch`, default 1). If the plan is missing, infer from branch name and ticket.

   On the last branch (`N == M`, or `M == 1`):
   - If `## As-built` is missing or still the TODO placeholder, warn that it documents the
     shipped state for testing-doc and future readers, offer to draft it from the diff now. If
     declined, list it as a follow-up in the PR Testing section.
   - If `testing/TESTING-GUIDE.md` is missing, offer to run `/atg:testing-doc {TICKET}` now.
     If declined, list it as a follow-up.

4. **Files by layer.** `git diff origin/main...HEAD --name-only`, grouped: `api/`, `service/`,
   `repository/`, `domain/`, `featureflag/`, `db/changelog/`, `test/`.

5. **Changeset pre-flight.** Read `changeset` from **atg-repo-profile**. Value `none`: skip.
   Otherwise apply the profile's rule — if the diff touches its declared paths and no changeset
   file is on the branch or in the working tree, stop before push until the user adds one
   (`/atg:changeset`) or explicitly confirms the skip label. Under `--dry-run`, report the gate
   result. Out of scope: note it and continue.

6. **Read the template.** The profile's `pr-template`, relative to the git toplevel. Missing:
   abort, never write a free-form body.

7. **Build the body.** Insert the ATG block above the profile's `pr-body-anchor` heading. Keep
   every template checklist item intact, including any AI-usage declaration — tick the
   AI-assisted option, since an `/atg:*` session is AI assistance. Write the prose per the
   **unslop** skill. Replace a `LINK_TO_JIRA` placeholder with
   `[{TICKET}](https://auctiontechnologygroup.atlassian.net/browse/{TICKET})`; where the template
   has no placeholder, put that link on the ATG block's first line instead.

   ```markdown
   ## Summary
   {2-4 bullets from `### Branch N:` or the diff}

   ## Branch Strategy
   Branch {N} of {M}: {what this branch covers}
   Merge order: {remaining branches}

   ## Changes
   - **api/**: {files}
   - **service/**: {files}
   {one line per layer present}

   ## Feature Flag
   {flag name and behaviour, or "No feature flag"}

   ### Before / After (example)
   {Only for a user-visible contract change: new CSV columns, API fields, params, labels, or a
   behaviour delta recorded in As-built or Pre-Analysis. Lead with the new capability. Before:
   realistic prior shape. After: same sample with the new fields populated. One caption line.
   Prefer story or As-built examples over invented edge matrices. Skip for refactors, tests,
   infra, internal renames.}

   ### Request / response
   {Only when a concrete shape is worth showing without an old/new contrast: new endpoint, or a
   persist-only change where the new row shape is the deliverable. Follow PR #3380: one
   `#### \`METHOD path\`` (or descriptive label) per shape, a ```json block with a real payload
   captured during /atg:test-run or from TESTING-PROGRESS, one prose line on invariants.
   Never fabricate payloads. Skip when nothing is worth showing.}

   ## Behavior change to flag for reviewers
   {Only when As-built or Pre-Analysis records an intentional delta. Short. Omit the heading
   entirely otherwise.}

   ## Testing
   {Inline only: specs added or changed and what they cover; whether the full gate suite passed;
   what test-run or manual verification exercised and the outcome, including any bug found.
   Never link a `bin/` path; summarize its content instead.}

   ---

   {full pull_request_template.md content}
   ```

8. **Title.** `{TICKET}: {description}` for single-branch,
   `{TICKET}: [Branch N/M] {description}` for multi-branch, description from `### Branch N:` or
   the branch slug.

   **Gate:** grep the finished body for `bin/`. Any hit is a local-only path; rewrite that
   section inline before continuing.

9. **Dry run or push.** With `--dry-run` print title and body between `--- DRY RUN ---` markers
   and stop. Otherwise:

   ```bash
   git push -u origin HEAD
   gh pr create --title "{title}" [--draft] --body "$(cat <<'EOF'
   {body}
   EOF
   )"
   ```

10. **Jira.** With `--draft`, skip and print a reminder to transition manually when the PR is
    marked ready. Otherwise transition `{TICKET}` to Code Review per the jira-cli skill. If Jira
    is unreachable, create the PR anyway and print the manual-transition reminder with the
    browse URL.

11. **Summary.**

    ```
    ✅ PR created: {url}
    Title:   {title}
    Branch:  {branch}
    Jira:    https://auctiontechnologygroup.atlassian.net/browse/{TICKET}
    Status:  {Code Review (transitioned) | Draft, Jira stays In Development}
    ```

## Failures

| Situation | Action |
|---|---|
| `pull_request_template.md` missing | Abort; no free-form PR |
| In-scope diff, no changeset, no `skip-changelog` confirmation | Stop before push |
| Push rejected (remote diverged) | Show the git error; suggest `git pull --rebase` |
| `gh` unavailable | Print title and body for manual creation |
| Jira unreachable | Create PR; print manual transition reminder |

**Next:** `/atg:review-feedback {PR}` as comments arrive; once merged, start the next branch or run `/atg:qa-comment {TICKET}`.
