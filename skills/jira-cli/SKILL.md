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

Prefer an existing ATG session. If `acli` is on the wrong site (e.g. a personal
OAuth account) for `WBPR-*`/`SP2-*` keys, **switch** — do not re-login:

```bash
acli jira auth switch \
  --site auctiontechnologygroup.atlassian.net \
  --email {your-atg-email}
```

`{your-atg-email}` is the current user's own ATG Atlassian account email — never hardcode a
specific person's address here. If it isn't already known from context, `git config user.email`
is a reasonable default; ask the user to confirm if that doesn't look like an ATG address.

Interactive: `acli jira auth switch`. Verify with:

```bash
acli jira auth status
acli jira workitem view WBPR-4570 --fields status
```

Only if the ATG account is missing entirely, login with the token (never echo it):

```bash
printf '%s' "$ATG_JIRA_TOKEN" | acli jira auth login \
  --site auctiontechnologygroup.atlassian.net \
  --email {your-atg-email} \
  --token
```

`ATG_JIRA_TOKEN` is the same token already configured for the `mcp-atlassian` server in `.mcp.json`.
Check presence with `${ATG_JIRA_TOKEN:+yes}` only — never `${ATG_JIRA_TOKEN:-…}` (that prints the value).


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

**If the comment uses any Markdown formatting** (`##` headings, `**bold**`, `` `code` ``, tables,
fenced code blocks, links), it **must be converted to Atlassian Document Format (ADF) JSON**
before posting. `acli comment create --help` confirms `--body-file` only accepts "plain text or
Atlassian Document Format (ADF)" — there is no Markdown option, and Jira Cloud dropped wiki-markup
rendering for comments. Posting a `.md` file directly succeeds with no error but renders the raw
`**`/`` ` ``/`##`/`|...|` characters as literal text in the Jira UI — and the comment is now live
and visible to whoever is watching the ticket (often QA, waiting on it) before anyone notices.

Follow this order every time. Do not treat step 2 as done until step 3 has actually run —
"the JSON looked right" is not verification, and a broken public comment costs more to fix
than the extra 10 seconds this step takes:

1. **Convert.** Any Markdown formatting → ADF JSON, using a small scoped Python converter
   (headings, paragraphs with bold/code/link marks, bullet lists, tables, fenced code blocks, and
   rules cover nearly all QA-comment content — no need for a generic Markdown library).
2. **Post.**
   ```bash
   acli jira workitem comment create --key {TICKET} --body-file /path/to/comment.adf.json
   ```
3. **Verify — mandatory, not optional.** Immediately re-fetch: `acli jira workitem comment list
   --key {TICKET} --json`, and confirm the flattened text has no stray `**`/`` ` ``/`##`
   characters (including single-asterisk italics, not just `**bold**` — both slip through the
   same way). Their absence means Jira parsed real marks rather than displaying raw syntax. Only
   report the comment as posted after this check passes.

If a comment was already posted with broken (literal-Markdown) formatting, fix it in place with
`--edit-last` (edits the last comment from the same author) rather than leaving the broken one and
posting a duplicate:

```bash
acli jira workitem comment create --key {TICKET} --body-file /path/to/comment.adf.json --edit-last
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
