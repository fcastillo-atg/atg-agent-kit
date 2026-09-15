---
description: Render a story's full lifecycle position (brief → plan → per-branch impl/verify/gap/ship → docs → retro) as a read-only dashboard published via Artifact
---

# Story view: visual lifecycle dashboard

One page showing where `{TICKET}` stands across every `/atg:*` step, with each step expandable
to its underlying document. Strictly read-only: no Gradle, no Jira writes, no pushes, no PRs,
and it never re-invokes another `/atg:*` command. Each run is a fresh snapshot to the same URL.
Story paths come from the atg-story-artifacts skill.

## Usage

```bash
/atg:story-view {TICKET}
/atg:story-view {TICKET} --branch N   # expand branch N by default; others still shown
```

## Steps

1. **Story directory.** None found: go to step 6.

2. **Static files.** From `implementation-plan.md`: `## Pre-Analysis` (and its `**Run:**` date),
   `## Branch strategy` branch names (absent means one implied branch), whether `## As-built` is
   still the TODO placeholder, LOC estimate. Plans vary; "plan done" means the file has any
   substantive section beyond Pre-Analysis (Branch strategy, LOC estimate, Architecture, or a
   filled As-built). From `{TICKET}-story.md`: AC count. Existence of `testing/TESTING-GUIDE.md`
   and `testing/TESTING-PROGRESS.md` (plus its pass/fail summary line).

3. **Live signals**, per branch:

   ```bash
   git branch -a | grep {branch}; git rev-list --count main..{branch}
   gh pr list --search "head:{branch}" --state all --json number,state,mergedAt,statusCheckRollup,reviewDecision
   ```

   Jira status per the jira-cli skill (show "Jira: unavailable" on failure). QA comment: list
   comments per jira-cli, look for a body containing `## QA Testing —`. Retro:
   `git log --all --oneline --grep="chore(retro): capture learnings from {TICKET}"`; no hit
   means "unknown, re-run /atg:retro to confirm", never "not run".

4. **Infer status per step.**

   | Step | ✓ Done | ● In progress | ○ Not started / unknown |
   |---|---|---|---|
   | Brief | `## Pre-Analysis` exists | | no plan, or plan without it |
   | Story Plan | substantive section beyond Pre-Analysis | | no plan, or Pre-Analysis only |
   | Story Impl (per branch) | branch exists, commits ahead of main | branch exists, 0 ahead | no branch |
   | Feature Flag | matching `*FeatureFlag.kt` found in `src/main/kotlin` | | plan needs one, none found |
   | Verify | PR exists, all checks green | PR exists, checks pending or red | no PR: "run /atg:verify to check" |
   | Pattern-check | never inferred | | "advisory, not persisted, run manually" |
   | Changeset | `.changeset/*.md` in `git diff origin/main...{branch} --name-only` | | missing and diff touches service/ui: "⚠ likely needed" |
   | Story Gap | never inferred | | "last run unknown, re-run to confirm" unless As-built states AC coverage |
   | Ship | PR merged | PR open | no PR |
   | Testing-doc / Test-run | guide and progress exist, progress passes | progress shows failures | either missing |
   | QA-comment | matching comment found | | not found / not checked |
   | Retro | matching commit found | | not found |

   Multi-branch: Brief and Story Plan are story-level rows; Impl through Ship nest per branch.

5. **Deep content** for every expandable row (anything not ○, excluding Pattern-check and Story
   Gap). Each fetch is independent; a failure becomes an explanatory line in that panel only.

   | Step | Content |
   |---|---|
   | Brief | full `## Pre-Analysis` text |
   | Story Plan | entire `implementation-plan.md` |
   | Story Impl | `git diff origin/main...{branch} --stat`, `git log {branch} ^main --oneline` |
   | Feature Flag | the flag file, located by `grep -rl {FlagName} src/main/kotlin`; zero or multiple hits: "could not uniquely locate" |
   | Verify | full `statusCheckRollup` (every check name and conclusion) |
   | Changeset | the matched `.changeset/*.md` |
   | Ship | `gh pr view {n} --json body`; empty: "No description provided" |
   | Testing-doc / Test-run | entire guide / progress file |
   | QA-comment | matched comment body |
   | Retro | matched commit with surrounding log lines |

6. **No-plan fallback.** Minimal page: ticket key, Jira status, and
   "Not yet planned — run /atg:brief {TICKET} or /atg:story-plan {TICKET}." Skip to step 7.

7. **Render and publish.** Load the `artifact-design` skill, then build one self-contained HTML
   page (inline CSS, no external requests) as a vertical timeline.
   - Rows with deep content are `<details>` accordions: expand in place, several open at once.
   - Rows without content are static: no chevron, no hover, default cursor.
   - Reformat each panel's markdown to the page's typography; Mermaid via `<pre class="mermaid">`.
   - If one document will not reformat cleanly, fall back to a raw `<pre>` for that panel only.
   - Never truncate; the collapsed default keeps the page scannable.
   - Header: `{TICKET} — {title}`, branch and state, Jira status.

   Write to `bin/stories/{year}/{month}/{TICKET}-{slug}/story-view.html` and publish via the
   Artifact tool from that path. Re-runs overwrite the file and redeploy to the same URL; keep
   the favicon stable (`📋`).

Any single signal that fails (gh, Jira, unreadable file, unrecognized plan format) shows
"unavailable" or "not checked" for that row; the rest of the page still renders.

**Next:** the first ○ or ● row on the page, or `/atg:verify` / `/atg:story-gap {TICKET}` for fresher status before re-running this view.
