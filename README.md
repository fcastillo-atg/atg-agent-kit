# atg-agent-kit

Personal `atg` slash commands and skills for Claude Code, omp, and Cursor. Git-tracked
backup and single source of truth; `link.sh` deploys them into each runtime's native
format so they load from any cwd or worktree.

## Contents

- `commands/atg/*.md` — 19 `/atg:*` slash commands (plus `README.md`, which is
  documentation and excluded from deploys).
- `skills/<name>/` — 6 flat skill directories (flattened from the repo's nested
  `skills/atg/<name>/` layout, which omp does not discover).
- `link.sh` — idempotent installer.

## Install (user-level, any machine)

```bash
~/ATG/atg-agent-kit/link.sh
```

Deploys three ways — each tool reads a different path/format:

- **omp** → `~/.claude/commands/atg/*.md` — real file copies in a subdir, **with**
  YAML frontmatter (omp renders `description:` in its picker). Exposed as `/atg:brief`.
- **Cursor (CLI + UI)** → `~/.cursor/commands/atg-*.md` — real file copies, **flat**
  (no subdir), with YAML frontmatter **stripped** and the description hoisted to line 1.
  Cursor's CLI picker uses line 1 as the description; a leading `---` renders as
  `--- (user)`. Exposed as `/atg-brief` (hyphen — Cursor has no `ns:cmd` syntax).
- **skills** → `~/.claude/skills/<name>/` — per-directory symlinks (omp skill discovery
  follows dir symlinks, so the kit stays single-source).

Commands are real file copies (not symlinks) because omp's command glob drops symlinked
`.md`, and Cursor's walker dead-ends on dir symlinks. Trade-off: the kit is the source of
truth — re-run `link.sh` after editing a command.

Safe to re-run; prunes only its own prior outputs. Restart omp / Cursor Agent after the
first install — discovery runs at session init, not on a watcher.

## Point a wavebid checkout/worktree at the kit

```bash
~/ATG/atg-agent-kit/link.sh --checkout /path/to/wavebid-a2o
```

Deploys real file copies into `<root>/.claude/commands/atg/` (Claude Code project) and
re-links skills. Cursor is served entirely user-level (above), so this does **not** touch
project `.cursor/` — it only removes any stale `.cursor/commands/atg/` subdir left by
older `link.sh` versions (those caused UI duplicates). Refuses to run unless the kit has a
clean commit.

## Why this exists

The content previously lived as untracked real directories inside the gitignored
`wavebid-a2o/.claude/` tree — invisible to `git`, destroyed by `git clean -xfd`, and (the
skills) undiscoverable by omp because of their nesting depth. This kit fixes all three:
real git history, cwd-independent deploys, and a flat skill layout.
