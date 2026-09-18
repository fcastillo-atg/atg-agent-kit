---
description: Cross-reference the PR diff against existing codebase patterns and project rules to catch antipatterns before shipping (advisory, never blocks)
---

# Pattern check

After `/atg:verify` passes, compare the diff against how similar code is already written in the
service and against the numbered rule docs. Advisory only: report, never block.

## Usage

```bash
/atg:pattern-check {TICKET}
/atg:pattern-check {TICKET} --branch N
```

Diff base and `--branch` scoping: atg-story-artifacts skill.

## Steps

1. Get the diff (`--name-only` and full). Exclude test files (`*Spec.groovy`, `*Test.kt`) from
   what is being checked; they are not compared against precedent.
2. Classify each changed file by shape. A file can match several shapes; evaluate each.

| Shape | Signal |
|---|---|
| Controller endpoint | a controller type, new route-mapped action |
| Service method | a service or handler type, new public method |
| Repository / entity | a repository type, a persistence entity, new entity field |
| Mapper | a mapping type |
| Feature flag | the profile's flag file pattern; omit this row when `feature-flag` is `none` |
| Migration | under the profile's `migrations-path`; omit this row when it is `none` |
| Event / messaging | RabbitMQ publisher or listener |

3. **Rules pass.** For each shape, read the rule docs listed in the atg-service-rules table and
   check the diff against them directly. No codebase search needed.
4. **Codebase pass.** For each shape, find the 2 to 3 strongest comparable implementations
   outside the diff (same package, then same module, then same shape anywhere). Compare on
   concrete axes: exception and error handling, null handling (`?.`, `requireNotNull`,
   `OrThrow`/`OrNull`), `@Transactional` presence and placement, logging, DTO or mapper use
   versus exposing entities, naming. If no comparable file exists, say so; do not force a finding.
5. Print findings and the verdict.

```
Pattern Check — {TICKET}
Diff: origin/main...HEAD ({N} files, {M} test files excluded)

| File | Shape | Compared against | Divergence | Severity | Suggested action |
|------|-------|------------------|------------|----------|------------------|
| LotService.kt:88 | Service | AuctionService.kt:60 | No @Transactional on multi-step write | High | Add per 301-error-handling.md |

{K} findings ({H} high, {M2} medium, {L} low) | {F} files had no comparable precedent
Advisory: use judgment on which findings to address before shipping.
```

With zero findings, say so in one line.

## Guardrails

- Every finding names the specific file and line it was compared against.
- Skip stylistic nits the profile's static-analysis gates already cover; that is verify's job.
- Prefer under-flagging to noise.

**Next:** `/atg:story-gap {TICKET} [--branch N]`
