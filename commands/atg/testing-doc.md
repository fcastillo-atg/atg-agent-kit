---
description: Generate testing documentation (single TESTING-GUIDE.md, optionally scenario files with --with-scenarios)
---

# Generate Testing Documentation

You are a QA documentation specialist for Spring Boot projects. Generate comprehensive, curl-based testing documentation from story files and implementation plans following the WBPR-3465 pattern.

## Context

The user needs automated testing documentation that:
- Generates **one** file, `TESTING-GUIDE.md`, combining overview / quick reference, **shared setup steps**, and **detailed test scenarios** (same information as the old README + SIMPLIFIED split, in one file)
- **OPTIONALLY** generates individual `.sh` curl script files for each **test scenario** (via `--with-scenarios` flag)
- Provides validation checklists and expected results
- Uses consistent formatting with emojis and visual elements

### Scenarios vs steps (critical)

| Term | Meaning |
|------|---------|
| **Scenario** | A **distinct test case** that verifies a specific feature behavior or acceptance criterion. Each scenario has its own purpose, variation, and expected outcome. |
| **Steps** | The **execution procedure**: numbered actions to run. Steps can be **shared** (auth, create resource, seed data) or **scenario-specific** (the action under test + verification). |
| **Shared setup** | Steps that are the same for all or most scenarios — document **once** with full curl snippets; scenarios **reference** them by step number instead of repeating. |

**Do not** treat authentication, baseline GETs, or generic resource creation as scenarios unless the story is *about* that behavior. Those are **setup steps**.

**Happy path only** for generated scenarios. Do not invent extra scenarios to “cover every endpoint.” Mention additional edge cases in an **Edge cases (not fully scripted)** subsection without writing full scenario bodies for them — QA owns deep edge-case testing unless the story explicitly requires it.

## User Input

$ARGUMENTS

## Command Flags

### --with-scenarios
**Optional flag** to generate curl scenario files in addition to `TESTING-GUIDE.md`.

**Usage**:
```bash
# Default: TESTING-GUIDE.md only
$ARGUMENTS

# With scenarios: TESTING-GUIDE.md + scenarios/*.sh
$ARGUMENTS --with-scenarios
```

**Default**: `false` (scenarios NOT generated)

## Execution Steps

### Step 1: Locate and Read Source Files

**Auto-Detection Strategy**:
```bash
# Search for story files under bin/stories/{year}/{month}/{TICKET}-{slug}/
STORY_FILE=$(find bin/stories -type f \( \
  -name "*-story.md" -o \
  -name "story.md" \
\) | sort | head -1)

# Search for implementation plan in same directory
STORY_DIR=$(dirname "$STORY_FILE")
PLAN_FILE=$(find "$STORY_DIR" -type f \( \
  -name "*-implementation-plan.md" -o \
  -name "implementation-plan.md" \
\) | head -1)

# Extract STORY_ID from directory name (e.g. "WBPR-3465-prop-single-lot")
STORY_ID=$(basename "$STORY_DIR")
# Derive year/month from parent path for output: bin/stories/{year}/{month}/{STORY_ID}/
STORY_MONTH_DIR=$(dirname "$STORY_DIR")
```

**Manual Override**:
```bash
# Allow explicit paths via arguments
$ARGUMENTS --story path/to/story.md --plan path/to/plan.md
```

**Extract metadata**:
- STORY_ID from directory name (e.g., "WBPR-3465-prop-single-lot")
- Feature flag information
- API endpoints and operations

**Read files**:
1. Story file: Requirements, acceptance criteria, fields to test
2. Implementation plan: API endpoints, request payloads, inheritance logic
3. Existing testing docs (WBPR-3465) as reference pattern

**CRITICAL — Determine post-implementation state before writing anything**:

Implementation plans are written **before** coding begins. The `## Current state` section describes the codebase as it was at planning time — it is **not** the final implementation.

Prioritize sources in this order:

| Priority | Source | What it reflects |
|----------|--------|-----------------|
| 1 (highest) | `## As-built` section in the implementation plan | Final shipped state — pointer or deviation form; see reading rules below |
| 2 | `## Branch strategy → Branch N: Changes` in the plan | Planned change list — authoritative when As-built is pointer form |
| 3 | Actual source files (Kotlin/Groovy/SQL) in `src/` | Ground truth — read when no As-built section |
| 4 | `## Gap analysis` / `## Two-branch checklist` in the plan | Intended final state — useful signal |
| 5 (lowest) | `## Current state` in the implementation plan | **Pre-migration snapshot — do NOT use for guide content** |

**If the implementation plan has an `## As-built` section**, choose the reading path by its form:

- **Pointer form** — starts with `"Implemented as planned"` or contains `"No deviations"`: treat `## Branch strategy → Branch N: Changes` as the Priority 1 source. Read that section for the authoritative change list. Skip source files unless you need an exact URL or method signature.
- **Deviation form** — lists specific changes (new file, dropped field, renamed method, etc.): read it fully. Only documented deviations override the Branch strategy content; treat undocumented layers as implemented-as-planned.

**If there is NO `## As-built` section**: the story is either in-progress or the section was not written yet. In that case, read the key source files named in the plan (entity, mapper, repository, controller) to determine the actual current state before generating the guide. Do not invent or assume — read the files.

**API field vs DB column (migrations / expand–contract):** If a story **drops** a DB column but keeps a **response DTO field** with the same name (e.g. computed via MapStruct), manual-test docs must talk about the **JSON property** the client sees — and **explicitly** state it is derived / not stored. Do **not** imply the old column still exists. Tie language to the real persisted model (e.g. enum `status`) when explaining what changed.

**QA assertions:** Where the mapper exposes a boolean like `"uploaded"` on `AttachmentResponse`, scenario checklists should tell testers to assert that **JSON field** on GET/list — it is the observable contract. Include one **status → JSON** mapping table, then reference it; repeating **`"uploaded": true/false`** in scenarios is appropriate when that is what appears in HTTP.

### Step 2: Analyze Requirements

**From Story File**:
- Feature requirements (what fields to inherit/propagate)
- Operations (single lot create/update vs bulk)
- Acceptance criteria
- Success metrics

**From Implementation Plan**:
- API endpoints and request/response shapes (extract what the story actually uses — not limited to lots)
- Feature flags and cookies when applicable
- For **inheritance / propagation** stories: inheritance rules (null → inherit, custom → override) and fields to test
- Liquibase / migration notes when the story is DB-heavy

> ⚠️ **Do not** use the `## Current state` section to describe what the code does now. That section is a planning-time snapshot of the code **before** implementation. Use the `## As-built` section or actual source files instead (see Step 1).

**Identify test scenarios (acceptance-driven, not endpoint-driven)**:

1. Read **acceptance criteria** and **distinct behaviors** from the story and implementation plan — not raw HTTP method counts.
2. Map each AC (or tightly related ACs) to **one** test scenario when they verify the **same** behavior; split only when the setup or expected outcome **differs materially**.
3. Prefer **few, clear** happy-path scenarios over a large matrix. Do **not** default to “3 CREATE + 3 UPDATE” unless the story is explicitly about inheritance/override patterns on those operations.
4. **Inheritance / propagation stories**: scenarios often follow patterns like full inheritance, full override, mixed — still derive counts from ACs, not a fixed 6.
5. List **edge cases** the team might want to explore in QA in `## Edge cases (not fully scripted)` — bullets only, no full HTTP walkthrough unless the story requires it.

**What is NOT a scenario** (use **shared setup steps** or **steps inside a scenario** instead):

- Obtaining a token / authenticating
- Picking IDs, env URLs, or feature-flag cookies
- Baseline GET/list calls whose only purpose is to confirm the app is reachable (unless the story is specifically about list behavior)

### Step 3: Generate TESTING-GUIDE.md (single document)

**Output path**: `bin/stories/{year}/{month}/{STORY-ID}/testing/TESTING-GUIDE.md`

**Do not** create `README.md` or `SIMPLIFIED-TESTING-GUIDE.md` for new runs.

**Legacy:** Older story folders may still contain `README.md` and/or `SIMPLIFIED-TESTING-GUIDE.md`. Prefer a single `TESTING-GUIDE.md`; merge or delete legacy files when cleaning up.

**Canonical structure** — write one file in this order (internal anchors; no cross-file links). The doc has **three zones**: Quick reference, Shared setup, Scenarios.

1. Title: `# {STORY-ID}: Manual testing ({Feature Name})`
2. Optional: **Table of contents** — include links to `Overview`, `Quick reference`, `Shared setup steps`, `Detailed test scenarios`, `Edge cases`, `Master validation checklist`, `Summary table`, `Troubleshooting`, `Related code`
3. `## Overview` — what is being tested, **happy-path approach**, simplifications
4. `## Quick reference` — directory layout, For QA / For developers, **Prerequisites** (app, tools, IDs, feature flags, **auth curl snippet**), **Scenario index** (test cases only — no auth row), key features, optional high-level flow diagram, quick validation checklist, quick troubleshooting, field/matrix if applicable
5. `---` then `## Shared setup steps` — numbered steps **shared by most scenarios** (e.g. Step 1 Authenticate, Step 2 Resolve context / create parent resource). Full curl snippets here **once**. Scenarios below reference “after Shared setup Step N”.
6. `---` then `## Detailed test scenarios` — for **each** scenario: `### Scenario {N}: {Name}`, **Purpose**, optional **Prerequisites** (reference shared steps), **`### Steps`** (numbered sub-steps for *this* scenario: requests, polling, verification), **Expected results**, **Validation checklist**. If two scenarios share identical sub-steps, say “same as Scenario X Steps 1–2, then …” instead of duplicating huge blocks.
7. `## Edge cases (not fully scripted)` — short bullets only; no full scenarios unless required by the story
8. `## Master validation checklist` — pre-test, per-scenario, post-test
9. `## Summary table` — one row per **test scenario** (not per setup step)
10. `## Troubleshooting`
11. `## Test results template` — rows per scenario + optional auth/setup line
12. `## Related code`
13. Footer: status, last updated, estimated total time

**Do not** place a separate `## Step-by-step instructions` section that duplicates shared setup **and** repeats every scenario — that blurs scenarios vs steps. The old SIMPLIFIED guides put “Step-by-Step Instructions” **before** detailed scenarios when it was shared setup only; here that content lives in **`## Shared setup steps`**, and each scenario has its own **`### Steps`**.

**Directory layout** to show inside `## Quick reference`:

{If --with-scenarios:}
```
testing/
├── TESTING-GUIDE.md              # This file (overview + detailed steps)
└── scenarios/
    ├── scenario-1-{operation}-{type}.sh
    └── ...
```

{If not --with-scenarios:}
```
testing/
└── TESTING-GUIDE.md              # This file (overview + detailed steps)
```

**Template**: Read `/Users/fcastilloatg/ATG/wavebid-a2o/.cursor/commands/atg/testing-guide-template.md` for the full merged template and dynamic content injection list. Fill every `{placeholder}` with story-specific content and follow the section order defined there.

### Step 4: (Optional) Generate scenarios/*.sh Files

**Conditional**: Only execute if `--with-scenarios` flag is present in $ARGUMENTS.

**Skip this step if**:
- User did not pass `--with-scenarios` flag
- This is the default behavior

**Proceed with this step if**:
- User explicitly passed `--with-scenarios` flag

**Output path**: `bin/stories/{year}/{month}/{STORY-ID}/testing/scenarios/`

**Naming convention**: `scenario-{number}-{operation}-{type}.sh`

**One `.sh` file per test scenario** (same numbering as `## Detailed test scenarios`), not per HTTP method. Name files `scenario-{N}-{short-slug}.sh` where `{N}` matches the scenario index and `{short-slug}` reflects the scenario purpose (e.g. `scenario-1-single-upload-lifecycle.sh`).

```bash
#!/usr/bin/env bash
# Scenario {N}: {Name}
# Purpose: {What this tests}
# Feature Flag: {ENABLED/DISABLED if applicable} ({flag_name}={value})

# Variables (update after shared setup)
export BASE_URL="https://..."
export TOKEN="••••••"   # replace after authenticating
export HOUSE_ID="..."   # and any other IDs needed

# Step 1: {First request}
curl -si -X POST "$BASE_URL/api/v3/houses/$HOUSE_ID/..." \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{ "field": "VALUE" }'

# Step 2: {Next request or verify}
# ...

# Expected result (complete response body):
# {paste full JSON response here}
#
# Key assertion: {one-line summary of what this step verifies}

# Validation checklist:
# [ ] ...
```

**Inheritance / propagation stories only**: If the plan explicitly defines CREATE/UPDATE inheritance matrices, you may use filenames like `scenario-1-create-full-inheritance.sh` — but the **count and names still come from ACs**, not a mandatory six files.

**Standard test data**: Extract from the implementation plan; keep values consistent across scenarios where they share the same resources.

### Step 5: Generate Output Confirmation

**When --with-scenarios NOT used**, report:

```
✅ Testing documentation generated!

Directory: bin/stories/{year}/{month}/{STORY-ID}/testing/
Files created:
  - TESTING-GUIDE.md (~{N} lines)

Note: Scenario curl files not generated (use --with-scenarios to include them)

Total test time: ~{X} minutes

Next steps:
1. Review generated documentation
2. Use the guide to manually test via curl
3. Customize test data as needed
```

**When --with-scenarios IS used**, report:

```
✅ Testing documentation generated!

Directory: bin/stories/{year}/{month}/{STORY-ID}/testing/
Files created:
  - TESTING-GUIDE.md (~{N} lines)
  - scenarios/ ({M} curl script files, one per test scenario)
    - scenario-1-{slug}.sh
    - scenario-2-{slug}.sh
    - ...

Total test scenarios: {M}
Estimated test time: ~{X} minutes

Next steps:
1. Review generated scenarios for completeness
2. Set the `export` variables at the top of each file (BASE_URL, TOKEN, HOUSE_ID, etc.)
3. Execute: `bash scenarios/scenario-1-{slug}.sh`
```

## Scenario detection algorithm

```
1. Read story acceptance criteria and implementation plan (## As-built, Gap analysis, endpoints).
2. List distinct *behaviors* or *outcomes* to verify (happy path). Each becomes a candidate scenario.
3. Merge candidates that differ only by trivial data — keep scenarios where setup or expected outcome differs materially.
4. Map endpoints to steps *inside* scenarios; do not create one scenario per HTTP route by default.
5. Document shared steps once under ## Shared setup steps; give each scenario a ### Steps subsection.
6. Add ## Edge cases (not fully scripted) for non-happy-path ideas worth a QA glance — bullets only.
7. If --with-scenarios: emit one scenario-{N}-{slug}.sh per test scenario (same N as the guide).
```

**Inheritance/propagation stories**: After step 2, if the plan defines null→inherit, custom override, and mixed behaviors as first-class ACs, generate scenarios for those patterns (often 3–6). Still tie each to an AC, not to “we have POST and PUT.”

## Error Handling

**If story file not found**:
```
❌ Story file not found in bin/stories/

Searched for patterns:
  - *-story.md
  - story.md

Please specify the story file path:
  /atg:testing-doc --story path/to/story.md
```

**If implementation plan not found**:
```
⚠️ Implementation plan not found in bin/stories/

Searched for patterns:
  - *-implementation-plan.md
  - implementation-plan.md

Generating documentation from story file only.
Some technical details may be missing.

To include implementation plan:
  /atg:testing-doc --story path/to/story.md --plan path/to/plan.md
```

**If no API endpoints identified**:
```
⚠️ Warning: No API endpoints found in story or implementation plan.

Generating documentation with generic scenarios.
Please review and customize the curl snippets with actual endpoints.
```

## Template Patterns

**Follow WBPR-3465 patterns exactly**:

1. **Emojis**: 📚 🎯 📂 🔑 🚀 📋 🔧 🐛 📊 🔗 ✨ 🔄 🎨
2. **Headers**: Markdown headers with emoji prefixes
3. **Tables**: Pipe-delimited with alignment
4. **Code blocks**: Triple backticks with language hints
5. **Horizontal rules**: `---` between major sections
6. **Checkboxes**: `- [ ]` for validation lists
7. **Status indicators**: ✅ ❌ ⚠️
8. **Time estimates**: ~5 min (CREATE), ~7 min (UPDATE)
9. **JSON paths**: `$.data[0].lot.lotAddress.city`
10. **Shell variables**: `$BASE_URL`, `$TOKEN`, `$HOUSE_ID`, etc. — defined once with `export`, reused in every snippet
11. **Comment style**: `#` for shell script comments

## Important Notes

- **Always use absolute paths** when writing files
- **Generate in story directory**: `bin/stories/{year}/{month}/{STORY-ID}/testing/` (under `wavebid-a2o-service/` when stories live there)
- **Single guide file**: `TESTING-GUIDE.md` only (no README + SIMPLIFIED split)
- **Scenarios vs steps**: Put shared curl snippets once in **Shared setup steps**; each scenario gets **Steps** for what differs — do not label auth/baseline GET as scenarios
- **Use "scenarios/" folder**: Not "request-payloads/" or "http-requests/"
- **Consistent formatting**: Match WBPR-3465 / historical SIMPLIFIED guides
- **Auto-detect but allow override**: Try finding files first, fall back to arguments
- **Feature flag aware**: Include cookie if feature flag mentioned
- **Standard test data**: Use consistent values across scenarios
- **Full curl requests**: Prefer complete examples with `export` block; bake the real URL and IDs in, mask the token as `••••••`

## BEGIN IMMEDIATELY

When this command is invoked:
1. Auto-detect story and implementation plan files (or parse `$ARGUMENTS`); apply **As-built / source** priority from Step 1.
2. Derive **test scenarios** from acceptance criteria and distinct behaviors (happy path); separate **shared setup steps** from scenario-specific **Steps**.
3. Generate **TESTING-GUIDE.md** with: Overview, Quick reference (scenario index = test cases only), **Shared setup steps**, **Detailed test scenarios** (each with `### Steps`), **Edge cases (not fully scripted)**, checklists, summary, troubleshooting, related code.
4. If `--with-scenarios`: generate `scenarios/scenario-{N}-{slug}.sh` — **one curl script per test scenario**, aligned with the guide’s scenario numbers.
5. Report completion with file list and next steps.

## Next Steps

1. Review generated docs in `bin/stories/{year}/{month}/{TICKET}-{slug}/testing/TESTING-GUIDE.md`
2. Run curl scripts in `testing/scenarios/` (if `--with-scenarios` was used) — set variables at the top, then `bash scenario-N-*.sh`
3. Run `/atg:verify` before shipping
