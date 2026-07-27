---
description: Pointer to monorepo changeset procedure — CI requires .changeset for service/ui PRs unless skip-changelog
---

# Changeset (ATG pointer)

**Purpose:** This repo does not duplicate the full changeset spec. Use the canonical GSD command and file.

## When you need a changeset

If your PR changes files under **`wavebid-a2o-service/`** or **`wavebid-a2o-ui/`**, CI ([`changeset-check.yml`](../../../../.github/workflows/changeset-check.yml)) expects a **`.changeset/*.md`** file on the branch, unless the PR has the **`skip-changelog`** label.

## What to run

- **Cursor:** **`/gsd/changeset-wavebid-a2o`** — writes `.changeset/[slug].md` with correct frontmatter, confirms bump type, stages the file. **Do not** run interactive `pnpm changeset` from agent sessions without a TTY.
- **Full procedure:** Read [`.cursor/commands/gsd/changeset-wavebid-a2o.md`](../../../../.cursor/commands/gsd/changeset-wavebid-a2o.md) from the monorepo root.

## Product copy

See [`.changeset/README.md`](../../../../.changeset/README.md) for writing style (user-facing sentences, not ticket IDs only).

## Workflow position

Add the changeset **before** `/atg:ship` when the diff is in scope. `/atg:ship` runs a matching pre-flight check.

## Next Steps

1. Create or confirm the changeset (or plan **`skip-changelog`** on the PR)
2. `/atg:ship {TICKET}`
