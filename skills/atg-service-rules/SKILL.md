---
name: atg-service-rules
description: Use before editing or reviewing any source file in a service the kit supports, and before an /atg:* command applies a code fix. Points at the service's own rule docs instead of restating them.
---

# ATG service rules

Conventions live in each service repo, not in this kit. Read `rules-dir` from the
**atg-repo-profile** skill, read the relevant docs there before writing code, and cite them by
name when flagging a divergence. A profile whose `rules-dir` is `none` has no rule docs; fall
back to the profile's `conventions-skill`.

## wavebid-a2o

The service's `CLAUDE.md` plus the numbered docs under its `rules-dir`.

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

## invoices-service

`CLAUDE.md` at the repo root plus the docs under its `rules-dir`.

| Touching | Read |
|---|---|
| Any controller or endpoint | `api-request-headers.md`, `playwright-integration-tests.md` |
| Anything marketplace-aware | `marketplace-resolution.md` |
| Publishing an event | `rabbitmq-event-categories.md` |
| A Core/Messaging domain event | `new-platform-domain-events.md` |
| A PXB legacy-sync message | `legacy-sync-messaging.md` |

These arrive with the `feature/claude-code-rules` branch. Until it merges, the same conventions
sit in `.cursor/rules/*.mdc`, which Claude Code does not load — so in that window lean on the
portable skills below.

## When the rule docs are not loaded

Some harnesses do not read a repo's rules directory. Sibling skills carry the essentials so the
conventions still travel with the kit — the profile's `conventions-skill` and
`cross-cutting-skill` name which pair applies:

| Profile | Conventions | Cross-cutting |
|---|---|---|
| `wavebid-a2o` | `atg-conventions-guard` | `atg-cross-cutting-spotter` |
| `invoices-service` | `atg-conventions-csharp` | `atg-cross-cutting-csharp` |

`atg-pr-self-review` is the third portable skill, service-agnostic: a pre-ship sanity pass
(clean tree, slice alignment, leftover `TODO`/`println`, the changeset gate) that applies
regardless of which pair above matches.

They are deliberately short. The rule docs stay the authority; when both are available, the
rule docs win.
