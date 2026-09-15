---
name: atg-service-rules
description: Use before editing or reviewing any .kt or .groovy file under wavebid-a2o-service, and before an /atg:* command applies a code fix. Points at the service's numbered rule docs instead of restating them.
---

# ATG service rules

The conventions for `wavebid-a2o-service` live in the service repo, not in this kit:
`wavebid-a2o-service/CLAUDE.md` and the numbered docs under `wavebid-a2o-service/.claude/rules/`.
Read the relevant ones before writing code, and cite them by number when flagging a divergence.

| Touching | Read |
|---|---|
| Any Kotlin | `002-kotlin.md`, `401-guardrails.md`, `403-detekt-extra-violations.md` |
| Any Groovy/Spock test | `101-test-patterns.md`, `102-groovy-kotlin-interop.md`, `103-tests.md` |
| Controller | `304-api-input-models.md`, `306-api-documentation.md`, `104-controller-test-auth.md` |
| Service | `301-error-handling.md`, `302-spring-boot.md` |
| Repository / entity | `201-database-architecture.md` |
| Migration | `202-postgresql-migrations.md`, `203-liquibase-formatting.md` |
| Feature flag | `303-feature-flags.md` |
| Events | `307-messaging-eventing.md` |
| Changeset | `406-changesets.md` |
| Plan file location | `405-plans-location.md` |

Gradle runs from `wavebid-a2o-service/`. Never pass `--no-daemon`. Coverage gates are ≥85%
branch and ≥95% line (`koverVerify`).

## When the rule docs are not loaded

Some harnesses do not read `.claude/rules/`. Three sibling skills carry the essentials so the
conventions still travel with the kit:

- `atg-conventions-guard`: Kotlin, Spring/JPA, Spock, feature-flag file, and hygiene checks
- `atg-cross-cutting-spotter`: migration, UUIDv7, MapStruct, soft delete, `@Transactional`,
  feature flag, events, money precision, downstream rewrites
- `atg-pr-self-review`: pre-ship sanity pass (clean tree, slice alignment, leftovers, changeset)

They are deliberately short. The rule docs stay the authority; when both are available, the
rule docs win.
