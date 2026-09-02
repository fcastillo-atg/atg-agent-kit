---
description: Render a story's current lifecycle position (brief → ship → docs → retro) as a read-only visual dashboard, published via Artifact
---

# Story View: Visual Lifecycle Dashboard

**Purpose:** Show where `{TICKET}` stands across the full `/atg:*` lifecycle — brief, plan, per-branch impl/verify/gap/ship, docs, retro — as a single visual page. **Read-only in every sense**: never runs Gradle, never posts to Jira, never pushes or creates PRs, never re-invokes `/atg:verify`, `/atg:pattern-check`, or `/atg:story-gap`. Each run is a fresh snapshot published to the same URL — there are no buttons on the page that trigger anything.

## Usage

```bash
/atg:story-view {TICKET}              # deep-dive on one story
/atg:story-view {TICKET} --branch N   # focus default detail on branch N (all branches still shown when multi-branch)
```

## Arguments

- `{TICKET}` — Jira ticket key (e.g. `WBPR-4032`)
- `--branch N` — optional; does not hide other branches, just focuses which one is expanded by default

## Execution Steps

### Step 1: Resolve ticket and story directory

Search `bin/stories/{year}/{month}/` for a directory matching `*{TICKET}*` (same convention as every other atg command). If none is found, skip directly to **Step 7 (No-plan fallback)**.

### Step 2: Read static story files

- `implementation-plan.md`, if present:
  - `## Pre-Analysis` — presence + `**Run:** {date}` line
  - `## Branch strategy` — branch count and each `### Branch N:` name; if absent, treat as a single implied branch (`N=1, M=1`)
  - `## As-built` — is it the `<!-- TODO -->` placeholder, or filled in?
  - Lines of code estimate

  **Real plans vary in format** — not every plan uses the full canonical section list. A condensed single-branch plan may have only `## Pre-Analysis` / `## Architecture` / `## Dependencies` / `## As-built` with no dedicated `## Branch strategy` or `## Lines of code estimate` heading at all. Treat "Story Plan done" as: the file exists **and** has substantive content beyond just `## Pre-Analysis` (i.e. `## Branch strategy`, `## Lines of code estimate`, `## Architecture`, or a filled-in `## As-built` — any one of these is sufficient). Don't require an exact heading match.
- `{TICKET}-story.md`, if present: count acceptance criteria (numbered list items, `- [ ]` checkboxes, or items under "Definition of Done" — whichever the file uses)
- `testing/TESTING-GUIDE.md` — exists?
- `testing/TESTING-PROGRESS.md` — exists? If so, extract the pass/fail summary line

### Step 3: Gather git signals (per branch)

For each branch identified in Step 2 (or the single implied branch):

```bash
git branch -a | grep {branch-name}
git rev-list --count main..{branch-name} 2>/dev/null
```

Classify: branch doesn't exist / exists with 0 commits ahead / exists with commits ahead.

### Step 4: Gather GitHub signals (per branch)

```bash
gh pr list --search "head:{branch-name}" --state all --json number,state,mergedAt,statusCheckRollup,reviewDecision
```

Classify per branch: no PR / PR open (+ CI rollup + review decision) / PR merged.

### Step 5: Gather Jira signal

Resolve per the **jira-cli** skill: `acli jira workitem view {TICKET} --fields status` first, falling back to `mcp__mcp-atlassian__jira_get_issue` if `acli` is unavailable. If both fail, show `Jira: unavailable` on the page rather than blocking the rest of the render.

### Step 6: Best-effort docs signals

These are best-effort — if a lookup fails or is ambiguous, show "not checked" rather than guessing:

- **QA comment posted?** `acli jira workitem comment list --key {TICKET} --json` (or MCP fallback), look for a comment body containing `## QA Testing —`.
- **Retro captured?** `git log --all --oneline --grep="chore(retro): capture learnings from {TICKET}"` — the commit `/atg:retro` offers at its last step, and the only signal that carries the ticket ID. The patterns retro appends are prose about the codebase and do not mention `{TICKET}`, so grepping the rule docs for the ticket would always come back empty. No commit means retro either never ran or the user declined the commit: show "unknown — re-run `/atg:retro {TICKET}` to confirm," never "not run."

### Step 7: No-plan fallback

If Step 1 found no story directory: render a minimal page with only the ticket key, Jira status (Step 5, best-effort), and the line:

```
Not yet planned — run /atg:brief {TICKET} or /atg:story-plan {TICKET} to get started.
```

Skip Steps 2–6, 8 entirely; go straight to Step 9 with this minimal content.

### Step 8: Apply the per-step status inference table

| Step | ✓ Done | ● In progress | ○ Not started / unknown |
|---|---|---|---|
| Brief | `## Pre-Analysis` exists | — | no plan file (or plan exists without it) |
| Story Plan | plan file has content beyond `## Pre-Analysis` (`## Branch strategy`, LOC estimate, `## Architecture`, or filled-in `## As-built` — any one) | — | no `implementation-plan.md`, or only `## Pre-Analysis` present |
| Story Impl *(per branch)* | branch exists, commits ahead of main | branch exists, 0 commits yet | branch doesn't exist |
| Feature Flag | matching `*FeatureFlag.kt` found via `grep -rl` in `src/main/kotlin` | — | plan's `## Feature flag` section is non-empty but no match found |
| Verify | PR exists, all CI checks green | PR exists, checks pending/red | no PR yet — "not yet run, or run `/atg:verify` to check" |
| Pattern-check | *(never inferred)* | | always "○ run manually if you want this — advisory, not persisted" |
| Changeset | matching `.changeset/*.md` found via `git diff origin/main...{branch-name} --name-only \| grep '^\.changeset/'` | | missing, but diff touches `wavebid-a2o-service/` or `wavebid-a2o-ui/` → "⚠ likely needed" |
| Story Gap | *(never inferred)* | | "○ last run: unknown — re-run to confirm," unless `## As-built` explicitly states AC coverage |
| Ship | PR merged | PR open | no PR |
| Testing-doc / Test-run | both guide + progress files exist, progress shows pass | progress file shows failures | either file missing |
| QA-comment | Step 6 found a matching comment | | not found / not checked |
| Retro | Step 6 found a matching grep hit | | not found |

For multi-branch stories, nest the **Story Impl → Ship** rows per branch under a shared "Story Plan" line, since Brief/Plan are story-level and the rest are per-branch:

```
✓ Story Plan     implementation-plan.md · 3 branches (~1200 LOC)

  Branch 1: fc/WBPR-XXXX-flag-and-domain
  ✓ Impl   ✓ Verify   ✓ Review   ✓ Gap   ✓ Ship — merged

  Branch 2: fc/WBPR-XXXX-service-layer
  ● Impl   ○ Verify   ○ Review   ○ Gap   ○ Ship — PR open, CI passing

  Branch 3: fc/WBPR-XXXX-api-endpoints
  ○ Not started
```

### Step 8b: Gather deep-info content per step (for expandable panels)

For every row that will render as expandable (anything not `○ Not started`, and excluding Pattern-check/Story Gap which are never expandable), additionally gather:

| Step | Content to fetch |
|---|---|
| Brief | The full `## Pre-Analysis` text block (already read in Step 2 — reuse it, don't re-read) |
| Story Plan | The entire `implementation-plan.md` file content (already read in Step 2 — reuse it in full, not just the extracted headings) |
| Story Impl *(per branch)* | `git diff origin/main...{branch-name} --stat` and `git log {branch-name} ^main --oneline` |
| Feature Flag | Locate the file via `grep -rl "{FlagName}" src/main/kotlin` (using the name from the plan's `## Feature flag` section) and read its full content. If the grep matches zero or more than one file, do not guess — record "could not uniquely locate the flag file" for the panel instead |
| Verify *(per branch)* | The full `statusCheckRollup` array already fetched in Step 4 — every check's `name` and `conclusion`, not just the compact all-green summary |
| Changeset *(per branch)* | The full content of the matched `.changeset/*.md` file |
| Ship *(per branch)* | `gh pr view {number} --json body` for that branch's PR description. If `body` is empty or null, record "No description provided" |
| Testing-doc | The entire `testing/TESTING-GUIDE.md` file content |
| Test-run | The entire `testing/TESTING-PROGRESS.md` file content |
| QA-comment | The matched comment's full body text (from the Step 6 lookup) |
| Retro | The matched excerpt (surrounding lines, not just the filename) from the Step 6 grep |

Every fetch in this table is independent — if one fails (file unreadable, `gh`/Jira error), record that specific failure for that one panel and continue gathering the rest. Never let one failed fetch stop the others.

### Step 9: Render and publish

Build a single self-contained HTML page (inline CSS, no external requests — per the Artifact tool's constraints) using the vertical-timeline layout. Every row with content gathered in Step 8b becomes an expandable accordion (`<details>`/`<summary>` or equivalent inline toggle — click to expand in place, click again to collapse, multiple open at once, no page navigation). Rows with no Step 8b content (`○ Not started`, or the never-expandable Pattern-check/Story Gap) render as plain static rows: no chevron, no hover state, default cursor.

```
{TICKET} — {title from story.md or plan}
Branch: {branch name} ({state})   Jira: {status}
───────────────────────────────────────────────────────────
▸ ✓ Brief          Pre-Analysis logged {date}
  {expanded: full Pre-Analysis text}
▸ ✓ Story Plan     implementation-plan.md · {N} branch(es) (~{LOC} LOC)
  {expanded: full implementation-plan.md, reformatted — Mermaid diagrams via <pre class="mermaid">}
{per-branch or single-branch rows, each independently expandable per Step 8b}
```

**Content fidelity rules:**
- Reformat each panel's markdown to match the dashboard's own typography (headings, tables, code blocks) — don't dump raw text in a `<pre>` block as the default.
- **Exception:** if a specific document's markdown doesn't cleanly reformat (malformed table, unclosed fence, deeply nested structure that breaks the renderer), fall back to a raw `<pre>` block for *that one panel only* — never let a malformed doc break the rest of the page.
- No truncation — embed full content once expanded, regardless of length. The accordion's collapsed default is what keeps the page scannable, not content trimming.
- A gather failure from Step 8b (unresolvable file, empty PR body, etc.) renders as an explanatory line in that panel ("could not uniquely locate the flag file — checked `grep -rl ... src/main/kotlin`"), never as a broken/empty panel or a page-level error.

Write the file to `bin/stories/{year}/{month}/{TICKET}-{slug}/story-view.html`, then publish it via the Artifact tool from that same path. **Re-running this command overwrites the file and redeploys to the same Artifact URL** — do not create a new path per run. Use a stable favicon emoji (e.g. `📋`) and keep it the same across re-runs of the same ticket.

## Error Handling

| Situation | Action |
|-----------|--------|
| No story directory found | Render minimal "not yet planned" page (Step 7) |
| `gh` unavailable / not authenticated | Show "GitHub state unavailable" for affected rows; continue rendering everything else |
| Jira unreachable (acli + MCP both fail) | Show "Jira: unavailable"; continue rendering everything else |
| `implementation-plan.md` exists but unparseable (missing expected headings) | Show what could be parsed; note "plan format not recognized" for the rest rather than failing |
| Any single signal-gathering step errors | Never abort the whole render — that section shows "unavailable" or "not checked" and the rest of the page still renders |
| A mapped file for a panel can't be uniquely located | Show what was checked in that panel; render every other panel normally |
| A doc's markdown doesn't cleanly reformat | Fall back to a raw `<pre>` block for that one panel only |

## Next Steps

- If the story isn't planned yet: `/atg:brief {TICKET}` or `/atg:story-plan {TICKET}`
- If you want fresher Verify/Story Gap status than "unknown": run `/atg:verify` / `/atg:story-gap {TICKET}` directly, then re-run `/atg:story-view {TICKET}` to reflect it
- Re-run `/atg:story-view {TICKET}` any time state changes — it always redeploys to the same link
