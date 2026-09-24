---
description: Draft a Postman-style QA testing comment from TESTING-GUIDE.md, wait for approval, post it to the Jira ticket
---

# QA comment

Republish the story's `TESTING-GUIDE.md` as a self-contained Jira comment so QA can verify on
dev or stage. Always show the draft and wait for an explicit `y` before posting. Vocabulary and
Postman variable rules: **atg-testing-guide**. Paths and the never-reference-`bin/` rule:
**atg-story-artifacts**.

## Usage

```bash
/atg:qa-comment {TICKET}              # draft → approve → post
/atg:qa-comment {TICKET} --dry-run    # write and print the draft, never post
```

## Steps

1. **Locate sources** in the story's `testing/` directory.

   | File | Required | Used for |
   |---|---|---|
   | `TESTING-GUIDE.md` | yes | scenarios, overview, variables |
   | `TESTING-PROGRESS.md` | no | "locally verified" footer |
   | `../implementation-plan.md` | no | AC deferral notes from `## As-built` |

   If the guide is missing, stop:
   `No TESTING-GUIDE.md for {TICKET}. Run /atg:testing-doc {TICKET}, then /atg:test-run {TICKET}.`

2. **Detect PR state** with `gh pr list --search "{TICKET} in:title" --state all --json number,url,state`.

   | State | Environment line |
   |---|---|
   | MERGED | `**Environment:** dev / stage — [PR #{N}]({url}) already merged` |
   | OPEN | `**Environment:** [Branch build — PR #{N}]({url}) — merge pending` |
   | none | `**Environment:** dev / stage` and warn that no PR was found |

3. **Extract from the guide.** Feature name from the title; "What changed" from `## Overview`;
   variables from `## Shared setup steps`; one block per `### Scenario N` (method, endpoint,
   body from Steps; assertions from Expected results); scope notes only where the overview or
   edge cases flag an AC gap or deferral.

4. **Convert every request to Postman form.** `{{baseURL}}`, `{{token}}`, `{{houseId}}` inside
   quoted strings. No `export`, `$VAR`, pipes, or `jq`. Steps that pick IDs become prose
   ("copy `id` into `{{newItemId}}`"). Complete response body after each request, then one ✅
   assertion line.

   ```bash
   curl -si "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" -H "Authorization: Bearer {{token}}"

   curl -si -X POST "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" \
     -H "Authorization: Bearer {{token}}" -H "Content-Type: application/json" \
     -d '{ "field": "VALUE" }'

   curl -si -X DELETE "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" -H "Authorization: Bearer {{token}}"
   ```

5. **Assemble** using the template below, prose per the **unslop** skill. The AI-disclaimer line is mandatory in every comment
   and must appear verbatim, never paraphrased. If `TESTING-PROGRESS.md` shows every scenario
   PASS, append one verification line naming the date, what was actually exercised, and the step
   numbers as this comment shows them, without naming the file. Never cite the guide's scenario
   count: a reader sees Steps, and the two rarely match. Say plainly where it was not run, e.g.
   `*Verified 2026-09-23 against a locally running service calling stage, not the branch build
   above. Steps 3 to 6 passed.*`
   Grep the result for `bin/` and fix any hit.

   Write it to `testing/QA-COMMENT.md` now, including under `--dry-run`. This file is the
   durable copy and the body that gets posted; re-runs overwrite it.

6. **Print the draft and stop.**

   ```
   Draft ready. Post this comment to {TICKET}?
     y  post now      n  cancel      e  describe edits and regenerate
   ```

   `--dry-run` skips the prompt. Never post without an explicit `y`.

7. **Post** from `testing/QA-COMMENT.md` per the **jira-cli** skill's comment recipe, which
   converts Markdown to ADF and verifies the rendered result. Then print:

   ```
   QA comment posted — {TICKET}   https://auctiontechnologygroup.atlassian.net/browse/{TICKET}
   Environment: {line}   Scenarios: {N}   Saved: testing/QA-COMMENT.md
   ```

## Comment template

```markdown
## QA Testing — {TICKET}: {feature name}

**Environment:** {environment line}

**What was added**
{1–2 sentences from the guide's Overview}

NOTE: This guide was created with AI; use it as a reference; perform your own validation based on the above ACs.

**Prerequisites**
- App deployed to your target env
- House-admin credentials for write operations
- Postman environment variables:

| Variable | Value |
|----------|-------|
| `baseURL` | `{branch preview URL}` |
| `token` | *(filled after Step 1)* |
| `houseId` | *(filled after Step 2)* |

---

**Step 1 — Authenticate**

Log in with house-admin credentials and copy `token` from the response into your `token` variable.

```bash
curl -si -X POST "{{baseURL}}/api/v3/auth" \
  -H "Content-Type: application/json" \
  -d '{"username":"your-house-admin@example.com","password":"your-password"}'
```

---

**Step 2 — {Baseline GET}**

```bash
curl -si "{{baseURL}}/api/v3/houses/{{houseId}}/{endpoint}" -H "Authorization: Bearer {{token}}"
```

Expected response:
```json
{ "field": expectedValue }
```

✅ {what this confirms}

---

**Step {N} — {Scenario name}**

```bash
{request}
```

Expected response:
```json
{ complete body }
```

✅ {assertion}

---

**Acceptance criteria scope note** *(only when the guide flags a gap or deferral)*
{what was excluded and why}
```

Jira renders `---` as a rule, so keep one per step.

**Next:** `/atg:retro {TICKET}` immediately after posting. Do not wait for QA sign-off.
