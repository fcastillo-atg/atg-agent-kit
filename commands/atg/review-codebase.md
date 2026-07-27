---
description: Cross-reference the PR diff against existing codebase patterns and project rules to catch antipatterns before shipping
---

# Review Codebase: Pattern & Convention Cross-Reference

**Purpose:** After `/atg:verify` passes, check the diff against **(1)** how similar code is already implemented elsewhere in the codebase and **(2)** the numbered rule docs in `wavebid-a2o-service/.claude/rules/`. Surfaces likely antipatterns and inconsistencies before `/atg:story-gap` and `/atg:ship`. **Advisory only — never blocks shipping.**

## Usage

```bash
/atg:review-codebase {TICKET}              # check current branch against main
/atg:review-codebase {TICKET} --branch N  # scope check to branch N's changes only
```

## Arguments

- `{TICKET}` — Jira ticket key (e.g. `WBPR-4032`)
- `--branch N` — restrict diff to files changed in branch N (uses `implementation-plan.md` → `## Branch strategy` → `### Branch N:` to determine base, same convention as `/atg:story-gap`)

## Execution Steps

### Step 1: Get the diff

```bash
git diff origin/main...HEAD --name-only     # files changed
git diff origin/main...HEAD                 # full diff for evidence
```

If `--branch N` is provided, scope using `implementation-plan.md` the same way `/atg:story-gap` does.

### Step 2: Classify each changed file's "shape"

Exclude test files (`*Spec.groovy`, `*Test.kt`) from this pass — they're not what's being cross-referenced against.

| Shape | Signal |
|-------|--------|
| Controller endpoint | `*Controller.kt`, new `@GetMapping`/`@PostMapping`/etc. |
| Service method | `*Service.kt`, new public method on an existing or new service class |
| Repository / entity | `*Repository.kt`, `@Entity` class, new field on existing entity |
| Mapper | `*Mapper.kt` (MapStruct) |
| Feature flag | `*FeatureFlag.kt` |
| Migration | file under `src/main/resources/db/changelog/` |
| Event / messaging | RabbitMQ publisher/listener change |

A file can match more than one shape (e.g. a new entity field plus its mapper update) — evaluate each shape independently.

### Step 3: Rules pass

For each shape present in the diff, read the relevant rule doc(s) and check the diff's content against them directly:

| Shape | Rule docs to check |
|-------|--------------------|
| Controller endpoint | `304-api-input-models.md`, `306-api-documentation.md`, `104-controller-test-auth.md` |
| Service method | `301-error-handling.md`, `302-spring-boot.md` |
| Repository / entity | `201-database-architecture.md` |
| Migration | `202-postgresql-migrations.md`, `203-liquibase-formatting.md` |
| Feature flag | `303-feature-flags.md` |
| Any Kotlin file | `002-kotlin.md`, `401-guardrails.md` |
| Any Groovy/Spock file | `102-groovy-kotlin-interop.md`, `101-test-patterns.md`, `103-tests.md` |

This is a direct docs-vs-diff check — it does not require searching the rest of the codebase.

### Step 4: Codebase pass (the core of this command)

For each shape found in Step 2, find comparable existing implementations **outside the diff** and compare structural conventions.

**Search mechanics:**
1. Identify the changed file's package directory (e.g. `src/main/kotlin/com/atg/lot/`).
2. Search for sibling files of the same shape, preferring the same package first, then the same module:
   - Controller: other `*Controller.kt` in the same or a sibling package
   - Service: other `*Service.kt` with a similar responsibility (CRUD, orchestration, etc.)
   - Repository/entity: other `*Repository.kt`/`@Entity` classes
   - Mapper: other `*Mapper.kt`
3. Cap at the **2-3 strongest matches** (same package > same module > same shape anywhere) — do not exhaustively scan the whole service for every file.
4. Compare against each match on concrete axes, not vibes:
   - Exception/error handling style (custom exception types, `orElseThrow` patterns)
   - Null handling (`?.`, `requireNotNull`, `OrThrow`/`OrNull` naming)
   - Transactional boundaries (`@Transactional` presence/placement)
   - Logging (`mu.KotlinLogging` usage and level)
   - DTO/mapper usage vs. exposing entities directly
   - Naming conventions consistent with `002-kotlin.md`

**If no comparable file exists** (genuinely first-of-its-kind in the codebase), say so explicitly — do not force a finding.

### Step 5: Output findings table

```
Codebase Review — {TICKET}
Diff: origin/main...HEAD ({N} files changed, {M} test files excluded)

| File | Shape | Compared against | Divergence | Severity | Suggested action |
|------|-------|-------------------|------------|----------|-------------------|
| LotController.kt:34 | Controller endpoint | AuctionController.kt:20 | Returns raw entity instead of DTO | Medium | Map through LotMapper before returning |
| LotService.kt:88 | Service method | AuctionService.kt:60 | No @Transactional on multi-step write | High | Add @Transactional per 301-error-handling.md |
| LotFeatureFlag.kt | Feature flag | (rules only) | Missing @KoverIgnore on proxy factory | Low | Add per atg-conventions-guard |

{K} findings ({H} high, {M2} medium, {L} low) | {F} files had no comparable precedent
```

### Step 6: Verdict (advisory — never blocks)

```
📋 Codebase review complete — {K} finding(s) to consider ({H} high, {M2} medium, {L} low).

This is advisory: use judgment on which findings are worth addressing before shipping.

Proceed to: /atg:story-gap {TICKET} [--branch N]
```

If there are zero findings:

```
✅ Codebase review — no divergences from existing patterns or rules found.

Proceed to: /atg:story-gap {TICKET} [--branch N]
```

## Guardrails

- Do not block `/atg:ship` or `/atg:story-gap` regardless of findings — this command only reports.
- Do not flag a divergence without naming the specific file/line it was compared against — "seems inconsistent" is not a finding.
- Prefer under-flagging to noise: skip stylistic nitpicks already covered by Detekt/CodeNarc (those are `/atg:verify`'s job).
- Test files are out of scope for the codebase pass.

## Next Steps

1. Review findings; fix anything worth fixing, then re-run `/atg:verify` if code changed
2. Run `/atg:story-gap {TICKET} [--branch N]`
3. When ready: `/atg:ship {TICKET} [--branch N]`
