---
description: Generate testing/TESTING-GUIDE.md from the story and plan, optionally one curl script per scenario with --with-scenarios
---

# Testing doc

Generate the curl-based `TESTING-GUIDE.md` for a story from its acceptance criteria and what
actually shipped. Read the **atg-testing-guide** skill (and its `template.md`) before writing;
resolve all paths per **atg-story-artifacts**.

## Usage

```bash
/atg:testing-doc {TICKET}                         # TESTING-GUIDE.md only
/atg:testing-doc {TICKET} --with-scenarios        # plus testing/scenarios/*.sh
/atg:testing-doc --story {path} --plan {path}     # explicit sources
```

## Steps

1. **Locate sources.** Resolve the story directory per atg-story-artifacts. Read
   `{TICKET}-story.md` and `implementation-plan.md`, or the `--story` / `--plan` overrides.
   Stop if no story file is found and say which patterns were searched.

2. **Determine what shipped.** Follow the source priority in atg-testing-guide: `## As-built`
   first, then `## Branch strategy → Branch N: Changes`, then the source files named in the
   plan. Never describe behaviour from `## Current state`. If there is no As-built section,
   read the entity, mapper, repository, and controller files before writing anything.

3. **Derive scenarios from acceptance criteria.**
   - List the distinct behaviours the ACs require. Each is a candidate scenario.
   - Merge candidates that differ only by trivial data. Split only when setup or outcome
     differs materially.
   - Map endpoints to steps inside scenarios, not to scenarios of their own.
   - Put authentication, ID resolution, and baseline GETs in `## Shared setup steps`.
   - Happy path only. Park other ideas under `## Edge cases (not fully scripted)`.
   - Inheritance or propagation stories often yield inherit / override / mixed scenarios. Still
     tie each to an AC.

4. **Write `testing/TESTING-GUIDE.md`.** Fill `template.md` in section order. Give every
   value-producing step a `Save:` line, show complete response bodies, and use `export` shell
   variables with the token masked. Include the directory layout matching the flag used.

5. **Write `testing/scenarios/scenario-{N}-{slug}.sh`** only when `--with-scenarios` is
   passed. One file per scenario, numbered as in the guide:

   ```bash
   #!/usr/bin/env bash
   # Scenario {N}: {Name}
   # Purpose: {what this verifies}
   # Feature flag: {FF_name=true | N/A}

   export BASE_URL="https://..."
   export TOKEN="••••••"     # replace after authenticating
   export HOUSE_ID="..."

   # Step 1: {request}
   curl -si -X POST "$BASE_URL/api/v3/houses/$HOUSE_ID/..." \
     -H "Authorization: Bearer $TOKEN" \
     -H 'Content-Type: application/json' \
     -d '{ "field": "VALUE" }'

   # Expected response: {complete JSON}
   # Key assertion: {one line}
   # Validation: [ ] ...
   ```

6. **Report.**

   ```
   Testing documentation generated: bin/stories/{year}/{month}/{TICKET}-{slug}/testing/
     TESTING-GUIDE.md (~{N} lines, {M} scenarios, ~{X} min)
     scenarios/ ({M} scripts)            <- only with --with-scenarios
   Scenario scripts not generated (use --with-scenarios)   <- otherwise
   ```

## Failures

| Situation | Action |
|---|---|
| No story file | Stop; list the patterns searched and the `--story` override |
| No implementation plan | Generate from the story and source files; note missing technical detail |
| No endpoints identifiable | Generate generic scenarios and flag the curl snippets for review |

**Next:** `/atg:test-run {TICKET}` (optional), then `/atg:ship {TICKET} [--branch N]`.
