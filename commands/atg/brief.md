---
description: Optional Socratic pre-story analysis — surface ambiguities and cross-cutting concerns before story-plan runs
---

# Brief: Pre-Story Deep-Dive

**Purpose:** Optional Phase 0 before `/atg:story-plan`. Runs a structured analysis of the story to surface ambiguities, missing details, and cross-cutting concerns. Use for complex or risky stories to avoid mid-implementation surprises.

## Usage

```bash
/atg:brief {TICKET}            # interactive — asks up to 3 questions if gaps found
/atg:brief {TICKET} --auto     # silent — log all assumptions, ask no questions
/atg:brief {TICKET} --discuss  # force interactive Socratic mode (all gaps surfaced)
```

## When to Use

Use `/atg:brief` **instead of going straight to `/atg:story-plan`** when any of the following apply:

- Story has vague ACs ("improve performance", "refactor X", "redesign Y flow")
- Story touches shared infrastructure (RabbitMQ, Aurora, Redis, S3, Liquibase)
- Story points > 8 or expected LOC > 500
- Story description has open questions or unresolved comments in Jira
- The team has asked for a design review before implementation

## Execution Steps

### Step 1: Fetch the story

Resolve per the **jira-cli** skill: `acli jira workitem view {TICKET} --fields summary,description,comment --json` first, falling back to `mcp__mcp-atlassian__jira_get_issue`.

If both are unavailable, ask the user to paste the story description and any relevant comments.

Write (or update) `bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-story.md` with:
- Title, description, acceptance criteria
- `## Jira comments (summary)` — bullet summary of substantive comments
- Link: `https://auctiontechnologygroup.atlassian.net/browse/{TICKET}`

### Step 2: Assess complexity signals

Evaluate the story against these signals:

| Signal | Weight |
|--------|--------|
| Vague AC (no measurable outcome) | High |
| Touches ≥ 2 bounded contexts | Medium |
| Requires Liquibase migration | High |
| Requires new RabbitMQ event | High |
| Story points > 8 | Medium |
| Estimated LOC > 500 | Medium |
| AC references external system (AWS, SLB, ATGPay) | High |
| AC says "refactor" without specifying scope | High |

### Step 3: Run 4-lens analysis

Evaluate the story through 4 lenses and note any gaps:

**Lens 1: Vague ACs**
- Are acceptance criteria specific and measurable?
- Can you write a failing test for each AC right now?
- If not, what's missing?

**Lens 2: Codebase gaps**
- Does the required infrastructure exist in the codebase?
  - Service, repository, entity, mapper for the relevant domain?
  - Liquibase migrations if schema changes are needed?
  - Feature flag infrastructure if needed?
- Search the codebase for related classes; note any that are absent.

**Lens 3: Cross-cutting concerns**

Run through the ATG cross-cutting checklist:

| Concern | Trigger | Action |
|---------|---------|--------|
| Liquibase migration | Any new DB field, table, or index | Add migration to Branch 1 estimate |
| Feature flag needed | Any user-facing behavior change | Plan flag in Branch 1 |
| RabbitMQ event | Any state change consumed by other services | Identify event schema |
| Soft-delete pattern | Any deletion logic | Use `disable()`, not `delete()` |
| UUIDv7 | Any new entity with primary key | Use `UuidCreator.timeOrderedEpochPlus1()` |
| MapStruct mapping | Any new entity ↔ model conversion | Plan mapper in same branch as entity |
| `@Transactional` | Any multi-step DB operation | Annotate service method |

**Lens 4: Scope risks**
- Does the AC mention "all X" or "bulk" operations? → Could be N+1 or performance risk.
- Does the AC mention "backward compatible"? → Needs deprecation path.
- Does the AC mention "real-time" or "live"? → Might need WebSocket or polling.
- Is the AC in conflict with another open story or recent change?

### Step 4: Decide — questions or assumptions

**Default (interactive):**
- If ≥1 gap found: ask up to **3 targeted questions**, **one at a time** — wait for the answer before surfacing the next.
- **Use the `AskUserQuestion` tool** for every question. Do NOT output questions as plain markdown text.
  - Set `question` to the gap label + the concrete question (e.g. `[Gap: vague AC] AC 3 says "improve lot import performance" — what's the target?`).
  - Set `header` to a short chip label (≤12 chars, e.g. `Perf target`).
  - The **recommended answer becomes the first option**, labelled `"… (Recommended)"`.
  - Each option needs a `label` and a `description`. Add 2–3 concrete alternatives (the tool always appends an "Other" option for free-text).
  - Use `multiSelect: false` unless the gap genuinely requires multi-select.
- After the user picks an option, record the answer in `## Pre-Analysis`, then ask the next question (if any) — again via `AskUserQuestion`.

**With `--auto`:**
- Do not ask questions.
- Log each assumption explicitly:

```
Assumption (AC 3): Interpreting "improve performance" as reducing P95 lot import time by ≥50%.
Assumption (schema): Treating invoice_status as a new column on the lot table (nullable, varchar(32)).
```

**With `--discuss`:**
- Ask about every gap found, no limit on questions — still **one `AskUserQuestion` call at a time**.
- Use Socratic mode: pose hypotheticals, give a recommended answer as the first option, and ask the user to confirm or redirect.

### Step 5: Write Pre-Analysis section

Write a `## Pre-Analysis` section to the beginning of `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md` (create the file if it doesn't exist):

```markdown
## Pre-Analysis

**Run:** {date}
**Mode:** {interactive|auto|discuss}

### Complexity signals
- {signal}: {description}

### Cross-cutting concerns identified
- {concern}: {action required}

### Assumptions logged
- {assumption}

### Open questions (if any)
- {question}

### Recommendation
{1-2 sentences: is this ready for story-plan, or does it need clarification first?}
```

### Step 5b: Append `## Next ATG command` to `implementation-plan.md` (required)

After `## Pre-Analysis` is in place, ensure **`implementation-plan.md` ends with** a footer that **matches the chat handoff** (same wording in both places).

- If the file already has `## Next ATG command` from a prior brief run, **replace** that section — do not stack duplicate footers.
- Use the **real ticket key** (not `{TICKET}`) in the body.

**If all questions have been answered via `AskUserQuestion`** (or `--auto`):

```markdown
---

## Next ATG command

`/atg:story-plan WBPR-4095`
```

**If the brief ended before all questions were answered** (e.g. session interrupted):

```markdown
---

## Next ATG command

Re-run `/atg:brief WBPR-4095` to resume, or run `/atg:story-plan WBPR-4095` and answer
remaining questions inline.
```

### Step 6: Commit

```bash
git add bin/stories/{year}/{month}/{TICKET}-{slug}/
git commit -m "chore(brief): pre-analysis for {TICKET} [$(date +%Y-%m-%d)]"
```

### Step 7: Print summary and hand off

End the assistant message with the **same `## Next ATG command` lines** you wrote to `implementation-plan.md` (Step 5b), then the standard summary block:

```
✅ Pre-analysis complete for {TICKET}

Complexity: {Low|Medium|High}
Cross-cutting concerns: {N}
  → {concern 1}
  → {concern 2}

Written to: bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md

{Repeat the Next ATG command block here verbatim — see Step 5b}
```

## Integration with story-plan

When `/atg:story-plan` runs and finds a `## Pre-Analysis` section in `implementation-plan.md`, it **skips its own analysis phase** and uses the pre-analysis as input instead. This prevents redundant analysis and ensures the brief's findings are carried forward.

## Example: High-complexity story

```
/atg:brief WBPR-4099

📖 Fetching WBPR-4099 from Jira...
   Title: Bulk lot end-time propagation for mid-catalog insertions
   ACs: 6  |  Comments: 3 substantive

🔍 4-lens analysis...

  Lens 1 - Vague ACs:
    ⚠️  AC 4: "system should be fast" — no target metric defined

  Lens 2 - Codebase gaps:
    ✅  LotPropagationService exists
    ✅  LotRepository.findByAuctionId exists
    ❌  No bulk update query — will need custom JPQL or batch update

  Lens 3 - Cross-cutting:
    🔴 Liquibase migration — new index on lot.auction_id + lot.sequence (performance)
    🟡 Feature flag — user-facing propagation behavior change
    🟡 @Transactional — multi-step propagation update

  Lens 4 - Scope risks:
    ⚠️  "all lots from insertion point onwards" — could be N+1 for large catalogs

Complexity: HIGH

*(Then calls AskUserQuestion for Round 1 — one question at a time:)*

AskUserQuestion({
  questions: [{
    question: "[Gap: vague AC] AC 4 says 'system should be fast' — what's the acceptable propagation time for a 10,000-lot catalog? (Baseline: ~45s)",
    header: "Perf target",
    multiSelect: false,
    options: [
      { label: "Under 60s P95 for 10k lots (Recommended)", description: "Baseline ~45s, gives 15s headroom" },
      { label: "Under 30s P95 for 10k lots", description: "Aggressive — may need batch tuning" },
      { label: "No SLA defined", description: "Just make it faster than today" }
    ]
  }]
})

*(After the user picks "Under 60s P95 …", the agent records the answer and calls AskUserQuestion again for Round 2.)*
```

## Next Steps

1. Review Pre-Analysis in `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md`
2. Run `/atg:story-plan {TICKET}` — it will read the brief and skip its own analysis
