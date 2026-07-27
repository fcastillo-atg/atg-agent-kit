---
description: Execute test scenarios from a TESTING-GUIDE.md — authenticate, run each step via curl, assert results, generate TESTING-PROGRESS.md
---

# Test Run: Execute TESTING-GUIDE Scenarios

**Purpose:** Read a Gen 3 `TESTING-GUIDE.md`, mechanically execute every shared-setup step and scenario step via `curl`, extract `{{variables}}` from JSON responses, assert expected status codes and field values, and generate a `TESTING-PROGRESS.md` alongside the guide with full request/response JSONs per step.

**Lifecycle position:** Runs after `/atg:testing-doc` generates the guide. Companion to the manual testing workflow. Also useful before merge to catch bugs that unit tests miss (e.g., Hibernate flush-order issues, constraint violations).

## Usage

```bash
/atg:test-run WBPR-4127                     # auto-discover guide under bin/stories/
/atg:test-run WBPR-4127 --stop-on-fail      # halt after first assertion failure
/atg:test-run WBPR-4127 --skip-cleanup      # leave test data in place after run
/atg:test-run bin/stories/.../TESTING-GUIDE.md  # direct path
```

## User Input

$ARGUMENTS

## Command Flags

| Flag | Effect |
|------|--------|
| `--stop-on-fail` | Stop after first scenario assertion failure. Default: continue all scenarios, report aggregate. |
| `--skip-cleanup` | Do not offer to delete test data created during the run. |
| `--retest-only` | Re-read existing `TESTING-PROGRESS.md` and re-run only failed scenarios. |

## Execution Steps

### Step 1: Parse arguments and locate TESTING-GUIDE.md

**Parse `$ARGUMENTS`** for:
- A ticket ID (matches `WBPR-\d+`, `SP2-\d+`, etc.) → auto-discover
- A direct path (ends in `.md`) → use directly
- Flags: `--stop-on-fail`, `--skip-cleanup`, `--retest-only`

**Auto-discovery from ticket ID:**
```bash
find bin/stories -path "*/${TICKET}*/testing/TESTING-GUIDE.md" | sort | head -1
```

**Gate:** If no TESTING-GUIDE.md is found, stop with:
```
No TESTING-GUIDE.md found for {TICKET}.
Generate one first: /atg:testing-doc {TICKET}
```

**Read the full TESTING-GUIDE.md.** Parse into structured sections:
1. **Prerequisites** — app URL, credentials, feature flags
2. **Shared setup steps** — HTTP method, URL, headers, body, `Save:` variable extraction
3. **Scenarios** — purpose, steps, expected results (status codes + field assertions), validation checklist
4. **Edge cases** — information only (not auto-executed unless fully scripted)

### Step 2: Check app availability and start/restart as needed

Check if the app is running on `localhost:8080` (or the URL from the guide's prerequisites):
```bash
curl -sf -o /dev/null -w "%{http_code}" http://localhost:8080/api/v3/auth -X POST -H "Content-Type: application/json" -d '{}' --max-time 5
```

**If the app is not reachable:** determine the project type first, then start automatically:

- **Backend (`wavebid-a2o-service`)** — detected by the presence of `build.gradle.kts` in the working directory:
  ```bash
  cd wavebid-a2o-service && ./gradlew bootRun &
  ```
  Poll `GET http://localhost:8080/actuator/health` every 5s until it returns 2xx — up to a 120s timeout. If still unreachable after 120s, stop with an error and show the last few lines of Gradle output.

- **Frontend (`wavebid-a2o-ui`) or other projects** — do **not** attempt `./gradlew bootRun`. Instead, stop and tell the user which command to run (e.g. `pnpm dev`, `npm run dev`) so they can start the app manually, then re-run `/atg:test-run`.

**If the app is reachable but a code change was just made** (i.e., the run was preceded by a bug fix in this backend session): kill the existing process (`pkill -f 'bootRun'` or `kill $(lsof -ti:8080)`), then start it again via the same `./gradlew bootRun &` + polling pattern above. (Frontend restarts are always manual.)

**Inform the user** when starting or restarting ("Starting app via `./gradlew bootRun`…") but do not wait for confirmation.

### Step 3: Initialize variable store

Create an in-memory variable map for `{{variableName}}` substitutions. Variables chain across steps and scenarios:
```
auth response → {{token}}
GET /houses → {{houseId}}
GET /auctions → {{templateData}}
POST create → {{templateId}}
```

**Rules:**
- Variables persist across all scenarios within a run
- Each `/atg:test-run` invocation starts fresh — no stale variables from previous runs
- If a scenario depends on a variable from a prior scenario that failed, mark it as SKIP

### Step 4: Resolve test data

When the guide references dynamic test data (e.g., "any existing auction"), use the `seller-portal-local` MCP tool to obtain valid IDs.

**Common queries (adapt per guide content):**
- Valid house: `SELECT id, name FROM seller_portal.atg_auction_house WHERE enabled = true LIMIT 1`
- Valid auction data: Query `seller_portal.slb_auction` for a complete JSON payload
- Other resources: Query relevant tables with `enabled = true` filter

**If the MCP tool is unavailable:** Fall back to the HTTP steps described in the guide's shared setup.

Store all fetched data in the variable map for substitution.

### Step 5: Execute shared setup steps

Process each shared setup step in order. For each step containing an HTTP block:

**5a. Substitute variables in the request:**
Replace all `{{variableName}}` tokens in URLs, headers, and JSON bodies with stored values. For large JSON objects (like `templateData`), write the body to a temp file and use `-d @/tmp/body.json`.

**5b. Execute via curl:**
```bash
RESPONSE_FILE=$(mktemp /tmp/test-run-XXXXXX.json)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" \
  -X {METHOD} \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d @{BODY_FILE} \
  "{URL}" \
  --max-time 30)
```

**5c. Extract variables from response:**
Parse `Save:` instructions from the guide. Common patterns:
- `Save: token from response` → `python3 -c "import json,sys; d=json.load(open('$RESPONSE_FILE')); print(d['token'])"`
- `Save: $.data[0].id as {{houseId}}` → `python3 -c "import json,sys; d=json.load(open('$RESPONSE_FILE')); print(d['data'][0]['id'])"`
- For full objects (templateData): store the entire JSON subtree

**5d. Record** the step: request details, response status, response body.

**5e. Assert** any status code expectations. If setup fails, stop — all scenarios depend on it.

### Step 6: Execute test scenarios

For each scenario in the guide's "Detailed test scenarios" section:

**6a. Execute each numbered step:**
Same curl pattern as Step 5, but also:
- Track scenario and step number
- Extract and store `Save:` variables (may be used by later scenarios)
- Record full request/response in the progress buffer

**6b. Assert expected results:**
For each expected result listed in the scenario:
- **Status code match:** Compare actual HTTP status to expected (201, 200, 204, 404, 409, etc.)
- **Response field values:** Extract and compare specific JSON fields
  - `response.templateName == "My Test Template"`
  - `response.defaultTemplate == false`
  - `response.page.totalCount >= 2`
- **Field presence:** Verify `createdDate`, `updatedDate`, `id` are non-null
- **Absence from collections:** After DELETE, verify deleted resource absent from list/search

**6c. Evaluate validation checklist:**
Map each `- [ ]` checkbox to an assertion. Record pass/fail per item.

**6d. Handle failures:**
When an assertion fails:
1. Record the failure with full details: expected vs actual, request, response
2. Attempt diagnosis — check response body for error messages
3. Common causes:
   - `401` → token expired, re-authenticate and retry once
   - `409` unique constraint → potential bug (like the WBPR-4127 flush-order issue)
   - `400` bad request → guide format mismatch, try alternative formats:
     - Pagination: `"pageNumber"/"pageSize"` (1-indexed) vs `"page"/"size"`
     - Sort: `[{"direction":"DESC","property":"field"}]` vs `["field:desc"]`
   - `422` validation → check request body structure
   - `500` server error → check app logs
4. **If a bug is suspected:** pause, describe the diagnosis, and ask the user:
   - Apply a fix? (code change) — **do NOT commit** without approval
   - Skip the failed scenario and continue?
   - Stop entirely?
5. If `--stop-on-fail`: stop after recording

**Bug diagnosis protocol:**
When a step returns unexpected 4xx/5xx on a happy-path step:
1. Read the full error response body
2. Check the relevant source file from the guide's "Related code" section
3. Identify root cause (constraint violation, missing flush, wrong status mapping, etc.)
4. Propose a fix with exact file and line — but do NOT write or commit
5. After user approves a fix (and app is rebuilt), re-run the failed scenario

### Step 7: Generate TESTING-PROGRESS.md

Write the progress file alongside the guide. Use this structure:

```markdown
# {TICKET}: Automated Testing Progress

**Date:** {ISO date}
**Tester:** Claude Code (automated via /atg:test-run)
**Environment:** Local (localhost:8080)
**House ID:** `{houseId}` ({houseName})

---

## Setup
{Full request/response JSONs for auth and shared setup steps}

---

## Scenario 1: {Name} — PASS/FAIL
{All steps with full HTTP request blocks and response JSONs}

### Validation Checklist
- [x]/[ ] {item}

---

## Summary

| Scenario | Status | Notes |
|----------|--------|-------|
| Setup/Auth | PASS/FAIL | {notes} |
| 1: {Name} | PASS/FAIL | {notes} |
| ... | ... | ... |

---

## Bugs Found and Fixed

### BUG 1: {Title} — FIXED/UNFIXED
- **File:** {path}:{line}
- **Symptom:** {description}
- **Root cause:** {analysis}
- **Fix applied:** Yes/No
- **Verification:** {retest result}

---

## Testing Guide Corrections

{Discrepancies between the guide and actual API behavior}
```

**Output path:** Same directory as TESTING-GUIDE.md, named `TESTING-PROGRESS.md`.

### Step 8: Print final report

```
Test Run Complete — {TICKET}

Environment: localhost:8080

Results:
  PASS: {N} scenarios
  FAIL: {M} scenarios
  SKIP: {K} scenarios

Summary:
| # | Scenario            | Status | Notes                      |
|---|---------------------|--------|----------------------------|
| - | Setup/Auth          | PASS   | Token + house resolved     |
| 1 | Create              | PASS   | 201, field names correct   |
| 2 | Default swap        | FAIL   | Step 2.4: 409 on PUT (bug) |
| ...                     |        |                            |

Bugs found: {N}
  BUG 1: {title} — {status}

Output: bin/stories/.../testing/TESTING-PROGRESS.md

Next steps:
1. Review TESTING-PROGRESS.md for full request/response details
2. If bugs found: review proposed fixes, apply, re-run: /atg:test-run {TICKET} --retest-only
3. If all pass: /atg:retro {TICKET}
```

### Step 9: Offer cleanup

If `--skip-cleanup` was not passed:
1. List all resources created during the run (IDs from POST 201 responses)
2. Offer to DELETE each one to restore the environment
3. Execute cleanup if user confirms
4. Record cleanup results in TESTING-PROGRESS.md

## Important Notes

- **Never commit code changes** made during bug fixes without explicit user approval
- **Use the TESTING-GUIDE.md as source of truth** for expected behavior
- **Record everything** — full request/response JSONs make the progress file invaluable for debugging
- **Use temp files for curl output** (`-o /tmp/test-run-XXXXXX.json`) to avoid JSON parsing issues with appended HTTP status
- **For large JSON bodies** (templateData), write to temp file and use `-d @/tmp/body.json`
- **Re-authenticate on 401** mid-run — token may expire; retry the auth step once, then retry the failed step
- **Handle format mismatches gracefully** — try the guide's format first; on 400, try the known alternative
- **Generate unique resource names** with timestamp suffix for idempotent re-runs (e.g., `"Claude Test Template 2026-05-06-143022"`)
- **Use python3 for JSON extraction** — `python3 -c "import json,sys; ..."` is more reliable than jq for complex paths
- **30-second curl timeout** for API calls; 5-second for health checks

## BEGIN IMMEDIATELY

When this command is invoked, start with Step 1: parse `$ARGUMENTS` and locate the TESTING-GUIDE.md. Do not wait for additional confirmation — proceed through all steps.
