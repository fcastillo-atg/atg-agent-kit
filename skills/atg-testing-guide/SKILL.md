---
name: atg-testing-guide
description: Use when generating, executing, or republishing a TESTING-GUIDE.md — /atg:testing-doc, /atg:test-run, and /atg:qa-comment all depend on it. Defines scenarios versus steps, the variable conventions each consumer expects, and holds the canonical guide template in template.md.
---

# ATG testing guide

`testing-doc` writes `testing/TESTING-GUIDE.md`, `test-run` executes it, `qa-comment` republishes
it to Jira. All three share the vocabulary and conventions below. The full section-by-section
template lives in the co-located `template.md`; read it before writing a guide.

## Scenarios versus steps

| Term | Meaning |
|---|---|
| **Scenario** | One distinct test case that verifies one behaviour or acceptance criterion. Own purpose, own expected outcome |
| **Step** | A numbered action inside a scenario or inside shared setup: one request, one poll, one check |
| **Shared setup** | Steps most scenarios need (authenticate, resolve house, create parent). Documented once with full curl, referenced by number from scenarios |

Authentication, picking IDs, and baseline GETs are setup, never scenarios, unless the story is
about that behaviour. Derive scenario count from acceptance criteria, not from HTTP verbs:
merge candidates that differ only by trivial data, split only when setup or outcome differs
materially. Happy path only. Extra ideas go under `## Edge cases (not fully scripted)` as
bullets, because QA owns deep edge-case testing.

## Source of truth for what shipped

Read `## As-built` first, then `## Branch strategy → Branch N: Changes`, then the actual source
files. Never `## Current state`. Rules for the two As-built forms are in atg-story-artifacts.
When a story drops a DB column but keeps a same-named JSON field, describe the JSON property QA
sees and say explicitly that it is derived.

## Variable conventions per consumer

| Consumer | Form | Why |
|---|---|---|
| `TESTING-GUIDE.md` (humans, `scenarios/*.sh`) | `export BASE_URL=... TOKEN=... HOUSE_ID=...` once, then `$VAR` in every snippet. Token masked as `••••••` | Runs in a shell |
| `test-run` | Reads `Save: {path} as {{name}}` lines after a step and substitutes `{{name}}` later. Uses `python3` for JSON extraction, temp files for bodies and responses | Mechanical execution |
| `QA-COMMENT.md` (Jira) | Postman `{{baseURL}}`, `{{token}}`, `{{houseId}}` inside quoted strings. No `export`, no `$VAR`, no pipes, no `jq` | QA pastes into Postman |

Every guide step that produces a value a later step needs must carry a `Save:` line, so test-run
can chain it and qa-comment can turn it into a "copy the `id` into `{{newItemId}}`" instruction.

## Expected results

Always the complete response body as JSON, then one ✅ line naming the key assertion. Never
truncate to "key fields".

## Output locations

Everything lands in the story's `testing/` directory (see atg-story-artifacts). `testing-doc`
writes `TESTING-GUIDE.md` and optionally `scenarios/scenario-{N}-{slug}.sh`, one per scenario,
numbered to match the guide. `test-run` writes `TESTING-PROGRESS.md`. `qa-comment` writes
`QA-COMMENT.md` even under `--dry-run`. Older folders may hold `README.md` plus
`SIMPLIFIED-TESTING-GUIDE.md`; merge into one `TESTING-GUIDE.md` when cleaning up.
