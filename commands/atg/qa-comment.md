---
description: Draft and post QA testing steps as a Jira comment — HTTP guide for QA to run on dev/stage after merge
---

# Post QA testing comment to Jira

After `/atg:test-run` confirms all scenarios pass locally, post a self-contained QA comment
on the Jira ticket so QA can independently verify on dev/stage. Uses the same HTTP format
as `TESTING-GUIDE.md` (Postman-compatible). Always shows a draft and waits for explicit
approval before posting.

## Usage

```bash
/atg:qa-comment WBPR-4243               # draft → approve → post
/atg:qa-comment WBPR-4243 --dry-run     # print draft only, do not post
```

## Execution Steps

### Step 1: Locate source files

Auto-detect from ticket ID:

```bash
find bin/stories -path "*/{TICKET}*/testing/TESTING-GUIDE.md" | sort | head -1
find bin/stories -path "*/{TICKET}*/testing/TESTING-PROGRESS.md" | sort | head -1
find bin/stories -path "*/{TICKET}*/implementation-plan.md" | sort | head -1
```

| File | Required? | Used for |
|------|-----------|---------|
| `testing/TESTING-GUIDE.md` | ✅ Required | Scenarios, overview, variables |
| `testing/TESTING-PROGRESS.md` | Optional | Confirm all scenarios passed (footer note) |
| `implementation-plan.md` | Optional | Scope / AC deferral notes from `## As-built` |

The directory holding `TESTING-GUIDE.md` (`bin/stories/{year}/{month}/{TICKET}-*/testing/`) is this
command's **output** location too — see Step 5. Never write the drafted comment to a scratchpad
or temp path; it belongs alongside the other testing artifacts for this story.

**Gate:** If `TESTING-GUIDE.md` not found → stop with:

```
❌ No TESTING-GUIDE.md found for {TICKET}.
Generate one first:  /atg:testing-doc {TICKET}
Then verify locally: /atg:test-run {TICKET}
```

### Step 2: Detect PR state → environment line

```bash
gh pr list --search "{TICKET} in:title" --state all --json number,url,state
```

| PR state | Environment line |
|----------|-----------------|
| `MERGED` | `**Environment:** dev / stage — [PR #{N}]({url}) already merged` |
| `OPEN` | `**Environment:** [Branch build — PR #{N}]({url}) — merge pending` |
| Not found | `**Environment:** dev / stage` *(warn user that PR was not found)* |

### Step 3: Extract content from TESTING-GUIDE.md

Parse these sections in order:

| Content | Source in TESTING-GUIDE.md |
|---------|---------------------------|
| Feature name | `# {TICKET}: Manual testing ({Feature Name})` |
| "What was added" | "What changed:" paragraph in `## Overview` |
| Variable list | `@baseURL`, `@token`, `@houseId`, `@auctionId`, etc. from `## Shared setup steps` |
| Scenarios | `## Detailed test scenarios` — each `### Scenario N` → one `---` block |
| Scope notes | "does NOT include" bullets from `## Overview`, or explicit AC gaps in `## Edge cases` |

**Per scenario, extract:**
- HTTP method + endpoint + request body from `#### Steps`
- Key assertion fields from `#### Expected results` or `#### Validation checklist`

### Step 4: Build curl request blocks

Use `curl` with **Postman `{{variable}}` placeholders** — no shell `export` blocks, no `$VAR` syntax, no `| jq`, no pipes. **No `.http` format.**

**Prerequisites block** (emit once, as a Postman environment table):

| Variable | Value |
|----------|-------|
| `baseURL` | `<branch preview URL>` |
| `token` | *(filled after Step 1)* |
| `houseId` | *(filled after Step 2)* |
| *(others as needed)* | |

Per-step snippets:

```bash
# GET (no body):
curl -si "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" \
  -H "Authorization: Bearer {{token}}"

# POST/PUT with body:
curl -si -X POST "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" \
  -H "Authorization: Bearer {{token}}" \
  -H "Content-Type: application/json" \
  -d '{ "field": "VALUE" }'

# DELETE:
curl -si -X DELETE "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" \
  -H "Authorization: Bearer {{token}}"
```

**Rules:**
- Placeholders: `{{baseURL}}`, `{{token}}`, `{{houseId}}`, etc. — camelCase, double-braces, inside quoted strings
- **Never** use shell `$VAR`, `export VAR=...`, `| jq`, `| head`, or `export VAR=$(...)` capture patterns
- Setup steps that require picking IDs become prose instructions ("copy the `id` into `newItemId`")
- Omit `-H "Content-Type: application/json"` and `-d` body for GET/DELETE requests with no body
- Expected response: always show the **complete response body**
- One ✅ assertion line per step summarising what the response confirms

### Step 5: Assemble comment

Build the comment from the template below in this order:

1. Header + environment line
2. "What was added" (1–2 sentences from `## Overview`)
3. **AI-disclaimer note** (fixed, verbatim — see below), directly under "What was added"
4. Prerequisites block (variable list + note to authenticate first)
5. `---` + **Step 1 — Authenticate** (instruction only — no HTTP block)
6. `---` + Step 2 (baseline GET) + expected JSON + ✅ line
7. `---` + one block per scenario + expected JSON + ✅ line
8. Scope notes (only when guide explicitly flags AC gaps or deferrals)

**AI-disclaimer note** — mandatory, non-negotiable, always included regardless of ticket type
or scenario count (never paraphrase or drop it):

```
NOTE: This guide was created with AI; use it as a reference; perform your own validation based on the above ACs.
```

If `TESTING-PROGRESS.md` exists and all scenarios show `PASS`, append:
> *Locally verified — all {N} scenarios passed.*

(No filename in the appended line — `TESTING-PROGRESS.md` lives under `bin/`, is never committed,
and QA reading the Jira comment cannot open it. Naming it as if it were referenceable is
misleading; state the fact it confirms, not the path.)

**Write the assembled comment to disk immediately** — always, including under `--dry-run` —
next to `TESTING-GUIDE.md`:

```
bin/stories/{year}/{month}/{TICKET}-*/testing/QA-COMMENT.md
```

This is the durable copy (multi-line Postman-format text with `{{variables}}` also doesn't
survive inline shell escaping, so Step 7 reads from this file rather than re-generating one).
Re-running `/atg:qa-comment {TICKET}` overwrites this file with the latest draft.

### Step 6: Print draft and wait for approval

Print the full comment (from the file just written), then **stop and prompt**:

```
───────────────────────────────────────────
Draft ready. Post this comment to {TICKET}?
  y  — post now
  n  — cancel
  e  — describe edits and regenerate
───────────────────────────────────────────
```

- **`y`** → proceed to Step 7
- **`n`** → exit; nothing is posted
- **`e`** → user describes changes → regenerate → re-show draft → repeat prompt
- `--dry-run` → print draft only; skip prompt entirely

**Do NOT post until the user explicitly confirms with `y`.**

### Step 7: Post + confirm

Resolve per the **jira-cli** skill. Post using the `QA-COMMENT.md` file already written in Step 5
(same `testing/` directory as `TESTING-GUIDE.md`) — do not re-write it to a scratch or temp path:

```bash
acli jira workitem comment create --key {TICKET} --body-file bin/stories/{year}/{month}/{TICKET}-*/testing/QA-COMMENT.md
```

Fallback if `acli` is unavailable:
```
mcp__mcp-atlassian__jira_add_comment(issue_key="{TICKET}", body="{comment}")
```

Print on success:

```
✅ QA comment posted — {TICKET}
   https://auctiontechnologygroup.atlassian.net/browse/{TICKET}

Environment: {environment line}
Scenarios:   {N} steps
Saved:       bin/stories/{year}/{month}/{TICKET}-*/testing/QA-COMMENT.md

Next: /atg:retro {TICKET}
Note: Run retro now — do not wait for PR merge (retro captures story work, not merge state).
```

---

## Comment template (canonical shape)

```markdown
## QA Testing — {TICKET}: {feature name}

**Environment:** {environment line}

**What was added**
{1-2 sentence summary — "What changed:" from TESTING-GUIDE.md Overview}

NOTE: This guide was created with AI; use it as a reference; perform your own validation based on the above ACs.

**Prerequisites**
- App deployed to your target env
- House-admin credentials required for write operations
- Set these variables in your Postman environment before running any request:

| Variable | Value |
|----------|-------|
| `baseURL` | `{branch preview URL}` |
| `token` | *(filled after Step 1)* |
| `houseId` | *(filled after Step 2)* |
| *(others as needed)* | |

---

**Step 1 — Authenticate**

Log in with house-admin credentials and copy the `token` from the response into your `token` environment variable.

```bash
curl -si -X POST "{{baseURL}}/api/v3/auth" \
  -H "Content-Type: application/json" \
  -d '{"username":"your-house-admin@example.com","password":"your-password"}'
```

---

**Step 2 — {Baseline GET description}**

```bash
curl -si "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" \
  -H "Authorization: Bearer {{token}}"
```

Expected response:
```json
{
  "fieldName": expectedValue
}
```

✅ {one-line confirmation of what this verifies}

---

**Step {N} — {Scenario name}**

```bash
curl -si -X POST "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" \
  -H "Authorization: Bearer {{token}}" \
  -H "Content-Type: application/json" \
  -d '{
  "field": "VALUE"
}'
```

Expected response:
```json
{
  "field": expectedValue
}
```

✅ {one-line assertion}

---

**Acceptance criteria scope note** *(only when guide flags AC gaps or deferrals)*
{Explanation of what was intentionally excluded and why — e.g. per reviewer feedback.}
```

---

## Design rules

1. **AI-disclaimer note is mandatory, non-negotiable** — always included verbatim under "What was
   added", regardless of ticket type or scenario count; never paraphrase or drop it
2. **Draft-first, explicit approval** — always print the full comment and wait for `y`; never post silently
3. **curl with Postman `{{variable}}` placeholders** — define variables once in a Prerequisites environment table; use `{{var}}` inside quoted strings in every `curl` snippet; never use `$VAR`, `export`, `| jq`, or pipe chains
4. **Authenticate = instruction only** — Step 1 shows the auth `curl` but tells QA to copy the token into their `token` env var; no shell capture
5. **Always show the complete response body** — never truncate or show key fields only
6. **Environment line is automatic** — derived from `gh pr list`; not typed manually
7. **Scope notes are conditional** — only included when the guide explicitly flags AC gaps
8. **`TESTING-PROGRESS.md` is optional** — command works even if `/atg:test-run` was skipped
9. **One `---` divider per step** — Jira renders `---` as `<hr>`; improves readability in the ticket
10. **Output always lands in `testing/QA-COMMENT.md`** — never a scratchpad or temp path; this holds
    even for `--dry-run`, so the draft is reviewable/diffable and survives the session
11. **Never reference a `bin/` path inside the comment content itself** — `bin/` is local scratch,
    gitignored/untracked, and invisible to QA reading the Jira ticket. Everything QA needs
    (scenarios, curl blocks, expected responses, the AI disclaimer) is already inlined by this
    template; the one place this used to leak was the `TESTING-PROGRESS.md` filename in the
    "Locally verified" line — state the fact, not the filename. Before posting, grep the drafted
    comment for `bin/` and fix any hit.

## Next steps (after posting)

Run retro immediately after posting the QA comment — do not wait for PR merge or QA
sign-off. The retro captures the story's implementation work, which is already done.
Opening a new branch/PR to do it later is not feasible.

```
/atg:retro {TICKET}
```
