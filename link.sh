#!/usr/bin/env bash
# Idempotent deployer for atg-agent-kit.
#   ./link.sh                      # user-level: ~/.claude/{commands/atg,skills}
#   ./link.sh --checkout <root>    # a wavebid checkout/worktree + its subrepos
#
# Asymmetry is load-bearing and mandated by omp's discovery model
# (omp://fs-scan-cache-architecture.md + omp://slash-command-internals.md):
#   - COMMANDS are deployed as REAL FILE COPIES. omp's command glob uses
#     ignore::WalkBuilder with follow_links OFF and loadFilesFromDir filters
#     fileType:File, so a symlinked .md is yielded then DROPPED (file_type is
#     Symlink, not File). Cursor's project walker likewise dead-ends on the
#     .cursor -> .claude -> kit dir-symlink chain. Real files pass everywhere.
#     Trade-off: kit is source of truth — re-run link.sh after editing a command.
#   - SKILLS are deployed as per-DIRECTORY SYMLINKS. Skill discovery is
#     readdir-based and follows dir symlinks, so the kit stays single-source.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Materialize commands/atg/*.md (except README.md) as real files at $1.
# Wipes $1 first so deletes propagate. Echoes the count copied.
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
    # omp reads user-level commands; Cursor reads project-level. Deploy real
    # files at the user level so omp (and Claude Code CLI) find them from any cwd.
    local n
    n=$(copy_commands_to "$HOME/.claude/commands/atg")
    echo "  copied $n commands -> ~/.claude/commands/atg (real files)"
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

# Deploy into a wavebid checkout/worktree. Commands become real files so Cursor's
# project walker (which resolves .cursor/commands/atg -> ../../.claude/commands/atg)
# finds them; the subrepos' own .claude/commands/atg symlinks chain into these.
# Skills stay a dir symlink — omp skill discovery follows dir symlinks.
link_checkout() {
    local root="$1"
    [[ -d "$root/.claude" ]] || { echo "not a wavebid root: $root" >&2; exit 1; }
    assert_backup_ready
    local n
    n=$(copy_commands_to "$root/.claude/commands/atg")
    rm -rf "$root/.claude/skills/atg"
    mkdir -p "$root/.claude/skills"
    ln -sfn "$KIT/skills" "$root/.claude/skills/atg"
    echo "  deployed $root: $n command copies + skill dir-symlink -> $KIT"
}

if [[ "${1:-}" == "--checkout" ]]; then
    link_checkout "${2:?usage: link.sh --checkout <wavebid-root>}"
else
    link_user
fi
