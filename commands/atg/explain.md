---
description: Plain-language brief of what a ticket/branch changes — verdict, before/after examples, behavior matrix, merge confidence
---

# Explain: Plain-Language Change Brief

**Purpose:** Answer “what am I about to merge?” in plain language — ticket intent, what changed, concrete before/after examples, and what to watch for. Use when you do not want to merge (or review) something you do not understand.

**Not this command:** Not a code review (`/atg:pattern-check`), not a lifecycle dashboard (`/atg:story-view`), not a branch/CI status table (`/atg:status`).

**Read-only:** Never commits, never posts to Jira, never runs Gradle, never creates or updates PRs. Chat output only — do not write story artifacts unless the user explicitly asks.

**Language:** Match the user’s language (e.g. Spanish → Spanish brief).

## Usage

```bash
/atg:explain                         # ticket from current branch; diff = origin/main...HEAD
/atg:explain {TICKET}                # e.g. WBPR-4595
/atg:explain {TICKET} --pr {N}       # explain that PR’s diff instead of local HEAD
```

## Arguments

- `{TICKET}` — optional Jira key; if omitted, parse from `git branch --show-current` (`WBPR-####`, `fc/WBPR-####`, etc.)
- `--pr N` — optional; use `gh pr diff {N}` / `gh pr view {N}` as the change source instead of `origin/main...HEAD`

## Execution Steps

### Step 1: Resolve ticket and change source

1. Resolve `{TICKET}` from the argument or the current branch name. If neither yields a ticket, ask once for the key (or confirm “explain this branch with no ticket”).
2. Resolve the diff:
   - **With `--pr N`:**
     ```bash
     gh pr view {N} --json number,title,body,baseRefName,headRefName,url
     gh pr diff {N}
     gh pr view {N} --json commits --jq '.commits[].messageHeadline'
     ```
   - **Default:**
     ```bash
     git log --oneline origin/main..HEAD
     git diff --stat origin/main...HEAD
     git diff origin/main...HEAD
     ```
     If `origin/main` is missing, try `origin/master`, then report and stop for the diff portion.
3. Note whether a PR already exists for the current branch (`gh pr list --head $(git branch --show-current) --state open`).

### Step 2: Load context (best-effort — never block)

Search under `wavebid-a2o-service/bin/stories/` (and monorepo `bin/stories/` if present) for a directory matching `*{TICKET}*`. When found, read:

- `{TICKET}-story.md` — summary, ACs, out of scope, related tickets, Jira comment decisions
- `implementation-plan.md` — prefer `## As-built` and any recorded product decisions (e.g. Option A); use planning sections only as fallback

Also load, when present:

- Branch changeset: `.changeset/*.md` (exclude `README.md`) via `git diff origin/main...HEAD --name-only` or working tree
- Jira via the **jira-cli** skill: `acli jira workitem view {TICKET} --fields summary,description,comment` first, falling back to Atlassian MCP. Use comments when they override the description (product Option A/B, etc.).

If story files or Jira are missing, continue from the diff alone. Optionally suggest `/atg:brief {TICKET}` only as a follow-up — do not require it.

### Step 3: Classify the change surface

From the diff paths and symbols, pick the example format(s) that fit. Prefer **labels and payloads that appear in the code**, never invented product copy.

| Signal in diff | Example type to produce |
|----------------|-------------------------|
| `SupportedColumn`, CSV labels, `lotimport`, column accessors | CSV headers + 2–3 sample rows |
| `*Request` / `*Response`, controllers, OpenAPI | API JSON before/after |
| `wavebid-a2o-ui/` | UI flow / screen copy before/after |
| `db/changelog`, Liquibase | Schema / column before/after |
| Mixed | Lead with the user-facing surface; mention others briefly |

Skim commits + changeset text for the product “why,” then confirm against the diff so the brief matches shipped code.

### Step 4: Spot intentional behavior changes

Look for same-shape inputs with different outcomes (e.g. blank CSV cells that used to Clear and now no-op). Sources:

- Story / Jira comments (Option A vs B)
- Plan decisions / `## As-built`
- Spec renames or assertion flips in tests

Call these out in their own subsection — do not bury them in the file list.

**Guardrail:** Do not invent product decisions. If A/B-style choices are unclear, write “unclear from ticket — ask product” instead of guessing.

### Step 5: Emit the brief (fixed shape)

Respond in the user’s language. Keep it skim-friendly (roughly the length of a strong PR walkthrough — not a full design doc). **Do not paste raw `git diff`.**

Use this structure every time:

```markdown
## Verdict
{One sentence: what this change does.}

## Why it exists
{Ticket ask + related tickets / gap this fills.}

## Business problem
{What a seller/admin/user can do now that they could not before.}

## What changed (tech, light)
| Surface | Change |
|---------|--------|
| … | … |

## What it does NOT do
- {Out of scope / unchanged behavior}

## Before → After
{Concrete artifact examples — CSV / JSON / UI / schema — from real symbols in the diff.}

## Behavior matrix
| Input | Result |
|-------|--------|
| … | … |

## Merge confidence
- Safe if: …
- Watch out for: …
- Intentional behavior change: … (or “none”)
```

**Before → After rules:**

- Show the **old** shape first (columns/fields that existed), then the **new** shape with additions highlighted in prose.
- Include 2–3 concrete rows/payloads covering: happy path, omit-new-field (backward compatible), and one edge (blank / explicit false / active-only).
- If there is **no diff vs main** (or empty PR diff): say so clearly and fall back to a story/Jira-only explanation of *intended* change; mark examples as “planned, not yet on this branch.”

**Behavior matrix:** blank / omitted / explicit values → what happens in DB or API. Skip the table only when the change has no sparse/omission semantics.

### Step 6: Next Steps footer

| Situation | Suggest |
|-----------|---------|
| No PR yet, code on branch | `/atg:story-gap {TICKET}` then `/atg:ship {TICKET}` when ready |
| PR open | `/atg:status {TICKET}` or review the PR; `/atg:review-feedback {N}` if comments exist |
| Story artifacts missing | Optional `/atg:brief {TICKET}` |
| User only wanted understanding | Stop — no forced next command |

## Example Output (shape)

```
## Verdict
CSV lot import can now set per-fee `active` (on/off) on a lot, without clearing custom amounts.

## Why it exists
WBPR-4595 extends WBPR-4367 (CSV amount/inclusive) after WBPR-4570 added `active` on the single-lot PUT.

## Business problem
Sellers can bulk turn a fee off for specific lots and re-import prices without accidentally turning those fees back on.

## What changed (tech, light)
| Surface | Change |
|---------|--------|
| CSV columns | `Buyer's premium active`, `Sales tax active`, `Shipping active` |
| Import pipeline | Processor → applier → writer threads `active` + real auction baseline |

## What it does NOT do
- No UI changes
- No Liquibase (column already from WBPR-4570)
- Legacy SLB tax columns unchanged

## Before → After
Before: amount + inclusive columns only.
After: same columns plus `* active`. CSV without the new columns behaves as today.

## Behavior matrix
| amount/inclusive | active | Result |
|------------------|--------|--------|
| both blank | blank/unmapped | no-op (do not clear override) |
| any set | blank | set price fields; leave active unchanged |
| blank | explicit false | turn fee off; price falls back to auction |

## Merge confidence
- Safe if: WBPR-4570 already on the target branch
- Watch out for: intentional Clear-on-blank → no-op change
- Intentional behavior change: yes — blank price cells no longer clear overrides
```

## Error Handling

| Situation | Action |
|-----------|--------|
| No ticket on branch and none passed | Ask once; or explain branch-only with a note |
| `origin/main` missing | Try `origin/master`; else explain story-only and say diff unavailable |
| `--pr N` not found / no access | Report `gh` error; fall back to local `origin/main...HEAD` if possible |
| Empty diff | Story/Jira-only brief; mark examples as planned |
| No story dir + no Jira | Explain from diff + commits + changeset only |
| Product Option A/B unclear | State “unclear — ask product”; do not pick a side |

## Guardrails

- Do not dump raw `git diff` into the reply.
- Do not invent product decisions or CSV/API labels that are not in the code or ticket.
- Do not run `/atg:verify`, `/atg:ship`, or post to Jira from this command.
- Prefer `## As-built` over planning-time “Current state” when both exist.
- Keep the file list out of the main brief; surfaces/tables only.

## Next Steps

- Need lifecycle/CI view: `/atg:status {TICKET}`
- Need AC coverage before merge: `/atg:story-gap {TICKET}`
- Ready to open PR: `/atg:ship {TICKET}`
- Missing story context: `/atg:brief {TICKET}` (optional)
