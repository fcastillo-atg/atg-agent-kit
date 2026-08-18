---
description: Create a branch-split implementation plan for a WBPR story — LOC estimate, feature flag strategy, branch breakdown, As-built placeholder
---

# Story Implementation Plan with Branch Strategy

You are a senior Spring Boot architect specializing in Trunk-Based Development with feature flags. Create comprehensive implementation plans that break down stories into manageable, independently testable branches.

## Context

The user has provided a story (JIRA ticket, feature description, or technical requirement) that needs implementation planning. Your task is to:

1. **Resolve** canonical story text: use existing `{TICKET}-story.md` when present, otherwise fetch Jira (per the **jira-cli** skill) and create or update that file; whenever Jira is fetched, also **retrieve and review ticket comments** (see Step 1).
2. **Analyze** the story requirements and current codebase
3. **Design** architecture flow and implementation details
4. **Capture explicit dependencies, decision points, and risk/performance notes**
5. **Estimate** total lines of code (production + test)
6. **Design** feature flag strategy (if needed)
7. **Split** work into branches following the LOC-based rule
8. **Document** detailed implementation plan with branch specifications

## Requirements

**Story Input**: $ARGUMENTS

**Refresh from Jira**: If the user asks to refresh, re-sync from Jira, or similar, treat `{TICKET}-story.md` as stale—fetch issue **and comments** (per the **jira-cli** skill) and overwrite or update the file before continuing.

## Branch Splitting Rule

**Apply this rule strictly:**

- **If total LOC ≤ 500**: Use **1 branch** only (full feature: production, tests, docs in one PR unless the team explicitly requests otherwise). **Baseline:** **~400–500 LOC** total is the natural sizing for a single-branch story; anything **at or below 500** stays one branch (including smaller changes).
- **If total LOC > 500 and < 1000**: Split into **2 branches**; size each slice toward **≤500 LOC** (same ceiling as single-branch stories—split the work in half, do not use 350 as a planning unit).
- **If total LOC >= 1000**: Start from **ceil(total_LOC / 500)** chunks, then **merge tiny tails**: let **r = total_LOC mod 500** (remainder after full 500-LOC blocks). If **0 < r < 100**, do **not** open a separate branch for that tail—use **N = floor(total_LOC / 500)** branches instead and **absorb** the extra lines into the last slice (or split evenly). A **~50 LOC** sliver is not its own branch.
  - If **r ≥ 100** (or **r = 0**), **N = ceil(total_LOC / 500)** as usual.
  - Each branch should target **~400–500 LOC** where practical; **≤500** is the norm, but **one** branch may land **slightly above 500** when absorbing a **<100 LOC** remainder (prefer that over a useless micro-branch).

**LOC Calculation Includes:**
- Production code (Kotlin/Java)
- Test code (Groovy/Kotlin)
- Documentation updates (markdown)
- Configuration files (if substantial)

**Example Calculations:**
- 450 LOC total → **1 branch** (~400–500 baseline band)
- 400 LOC total → **1 branch** (≤500 LOC)
- 700 LOC total → **2 branches** (501–999 tier; each slice ~half of total, each **≤500 LOC**)
- 1,050 LOC total → **2 branches** (≥1000; remainder 50 after 2×500 → **<100**, merge—do not split off ~50 LOC)
- 1,750 LOC total → **4 branches** (≥1000; remainder 250 ≥ 100 → ceil(1750 / 500) = 4)

## Instructions

### Step 1: Resolve story input (canonical source)

**Goal:** One authoritative story text for all later steps—either an existing snapshot file or Jira (resolved per the **jira-cli** skill)—and **awareness of ticket discussion** (comments) that can change scope or acceptance.

**Policy:**

- **Jira is source of truth** when you fetch or refresh; `{TICKET}-story.md` is a **repo snapshot** for planning and review (avoid two divergent specs).
- **If** `bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-story.md` **exists** and the user did **not** request a refresh from Jira, **read and use that file** as the planning input (fast; works when Jira is unreachable). **Note in the preamble** that Jira comments were **not** re-fetched; if the ticket may have new discussion, recommend a refresh.
- **If** the file **does not exist**, or the user requests **refresh**, or `$ARGUMENTS` is only a ticket key/URL with no pasted description, **fetch the issue** per the **jira-cli** skill (`acli jira workitem view {TICKET} --fields summary,description,comment --json`, falling back to `mcp__mcp-atlassian__jira_get_issue`), then **create or update** `bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-story.md` with title, description, acceptance criteria, and a link to `https://auctiontechnologygroup.atlassian.net/browse/{TICKET}`.
- **Jira comments (required whenever Jira is fetched):**
  - **Retrieve** comments for the issue as part of the same fetch (the `comment` field on `acli jira workitem view`, or the equivalent MCP `fields`/`expand` param).
  - **Review** comments for scope changes, clarifications, AC tweaks, blockers, or decisions **not** in the description.
  - **Summarize** material comment takeaways in the plan preamble (and in **Analyze**, treat them like part of the story).
  - When writing or updating `{TICKET}-story.md`, add or update a **## Jira comments (summary)** section (or equivalent): short bullet summary of relevant threads; omit noise. If there are no substantive comments, state that explicitly.
- **If** both `acli` and MCP fail, say so, and fall back to pasted description or ask the user to paste Jira fields **and** important comments.

**Output (include in the plan preamble):**

- Ticket key and browse URL
- Path to `{TICKET}-story.md` used or created
- Whether content came from **file** or **Jira** (and via `acli` or MCP)
- **Jira comments:** retrieved or not (and why); **summary** of anything that affects planning (or “none substantive”)

### Step 2: Analyze Story Requirements

**Extract from story:**
```
- Feature description and acceptance criteria
- Jira comment takeaways from Step 1 (scope, decisions, AC changes)
- User flows and use cases
- Performance requirements
- Dependencies on existing code
- Testing requirements
- Documentation needs
```

**Investigate codebase:**
- Search for related existing functionality
- Identify services/repositories/controllers to modify
- Check for similar patterns in the codebase
- Review recent related changes (git history)

**Output:**
```markdown
## Story Analysis

### Requirements Summary
- [List key requirements]

### Current State
- [What exists today]
- [Related code: file paths with line numbers]

### Gap Analysis
- [What's missing]
- [What needs modification]
```

### Step 2b: Architecture Design (Required)

After analysis, add an explicit architecture section to make implementation intent obvious before branch slicing.

**Output (required in plan):**

```markdown
## Architecture design

### Component diagram
- Use **Mermaid** or ASCII diagram.
- Show event flow and service/repository/external-system interactions.
- Include queue/topic names when messaging is involved.
- Include transaction boundaries or listener boundaries when relevant.

### Key implementation details
- List the critical production changes with concrete signatures/snippets.
- Include 4-8 focused snippets (not full files), e.g.:
  - repository query method signature
  - service orchestration method
  - listener handler flow
  - feature-flag interface wiring (if used)
  - validation rule method
  - migration/index DDL (if any)
- For each snippet, state **why** it exists and **what risk/edge-case** it addresses.
```

**Depth rule:**
- For stories touching 2+ components (service + repo + events/external), this section is mandatory and detailed.
- For tiny single-file changes, include a compact version (at least one mini diagram + 2 key snippets).

### Step 2c: Dependencies, Open Questions, and Performance Notes

Add these sections to avoid hidden assumptions:

```markdown
## Dependencies

### External dependencies
- [SLB/RabbitMQ/DB/index/cache/etc. dependencies]

### Internal dependencies
- [Required existing modules/services/stories]

## Open questions
- [Decision that impacts implementation shape]
- [Decision that impacts acceptance criteria/test strategy]
- If none: `- None at planning time.`

## Performance considerations
- Include this section when the story touches queries, batch processing, messaging, or loops over large datasets.
- Capture baseline/expected impact and any required index/query/batch strategy.
- If not applicable, add one line: `Not performance-sensitive for current scope.`
```

**Conditional rule for `## Open questions`:**
- If `## Pre-Analysis` exists and already contains unresolved open questions, do **not** duplicate; add a short
  carry-forward line in `## Open questions` pointing to `## Pre-Analysis`.
- If `## Pre-Analysis` exists and has no open questions, `## Open questions` is optional (you may omit it).
- If `## Pre-Analysis` is absent, include `## Open questions` explicitly (or `None at planning time`).

### Step 3: Estimate Lines of Code

**Estimate for each component:**

```
Production Code Estimate:
- New files: [estimate per file]
- Modified files: [estimate per file]
- Subtotal: XXX LOC

Test Code Estimate:
- Unit tests: [estimate]
- Integration tests: [estimate]
- Subtotal: XXX LOC

Documentation:
- README updates: [estimate]
- API docs: [estimate]
- Subtotal: XXX LOC

TOTAL: XXX LOC
```

**Be realistic with estimates:**
- Simple CRUD: ~50-100 LOC per operation
- Service methods: ~30-60 LOC each
- Repository queries: ~10-20 LOC each
- Unit tests: ~80-120 LOC per service method
- Integration tests: ~100-150 LOC per endpoint
- Event listeners: ~40-80 LOC
- Feature flags (single file): ~80-120 LOC

### Step 4: Design Feature Flag (If Needed)

**Determine if feature flag is needed:**
- ✅ New user-facing functionality
- ✅ Complex changes requiring gradual rollout
- ✅ Changes with rollback risk
- ❌ Bug fixes
- ❌ Refactoring (no behavior change)
- ❌ Documentation-only changes

**🛡️ CRITICAL: If feature flag is needed, it MUST be implemented in Branch 1 (FIRST)!**

**If feature flag needed, apply /atg:feature-flag logic:**

```markdown
## Feature Flag Design

**Priority**: MUST be implemented in Branch 1 (FIRST)

**Feature Name**: `{snake_case_name}`
**Cookie Control**: `FF_{snake_case_name}=true`

**Interface**: `{DomainConcept}`
**Noop Implementation**: `Noop{DomainConcept}` (legacy behavior - does nothing)
**Enabled Implementation**: `{Descriptive}{DomainConcept}` (new behavior)

**Branch 1 Implementation**:
- Enabled implementation throws `UnsupportedOperationException` (safe failure)
- Flag DISABLED by default
- Wire into services (calls noop by default)
- NO production behavior change

**Subsequent Branches**:
- Replace `UnsupportedOperationException` with actual logic
- Flag remains DISABLED by default
- All functionality behind disabled flag (safe)

**Single File**: `src/main/kotlin/com/{package}/{DomainConcept}FeatureFlag.kt`

**LOC Estimate**: ~100 LOC (interface + 2 impls + factory + docs)
```

### Step 5: Apply Branch Splitting Strategy

**Calculate branches needed:**
```
Total LOC: [from Step 3]
Branch count: [apply rule from Branch Splitting Rule section]
LOC per branch: [total / branch count]
```

**For total LOC ≥ 1000:** compute **r = total_LOC mod 500**. If **0 < r < 100**, use **floor(total_LOC / 500)** branches and merge the tail; otherwise **ceil(total_LOC / 500)**. (Align with **500 LOC** base—do **not** use 350 as the divisor.)

**If total LOC ≤ 500:** branch count is **1** (the **~400–500 LOC** band is the baseline for single-branch work). Put production code, tests, documentation, and any feature-flag scaffolding in that **single** branch/PR (do not apply multi-branch patterns A/B/C below).

**Create branch breakdown:**

For each branch:
1. **Branch name**: `fc/{TICKET}-{descriptive-name}`
2. **LOC estimate**: ~XXX lines
3. **Files changed**: List with LOC per file
4. **Focus**: What this branch accomplishes
5. **Dependencies**: Which branch must merge first
6. **Testing strategy**: How to verify this branch works
7. **PR template**: Description for pull request

**Branch Progression Pattern:**

**🛡️ CRITICAL: SAFETY-FIRST PRINCIPLE**

**If feature flag is needed, it MUST be Branch 1 (FIRST)!**

**Pattern A (SAFETY FIRST - Feature Flag Required):**
```
Branch 1: Feature Flag Infrastructure (ALWAYS FIRST) (aim ≤500 LOC)
  - Feature flag file (interface + noop + enabled with UnsupportedOperationException)
  - Wire into services (stub calls)
  - Tests for flag behavior
  - Flag DISABLED by default
  - ✅ ZERO production risk

Branch 2: Core Logic (aim ≤500 LOC)
  - Repository queries
  - Service methods (replace UnsupportedOperationException)
  - Unit tests
  - ✅ Behind disabled flag (safe)

Branch 3: Complete Feature (aim ≤500 LOC)
  - Controllers/endpoints
  - Event systems
  - Integration tests
  - Complete enabled implementation
  - ✅ Behind disabled flag (safe)
```

**Pattern B (No Feature Flag - Simple Changes):**
```
Branch 1: Infrastructure (aim ≤500 LOC)
  - Repository queries
  - Service methods (core logic)
  - Unit tests

Branch 2: Feature Implementation (aim ≤500 LOC)
  - Controllers/endpoints
  - Integration tests
```

**Pattern C (Vertical Slices - No Feature Flag):**
```
Branch 1: CRUD Operations (aim ≤500 LOC)
  - Create + Read endpoints
  - Basic service logic
  - Tests

Branch 2: Advanced Features (aim ≤500 LOC)
  - Update + Delete endpoints
  - Business logic
  - Tests
```

**Choose pattern based on:**
- **Pattern A (SAFETY FIRST)**: When feature flag is needed (user-facing changes, complex changes, rollback risk)
- **Pattern B (Infrastructure)**: New systems/complex changes WITHOUT feature flag
- **Pattern C (Vertical Slices)**: Extending existing systems WITHOUT feature flag

**⚠️ IMPORTANT**: If feature flag is needed, Pattern A is MANDATORY. Never put feature flag last!

### Step 6: Document Branch Strategy

Write all per-branch content into **`implementation-plan.md`** under **`## Branch strategy`**, using **`### Branch N: \`fc/{TICKET}-{name}\`** headings (see **Canonical structure** above). Do not create a separate `branch-strategy.md` file.

**For each branch, provide:**

```markdown
### Branch {N}: `fc/{TICKET}-{name}` (~XXX LOC)

**Goal**: [One-sentence description]

**Depends On**: [Previous branch or "None"]

**Files Changed** ({X} files):
```
path/to/file1.kt          +XX LOC
path/to/file2.kt          +XX LOC
path/to/test/Spec.groovy  +XX LOC
Total: ~XXX lines
```

**Changes**:

1. **File1.kt** (+XX lines)
   ```kotlin
   // Show key code snippets or signatures
   ```

2. **File2.kt** (+XX lines)
   ```kotlin
   // Show key code snippets or signatures
   ```

**Testing Strategy**:
```bash
# Commands to test this branch
./gradlew test --tests "SpecificSpec"

# Manual testing steps
1. [Step-by-step verification]
```

**Acceptance Criteria**:
- ✅ [Specific success criterion]
- ✅ [Another criterion]

**PR Description Template**:
```markdown
## {TICKET}: [Branch description]

### Summary
[What this branch accomplishes]

### Changes
- [Bullet list of changes]

### Testing
- [x] Unit tests pass
- [x] Integration tests pass
- [x] Manual verification completed

### Performance Impact (if applicable)
[Benchmarks or measurements]

### Dependencies
[If depends on other branch]
```
```

### Step 7: Create Testing Strategy Per Branch

**For each branch, specify:**

```markdown
## Testing Strategy

### Branch 1 Testing
**Unit Tests**:
- Test {component} with {scenarios}
- Expected coverage: 95%+

**Integration Tests**:
- None (infrastructure only)

**Manual Testing**:
```bash
# Can call method directly
service.methodName(params)
# Verify [expected behavior]
```

### Branch 2 Testing
**Unit Tests**:
- [Specific test cases]

**Integration Tests**:
- Test {endpoint} with {scenarios}
- Verify {behavior}

**Manual Testing**:
```bash
curl -X POST http://localhost:8080/api/...
# Verify [expected result]
```

### Branch 3 Testing
**Unit Tests**:
- Feature flag toggle tests

**Integration Tests**:
- End-to-end workflow tests

**Manual Testing**:
```bash
# With feature flag enabled
curl -H "Cookie: FF_{name}=true" ...

# With feature flag disabled
curl -H "Cookie: FF_{name}=false" ...
```
```

### Step 8: Add Merge Strategy

**Document merge order:**

```markdown
## Merge Strategy

### Sequential Merge Order
```
main
 ↓
{TICKET}-1 ({name}) ✅ Merge to main
 ↓
{TICKET}-2 ({name}) ✅ Merge to main
 ↓
{TICKET}-3 ({name}) ✅ Merge to main
```

### Testing at Each Stage

**After Branch 1 Merge**:
- [What works at this point]
- [What doesn't work yet]

**After Branch 2 Merge**:
- [What additional functionality is available]

**After Branch 3 Merge**:
- [Complete feature available]
- [Feature flag controls rollout]

### Rollback Strategy

**If issues in production:**
- Branch 3: Toggle feature flag to disabled
- Branch 2: Revert merge commit
- Branch 1: Requires new code (infrastructure changes)
```

### Step 9: Create Summary Table

**Provide overview:**

```markdown
## Summary

| Branch | LOC | Files | Tests | Focus | Duration |
|--------|-----|-------|-------|-------|----------|
| {TICKET}-1 | ~XXX | X | XXX | {Focus} | {Time} |
| {TICKET}-2 | ~XXX | X | XXX | {Focus} | {Time} |
| {TICKET}-3 | ~XXX | X | XXX | {Focus} | {Time} |
| **Total** | **~XXX** | **X** | **XXX** | **Complete** | **{Total}** |

**Timeline**: {X} weeks ({duration} per branch)

**Risk Level**: {Low/Medium/High} ({rationale})

**Performance Impact**: {Expected improvement or impact}
```

## Output Format

Your output must include:

1. **Story source resolution** (from Step 1): ticket key, browse URL, path to `{TICKET}-story.md`, file vs Jira (acli/MCP); Jira comments retrieved/summarized (or noted as skipped when using local-only file)
2. **Story Analysis** (from Step 2)
3. **Architecture Design** (from Step 2b: component diagram + key implementation details)
4. **Dependencies / Open Questions / Performance Notes** (from Step 2c; open questions may be conditional)
5. **LOC Estimate** (from Step 3)
6. **Feature Flag Design** (from Step 4, if applicable)
7. **Branch Breakdown** (from Step 5-6)
8. **Testing Strategy** (from Step 7)
9. **Merge Strategy** (from Step 8)
10. **Summary Table** (from Step 9)

**Write to files:**
- `bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-story.md` — When missing or when refreshing from Jira (Step 1); snapshot of Jira description and acceptance criteria; include **## Jira comments (summary)** when comments were fetched
- `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md` — **Single canonical plan file** (see **Canonical structure** below). Do **not** create `branch-strategy.md` for new work.
- `wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md` — **Required.** Concise Claude-facing plan stub written/updated on every `/atg:story-plan` run (create if missing; overwrite if stale). Points at the canonical `bin/stories/.../implementation-plan.md`. Path is `.claude/plans` under the service (not monorepo-root `.cursor/plans/`, and not `claude/plans`).

**Required `.claude/plans` stub** (keep short — summary, not a second full plan):

```markdown
# {TICKET}: {short title}

Full plan: `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md`

## Summary
- [1–6 bullets: what changes / what is out of scope]

## Branch
`fc/{TICKET}-{slug}` (or list branches if multi-branch)

## Decisions
- [Locked brief/story-plan decisions]

## Files
- [Planned production/test/changeset paths]

## Status
Planned. Ready for `/atg:story-impl {TICKET}`.
```

**Canonical structure** (write `implementation-plan.md` using these headings so `/atg:story-impl` can find branch slices):

1. `# {TICKET}: {short title} — Implementation plan`
2. `## Pre-Analysis` — only when present (from `/atg:brief`); otherwise omit
3. `## Preamble` — ticket URL, story source (file vs Jira, acli/MCP), Jira comment summary
4. `## Story analysis` — requirements, current state, gaps
5. `## Architecture design` — required; include `### Component diagram` and `### Key implementation details`
6. `## Dependencies` — include external and internal dependencies
7. `## Open questions` — conditional: include when no `## Pre-Analysis` exists, or when new unresolved questions arise during story-plan; if brief already has unresolved questions, reference carry-forward instead of duplicating
8. `## Performance considerations` — required when performance-sensitive; otherwise one-line not-applicable note
9. `## As-built` — **add this section after all branches are merged and shipped**; describes the final state of every changed layer (DB, entity, API response, repository, handler, etc.) so that `/atg:testing-doc` and future readers have an accurate post-implementation picture. Leave a placeholder comment `<!-- TODO: fill in after implementation -->` while work is in-progress so the section is easy to find and complete.
10. `## Lines of code estimate`
11. `## Feature flag` — omit section entirely if not applicable
12. `## Branch strategy` — **required when multi-branch**; for each slice use: `### Branch N: \`fc/{TICKET}-{slug}\` (~XXX LOC)` with goal, depends-on, files table, changes, testing strategy, acceptance criteria, PR description template (Steps 5–6 content lives here, not in a second file)
13. `## Testing strategy` — cross-branch or per-branch as needed
14. `## Merge strategy` — order, rollback
15. `## Summary` — table (timeline, risk, performance)
16. `## Next ATG command` — **required, always last section** of the file (after `## Summary`). If `/atg:brief` already appended this section, **replace** it with the story-plan handoff below so the doc does not show two different “next” steps.

**`## Next ATG command` template (story-plan):** use the real ticket key:

```markdown
---

## Next ATG command

`/atg:story-impl {TICKET}` — build the work queue from this plan and implement the current branch.

Then `/atg:verify` before ship; add a changeset (or plan **`skip-changelog`** on the PR) when `wavebid-a2o-service/` or `wavebid-a2o-ui/` paths change.
```

**Chat parity:** repeat the same **Next ATG command** block at the end of the assistant message.

**Legacy:** Older story folders may still contain `branch-strategy.md` beside `implementation-plan.md`. Prefer one merged `implementation-plan.md`; delete `branch-strategy.md` when cleaning up. New `/atg:story-plan` runs must not add `branch-strategy.md`.

**File Naming:**
- Use ticket number if provided (e.g., `WBPR-3215`)
- Use descriptive name if no ticket (e.g., `user-auth-feature`)

## Validation Checklist

Before delivering the plan:

- [ ] Story input resolved: existing `{TICKET}-story.md` used, or Jira fetched (acli/MCP) and file created/updated (unless both unavailable and user provided pasted text)
- [ ] When Jira was fetched: issue **comments** retrieved and reviewed; material takeaways in preamble and in `{TICKET}-story.md` comment summary (or explicit “none substantive”)
- [ ] Total LOC estimated realistically
- [ ] `## Architecture design` present with both `### Component diagram` and `### Key implementation details`
- [ ] Key implementation details include concrete method/query signatures or focused code snippets (not only prose)
- [ ] `## Dependencies` section present (external + internal)
- [ ] `## Open questions` handled correctly: present when needed, or intentionally omitted when `## Pre-Analysis` already resolves all questions
- [ ] `## Performance considerations` section present (or explicit not-applicable note)
- [ ] Branch count follows splitting rule (1 if ≤500 LOC, ~400–500 as single-branch baseline; 2 if 501–999 LOC; if ≥1000: merge remainder **<100** into fewer branches; else ceil(total/500); per-branch target ≤500 LOC, not 350)
- [ ] Each branch has clear focus and deliverable
- [ ] Dependencies between branches documented
- [ ] Testing strategy defined per branch
- [ ] Feature flag included if needed
- [ ] Cookie-based control documented with `FF_` prefix
- [ ] PR templates provided for each branch
- [ ] Merge order clearly specified
- [ ] Rollback strategy defined
- [ ] Summary table complete
- [ ] Single `implementation-plan.md` produced with `## Branch strategy` (and `### Branch N:`) when multi-branch; no new `branch-strategy.md`
- [ ] `wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md` written/updated (**Required** stub; links to canonical `implementation-plan.md`)
- [ ] `## As-built` section present in `implementation-plan.md` (filled after implementation, or placeholder comment if still in-progress)
- [ ] `## Next ATG command` is the **final** section of `implementation-plan.md` (replaces any brief-only footer) and matches the chat handoff

## Example Scenarios

### Scenario 1: Small Feature (≤500 LOC, ~400–500 baseline)

**Story**: "Add a single validation rule to lot update API"

**Total Estimate**: 400 LOC
- Production: 120 LOC
- Tests: 260 LOC
- Docs: 20 LOC

**Branch Strategy**: **1 branch** (≤500 LOC; fits single-branch **~400–500** sizing)
- Single branch: validator + service wiring + unit/integration tests + docs

**Feature Flag**: Usually not needed unless product asks for gradual rollout

---

### Scenario 2: Simple Feature (501–999 LOC)

**Story**: "Add pagination to auction list endpoint"

**Total Estimate**: 600 LOC
- Production: 150 LOC
- Tests: 400 LOC
- Docs: 50 LOC

**Branch Strategy**: 2 branches (501 ≤ 600 < 1000)
- Branch 1: Repository pagination (~300 LOC; under **500** ceiling)
- Branch 2: Controller + integration tests (~300 LOC; under **500** ceiling)

**Feature Flag**: Not needed (straightforward enhancement)

---

### Scenario 3: Complex Feature (>1000 LOC)

**Story**: "Implement lot end time propagation optimization (Case D)"

**Total Estimate**: 1,060 LOC
- Production: 400 LOC
- Tests: 590 LOC
- Docs: 70 LOC

**Branch Strategy**: 2 branches (1060 ≥ 1000; remainder 60 **<100** → merge tail, **not** a third micro-branch)
- Branch 1: Feature flag + partial propagation (~530 LOC; slightly over 500 to absorb tail)
- Branch 2: Event system + bulk + integration tests + docs (~530 LOC)

**Feature Flag**: Yes - `lot_creation_stagger_propagation`

---

### Scenario 4: Very Large Feature (>2000 LOC)

**Story**: "Implement complete bidding system with live updates"

**Total Estimate**: 2,400 LOC
- Production: 1,000 LOC
- Tests: 1,200 LOC
- Docs: 200 LOC

**Branch Strategy**: 5 branches (ceil(2400/500) = 5)
- Branch 1: Feature flag infrastructure (~480 LOC; ≤500)
- Branch 2: Data model + repositories (~480 LOC; ≤500)
- Branch 3: Core bidding service + unit tests (~480 LOC; ≤500)
- Branch 4: REST API + WebSocket (~480 LOC; ≤500)
- Branch 5: Integration tests + optimizations (~480 LOC; ≤500)

**Feature Flag**: Yes - `live_bidding_system`

## Special Instructions

### When Story is Ambiguous

If requirements are unclear:

```markdown
## ⚠️ Clarification Needed

Before creating implementation plan, need answers to:

1. [Specific question about requirements]
2. [Technical decision point]
3. [Scope boundary question]

**Suggested approach**: [Your recommendation]
```

### When Existing Code is Incomplete

If you find gaps in current implementation:

```markdown
## 🔍 Critical Findings

The story assumes X exists, but investigation shows:

- **Missing**: [What's not implemented]
- **Impact**: [How this affects the story]
- **Recommendation**: [Adjust scope or create prerequisite stories]
```

### When Performance is Critical

Include benchmark requirements:

```markdown
## Performance Requirements

### Baseline (Current)
- [Metric]: [Current value]

### Target (After Implementation)
- [Metric]: [Target value]
- [Improvement]: [Percentage]

### Measurement Strategy
```bash
# Benchmark commands
[How to measure performance]
```
```

## Command Usage Examples

```bash
# Basic usage with ticket number
/atg:story-plan WBPR-3215

# With story description
/atg:story-plan "Implement lot end time propagation optimization for mid-catalog insertions"

# With full story context
/atg:story-plan "
Story: WBPR-3215
Title: Optimize lot end time propagation (Case D)
Description: When a lot is created in the middle of the catalog, propagate end times only from the new lot onwards, not all lots.
Acceptance Criteria:
- Lots before insertion point unchanged
- Lots from insertion point onwards recalculated
- Performance improves for large catalogs (10k+ lots)
"
```

## Integration with Other Commands

This command works with:

- **/atg:feature-flag**: Automatically integrates feature flag design
- **/atg:story-impl**: Run after planning to align the current branch and produce a work queue from this plan
- **/atg:verify**: Use to verify each branch before merging
- **/gsd/changeset-wavebid-a2o** or **/atg:changeset**: Add a `.changeset/*.md` before shipping when service or UI paths change (or use **skip-changelog** on the PR)

## Notes

- **Be skeptical**: Question if features already exist before planning. Don't assume new code is needed.
- **Be realistic**: Don't underestimate LOC, especially for tests
- **Be modular**: Each branch should be independently testable
- **Be safe**: Feature flags for any user-facing changes
- **Be thorough**: Include all testing, docs, and cleanup in estimates
- **Be curious**: use the AskUserQuestion tool to clarify any uncertainties before finalizing the plan.

Look for opportunities to improve code quality or performance during implementation

### Important
- Ask questions everytime you need, do make asumptions on unclear/unverify stuff.

## Next Steps

1. If new feature with user-facing behavior: `/atg:feature-flag {description}`
2. Start implementation on Branch 1 (see `## Branch strategy` in `bin/stories/{year}/{month}/{TICKET}-{slug}/implementation-plan.md`) — use `/atg:story-impl {TICKET}` to build the work queue for the current branch
3. When implementation is done for a branch: `/atg:verify`
4. Before opening a PR that touches `wavebid-a2o-service/` or `wavebid-a2o-ui/`: add a changeset (`/gsd/changeset-wavebid-a2o` or `/atg:changeset`) or plan the **`skip-changelog`** label on the PR
5. After verify passes: `/atg:ship {TICKET} --branch {N}`
6. After all branches merged: `/atg:retro {TICKET}`