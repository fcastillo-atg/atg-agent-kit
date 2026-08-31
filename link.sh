#!/usr/bin/env bash
# Idempotent deployer for atg-agent-kit.
#   ./link.sh                      # user-level: ~/.cursor/commands/atg-*.md only
#                                  #              (also prunes stale user-level
#                                  #              omp commands/skills from older
#                                  #              link.sh versions)
#   ./link.sh --checkout <root>    # a wavebid checkout/worktree + its subrepos:
#                                  # project-level omp commands + skills
#
# Asymmetry is load-bearing and mandated by each tool's discovery model:
#   - omp COMMANDS (<checkout>/.claude/commands/atg/): REAL FILE COPIES in a
#     subdir, WITH frontmatter, PROJECT-SCOPE ONLY (deployed per checkout by
#     link_checkout). omp's command glob uses ignore::WalkBuilder
#     (follow_links OFF) and loadFilesFromDir filters fileType:File, so a
#     symlinked .md is yielded then DROPPED. omp renders the frontmatter
#     description in its picker. No user-level copy: Claude Code lists user-
#     and project-scope commands separately (no dedupe by name), so a
#     ~/.claude/commands/atg copy showed every /atg:* twice in the picker.
#   - Cursor COMMANDS (~/.cursor/commands/atg-*.md): REAL FILE COPIES, FLAT
#     (no subdir — the CLI reads flat ~/.cursor/commands/*.md only), with YAML
#     frontmatter STRIPPED and the description promoted to line 1. Cursor's CLI
#     picker uses the file's first line as the description; a leading --- renders
#     as "--- (user)". omp is unaffected — it reads intact frontmatter from
#     ~/.claude. Cursor is served entirely user-level (it has no project/user
#     distinction worth exploiting the way omp does); project-level .cursor/
#     deploys only caused UI duplicates (brief + atg-brief).
#   - SKILLS (<checkout>/.claude/skills/<name>): per-DIRECTORY SYMLINKS,
#     PROJECT-SCOPE ONLY (deployed per checkout by link_checkout, same reasoning
#     as omp commands above). Skill discovery is readdir-based and follows dir
#     symlinks, so the kit stays single-source.
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

# Drop every symlink in $1 that points into the kit. Used to tear down a scope
# we no longer serve. Leaves unrelated skills (npx-installed, etc.) alone.
drop_kit_skills_from() {
    local dest="$1" m=0
    [[ -d "$dest" ]] || { echo 0; return; }
    while IFS= read -r -d '' l; do
        case "$(readlink "$l")" in "$KIT"/*) command rm -f "$l"; m=$((m + 1)) ;; esac
    done < <(find "$dest" -maxdepth 1 -type l -print0 2>/dev/null)
    echo "$m"
}

link_user() {
    # omp/Claude Code commands and skills are project-scope only now, deployed
    # per checkout by link_checkout (run `./link.sh --checkout <root>` for each
    # wavebid checkout/worktree). Claude Code lists user- and project-scope
    # commands separately (no dedupe by name), so a user-level ~/.claude/commands/atg
    # copy showed every /atg:* twice in the picker: "(user)" + "(project)" — same
    # reason skills don't get a user-level symlink either.
    #
    # Cursor has no project/user distinction worth exploiting the same way (its CLI
    # reads one flat ~/.cursor/commands/*.md dir, no per-project variant), so it stays
    # the one thing served user-level: REAL FILE COPIES, FLAT, with YAML frontmatter
    # STRIPPED and the description promoted to line 1 (Cursor's CLI picker uses the
    # file's first line as the description; a leading --- renders as "--- (user)").
    rm -rf "$HOME/.claude/commands/atg"   # remove any copy from an older link.sh
    echo "  removed ~/.claude/commands/atg/ (project-scope only; avoids picker dups)"
    rm -rf "$HOME/.cursor/commands/atg"   # stale subdir from older link.sh (caused UI dups)
    local n
    n=$(copy_commands_flat_to "$HOME/.cursor/commands") || exit 1
    echo "  copied $n commands -> ~/.cursor/commands/atg-*.md (Cursor CLI+UI, frontmatter stripped)"
    local m
    m=$(drop_kit_skills_from "$HOME/.claude/skills")
    echo "  removed $m kit skill symlinks from ~/.claude/skills (project scope only)"
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
    # Per-skill symlinks at .claude/skills/<name>, NOT one .claude/skills/atg group
    # symlink. Skill discovery is only proven to load SKILL.md ONE level under
    # .claude/skills/; a group symlink puts them two levels down, where they were
    # never observably contributing (the user-level links were doing the work).
    rm -rf "$root/.claude/skills/atg"   # legacy group symlink from an older link.sh
    mkdir -p "$root/.claude/skills"
    local m
    m=$(link_skills_to "$root/.claude/skills")
    echo "  deployed $root: $n cmd copies + $m per-skill symlinks (.claude, project scope only)"
}

# Walk up from $PWD looking for a wavebid root (same signature link_checkout
# checks: wavebid-a2o-service + wavebid-a2o-ui as direct children). Lets
# `--checkout` with no path work from anywhere inside the checkout, e.g. cwd
# is wavebid-a2o-service itself. Echoes the root, or errors if none is found
# by the time we hit /.
find_wavebid_root() {
    local dir="$PWD"
    while true; do
        if [[ -d "$dir/wavebid-a2o-service" && -d "$dir/wavebid-a2o-ui" ]]; then
            echo "$dir"
            return 0
        fi
        [[ "$dir" == "/" ]] && break
        dir="$(dirname "$dir")"
    done
    echo "not inside a wavebid checkout (no ancestor of $PWD has both wavebid-a2o-service and wavebid-a2o-ui)" >&2
    return 1
}

if [[ "${1:-}" == "--checkout" ]]; then
    if [[ -n "${2:-}" ]]; then
        link_checkout "$2"
    else
        root="$(find_wavebid_root)" || exit 1
        link_checkout "$root"
    fi
else
    link_user
fi
