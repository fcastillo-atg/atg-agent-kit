---
description: Pointer to the monorepo changeset procedure — CI requires a .changeset file for service/ui PRs unless the PR has skip-changelog
---

# Changeset (pointer)

CI (`.github/workflows/changeset-check.yml`) requires a `.changeset/*.md` on any PR that changes
`wavebid-a2o-service/` or `wavebid-a2o-ui/`, unless the PR carries the `skip-changelog` label.
This command does not duplicate the procedure.

## Usage

```bash
/atg:changeset
```

## What to do

- **Cursor:** run `/gsd/changeset-wavebid-a2o`. It writes the file, confirms the bump type, and stages it.
- **Anywhere else:** follow `.cursor/commands/gsd/changeset-wavebid-a2o.md` at the monorepo root.
- Never run interactive `pnpm changeset` from an agent session.
- Writing style and rules: `.changeset/README.md` and rule doc `406-changesets.md`.

`/atg:ship` runs the same pre-flight and stops without a changeset or an explicit `skip-changelog` confirmation.

**Next:** `/atg:ship {TICKET} [--branch N]`
