---
description: Run all quality gates (tests, Detekt, CodeNarc, Kover) and auto-fix violations — the gate before /atg:ship
---

# Verify: quality gates

Run the service's quality gates in order, fix what fails, and stop only when every gate is green.
Start immediately; do not wait for confirmation. Gradle rules (working directory, no `--no-daemon`,
coverage thresholds) are in the atg-service-rules skill.

## Usage

```bash
/atg:verify
```

## Gates, in order

| Step | Gate | Command |
|---|---|---|
| 0 | Liquibase preflight (conditional) | `./gradlew liquibaseUpdate` |
| 1 | Tests | `./gradlew test` |
| 2 | Kotlin static analysis | `./gradlew detektMain detektTest` |
| 3 | Groovy static analysis | `./gradlew codenarcTest` |
| 4 | Coverage | `./gradlew koverVerify` |

Sequential. Do not start a gate until the previous one passes. 15-minute timeout per command.

## Steps

1. **Freshness check, per gate.** Skip a gate only when both hold: you personally ran that exact
   command earlier in this conversation and saw it pass, and `git status --short` shows nothing
   changed under `wavebid-a2o-service/` since that run. Any change, even one unrelated-looking
   file, means re-run. Never carry a result across sessions; a fresh session runs everything.
   When unsure, re-run, and default to re-running `koverVerify` because coverage drifts silently.
2. **Step 0.** If the diff or working tree touches `src/main/resources/db/changelog/`, run
   `liquibaseUpdate` once before tests (local Postgres must be up). Otherwise skip.
3. **Run each gate.** On failure, fix and re-run that gate, max 3 cycles. Do not move on until it passes.
   - **Tests.** Before chasing code bugs, apply Liquibase recovery once per verify session if not
     already run: schema-like signals (`PSQLException`, `BadSqlGrammarException`, `does not exist`,
     `relation`, `undefined_column`, `42P01`, `42703`) or mass unrelated failures suggest a stale
     local DB. Run `liquibaseUpdate`, re-run tests, then continue with normal fixes. Never loop it.
   - **Detekt / CodeNarc.** Fix violations per the rule docs (403 for Detekt extras).
   - **Kover.** Add tests for uncovered branches and lines; exclude only genuine infrastructure.
4. **Report.** After all gates pass, print the summary below. Mark a skipped gate as
   `PASSED (cached — no changes since last run in this session)` with 0s duration.

```
Verification complete

Step 1 Tests      ✅ PASSED ({N} tests, {t}s)
Step 2 Detekt     ✅ PASSED (0 violations, {t}s)
Step 3 CodeNarc   ✅ PASSED (0 violations, {t}s)
Step 4 Coverage   ✅ PASSED ({b}% branch, {l}% line, {t}s)

Total: {t}s. All quality gates passed. Ready to commit.
```

On a gate that does not converge after 3 cycles, stop, print which gate failed with the
remaining violations or failures, and ask for guidance.

## Failures

| Situation | Action |
|---|---|
| Postgres unreachable during `liquibaseUpdate` | Stop; ask the user to start it (e.g. `infra/init-dependencies.sh`) |
| Tests pass in CI but fail locally | Suspect seed data or ordering; report as flaky candidate |
| Gate cannot be auto-fixed | Stop after 3 cycles and report |

**Next:** `/atg:pattern-check {TICKET} [--branch N]`
