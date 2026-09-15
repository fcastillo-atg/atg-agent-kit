---
name: atg-story-artifacts
description: Use whenever an /atg:* command resolves a ticket, reads or writes anything under bin/stories/, touches implementation-plan.md (including ## As-built), or scopes a diff to a branch. Single source of truth for the story directory layout, file roles, and the never-commit-bin rule.
---

# ATG story artifacts

Every `/atg:*` command reads or writes the same small set of local files. This skill defines
them once. Commands say "resolve per atg-story-artifacts" instead of restating paths and rules.

## Resolve the ticket

In order: explicit argument, then the current branch (`fc/WBPR-1234-slug` → `WBPR-1234`), then
`find bin/stories -type d -name '*WBPR-*'` and pick the directory matching active work. Ticket
prefixes are `WBPR-*` and `SP2-*`. If nothing resolves, ask once.

## Story directory

```
bin/stories/{year}/{month}/{TICKET}-{slug}/
├── {TICKET}-story.md          Jira snapshot: title, description, ACs, ## Jira comments (summary)
├── {TICKET}-scout.md          scout audit (read-only verdict + evidence)
├── implementation-plan.md     the canonical plan (sections below)
├── EXPLAIN.md                 explain's plain-language brief
├── story-view.html            story-view's published dashboard
└── testing/
    ├── TESTING-GUIDE.md       testing-doc output (see atg-testing-guide)
    ├── TESTING-PROGRESS.md    test-run output
    ├── QA-COMMENT.md          qa-comment draft, also the posted body
    └── scenarios/*.sh         optional, testing-doc --with-scenarios
```

Locate an existing directory with `find bin/stories -type d -path "*/{TICKET}-*"`. Prefer the one
containing `implementation-plan.md` when several match. Only `brief`, `story-plan`, and `scout`
create the directory; every other command stops (or goes chat-only) when it is missing.

`bin/stories/` may sit under `wavebid-a2o-service/` or the monorepo root. Check both.

## `bin/` is local scratch, never repo content

Never `git add` or `git commit` anything under `bin/`. It is gitignored under the service but
not at the monorepo root, so the rule is behavioural. Never reference a `bin/` path in a PR
body, Jira comment, or anything a reviewer or QA will read. Inline the fact instead of linking
the file, and grep the drafted text for `bin/` before publishing.

The one repo-visible planning artifact is `wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md`
(condensed, ~100 lines, links back to the full plan; see rule doc `405-plans-location.md`).
It is committed on the implementation branch, never on `main` alone.

## `implementation-plan.md` canonical sections

In this order. Omit a section only where noted.

1. `# {TICKET}: {short title} — Implementation plan`
2. `## Pre-Analysis` — written by `brief`; omit if brief never ran
3. `## Preamble` — ticket URL, story source (file or Jira, acli or MCP), Jira comment summary
4. `## Story analysis` — requirements, current state, gaps
5. `## Architecture design` — `### Component diagram` and `### Key implementation details`
6. `## Dependencies` — external and internal
7. `## Open questions` — omit when Pre-Analysis already resolved everything; otherwise required
8. `## Performance considerations` — one line when not applicable
9. `## As-built` — placeholder `<!-- TODO: fill in after implementation -->` until the last branch ships
10. `## Lines of code estimate`
11. `## Feature flag` — omit entirely when not applicable
12. `## Branch strategy` — `### Branch N: \`fc/{TICKET}-{slug}\` (~XXX LOC)` per slice
13. `## Testing strategy`
14. `## Merge strategy`
15. `## Summary`
16. `## Next ATG command` — always the final section

Write a plan using these headings so downstream commands can find `### Branch N:` slices.
Older folders may carry a separate `branch-strategy.md`; fold it in, never create a new one.

## `## Current state` versus `## As-built`

`## Current state` (inside Story analysis) is a planning-time snapshot of the code before
implementation. Never use it to describe what the code does now.

`## As-built` records what actually shipped. Two forms:

- **Pointer form**: starts with "Implemented as planned" or contains "No deviations". The
  authoritative change list is then `## Branch strategy → Branch N: Changes`.
- **Deviation form**: lists only what differs from the plan (added file, dropped field, renamed
  method). Undocumented layers are implemented as planned.

Who touches it: `story-plan` writes the placeholder. `story-impl` fills it on the last branch,
then syncs the `.claude/plans/` copy. `ship` warns when it is still a placeholder on the last
branch. `testing-doc`, `explain`, `qa-comment`, and `retro` read it as the source of truth,
falling back to source files when absent. Do not re-document layers that matched the plan.

## `## Next ATG command` footer

`brief` and `story-plan` end `implementation-plan.md` with this section and repeat the same
lines at the end of the chat reply. On re-run, replace the existing footer; never stack two.
Use the real ticket key, not `{TICKET}`.

## Diff base and branch scoping

The default diff is `git diff origin/main...HEAD`. With `--branch N`, read
`## Branch strategy → ### Branch N:` to find the planned branch name and base. If the plan does
not spell out bases, compare against `origin/main` and say so. If `origin/main` is missing, try
`origin/master`, then report and stop the diff portion.
