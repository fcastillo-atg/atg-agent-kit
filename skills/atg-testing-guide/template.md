# TESTING-GUIDE.md canonical template

Fill every `{placeholder}`. Keep the section order. Three zones: Quick reference, Shared setup,
Scenarios. Vocabulary and variable rules are in `SKILL.md`.

## Section order

1. `# {STORY-ID}: Manual testing ({Feature Name})`
2. Optional table of contents
3. `## Overview` — what is tested, happy-path approach, simplifications
4. `## Quick reference` — directory layout, For QA / For developers, Prerequisites (app, tools, IDs, flags, auth curl), Scenario index (test cases only), key features, quick checklist, quick troubleshooting, field matrix if applicable
5. `---` `## Shared setup steps` — numbered, full curl once, `Save:` lines
6. `---` `## Detailed test scenarios` — per scenario: Purpose, Prerequisites, `#### Steps`, Expected results, Validation checklist
7. `## Edge cases (not fully scripted)` — bullets only
8. `## Master validation checklist`
9. `## Summary table` — one row per scenario
10. `## Troubleshooting`
11. `## Test results template`
12. `## Related code`
13. Footer: status, last updated, estimated total time

## Template

```markdown
# {STORY-ID}: Manual testing ({Feature Name})

## Overview

Manual testing resources for **{STORY-ID}: {Feature Name}** — {brief description}.

**Approach**: Happy path only, {N} test scenarios. Feature flag: {enabled/disabled / N/A}.

**Simplifications**: {bullets}

---

## Quick reference

### Directory layout
```
testing/
└── TESTING-GUIDE.md
{└── scenarios/scenario-{N}-{slug}.sh   when --with-scenarios}
```

### For QA
1. Read Overview and Quick reference.
2. Run Shared setup steps once per environment.
3. Execute each scenario in order, following its Steps.

### For developers
- Implementation: `{path}`
- API: `{path}`

### Prerequisites
- {App URL, credentials, tools, IDs, flags}

```bash
export BASE_URL="{branch preview or local URL}"
export TOKEN="••••••"        # replace after Shared setup Step 1
export HOUSE_ID="{houseId}"  # and any other IDs needed
```

### Scenario index

| # | Scenario | Purpose | ~Time |
|---|----------|---------|-------|
| 1 | {Name} | {One line} | ~X min |

### Key features & what's tested
{table or bullets}

### Quick troubleshooting
| Issue | Solution |
|-------|----------|

### Field coverage matrix (if applicable)
{only for inheritance / override stories}

---

## Shared setup steps

### Step 1: Authenticate

```bash
curl -si -X POST "$BASE_URL/api/v3/auth" \
  -H 'Content-Type: application/json' \
  -d '{"username":"your-admin@example.com","password":"your-password"}'
```

Save: `$.token` as `{{token}}`

### Step 2: {Resolve context — pick house, auction, lot}
{curl + Save: lines}

---

## Detailed test scenarios

### Scenario 1: {Name}

#### Purpose
{Which behaviour or AC this verifies}

#### Prerequisites
- Shared setup through Step {N}

#### Steps
1. {Action}
2. {Verify}

```bash
{curl for this scenario}
```

Save: `$.id` as `{{createdId}}`

#### Expected results
```json
{complete response body}
```

✅ **Key assertion:** {one line}

#### Validation checklist
- [ ] ...

---

### Scenario 2: {Name}
{Same structure. Say "same as Scenario 1 Steps 1–2" instead of duplicating identical steps}

---

## Edge cases (not fully scripted)
- {Edge case}

## Master validation checklist
{pre-test, per scenario, post-test}

## Summary table
| Scenario | Focus | ~Time |
|----------|-------|-------|

## Troubleshooting
{expanded}

## Test results template
{scenarios as rows, optional Auth/setup line}

## Related code
- ...

---
**Status**: Ready for QA (happy path)
**Last updated**: {Date}
**Estimated total time**: ~{X} minutes
```
