#!/usr/bin/env bash
# Idempotent deployer for atg-agent-kit.
#   ./link.sh                      # user-level: ~/.claude/{commands/atg,skills}
#                                  #              ~/.cursor/commands/atg-*.md
#   ./link.sh --checkout <root>    # a wavebid checkout/worktree + its subrepos
#
# Asymmetry is load-bearing and mandated by each tool's discovery model:
#   - omp COMMANDS (~/.claude/commands/atg/): REAL FILE COPIES in a subdir,
#     WITH frontmatter. omp's command glob uses ignore::WalkBuilder
#     (follow_links OFF) and loadFilesFromDir filters fileType:File, so a
#     symlinked .md is yielded then DROPPED. omp renders the frontmatter
#     description in its picker.
#   - Cursor COMMANDS (~/.cursor/commands/atg-*.md): REAL FILE COPIES, FLAT
#     (no subdir — the CLI reads flat ~/.cursor/commands/*.md only), with YAML
#     frontmatter STRIPPED and the description promoted to line 1. Cursor's CLI
#     picker uses the file's first line as the description; a leading --- renders
#     as "--- (user)". omp is unaffected — it reads intact frontmatter from
#     ~/.claude. Cursor is served entirely user-level; project-level .cursor/
#     deploys only caused UI duplicates (brief + atg-brief).
#   - SKILLS (~/.claude/skills/<name>): per-DIRECTORY SYMLINKS. Skill discovery
#     is readdir-based and follows dir symlinks, so the kit stays single-source.
# Kit is source of truth — re-run link.sh after editing a command.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Materialize commands/atg/*.md (except README.md) as real files at $1, WITH
# frontmatter intact (omp renders the description field). Wipes $1 first so
# deletes propagate. Echoes the count copied.
copy_commands_to() {
    local dest="$1"
    rm -rf "$dest"
    mkdir -p "$dest"
    local n=0
    for f in "$KIT"/commands/atg/*.md; do
        # README.md is documentation, not a command — skip so it doesn't
        # register as /atg:README in autocomplete.
        [[ "$(basename "$f")" == "README.md" ]] && continue
        cp "$f" "$dest/$(basename "$f")"
        n=$((n + 1))
    done
    echo "$n"
}

# Materialize commands/atg/*.md as FLAT $1/atg-<name>.md with YAML frontmatter
# STRIPPED and the description promoted to line 1 — the format Cursor's CLI
# picker needs (it uses line 1 as the description; a leading --- shows as
# "--- (user)"). Wipes only prior atg-*.md so siblings (rams.md, pgsd/) survive.
# Files without frontmatter are copied verbatim (their H1 already renders).
copy_commands_flat_to() {
    local dest="$1"
    mkdir -p "$dest"
    rm -f "$dest"/atg-*.md
    local n=0 f base out
    for f in "$KIT"/commands/atg/*.md; do
        base=$(basename "$f")
        [[ "$base" == "README.md" ]] && continue
        out="$dest/atg-${base%.md}.md"
        awk -v out="$out" '
            BEGIN { infm=0; have_desc=0; desc=""; body="" }
            NR==1 && /^---[[:space:]]*$/ { infm=1; next }
            infm && /^---[[:space:]]*$/ { infm=0; next }
            infm && /^description:[[:space:]]*/ { sub(/^description:[[:space:]]*/, ""); desc=$0; have_desc=1; next }
            infm { next }
            { body = body $0 "\n" }
            END {
                if (have_desc) { print desc > out; print "" > out }
                printf "%s", body > out
            }
        ' "$f"
        n=$((n + 1))
    done
    # Assert no output kept frontmatter on line 1 — catches a silent awk
    # portability failure ([[:space:]] on older BWK awk) loudly instead of
    # shipping mangled files that render as "--- (user)" in Cursor's picker.
    local bad
    bad=$(for fb in "$dest"/atg-*.md; do if [ "$(head -1 "$fb")" = "---" ]; then echo "$fb"; fi; done)
    if [ -n "$bad" ]; then
        echo "refusing: frontmatter not stripped from (awk failure?): $bad" >&2
        return 1
    fi
    echo "$n"
}

# Symlink each skills/<name>/ dir into $1, pruning only prior links into KIT.
link_skills_to() {
    local dest="$1"
    mkdir -p "$dest"
    find "$dest" -maxdepth 1 -type l -print0 2>/dev/null | while IFS= read -r -d '' l; do
        case "$(readlink "$l")" in "$KIT"/*) rm -f "$l" ;; esac
    done
    local m=0
    for d in "$KIT"/skills/*/; do
        ln -sfn "${d%/}" "$dest/$(basename "${d%/}")"
        m=$((m + 1))
    done
    echo "$m"
}

link_user() {
    # omp reads ~/.claude/commands/atg/ (subdir, frontmatter intact). Cursor's
    # CLI reads FLAT ~/.cursor/commands/atg-*.md with frontmatter stripped
    # (line 1 = description). Skills symlink into ~/.claude/skills (omp skill
    # discovery follows dir symlinks). Cursor is served entirely user-level —
    # no project-level deploy, which only caused UI duplicates.
    local n
    n=$(copy_commands_to "$HOME/.claude/commands/atg")
    echo "  copied $n commands -> ~/.claude/commands/atg/ (omp, frontmatter intact)"
    rm -rf "$HOME/.cursor/commands/atg"   # stale subdir from older link.sh (caused UI dups)
    n=$(copy_commands_flat_to "$HOME/.cursor/commands") || exit 1
    echo "  copied $n commands -> ~/.cursor/commands/atg-*.md (Cursor CLI+UI, frontmatter stripped)"
    local m
    m=$(link_skills_to "$HOME/.claude/skills")
    echo "  linked $m skills -> ~/.claude/skills (dir symlinks)"
}

# Content guard — link_checkout rm -rf's the checkout's atg dirs; refuse unless
# the kit is a real backup (content present AND tree fully matches HEAD, tracked
# + untracked; `git diff --quiet HEAD` alone misses untracked files).
assert_backup_ready() {
    local cmds skills
    cmds=$(ls -1 "$KIT"/commands/atg/*.md 2>/dev/null | wc -l | tr -d ' ')
    skills=$(ls -1d "$KIT"/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$cmds" -le 0 || "$skills" -le 0 ]]; then
        echo "refusing: kit is empty ($cmds commands / $skills skills)" >&2
        exit 1
    fi
    git -C "$KIT" rev-parse HEAD >/dev/null 2>&1 \
        || { echo "refusing: $KIT has no commit yet" >&2; exit 1; }
    [[ -z "$(git -C "$KIT" status --porcelain)" ]] \
        || { echo "refusing: $KIT has uncommitted/untracked changes — commit first" >&2; exit 1; }
    echo "  backup verified: $cmds commands, $skills skills, clean tree @ $(git -C "$KIT" rev-parse --short HEAD)"
}

# Deploy into a wavebid checkout/worktree. omp + Claude Code read project-level
# .claude/commands/atg/ (subdir, frontmatter intact). Cursor is served entirely
# by link_user's user-level flat deploy, so we do NOT touch project .cursor/ —
# we only remove any stale .cursor/commands/atg subdir left by older link.sh
# versions (it caused UI duplicates). Skills stay a dir symlink.
link_checkout() {
    local root="$1"
    # Guard on wavebid structure, NOT $root/.claude — .claude is gitignored, so a
    # fresh `git worktree add` has none until we create it (copy_commands_to mkdirs).
    [[ -d "$root/wavebid-a2o-service" && -d "$root/wavebid-a2o-ui" ]] \
        || { echo "not a wavebid root (expected wavebid-a2o-service + wavebid-a2o-ui): $root" >&2; exit 1; }
    assert_backup_ready
    local n
    n=$(copy_commands_to "$root/.claude/commands/atg")
    local sub
    for sub in "" "wavebid-a2o-service" "wavebid-a2o-ui"; do
        rm -rf "$root/$sub/.cursor/commands/atg"
    done
    rm -rf "$root/.claude/skills/atg"
    mkdir -p "$root/.claude/skills"
    ln -sfn "$KIT/skills" "$root/.claude/skills/atg"
    echo "  deployed $root: $n cmd copies (.claude) + skill symlink (Cursor served user-level by link_user)"
}

if [[ "${1:-}" == "--checkout" ]]; then
    link_checkout "${2:?usage: link.sh --checkout <wavebid-root>}"
else
    link_user
fi
