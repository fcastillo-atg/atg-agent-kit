---
description: Quick multi-branch story status overview — shows which branches are merged, open, or pending
---

# Status: Multi-Branch Story Overview

**Purpose:** Quick snapshot of where a multi-branch story stands — which branches are merged, which have open PRs, and which haven't started yet. Useful for stories spanning 2+ branches.

## Usage

```bash
/atg:status {TICKET}
```

## Execution Steps

### Step 1: Read branch strategy from the implementation plan

Look for `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md`. Search recursively under `bin/stories/` for any directory matching `*{TICKET}*`.

From **`## Branch strategy`**, extract:
- Total branch count
- Branch names (e.g. `fc/WBPR-4032-feature-flag`, `fc/WBPR-4032-service-layer`) — from each **`### Branch N:`** heading or body
- Branch descriptions and dependencies

If `implementation-plan.md` is not found or has no `## Branch strategy`, proceed with git-only detection (legacy folders may still have only `branch-strategy.md`; prefer merging into `implementation-plan.md`).

### Step 2: Detect branch states

For each branch identified in the strategy:

**Check if merged:**
```bash
gh pr list --search "head:{branch-name}" --state merged --json number,mergedAt,title
```

**Check if PR open:**
```bash
gh pr list --search "head:{branch-name}" --state open --json number,title,reviewDecision,statusCheckRollup
```

**Check if branch exists locally or on remote:**
```bash
git branch -a | grep {branch-name}
```

**Classify each branch:**
- `✅ Merged` — PR found in merged state
- `🔄 PR Open` — PR open (include CI status and review status)
- `🚧 In progress` — branch exists locally or remotely but no PR yet
- `⬜ Not started` — branch in strategy but not found anywhere

### Step 3: Get Jira ticket status

Resolve per the **jira-cli** skill: `acli jira workitem view {TICKET} --fields status` first, falling back to `mcp__mcp-atlassian__jira_get_issue` if `acli` is unavailable.

If neither is available, skip this step.

### Step 4: Print status report

```
Story: {TICKET} — {title from Jira or implementation-plan.md}
Jira status: {status}
Branches: {N} planned

  Branch 1 [{description}]   ✅ Merged         PR #{number} (merged {date})
  Branch 2 [{description}]   🔄 PR Open        PR #{number} — CI {passing|failing}, {review status}
  Branch 3 [{description}]   🚧 In progress    branch fc/{TICKET}-{slug} exists, no PR yet
  Branch 4 [{description}]   ⬜ Not started

Progress: {X}/{N} branches merged
```

**CI status codes for open PRs:**
- `CI passing` — all checks green
- `CI failing` — one or more checks red (show which check failed)
- `CI pending` — checks still running

**Review status codes:**
- `awaiting review` — no reviews yet
- `changes requested` — reviewer requested changes
- `approved` — at least one approval, no blocking changes

### Step 5: Print next action

Based on the current state, suggest the most relevant next action:

| State | Suggested next action |
|-------|----------------------|
| Branch not started | Implement, then run `/atg:verify` |
| Branch in progress (no PR) | Run `/atg:verify`, then `/atg:ship {TICKET} --branch {N}` |
| PR open, CI failing | `/atg:review-feedback {PR_NUMBER}` |
| PR open, changes requested | `/atg:review-feedback {PR_NUMBER}` |
| PR open, approved | Merge on GitHub, then start next branch |
| All branches merged | `/atg:retro {TICKET}` |

## Example Output

```
/atg:status WBPR-4032

Story: WBPR-4032 — Lot Address Inheritance from Auction
Jira status: In Review
Branches: 3 planned

  Branch 1 [feature-flag + domain model]   ✅ Merged      PR #451 (merged 2026-04-02)
  Branch 2 [service + repository]          🔄 PR Open     PR #456 — CI passing, awaiting review
  Branch 3 [API endpoints + integration]   ⬜ Not started

Progress: 1/3 branches merged

Next:
  → Branch 2 (PR #456) is open and CI is passing — waiting on reviewer.
    If reviewer comments arrive: /atg:review-feedback 456
  → Branch 3 can be started once Branch 2 is merged:
    /atg:story-impl WBPR-4032 --branch 3
```

## Single-Branch Story Output

For stories with only 1 branch:

```
Story: WBPR-4099 — Quick fix for lot sequence assignment
Jira status: In Review
Branches: 1

  Branch 1 [full implementation]   🔄 PR Open   PR #461 — CI passing, 1 approval ✅

Next:
  → Merge PR #461 on GitHub, then run: /atg:retro WBPR-4099
```

## Error Handling

| Situation | Action |
|-----------|--------|
| No `## Branch strategy` in plan | Use git branch listing and PR search for `{TICKET}` |
| No branches found in git or GitHub | Report "No branches found — has implementation started?" |
| `acli` and Jira MCP both unavailable | Skip Jira status; note it in output |
| `gh` CLI not available | Report error; suggest running `gh auth login` |

## Next Steps

- Branch not started: implement and run `/atg:verify`
- Branch has PR open: `/atg:review-feedback {PR_NUMBER}`
- All branches merged: `/atg:retro {TICKET}`
