---
description: Execute every scenario in a TESTING-GUIDE.md via curl, assert results, write testing/TESTING-PROGRESS.md
---

# Test run

Mechanically execute a `TESTING-GUIDE.md`: shared setup, then every scenario step via `curl`,
chaining `Save:` variables, asserting status codes and fields, and recording full
request/response pairs in `TESTING-PROGRESS.md`. Useful before merge to catch what unit tests
miss (flush order, constraint violations). Vocabulary and variable rules: **atg-testing-guide**.
Paths: **atg-story-artifacts**. Start immediately; do not wait for confirmation.

## Usage

```bash
/atg:test-run {TICKET}                      # auto-discover testing/TESTING-GUIDE.md
/atg:test-run {path/to/TESTING-GUIDE.md}    # direct path
/atg:test-run {TICKET} --stop-on-fail       # halt after first failed assertion
/atg:test-run {TICKET} --skip-cleanup       # do not offer to delete created data
/atg:test-run {TICKET} --retest-only        # re-run only scenarios that failed last time
```

## Steps

1. **Locate the guide.** Ticket → `find bin/stories -path "*/{TICKET}*/testing/TESTING-GUIDE.md"`;
   a path ending in `.md` is used directly. If none: stop with
   `No TESTING-GUIDE.md for {TICKET}. Generate one: /atg:testing-doc {TICKET}`.
   Parse Prerequisites, Shared setup steps, Scenarios (steps, expected results, checklist), and
   Edge cases (informational only). With `--retest-only`, read the existing
   `TESTING-PROGRESS.md` and keep only failed scenarios.

2. **Check the app.**
   `curl -sf -o /dev/null -w "%{http_code}" {baseURL}/api/v3/auth -X POST -H "Content-Type: application/json" -d '{}' --max-time 5`
   - Not reachable and `build.gradle.kts` present: `cd wavebid-a2o-service && ./gradlew bootRun &`,
     poll `/actuator/health` every 5s up to 120s, then fail with the last Gradle lines.
   - Not reachable and frontend or other project: stop and tell the user the command to run
     (`pnpm dev` etc.), then re-run.
   - Reachable but a backend code change was just made this session: kill the process on 8080
     and restart with the same pattern. Announce starts and restarts; do not ask.

3. **Initialise the variable store.** Empty map per run. Variables chain across setup and all
   scenarios. A scenario that needs a variable from a failed scenario is SKIP.

4. **Resolve test data.** When the guide says "any existing X", query the `seller-portal-local`
   MCP tool (e.g. `SELECT id, name FROM seller_portal.atg_auction_house WHERE enabled = true LIMIT 1`).
   If unavailable, use the guide's shared-setup HTTP steps. Store results in the map.

5. **Execute shared setup, then each scenario step.** For every HTTP block:

   ```bash
   RESPONSE_FILE=$(mktemp /tmp/test-run-XXXXXX.json)
   HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" -X {METHOD} \
     -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
     -d @{BODY_FILE} "{URL}" --max-time 30)
   ```

   - Substitute `{{var}}` in URL, headers, and body first. Large bodies go to a temp file.
   - Honour `Save:` lines with `python3 -c "import json; d=json.load(open('$RESPONSE_FILE')); print(d['data'][0]['id'])"`.
     Store whole subtrees when the guide saves an object.
   - Generate unique resource names with a timestamp suffix so re-runs are idempotent.
   - Record method, URL, body, status, and response for every step.
   - A failed shared-setup assertion stops the run; every scenario depends on it.

6. **Assert.** Status code; JSON field equality or comparison (`page.totalCount >= 2`); presence
   of `id`, `createdDate`, `updatedDate`; absence from a list after DELETE. Map each
   validation-checklist checkbox to a pass/fail.

7. **Handle failures.**
   - `401`: re-authenticate once, retry the step once.
   - `400`: try the known alternative format once (`pageNumber`/`pageSize` 1-indexed vs
     `page`/`size`; sort `[{"direction":"DESC","property":"f"}]` vs `["f:desc"]`), then record
     it as a guide correction.
   - `409` on a happy-path step, or any `5xx`: suspected bug. Read the error body and the file
     named in the guide's Related code, identify the root cause, and propose a fix with file
     and line. Never write or commit the fix without approval. Then ask: apply the fix, skip
     the scenario, or stop. After an approved fix and rebuild, re-run the failed scenario.
   - With `--stop-on-fail`, stop after recording the first failure.

8. **Write `testing/TESTING-PROGRESS.md`** next to the guide:
   header (date, tester `Claude Code via /atg:test-run`, environment, house) · `## Setup` with
   full request/response · `## Scenario N: {Name} — PASS/FAIL` with every step and its checklist
   · `## Summary` table · `## Bugs found and fixed` (file:line, symptom, root cause, fix
   applied, verification) · `## Testing guide corrections`.

9. **Report.**

   ```
   Test run complete — {TICKET}   ({baseURL})
   PASS {N}   FAIL {M}   SKIP {K}

   | # | Scenario | Status | Notes |
   |---|----------|--------|-------|
   | - | Setup/Auth | PASS | token + house resolved |
   | 1 | {name} | PASS | 201, fields correct |
   | 2 | {name} | FAIL | step 2.4: 409 on PUT (bug) |

   Bugs: {N}  ({title} — fixed|unfixed)
   Output: bin/stories/.../testing/TESTING-PROGRESS.md
   ```

10. **Offer cleanup** unless `--skip-cleanup`: list resources created (IDs from 201 responses),
    delete them on confirmation, record the result in the progress file.

**Next:** bugs found → fix, rebuild, `/atg:test-run {TICKET} --retest-only`; all pass →
`/atg:ship {TICKET}` or `/atg:qa-comment {TICKET}`.
