#!/usr/bin/env bash
# Idempotent linker for atg-agent-kit.
#   ./link.sh                      # user-level: ~/.claude/{commands/atg,skills}
#   ./link.sh --checkout <root>    # point a wavebid checkout/worktree at the kit
#
# Per-file command links + per-directory skill links — the asymmetry is load-bearing:
# the recursive **/*.md command walk skips directory symlinks (the original omp bug),
# while skill scanning follows them. Do NOT "tidy" commands into a single dir symlink.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD_DEST="$HOME/.claude/commands/atg"
SKILL_DEST="$HOME/.claude/skills"

# Prune only links whose target lives inside KIT — never touch unrelated symlinks
# (e.g. ~/.claude/skills/frontend-design -> ~/.agents/skills/...).
prune_kit_links() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    find "$dir" -maxdepth 1 -type l -print0 2>/dev/null | while IFS= read -r -d '' l; do
        case "$(readlink "$l")" in "$KIT"/*) rm -f "$l" ;; esac
    done
}

link_user() {
    mkdir -p "$CMD_DEST" "$SKILL_DEST"
    prune_kit_links "$CMD_DEST"
    prune_kit_links "$SKILL_DEST"

    local n=0
    for f in "$KIT"/commands/atg/*.md; do
        ln -sfn "$f" "$CMD_DEST/$(basename "$f")"
        n=$((n + 1))
    done
    echo "  linked $n commands -> $CMD_DEST"

    local m=0
    for d in "$KIT"/skills/*/; do
        ln -sfn "${d%/}" "$SKILL_DEST/$(basename "${d%/}")"
        m=$((m + 1))
    done
    echo "  linked $m skills -> $SKILL_DEST"
}

# Content guard — the only irreversible step in the whole kit is
# `rm -rf <root>/.claude/{commands,skills}/atg`. Refuse to run it unless the
# backup is real: kit has some content AND the working tree fully matches HEAD
# (tracked + untracked; `git diff` alone ignores untracked files). Counts are a
# sanity floor, not exact — the set grows as commands/skills are added.
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

link_checkout() {
    local root="$1"
    [[ -d "$root/.claude" ]] || { echo "not a wavebid root: $root" >&2; exit 1; }
    assert_backup_ready
    rm -rf "$root/.claude/commands/atg" "$root/.claude/skills/atg"
    mkdir -p "$root/.claude/commands" "$root/.claude/skills"
    ln -sfn "$KIT/commands/atg" "$root/.claude/commands/atg"
    ln -sfn "$KIT/skills" "$root/.claude/skills/atg"
    echo "  pointed $root at $KIT"
}

if [[ "${1:-}" == "--checkout" ]]; then
    link_checkout "${2:?usage: link.sh --checkout <wavebid-root>}"
else
    link_user
fi
