# atg-agent-kit

Personal `atg` slash commands and skills for Claude Code / omp. Git-tracked backup
and single source of truth; linked into the runtimes via symlinks so they load from
any cwd.

## Contents

- `commands/atg/*.md` — 19 `/atg:*` slash commands.
- `skills/<name>/` — 6 flat skill directories (flattened from the repo's nested
  `skills/atg/<name>/` layout, which omp does not discover).
- `link.sh` — idempotent installer.

## Install

```bash
~/ATG/atg-agent-kit/link.sh
```

Creates per-file symlinks `~/.claude/commands/atg/*.md` → kit, and per-directory
symlinks `~/.claude/skills/<name>` → kit. Safe to re-run; prunes only links that
already point into this kit. Restart omp (or start a new Claude Code session) after
the first install — command and skill discovery runs at session init, not on a watcher.

To point a wavebid checkout or worktree at the kit (so Cursor's project-relative
`.claude/` paths resolve to the same content):

```bash
~/ATG/atg-agent-kit/link.sh --checkout /path/to/wavebid-a2o
```

This replaces real dirs with symlinks and refuses to run unless the kit has a clean
commit with 19 commands and 6 skills.

## Why this exists

The content previously lived as untracked real directories inside the gitignored
`wavebid-a2o/.claude/` tree — invisible to `git`, destroyed by `git clean -xfd`, and
(the skills) undiscoverable by omp because of their nesting depth. This kit fixes all
three: real git history, cwd-independent symlinks, and a flat skill layout.

See `local://atg-agent-kit-migration-plan.md` for the full rationale and the
load-bearing asymmetry between command links (per-file) and skill links (per-directory).
