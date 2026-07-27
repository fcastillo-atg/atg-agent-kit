---
name: atg-cross-cutting-spotter
description: Use when adding entities, repository methods, schema fields, delete behavior, multi-step operations, or user-facing changes in wavebid-a2o-service.
---

# ATG Cross-Cutting Spotter

This skill catches architectural concerns that are easy to miss during implementation and expensive to fix after PR feedback.

## Use when

- Adding entities, repository methods, or schema fields
- Implementing multi-step service operations
- Modifying delete behavior, domain mapping, or event emission
- Introducing user-facing behavior changes

## Spotting checklist

For each relevant change, verify whether it introduces one or more of these concerns:

1. Database schema change -> add Liquibase migration
2. New entity identifier -> use UUIDv7 (`UuidCreator.timeOrderedEpochPlus1()`)
3. New entity/model conversion -> add or update MapStruct mapper
4. Delete semantics -> use soft-delete (`enabled = false`) where applicable
5. Multi-step DB operation -> consider `@Transactional`
6. User-facing behavior change -> evaluate feature-flag requirement (`/atg:feature-flag`)
7. State changes consumed externally -> evaluate RabbitMQ event/schema updates

## Output format

Return a short matrix:
- Concern
- Why triggered
- Required action
- Suggested command/file

Example action pointers:
- "Add Liquibase migration file under `src/main/resources/db/changelog/{TICKET}/`"
- "Plan this in branch 1 and gate with `/atg:feature-flag`"
- "Validate final behavior with `/atg:story-gap {TICKET}`"

## Guardrails

- Prefer preventive guidance over speculative refactors
- Do not force all concerns; only flag those evidenced by current changes
