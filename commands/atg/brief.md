---
description: Optional Socratic pre-story analysis. Surfaces ambiguities and cross-cutting concerns before story-plan runs
---

# Brief

Optional Phase 0 before `/atg:story-plan`. Analyses the story for vague ACs, codebase gaps,
cross-cutting concerns, and scope risks, asks up to three targeted questions, and writes
`## Pre-Analysis` so story-plan can skip its own analysis. Brief assumes the ticket is true;
`/atg:scout` is what checks that. Run scout first if nobody has.

## Usage

```bash
/atg:brief {TICKET}            # interactive: up to 3 questions if gaps are found
/atg:brief {TICKET} --auto     # silent: log assumptions, ask nothing
/atg:brief {TICKET} --discuss  # Socratic: ask about every gap, no limit
```

Use brief when the story has vague ACs ("improve performance", "refactor X"), touches shared
infrastructure (RabbitMQ, Aurora, Redis, S3, Liquibase), is over 8 points or 500 LOC, has open
questions or unresolved comments, or the team asked for a design review.

## Steps

### 1. Fetch the story

Resolve the ticket and story directory per the **atg-story-artifacts** skill. Fetch summary,
description, and comments per the **jira-cli** skill; if unreachable, ask the user to paste them.
Write or update `{TICKET}-story.md` with title, description, ACs, `## Jira comments (summary)`,
and the browse URL.

### 2. Score complexity

| Signal | Weight |
|---|---|
| Vague AC (no measurable outcome) | High |
| Requires Liquibase migration | High |
| Requires new RabbitMQ event | High |
| AC references an external system (AWS, SLB, ATGPay) | High |
| AC says "refactor" without scope | High |
| Touches 2+ bounded contexts | Medium |
| Story points > 8 or LOC > 500 | Medium |

### 3. Four-lens analysis

**Lens 1, vague ACs.** Is each AC specific and measurable? Could you write a failing test for it
now? If not, what is missing?

**Lens 2, codebase gaps.** Does the service, repository, entity, mapper, migration, or flag
infrastructure exist? Search and note absences. Defined is not the same as evaluated: a domain
can have a rich configuration model, enums, override cascades, and CRUD while nothing consumes
it. Grep the enum value or constant in use, not where it is declared. One hit means a definition
with no engine behind it, and a story that assumes the capability is a build, not an integration.
This is the most expensive gap to find late. Also note fields persisted on the entity but dropped
by the response model: the data exists, only the contract is lossy.

**Lens 3, cross-cutting concerns.**

| Concern | Trigger | Action |
|---|---|---|
| Liquibase migration | New DB field, table, or index | Add to Branch 1 estimate |
| Feature flag | User-facing behaviour change | Plan flag in Branch 1 |
| RabbitMQ event | State change consumed by other services | Identify event schema |
| Soft delete | Any deletion | `disable()`, not `delete()` |
| UUIDv7 | New entity primary key | `UuidCreator.timeOrderedEpochPlus1()` |
| MapStruct | New entity ↔ model conversion | Mapper in the same branch as the entity |
| `@Transactional` | Multi-step DB operation | Annotate the service method |
| Money precision | Any amount read, moved, or displayed | Carry stored values through; scale-2 `HALF_EVEN`; never re-round or re-derive from rates |
| Downstream rewrite | Payload posted to another service | Check what the receiver normalizes, strips, or merges, then read the record back. A success status is not proof it stored what you sent |

**Lens 4, scope risks.** "All X" or "bulk" → N+1 or performance risk. "Backward compatible" →
deprecation path. "Real-time" → WebSocket or polling. Conflict with another open story or recent
change. Then two harder questions:

- Where can the boundary go so this does not queue behind in-flight work? Check the epic for
  siblings In Development. If the last step depends on one of them, consider stopping one step
  earlier and naming the handoff. A story that ends at "produce the thing" instead of "produce
  and send it" can be built and tested alone. State the boundary in the plan or it drifts.
- If a needed capability only partly exists, say what the story will not cover. An honest limit
  beats a contract that implies full coverage; otherwise the implementer assumes the gap is theirs.

### 4. Questions or assumptions

Before asking anything, check it is not already answered: PRD open-question tables, Jira
comments on this ticket and its siblings, sibling descriptions that record a call. Asking a
closed question costs credibility and a day.

Then check whose question it is. Scope, priority, and what counts as done go to product. What
another service's code does goes to that service's owner. Where data lives, which repo owns a
capability, and transport direction are engineering calls the user can make now. Only the last
kind goes to AskUserQuestion; surface the others as escalations in the write-up.

- **Interactive (default):** up to 3 questions, one AskUserQuestion call at a time, wait for
  each answer. `question` = gap label plus the concrete question (`[Gap: vague AC] AC 3 says
  "improve import performance". What is the target?`). `header` ≤ 12 chars. Recommended answer
  first, labelled `(Recommended)`. 2–3 concrete alternatives, each with label and description.
  `multiSelect: false` unless the gap truly needs it. Record each answer in Pre-Analysis before
  asking the next. Never print questions as plain markdown.
- **`--auto`:** ask nothing. Log each assumption explicitly:
  `Assumption (AC 3): interpreting "improve performance" as P95 import time down ≥50%.`
- **`--discuss`:** ask about every gap, still one call at a time, Socratic: pose the hypothetical,
  recommend, ask the user to confirm or redirect.

### 5. Write Pre-Analysis

Prepend `## Pre-Analysis` to `implementation-plan.md` (create the file if needed):

```markdown
## Pre-Analysis
**Run:** {date}   **Mode:** {interactive|auto|discuss}

### Complexity signals
### Cross-cutting concerns identified
### Assumptions logged
### Known limits            (omit only if none)
### Open questions (if any) (name who answers: user, product, or another service's owner)
### Recommendation          (ready for story-plan, or needs clarification first?)
```

Then set the `## Next ATG command` footer per **atg-story-artifacts**: `/atg:story-plan {TICKET}`
when all questions were answered or `--auto`; otherwise "Re-run `/atg:brief {TICKET}` to resume,
or run `/atg:story-plan {TICKET}` and answer remaining questions inline."

If the ticket itself is wrong, that is scout's output. Never edit a Jira description from here;
when suggesting one, propose surgical changes that name what stays.

Never `git add` anything under `bin/`.

### 6. Report

End the reply with the same footer lines, then:

```
Pre-analysis complete for {TICKET}
Complexity: {Low|Medium|High}   Cross-cutting concerns: {N}
  → {concern}
Written to: bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md
```

**Next:** `/atg:story-plan {TICKET}` (it reads Pre-Analysis and skips its own analysis).
