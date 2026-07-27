# TESTING-GUIDE.md — Canonical Template

Fill every `{placeholder}`. Follow section order exactly. Three zones: Quick reference, Shared setup, Scenarios.

## Section order

1. `# {STORY-ID}: Manual testing ({Feature Name})`
2. Optional: **Table of contents** — links to Overview, Quick reference, Shared setup steps, Detailed test scenarios, Edge cases, Master validation checklist, Summary table, Troubleshooting, Related code
3. `## Overview` — what is being tested, happy-path approach, simplifications
4. `## Quick reference` — directory layout, For QA / For developers, **Prerequisites** (app, tools, IDs, feature flags, **auth curl snippet**), **Scenario index** (test cases only — no auth row), key features, optional high-level flow diagram, quick validation checklist, quick troubleshooting, field/matrix if applicable
5. `---` then `## Shared setup steps` — numbered steps shared by most scenarios (Step 1 Authenticate, Step 2 Resolve context). Full curl snippets here **once**. Scenarios reference "after Shared setup Step N".
6. `---` then `## Detailed test scenarios` — each: `### Scenario {N}: {Name}`, Purpose, optional Prerequisites, `### Steps`, Expected results, Validation checklist. If two scenarios share identical sub-steps, say "same as Scenario X Steps 1–2" instead of duplicating.
7. `## Edge cases (not fully scripted)` — short bullets only
8. `## Master validation checklist` — pre-test, per-scenario, post-test
9. `## Summary table` — one row per test scenario (not per setup step)
10. `## Troubleshooting`
11. `## Test results template` — rows per scenario + optional auth/setup line
12. `## Related code`
13. Footer: status, last updated, estimated total time

---

## Merged template (copy-paste and fill)

```markdown
# {STORY-ID}: Manual testing ({Feature Name})

## Table of contents (optional)
- [Overview](#overview)
- [Quick reference](#quick-reference)
- [Shared setup steps](#shared-setup-steps)
- [Detailed test scenarios](#detailed-test-scenarios)
- [Edge cases (not fully scripted)](#edge-cases-not-fully-scripted)
- [Master validation checklist](#master-validation-checklist)
- [Summary table](#summary-table)
- [Troubleshooting](#troubleshooting)

## Overview

Manual testing resources for **{STORY-ID}: {Feature Name}** — {brief description}.

**Approach**: Happy path only, {N} test scenarios. Feature flag: {enabled/disabled / N/A}.

**Simplifications**: {bullets}

---

## Quick reference

### Directory layout
{Show testing/ tree from Step 3}

### For QA
1. Read **Overview** and **Quick reference**.
2. Run **Shared setup steps** once (or per environment).
3. Execute each **Detailed test scenario** in order; follow the **Steps** inside each scenario.
{If --with-scenarios: 4. Optionally use `scenarios/scenario-{N}-*.sh` files.}

### For developers
- Implementation: `{path}`
- API: `{path}`

### Prerequisites
- App URL, credentials, tools, IDs, flags as needed
- Set these variables once before running any snippet:

```bash
export BASE_URL="{branch preview or local URL}"
export TOKEN="••••••"   # replace after Step 1
export HOUSE_ID="{houseId}"  # and any other IDs needed
```

- **Authenticate** (curl snippet below — prerequisite, not a numbered scenario)

```bash
curl -si -X POST "$BASE_URL/api/v3/auth" \
  -H 'Content-Type: application/json' \
  -d '{"username":"your-admin@example.com","password":"your-password"}'
```

### Scenario index

> **Test scenarios only** — not auth, not generic setup. See [Shared setup steps](#shared-setup-steps) for shared procedure.

| # | Scenario | Purpose | ~Time |
|---|----------|---------|-------|
| 1 | {Name} | {One line} | ~X min |
| 2 | {Name} | {One line} | ~X min |

### Key features & what's tested
{Table or bullets}

### Quick validation checklist
{Per-scenario one-liners}

### Quick troubleshooting
| Issue | Solution |
|-------|----------|

### Field coverage matrix (if applicable)
{Only when the story compares fields / inheritance / override}

---

## Shared setup steps

> Steps **shared** by multiple scenarios. Complete these first; each scenario assumes this context unless it says otherwise.

### Step 1: Authenticate
{Full curl snippet + what to extract: token, houseId, etc.}

### Step 2: {e.g. Resolve context — pick house, auction, lot}
{curl snippet or narrative}

### Step 3: {Optional further shared setup}
...

---

## Detailed test scenarios

### Scenario 1: {Name}

#### Purpose
{What distinct behavior this test case verifies — tie to AC if helpful}

#### Prerequisites
- Shared setup through Step {N} complete
- {Any extra data flags}

#### Steps

1. {Action — e.g. POST presign}
2. {Action — e.g. PUT file to S3}
3. {Verify — e.g. GET until condition}

```bash
{curl snippet as needed for this scenario}
```

#### Expected results
Show the **complete response body** as JSON. Include all fields returned by the API.

✅ **Key assertion:** {one-line summary of what this step verifies}

#### Validation checklist
- [ ] ...

---

### Scenario 2: {Name}
{Same structure — own Steps subsection; reference "same as Scenario 1 Steps 1–2" when identical}

---

## Edge cases (not fully scripted)

> Optional QA follow-ups — **not** full happy-path scenarios. Expand in test plans if needed.

- {Edge case 1}
- {Edge case 2}

---

## Master validation checklist
{Pre-test, per scenario, post-test}

## Summary table
| Scenario | Focus | ~Time |
|----------|-------|-------|
| 1 | ... | ... |

## Troubleshooting
{Expanded}

## Test results template
{Scenarios as rows; optional "Auth/setup" line}

## Related code
- ...

---
**Status**: Ready for QA (happy path)
**Last updated**: {Date}
**Estimated total time**: ~{X} minutes
```

## Dynamic content to inject

- Story ID, title, feature name, **acceptance-driven scenario list** (happy path), shared setup steps, per-scenario **Steps**, edge-case bullets, emojis, fields/matrices when relevant, flags, endpoints, curl examples, JSON paths, time estimates
