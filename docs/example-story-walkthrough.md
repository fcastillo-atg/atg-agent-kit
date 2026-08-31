# Worked example: WBPR-4032 end to end

A single story, followed through the full command timeline with abbreviated real output at
each step. `WBPR-4032` ("lot inherits address from auction when not explicitly set") is used
consistently because it's the same example several command files already anchor their own
usage examples to (`ship.md`, `story-gap.md`, `pattern-check.md`) — this walkthrough connects
those dots into one story instead of inventing a new one.

**Shape of the story:** user-facing behavior change → needs a feature flag → Pattern A
(safety-first): 3 branches, feature flag first. See [Commands](../README.md#commands) for
what each command below does in isolation.

Steps 1 through "testing-doc" below (everything up to `ship`) are exactly what
**`/atg:story-auto-run WBPR-4032`** would run unattended in one shot, branch by branch,
stopping only at a hard blocker (like the missing-AC failure in step 4). This walkthrough
runs them one command at a time instead, to show what each one actually produces.

## 0. `/atg:brief WBPR-4032` — skipped

`brief` is for ambiguous or cross-cutting-risky stories (see its own example, `WBPR-4099`, a
bulk propagation change with a Liquibase index and N+1 risk). WBPR-4032 is a well-scoped,
single-concept change with clear acceptance criteria — `story-plan` goes straight to
analysis without a pre-analysis pass.

## 1. `/atg:story-plan WBPR-4032`

```
📖 Fetching WBPR-4032 from Jira... found. 5 acceptance criteria, 0 substantive comments.
📝 Wrote bin/stories/2026/03/WBPR-4032-lot-address/WBPR-4032-story.md

## Lines of code estimate
Production: 180 LOC   Tests: 310 LOC   Docs: 20 LOC   TOTAL: 510 LOC

## Feature Flag Design
lot_address_inheritance — Branch 1 (MUST be first, Pattern A: safety-first)

## Branch strategy (3 branches, Pattern A)
Branch 1: fc/WBPR-4032-address-flag    (~170 LOC) — feature flag infra, DISABLED by default
Branch 2: fc/WBPR-4032-service-layer   (~170 LOC) — repository + service, behind disabled flag
Branch 3: fc/WBPR-4032-lot-address     (~170 LOC) — API + migration + integration tests

📝 Wrote implementation-plan.md + wavebid-a2o-service/.claude/plans/WBPR-4032-lot-address.md

## Next ATG command
/atg:story-impl WBPR-4032 --branch 1
```

## 2. Branch 1 — feature flag infrastructure

**`/atg:feature-flag "lot address inherits from auction when null"`** — generates the
single-file flag before `story-impl` wires it in:
```
📝 Generated LotAddressInheritance.kt:
  @Feature("lot_address_inheritance") interface + NoopLotAddressInheritance (legacy) +
  EnabledLotAddressInheritance (throws UnsupportedOperationException — Branch 1 only) +
  @Primary @KoverIgnore factory.
Cookie control: FF_lot_address_inheritance=true|false. Flag DISABLED by default.
```

**`/atg:story-impl WBPR-4032 --branch 1`**
```
🔀 Branch: fc/WBPR-4032-address-flag (created from main)
📋 Work queue (Branch 1 of 3):
  1. Wire LotAddressInheritance.kt into LotService (stub call, flag disabled)
  2. FeatureFlagSpec.groovy — flag toggle tests
✅ Implemented. 3 files, +164 LOC.
```

**`/atg:verify`**
```
=== STEP 1: Tests ===        ✅ 41 tests passed (12s)
=== STEP 2: Detekt ===       ✅ No violations
=== STEP 3: CodeNarc ===     ✅ No violations
=== STEP 4: Coverage ===     ✅ 96% (≥85% target)
✅ Ready to commit.
```

**`/atg:ship WBPR-4032 --branch 1`** — not the last branch, so the As-built/testing-doc
checks are skipped silently:
```
✅ PR created: https://github.com/wavebid-ATG/wavebid-a2o/pull/451
Title:  WBPR-4032: [Branch 1/3] Feature flag infrastructure
Status: Code Review (transitioned via acli)
```

## 3. Branch 2 — service layer

**`/atg:story-impl WBPR-4032 --branch 2`** → repository query + service method replacing the
`UnsupportedOperationException` from Branch 1, behind the still-disabled flag. `/atg:verify`
passes the same way as Branch 1.

**`/atg:ship WBPR-4032 --branch 2`** — the real example from `ship.md`:
```
✅ PR created: https://github.com/ATG/wavebid-a2o/pull/456
Title:    WBPR-4032: [Branch 2/3] Service layer + unit tests
Branch:   fc/WBPR-4032-service-layer
Status:   Code Review ✅ (transitioned via acli)
```

## 4. Branch 3 — complete feature (last branch)

**`/atg:story-impl WBPR-4032 --branch 3`** → `PUT /lots/{id}` controller wiring, a Liquibase
migration guarding existing rows, and integration tests. **`/atg:verify`** passes.

**`/atg:pattern-check WBPR-4032`** (advisory, never blocks):
```
🔍 Comparing diff against 3 similar controllers + wavebid-a2o-service/.claude/rules/

⚠️  LotController.kt:78 — inherits address inline; 2 other controllers extract this to a
    @Mapper (see AuctionController.kt:112). Consider matching the pattern.
✅  Everything else consistent with existing patterns.

Advisory only — does not block /atg:story-gap or /atg:ship.
```

**`/atg:changeset`** (pointer):
```
wavebid-a2o-service/ paths changed → CI requires .changeset/*.md (or skip-changelog label).
Run /gsd/changeset-wavebid-a2o in Cursor, or add .changeset/wbpr-4032-lot-address.md manually.
✅ .changeset/wbpr-4032-lot-address.md staged.
```

**`/atg:story-gap WBPR-4032`** — first run catches a real gap, using the same table
`story-gap.md`'s own example shows:
```
| # | Acceptance Criterion                                  | Status                  |
|---|--------------------------------------------------------|-------------------------|
| 1 | Lot inherits address from auction when null           | ✅ Implemented + tested  |
| 2 | Lot retains custom address when explicitly set         | ✅ Implemented + tested  |
| 3 | Feature flag FF_lot_address_inheritance controls gate  | ✅ Implemented + tested  |
| 4 | PUT /lots/{id} updates inherited address on update     | ⚠️ Implemented, no test  |
| 5 | Existing lots not affected by migration                | ❌ Missing               |

❌ Story gap check FAILED — 1 AC missing (needs a migration + repository test).
Blocked: do NOT ship until missing ACs are addressed.
```
→ Migration test added, `/atg:story-gap WBPR-4032` re-run: all 5 ACs now ✅.

**`/atg:testing-doc WBPR-4032`** — fills in the `testing-guide-template` command's structure
(that command isn't run directly; `testing-doc` reads it):
```
📝 Generated bin/stories/2026/03/WBPR-4032-lot-address/testing/TESTING-GUIDE.md
   1 shared setup (auth), 3 scenarios (null→inherited, explicit-set retained, migration safety)
```

**`/atg:test-run WBPR-4032`** — optional, but worth running here: executes the guide
`testing-doc` just produced, *before* `ship`, specifically to catch bugs unit tests miss
(Hibernate flush-order issues, constraint violations):
```
🔐 Authenticated. 3 scenarios:
  ✅ Scenario 1: null address → inherits from auction (201, address matches auction)
  ✅ Scenario 2: explicit address → retained (201, address unchanged)
  ✅ Scenario 3: existing lot unaffected by migration (200, address unchanged pre-migration)
📝 Wrote TESTING-PROGRESS.md — 3/3 passed.
```

**`/atg:ship WBPR-4032 --branch 3`** — last branch, so the As-built and testing-doc checks
both pass (already filled in / already generated above):
```
✅ PR created: https://github.com/wavebid-ATG/wavebid-a2o/pull/461
Title:  WBPR-4032: [Branch 3/3] API + migration + integration tests
Status: Code Review (transitioned via acli)
```

*(If a reviewer leaves comments on any of these three PRs: `/atg:review-feedback {PR_NUMBER}`
classifies and resolves them, then loops back to `/atg:verify` before re-requesting review. A
single finding worth a standalone inline comment — e.g. spotted while reading someone else's
PR — goes through `/atg:pr-comment` instead, which `/atg:review-feedback` would later pick up.)*

## 5. Post-merge (once all 3 PRs are merged)

**`/atg:qa-comment WBPR-4032`** — runs *after* `test-run` already confirmed everything
locally (above); reposts the same `TESTING-GUIDE.md` content as Jira-facing instructions so
QA can independently verify on dev/stage:
```
Draft QA comment for WBPR-4032:
  Environment: dev / stage — PR #461 already merged
  3 scenarios, Postman-format {{variables}}
Post this comment to WBPR-4032? (y/n): y
✅ Comment posted.
```

**`/atg:retro WBPR-4032`** — the real example from `retro.md`:
```
🔍 Retro complete for WBPR-4032

=== Mining summary ===
  ✓ Implementation plan: 1 scope note — Liquibase migration missing from initial estimate
  ✓ PR comments: 3 acted on (1 Kotlin null-handling, 1 Spock fixture, 1 Kover exclusion)
  ✓ CodeNarc: ExpressionBodySyntax recurred in 2 files across 2 branches

=== Suggested patterns (2 candidates) ===
Pattern 1 → .claude/rules/service-patterns.md — log before returning null from a service method
Pattern 2 → CLAUDE.md — always budget Liquibase migrations into the LOC estimate at story-plan

Nothing has been written yet — review and tell me which ones to add.
```

## Along the way (cross-cutting, used as needed)

Not part of the fixed timeline above — reach for these whenever they're useful:

- **`/atg:status`** — while all 3 branches are in flight, a quick multi-branch check: which of
  the 3 PRs are merged, open, or still pending review.
- **`/atg:explain WBPR-4032`** — hand this to a teammate (or your future self) for a
  plain-language summary of what the ticket changed, instead of re-reading 3 PRs.
- **`/atg:story-view WBPR-4032`** — the same story's lifecycle position (`brief → ship → docs
  → retro`) as a visual dashboard, published via Artifact, if a text summary isn't enough.
