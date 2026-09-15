---
description: Quick multi-branch story status. Shows which planned branches are merged, open, in progress, or not started, plus Jira status and the next action
---

# Status: multi-branch story overview

Text snapshot of where a story stands per planned branch. Story paths come from the
atg-story-artifacts skill; the richer published dashboard is `/atg:story-view`.

## Usage

```bash
/atg:status {TICKET}
```

## Steps

1. **Planned branches.** From `implementation-plan.md` `## Branch strategy`, take the count and
   each `### Branch N:` name and description. Without a plan, fall back to git branches and PRs
   matching `{TICKET}`.

2. **Branch state.** Per branch:

   ```bash
   gh pr list --search "head:{branch}" --state merged --json number,mergedAt,title
   gh pr list --search "head:{branch}" --state open --json number,title,reviewDecision,statusCheckRollup
   git branch -a | grep {branch}
   ```

   Classify: `✅ Merged`, `🔄 PR Open` (with CI passing/failing/pending and awaiting review /
   changes requested / approved), `🚧 In progress` (branch exists, no PR), `⬜ Not started`.

3. **Jira status** per the jira-cli skill (status field only). Skip with a note if unreachable.

4. **Report.**

   ```
   Story: {TICKET} — {title}
   Jira status: {status}
   Branches: {N} planned

     Branch 1 [{description}]   ✅ Merged         PR #{n} (merged {date})
     Branch 2 [{description}]   🔄 PR Open        PR #{n} — CI {state}, {review state}
     Branch 3 [{description}]   🚧 In progress    {branch}, no PR yet
     Branch 4 [{description}]   ⬜ Not started

   Progress: {X}/{N} branches merged

   Next:
     → {one or two lines from the table below}
   ```

5. **Next action.**

   | State | Suggest |
   |---|---|
   | Branch not started | `/atg:story-impl {TICKET} --branch N` |
   | In progress, no PR | `/atg:verify`, then `/atg:ship {TICKET} --branch N` |
   | PR open, CI failing or changes requested | `/atg:review-feedback {PR}` |
   | PR open, approved | Merge on GitHub, start next branch |
   | All merged | `/atg:qa-comment {TICKET}` then `/atg:retro {TICKET}` |

## Failures

| Situation | Action |
|---|---|
| No branches in git or GitHub | "No branches found. Has implementation started?" |
| `gh` unavailable | Report; suggest `gh auth login` |

**Next:** whatever step 5 named for the furthest-along branch.
