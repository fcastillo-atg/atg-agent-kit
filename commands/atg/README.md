# `/atg:*` commands

Canonical directory: `~/ATG/atg-agent-kit/commands/atg/`. `link.sh` deploys real copies to
`<repo-root>/.claude/commands/atg/` (Claude Code) and `~/.cursor/commands/atg-*.md` (Cursor,
frontmatter stripped). Re-run it after editing anything here.

The command table, workflow diagram, skills table and install steps are in the
[kit README](../../README.md). Each command's own file is its reference: usage, flags, steps.

## Shared rules live in skills

Commands do not restate these. When you need one, read the skill.

| Need | Skill |
|---|---|
| Ticket resolution, `bin/stories/` layout, `implementation-plan.md` sections, `## As-built`, never commit `bin/` | `atg-story-artifacts` |
| What runs next, which steps block or stay manual | `atg-lifecycle` |
| Scenario vs step, variable conventions, `TESTING-GUIDE.md` template | `atg-testing-guide` |
| Kotlin, Spock, Gradle and rule-doc pointers | `atg-service-rules` |
| Jira fetch, transition, comment, ADF | `jira-cli` |

## Command skeleton

```markdown
---
description: one line, shown in the picker
---

# Title

One or two sentences.

## Usage
```bash
/atg:name {TICKET} [--flag]
```

## Steps
1. ...

## Failures            (optional)
| Situation | Action |

**Next:** /atg:successor ...
```

Target under 150 lines. Examples: at most one, under 15 lines, only when the format is
non-obvious. Emphasis once. No "Legacy" notes; fold migrations into the rule itself.

## Adding a command

1. Create `<name>.md` here following the skeleton.
2. Add it to the kit README's table and to the `atg-lifecycle` successor table.
3. `~/ATG/atg-agent-kit/link.sh` then `link.sh --checkout <wavebid-root>`.

## Project context

These commands are service-agnostic. Everything that differs between services - build and gate
commands, repo paths, branch naming, PR template, whether the service has changesets or feature
flags - is resolved at run time from the **atg-repo-profile** skill. See `## Supported services`
in the kit README for the current list and what adding another one takes.
