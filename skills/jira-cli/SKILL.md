---
name: jira-cli
description: Jira operations via Atlassian CLI (acli) for ATG's Jira site. Use for fetching issues/comments, searching JQL, transitioning status, and adding comments from any /atg:* command. Preferred over the mcp-atlassian MCP server; MCP is the fallback.
---

# Jira CLI (ATG)

Wraps **`acli`** (Atlassian CLI, already installed — `acli --version`). This repo's Jira site is
**`auctiontechnologygroup.atlassian.net`**; ticket prefixes are `WBPR-*` and `SP2-*`.

## Resolution order (all `/atg:*` commands)

1. **`acli`** — try first. Compact output, no MCP server round-trip.
2. **`mcp__mcp-atlassian__jira_*`** — fallback if `acli` is missing, unauthenticated, or errors.
3. **Local file / ask the user** — fallback if both are unavailable (e.g. `{TICKET}-story.md`, or ask the user to paste the ticket).

Do not duplicate this fallback tree in each command file — commands should just say "resolve per the jira-cli skill" and note which of the three tiers was actually used in their output.

## Auth

Auth is token-based against the ATG site and does not need a per-command `acli auth switch` —
`acli` resolves the ATG session automatically for `WBPR-*`/`SP2-*` keys. Verify with:

```bash
acli jira workitem view WBPR-4570 --fields status
```

If that returns the wrong site's data (e.g. an unrelated ticket, or a "not found" for a real
key), re-auth explicitly:

```bash
echo "$ATG_JIRA_TOKEN" | acli jira auth login \
  --site auctiontechnologygroup.atlassian.net \
  --email franklincastillo@auctiontechnologygroup.com \
  --token
```

`ATG_JIRA_TOKEN` is the same token already configured for the `mcp-atlassian` server in `.mcp.json`.

## Token-efficiency rule

**Always pass `--fields`.** Unscoped `view`/`search` return every field (custom fields, avatars,
watchers, etc.) — the whole point of preferring the CLI is smaller output.

- **Status-only checks** (e.g. `/atg:status`): use plain text output, not `--json` — a single field
  doesn't need a JSON wrapper.
  ```bash
  acli jira workitem view {TICKET} --fields status
  ```
- **Full fetch with comments** (e.g. `/atg:story-plan`, `/atg:brief`, `/atg:story-gap`): use `--json`
  so the comment bodies are cleanly parseable.
  ```bash
  acli jira workitem view {TICKET} --fields summary,description,comment --json
  ```
- **Comment listing on its own**: also use `--json` — the default table renderer pads every column
  to the widest cell and is *more* verbose than JSON for anything but a one-line comment.
  ```bash
  acli jira workitem comment list --key {TICKET} --json
  ```

## Recipes

### View issue (status only)
```bash
acli jira workitem view {TICKET} --fields status
```

### View issue + comments (full fetch, e.g. story-plan/brief/story-gap)
```bash
acli jira workitem view {TICKET} --fields summary,description,comment --json
```

### Search with JQL
```bash
acli jira workitem search --jql "key = {TICKET}" --json
```

### Transition status (e.g. ship.md Step 10)
```bash
acli jira workitem transition --key {TICKET} --status "Code Review" -y
```
Use the **exact** status name from the ATG Jira workflow (`Code Review`, not `code review` or `In Review`).

### Add a comment (e.g. qa-comment.md)

Always write the body to a file first — QA comments are multi-line Postman-format text with
`{{variables}}`; inline `--body` is subject to shell-escaping mangling.

```bash
acli jira workitem comment create --key {TICKET} --body-file /path/to/comment.md
```

## Fallback to MCP

If any `acli` command fails (not installed, auth error, network error), fall back to the
equivalent `mcp__mcp-atlassian__jira_*` tool for that same step, and note in the command's output
that the CLI was unavailable:

| Operation | acli | MCP fallback |
|---|---|---|
| View issue | `jira workitem view` | `mcp__mcp-atlassian__jira_get_issue` |
| Search | `jira workitem search` | `mcp__mcp-atlassian__jira_search` |
| Transition | `jira workitem transition` | `mcp__mcp-atlassian__jira_get_transitions` + `mcp__mcp-atlassian__jira_transition_issue` |
| Add comment | `jira workitem comment create` | `mcp__mcp-atlassian__jira_add_comment` |

Never use `getJiraIssue` / `searchJiraIssuesUsingJql` — those are claude.ai-connector tool names,
not the real `mcp-atlassian` MCP tool names.

## If both are unavailable

Fall back to the ticket's local snapshot file (`bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-story.md`)
if it exists, or ask the user to paste the Jira fields and relevant comments.
