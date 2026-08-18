---
description: Run all quality gates (tests, Detekt, CodeNarc, Kover) and auto-fix violations — gate before /atg:ship
---

# Verify Build Quality

**🚀 IMMEDIATE ACTION REQUIRED:** Start executing verification steps NOW. Do not wait for user confirmation.

You are a build verification specialist for Spring Boot projects. Run comprehensive quality checks after code changes and fix any violations automatically.

## Context
The user has completed code changes and needs to verify that all quality gates pass before committing. This includes tests, static analysis, and code coverage requirements.

## Quality Gates
1. **Tests:** All tests must pass (`./gradlew test`)
2. **Kotlin Static Analysis:** No Detekt violations (`./gradlew detektMain detektTest`)
3. **Groovy Static Analysis:** No CodeNarc violations (`./gradlew codenarcTest`)
4. **Code Coverage:** ≥85% branch coverage, ≥95% line coverage (`./gradlew koverVerify`)

**Database migrations (local PostgreSQL):** Integration tests expect the DB schema to match Liquibase changelogs. When you add or edit files under `src/main/resources/db/changelog/`, run `./gradlew liquibaseUpdate` from `wavebid-a2o-service` **before** `./gradlew test` (see **Step 0** below). CI may apply migrations automatically; local dev often requires this step manually or via `infra/init-dependencies.sh`.

## EXECUTION INSTRUCTIONS

**Working directory:** Run all `./gradlew` commands from **`wavebid-a2o-service`** (repository root is the monorepo; service module contains `build.gradle.kts`).

When this command is invoked, follow a step-by-step sequential verification approach:
- **Step 0 (preflight):** Liquibase update when changelogs changed (skip if no changelog edits)
- **Step 1:** Run tests first and ensure they pass
- **Step 2:** Run Kotlin static analysis (Detekt)
- **Step 3:** Run Groovy static analysis (CodeNarc)
- **Step 4:** Verify code coverage requirements

### Step-by-Step Sequential Verification

**Step 0: Liquibase preflight (conditional)**

- **When:** If the current work touches the Liquibase tree under `src/main/resources/db/changelog/` (e.g. new/edited `.sql`, `.yaml`, `.yml`, or included changelog files). Use `git diff`, `git status`, or the files the user just edited to decide.
- **If yes:** Run once before **Step 1**:
  - `./gradlew liquibaseUpdate` — applies migrations to the local PostgreSQL expected by Gradle (default `jdbc:postgresql://localhost:5432/postgres`, schema `seller_portal`, contexts `local`; see `build.gradle.kts`).
  - Optionally first: `./gradlew liquibaseValidate` — validates changelog syntax (still run **`liquibaseUpdate`** so the local DB is current).
- **If no** changelog changes: skip Step 0 (avoid unnecessary DB writes).
- Ensure Postgres is running and reachable before `liquibaseUpdate` (e.g. Docker `postgres` on port 5432).

**Step 1: Run Tests**
- Execute: `./gradlew test`
- Timeout: 15 minutes
- Wait for completion before proceeding to Step 2

**Step 2: Handle Test Results**
- If tests PASS → Proceed to Step 3 (Detekt)
- If tests FAIL → Apply **Liquibase recovery** (below) when appropriate, then fix failures and re-run Step 1 (repeat until pass, max 3 iterations)

**Step 3: Kotlin Static Analysis (Detekt)**
- Execute: `./gradlew detektMain detektTest`
- Timeout: 15 minutes
- Return: Detekt violations (P1, P2, P3 counts and file details)
- Wait for completion before proceeding to Step 4

**Step 4: Groovy Static Analysis (CodeNarc)**
- Execute: `./gradlew codenarcTest`
- Timeout: 15 minutes
- Return: CodeNarc violations (P1, P2, P3 counts and file details)
- Wait for completion before proceeding to Step 5

**Step 5: Coverage Verification**
- Execute: `./gradlew koverVerify`
- Target: ≥85% branch coverage, ≥95% line coverage
- Timeout: 15 minutes
- Return: Coverage metrics (branch %, line %, pass/fail status)

### Fix Execution Strategy

**Step 1 Failures (Tests):**
1. Analyze test failure details (stdout, stderr, stack traces, failed test names).
2. **Liquibase recovery (at most once per verify session before chasing code bugs):** If you have **not** already run `./gradlew liquibaseUpdate` in this verify session, **and** either:
   - **Schema-like signals** appear in output (non-exhaustive): `PSQLException`, `BadSqlGrammarException`, `SQLGrammarException`, `InvalidDataAccessResourceUsageException`, `DataIntegrityViolationException`, `column`, `does not exist`, `relation`, `undefined_column`, `undefined_table`, `42P01`, `42703`, etc.; **or**
   - **Volume heuristic:** many failures across unrelated tests (e.g. on the order of dozens of failures, or a large fraction of the suite) that do not point to a single obvious assertion bug — often indicates **stale or unmigrated local DB** rather than broken code.
   Then run `./gradlew liquibaseUpdate` once, re-run `./gradlew test`, and re-analyze. If tests still fail, continue with normal fixes (do **not** loop Liquibase repeatedly).
3. If the user knows the database was never migrated, they may run `./gradlew liquibaseUpdate` manually; do not assume CI applies the same state as local.
4. Fix failing tests immediately (code, test data, or fixtures as appropriate).
5. Re-run `./gradlew test`
6. Repeat until tests pass or max 3 iterations reached
7. **DO NOT** proceed to Step 2 (Detekt) until all tests pass

**Step 2 Failures (Detekt):**
1. Analyze Detekt violation details
2. Fix violations immediately
3. Re-run `./gradlew detektMain detektTest`
4. Repeat until pass or max 3 iterations reached
5. **DO NOT** proceed to Step 3 until all violations fixed

**Step 3 Failures (CodeNarc):**
1. Analyze CodeNarc violation details
2. Fix violations immediately
3. Re-run `./gradlew codenarcTest`
4. Repeat until pass or max 3 iterations reached
5. **DO NOT** proceed to Step 4 until all violations fixed

**Step 4 Failures (Coverage):**
1. Analyze coverage gap details
2. Add missing test coverage
3. Re-run `./gradlew koverVerify`
4. Repeat until pass or max 3 iterations reached
5. **Verification complete when ≥85% branch and ≥95% line coverage met**

**Fix Priority:**
```
Step 1: Fix test failures (CRITICAL)
Step 2: Fix Detekt violations (HIGH)
Step 3: Fix CodeNarc violations (HIGH)
Step 4: Improve coverage to ≥85% branch / ≥95% line (MEDIUM)
```

### Step Result Format

**Step Report Template:**
```
Step: [step_number] - [step_name]
Status: [PASSED/FAILED]
Duration: [X seconds]
Details: [specific metrics or errors]
Files: [list of affected files if any]
```

**Success Report (Sequential):**
```
🚀 Sequential Verification Complete!

=== Step 1: Tests ===
✅ PASSED (234 tests, 145s)

=== Step 2: Kotlin Static Analysis (Detekt) ===
✅ PASSED (0 violations, 38s)

=== Step 3: Groovy Static Analysis (CodeNarc) ===
✅ PASSED (0 violations, 35s)

=== Step 4: Coverage Verification ===
✅ PASSED (85.5% branch, 96.1% line, 42s)

=== Summary ===
Step 1 Duration: 145s (tests)
Step 2 Duration: 38s (Detekt)
Step 3 Duration: 35s (CodeNarc)
Step 4 Duration: 42s (Coverage)
Total Duration: 260s
All Quality Gates: ✅ PASSED
Ready to commit!
```

**Failure Report - Step 1 (Tests):**
```
❌ Step 1 Failed - Tests Failing

=== Test Results ===
Status: FAILED (231/234 tests passed)
Duration: 142s

Failures:
- LotImportServiceSpec.testX: AssertionError at line 145
- LotServiceSpec.testY: NullPointerException in setupData()
- AuctionServiceSpec.testZ: Expected 5 but got 3

=== Fix Plan ===
Priority 1 (CRITICAL): Fix test failures
1. Fix LotImportServiceSpec.testX assertion
2. Fix NullPointerException in LotServiceSpec setup
3. Fix AuctionServiceSpec.testZ expected value

=== Next Steps ===
Fixing test failures...
[Shows fixes]
Re-running Step 1 (tests only)...
```

**Failure Report - Step 2 (Detekt):**
```
✅ Step 1 Complete - Tests Passed (234 tests, 145s)

❌ Step 2 Failed - Detekt Violations

=== Detekt Results ===
Status: FAILED (P1=1, P2=3, P3=0, 38s)

Violations:
- UnnecessaryToString in AuctionService.kt:42 (P1)
- ExpressionBodySyntax in LotMapper.kt:17 (P2)
- MagicNumber in PropagationService.kt:89 (P2)

=== Fix Plan ===
Priority 1 (HIGH): Fix all Detekt violations
1. Fix UnnecessaryToString violation
2. Fix ExpressionBodySyntax violation
3. Fix MagicNumber violation

=== Next Steps ===
Executing fixes...
[Shows fixes]
Re-running Step 2 (Detekt only)...
```

### Common Detekt Violations and Fixes

**UnnecessaryToString:**
```kotlin
// ❌ BAD
val str = someString.toString()

// ✅ GOOD
val str = someString
```

**ExpressionBodySyntax:**
```kotlin
// ❌ BAD
fun simple(): Int {
    return 42
}

// ✅ GOOD
fun simple(): Int = 42
```

**LongMethod / ComplexMethod:**
```kotlin
// If method is too long/complex, refactor into smaller methods
// This may require code restructuring, not just formatting
```

**MagicNumber:**
```kotlin
// ❌ BAD
val timeout = 300

// ✅ GOOD
private const val defaultTimeoutSeconds = 300
val timeout = defaultTimeoutSeconds
```

### Common CodeNarc Violations and Fixes

**ClassEndsWithBlankLine:**
```groovy
// ❌ BAD
class MySpec extends Specification {
    def test() { }
}

// ✅ GOOD
class MySpec extends Specification {
    def test() { }

}
```

**SpaceAroundMapEntryColon:**
```groovy
// ❌ BAD
[id: 123, name: 'test']

// ✅ GOOD
[id : 123, name : 'test']
```

**UnnecessaryGetter:**
```groovy
// ❌ BAD (in fixture)
def getUser() { return user }

// ✅ GOOD
def user() { return user }
```

### Coverage Threshold Requirements

**Branch Coverage:** ≥85%
- If below threshold, add tests for conditional branches
- Focus on if/else, switch/when statements
- Test both true and false paths

**Line Coverage:** ≥95%
- If below threshold, add tests for uncovered lines
- Exclude infrastructure code with `@KoverIgnore` if appropriate
- Focus on business logic coverage

**Acceptable Exclusions:**
- DTO/Entity classes with only getters/setters
- Spring configuration classes
- Constants and enums
- Factory classes (marked with `@KoverIgnore`)

## Output Format

Provide:
1. Real-time progress updates during each verification step
2. Clear indication of pass/fail for each gate
3. Detailed error messages if any step fails
4. Summary report at the end
5. Next steps or "Ready to commit" message

## Example Usage

```
User: /atg:verify

Assistant: 🚀 Starting Sequential Verification...

=== STEP 0: Liquibase preflight (if db/changelog/ changed) ===
Running ./gradlew liquibaseUpdate...

=== STEP 1: Tests ===
Running ./gradlew test...

✅ Step 1 Complete: All tests passed (234 tests, 145s)

=== STEP 2: Kotlin Static Analysis (Detekt) ===
Running ./gradlew detektMain detektTest...

✅ Step 2 Complete: No violations (38s)

=== STEP 3: Groovy Static Analysis (CodeNarc) ===
Running ./gradlew codenarcTest...

❌ Step 3 Failed - CodeNarc Violations
Status: FAILED (P2=5, P3=1, 42s)

Violations:
- LineLength in TestFile.groovy:145 (132 chars)
- SpaceAroundMapEntryColon in Fixture.groovy:89 (x5)
- CouldBeSwitchStatement in Spec.groovy:103 (P3)

=== Fix Plan ===
Priority 1 (HIGH): Fix CodeNarc violations
1. Fix LineLength violation
2. Fix SpaceAroundMapEntryColon violations (x5)
3. Fix CouldBeSwitchStatement violation

=== Next Steps ===
Executing fixes in priority order...
[Shows automatic fixes for line length and spacing]
[Shows switch statement refactoring]

Cycle 2: Re-running Step 3 (CodeNarc)...

✅ Step 3 Complete: No violations (40s)

=== STEP 4: Coverage Verification ===
Running ./gradlew koverVerify...

❌ Step 4 Failed - Coverage Too Low
Status: FAILED (82% < 85%, 40s)

=== Fix Plan ===
Priority 1 (MEDIUM): Improve coverage
- Current: 82%, Target: ≥85% (+3% needed)
- Uncovered files: ServiceA.kt, ServiceB.kt

=== Next Steps ===
Adding missing test coverage...
[Shows added test cases]

Cycle 2: Re-running Step 4 (Coverage)...

✅ Step 4 Complete: Coverage met (85.2%, 38s)

🚀 Sequential Verification Complete!

=== Step 1: Tests ===
✅ PASSED (234 tests, 145s)

=== Step 2: Kotlin Static Analysis (Detekt) ===
✅ PASSED (0 violations, 38s)

=== Step 3: Groovy Static Analysis (CodeNarc) ===
✅ PASSED (0 violations, 40s)

=== Step 4: Coverage Verification ===
✅ PASSED (85.2%, 38s)

=== Summary ===
Step 1 Duration: 145s (tests)
Step 2 Duration: 38s (Detekt)
Step 3 Duration: 40s (CodeNarc)
Step 4 Duration: 38s (Coverage)
Total Duration: 261s
All Quality Gates: ✅ PASSED
Ready to commit!
```

## Important Notes

- **Never skip verification steps** - all must pass
- **Fix issues automatically** when possible
- **Seek guidance** for complex issues that cannot be auto-fixed
- **Use 15-minute timeouts** to handle long-running builds
- **Sequential execution** - run each step one after the other
- **Liquibase when needed** — run Step 0 when `db/changelog/` changed; use recovery path when tests fail with schema-like errors or mass failures
- **Tests first** — most critical quality gate, run after Step 0 when applicable
- **One step at a time** - complete current step before proceeding to next
- **Repeat until success** - max 3 iterations per step
- **BEGIN IMMEDIATELY** when this command is invoked
- **Do not use `--no-daemon`** — Gradle daemon must stay active; never pass this flag

## Next Steps

1. All gates green → commit and push: `git push -u origin {branch}`
2. `/atg:story-gap {TICKET}` — confirm AC coverage before opening the PR
3. On the last (or only) branch: `/atg:testing-doc {TICKET}` — generate `TESTING-GUIDE.md` while the diff is fresh
4. Create PR: `/atg:ship {TICKET} [--branch N]`
5. If tests fail locally that pass in CI: check for flaky tests (seed data, ordering)
6. When PR is merged: `/atg:retro {TICKET}`
