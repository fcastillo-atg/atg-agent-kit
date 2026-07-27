---
description: Create a PR after verify passes — respects monorepo PR template, adds ATG context, transitions Jira ticket
---

# Ship: Create Pull Request

**Purpose:** Create a pull request after `/atg:verify` passes. Reads the monorepo PR template, prepends an ATG-specific summary block, and transitions the Jira ticket to "In Review" (only for non-draft PRs).

## Usage

```bash
/atg:ship {TICKET}              # single-branch story
/atg:ship {TICKET} --branch N  # specify which branch this PR covers
/atg:ship {TICKET} --draft      # create as draft PR (Jira NOT transitioned)
/atg:ship {TICKET} --dry-run   # print PR body without creating
```

## Arguments

**Required:**
- `{TICKET}` — Jira ticket key (e.g. `WBPR-4032`)

**Flags:**
- `--branch N` — specifies which branch of a multi-branch story this PR covers
- `--draft` — create a GitHub draft PR; **skips Jira transition** (ticket stays In Development until the PR is marked ready for review)
- `--dry-run` — print the PR body to stdout; do not create the PR or push

## Execution Steps

### Step 1: Confirm verify passed

Check if `./gradlew test detektMain detektTest codenarcTest koverVerify` has been run recently and passed. If there are uncommitted or unstaged changes, warn the user and suggest running `/atg:verify` first.

If the user explicitly continues (or the working tree is clean with a recent successful verify), proceed.

### Step 2: Check for uncommitted changes

```bash
git status --short
```

- If there are uncommitted changes: warn and ask the user to commit first.
- If everything is committed: proceed.

### Step 3: Determine branch context

1. Run `git branch --show-current` to get the current branch name.
2. Read `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md` (search for the most recent matching directory under `bin/stories/`). Use **`## Branch strategy`** and each **`### Branch N:`** section.
3. Extract:
   - Total branch count (`M`)
   - Description of branch `N` (from `--branch N`, or default to 1 if single-branch)
   - Merge order for remaining branches

If `implementation-plan.md` is not found or lacks `## Branch strategy`, proceed with what can be inferred from the git branch name and ticket.

**As-built check (last branch only):**

If this is the **last branch** (N == M) or a **single-branch story** (M == 1), check whether `implementation-plan.md` contains a filled-in `## As-built` section.

- **If present and filled in:** proceed.
- **If missing or still a placeholder comment (`<!-- TODO ... -->`):** warn before continuing:

```
⚠️  This is the last branch for {TICKET} — implementation-plan.md has no ## As-built section.

    ## As-built documents the final state of every changed layer (DB, entity,
    API response, repository, handler, Liquibase) so /atg:testing-doc and future
    readers have an accurate picture of what shipped.

    Fill it in now before creating the PR? (Recommended — the diff is fresh.)
    Layers to cover: DB column, Kotlin entity/model, API response shape,
    repository queries, service/event handler behavior, Liquibase changesets.
```

If the user agrees, draft and write `## As-built` from the current diff before proceeding to Step 4.
If the user declines, note it in the PR summary block (Step 7) as a follow-up item.
If `implementation-plan.md` is not found, skip this check silently.

### Step 4: Determine changed files by layer

```bash
git diff origin/main...HEAD --name-only
```

Group files by architectural layer:
- `api/` — controllers, request/response models
- `service/` — service classes
- `repository/` — JPA repositories
- `domain/` — entities, value objects
- `featureflag/` — feature flag files
- `src/main/resources/db/changelog/` — Liquibase migrations
- `test/` — test files

### Step 5: Changeset pre-flight (monorepo CI)

Run from the **monorepo root** (same scope as `changeset-check.yml`):

```bash
git rev-parse --show-toplevel
cd "$(git rev-parse --show-toplevel)"
git diff origin/main...HEAD --name-only
```

**In scope:** any changed path matching `^wavebid-a2o-service/` or `^wavebid-a2o-ui/`.

**If in scope:**

1. Check that the branch includes at least one **changeset file** (not `README.md`):

   ```bash
   git diff origin/main...HEAD --name-only | grep -E '^\.changeset/[^/]+\.md$' | grep -v README
   ```

   Also accept if the changeset exists **only in the working tree** (staged or committed) and will be pushed with this PR — list `git status --short .changeset/` and `git diff origin/main...HEAD --name-only` together.

2. **If no matching `.changeset/*.md` is present:**  
   - **Stop** before push/PR creation.  
   - Tell the user to either:
     - Run **`/gsd/changeset-wavebid-a2o`** in Cursor, or **`/atg:changeset`** (pointer) / follow [`.cursor/commands/gsd/changeset-wavebid-a2o.md`](../../../../.cursor/commands/gsd/changeset-wavebid-a2o.md), **or**
     - Confirm explicitly that they will add the **`skip-changelog`** label to the PR (infra-only, test-only, docs-only, etc.).  
   - **Do not** proceed to Step 9 (push) until the user commits a changeset file or explicitly confirms `skip-changelog`.

3. **If `--dry-run`:** print whether the changeset gate passes or what is missing; still do not create the PR without user acknowledgement for the gate.

**If not in scope** (only infra, E2E, `.github` without touching service/ui paths per workflow): note that no changeset is required for CI; continue.

### Step 6: Read the PR template

Read the monorepo PR template from `../pull_request_template.md` (relative to the service root, i.e. the repo root's `pull_request_template.md`).

**Critical:** Never replace or omit the checklist from the template. The ATG-specific content is prepended **above** `#### Requirements`.

### Step 7: Build the PR body

Construct the PR body by prepending the ATG summary block to the template:

```markdown
## Summary

{2-4 bullet points describing what this branch does — derived from `implementation-plan.md` (`### Branch N:`) or the diff}

## Branch Strategy

Branch {N} of {M}: {what this branch covers}
Merge order: {list remaining branches in order}

## Changes

{files grouped by layer}
- **api/**: {files}
- **service/**: {files}
- **repository/**: {files}
- **domain/**: {files}

## Feature Flag

{flag name and behavior if a feature flag is present in the diff; "No feature flag" otherwise}

### Before / After (example)

{Include this subsection only when the story / `## As-built` / branch changes / diff show a **user-visible contract** change — e.g. new or changed CSV columns, API request/response fields, query params, or UI-visible labels — **or** an explicit behavior change called out in As-built / Pre-Analysis.

Skip entirely for pure refactors, test-only, infra, or internal renames with no observable contract change.

**Lead with the new capability** (not the edge case):
- **Before:** prior CSV headers / JSON shape / labels with a realistic sample.
- **After:** the same example with the new fields/columns populated.
- Optional third mini-example when the contract supports “field alone” or “omit = no change.”
- 1–2 sentence caption of what changes for the caller.

Prefer examples from the story or As-built over inventing large edge matrices.}

## Behavior change to flag for reviewers

{Include this heading **only** when As-built / Pre-Analysis documents an intentional behavior delta (e.g. Clear → no-op). Keep it short; do not duplicate the Before/After hero table here.

If there is no intentional behavior delta, **omit this heading entirely**.}

## Testing

See: `bin/stories/{year}/{month}/{TICKET}-{slug}/testing/TESTING-GUIDE.md`
Scenarios: `bin/stories/{year}/{month}/{TICKET}-{slug}/testing/scenarios/` (if present)

---

{full content of pull_request_template.md, with LINK_TO_JIRA replaced by the actual Jira URL}
```

**Jira URL format:** `https://auctiontechnologygroup.atlassian.net/browse/{TICKET}`

### Step 8: Generate PR title

Format: `{TICKET}: {branch description}`

- Single-branch: `WBPR-4032: Add lot address inheritance`
- Multi-branch: `WBPR-4032: [Branch 2/3] Service layer + unit tests`

Derive the description from `implementation-plan.md` (`### Branch N:`) or the git branch name slug.

### Step 9: Push and create PR (unless --dry-run)

**If `--dry-run`:**
```
--- DRY RUN ---
Title: {title}

Body:
{full PR body}
--- END DRY RUN ---
```
Stop here.

**Otherwise:**

```bash
git push -u origin HEAD
```

Then create the PR (add `--draft` flag when `--draft` was passed):
```bash
gh pr create \
  --title "{TICKET}: {description}" \
  [--draft] \
  --body "$(cat <<'EOF'
{full PR body}
EOF
)"
```

### Step 10: Transition Jira ticket

**If `--draft` was passed:** skip the Jira transition entirely. Print:
```
ℹ️  Draft PR — Jira ticket NOT transitioned. Transition {TICKET} to "Code Review" manually
    when you mark the PR ready for review:
    https://auctiontechnologygroup.atlassian.net/browse/{TICKET}
```

**Otherwise (non-draft PR):** resolve per the **jira-cli** skill to transition the ticket to "Code Review":
- Try: `acli jira workitem transition --key {TICKET} --status "Code Review" -y`
- Fallback: `mcp__mcp-atlassian__jira_get_transitions` then `mcp__mcp-atlassian__jira_transition_issue`

If neither is available, print a reminder:
```
⚠️  Jira unreachable (acli + MCP) — manually transition {TICKET} to "Code Review":
    https://auctiontechnologygroup.atlassian.net/browse/{TICKET}
```

### Step 11: Print summary

```
✅ PR created: {PR URL}

Title:    {TICKET}: {description}
Branch:   {current branch}
Jira:     https://auctiontechnologygroup.atlassian.net/browse/{TICKET}
Status:   {Draft PR — Jira stays In Development | Code Review (transitioned via acli|Jira MCP)}
```

## PR Body Rules

- **Always extend the monorepo template** — never write a free-form body that omits the checklist.
- Replace `LINK_TO_JIRA` with `[{TICKET}](https://auctiontechnologygroup.atlassian.net/browse/{TICKET})`.
- Keep all template checklist items intact (`- [ ] ...`).
- The ATG summary block goes **above** `#### Requirements`.
- If `implementation-plan.md` is missing or has no `### Branch N:` for this slice, generate a concise summary from the diff instead.
- **Before / After** (when included) must highlight the **new capability**; put regressions / edge semantics under **Behavior change to flag for reviewers**, not as the primary table.
- Prefer story / As-built examples over inventing edge matrices. Omit Before/After and Behavior change headings when they do not apply.

## Error Handling

| Situation | Action |
|-----------|--------|
| Uncommitted changes | Warn; do not push; ask user to commit first |
| `implementation-plan.md` missing or incomplete | Proceed with inferred context; note the gap |
| `pull_request_template.md` missing | Abort with error; do not create a free-form PR |
| In-scope diff without changeset and no `skip-changelog` confirmation | Stop; run `/gsd/changeset-wavebid-a2o` or `/atg:changeset`, or confirm label |
| Push fails (remote has diverged) | Show the git error; suggest `git pull --rebase` |
| `gh` CLI not available | Print the PR body and title for manual creation |
| `acli` and Jira MCP both unavailable | Create PR; print manual Jira transition reminder |

## Example Output

```
🚀 /atg:ship WBPR-4032 --branch 2

Step 1: Verify status         ✅ (last run: 3 minutes ago, all gates passed)
Step 2: Working tree          ✅ (clean — 1 commit ahead of origin)
Step 3: Branch context        ✅ (implementation-plan.md — Branch 2 of 3)
Step 4: Files changed (8)
  service/   3 files
  api/       2 files
  test/      3 files
Step 5: Changeset pre-flight  ✅ (.changeset/wbpr-4032-*.md present, or skip-changelog confirmed)
Step 6: PR template           ✅ (read from ../pull_request_template.md)
Step 7: PR body               ✅ (built — 42 lines)
Step 8: PR title              WBPR-4032: [Branch 2/3] Service layer + unit tests
Step 9: Push + create PR      ✅ git push -u origin fc/WBPR-4032-service-layer; gh pr create

✅ PR created: https://github.com/ATG/wavebid-a2o/pull/456

Title:    WBPR-4032: [Branch 2/3] Service layer + unit tests
Branch:   fc/WBPR-4032-service-layer
Jira:     https://auctiontechnologygroup.atlassian.net/browse/WBPR-4032
Status:   Code Review ✅ (transitioned via acli)
```

**Draft PR example (`--draft`):**
```
Step 9: Push + create PR      ✅ git push -u origin fc/WBPR-4032-service-layer; gh pr create --draft
Step 10: Jira transition      ⏭️  SKIPPED (draft PR — ticket stays In Development)

✅ Draft PR created: https://github.com/ATG/wavebid-a2o/pull/456

Title:    WBPR-4032: [Branch 2/3] Service layer + unit tests
Branch:   fc/WBPR-4032-service-layer
Jira:     https://auctiontechnologygroup.atlassian.net/browse/WBPR-4032
Status:   In Development (transition to Code Review when PR is marked ready)
```

## Next Steps

1. Request reviewers on GitHub
2. Monitor CI — if it fails: `/atg:review-feedback {PR_NUMBER}`
3. When reviewer comments arrive: `/atg:review-feedback {PR_NUMBER}`
4. When PR is approved and merged: start next branch or run `/atg:retro {TICKET}`
