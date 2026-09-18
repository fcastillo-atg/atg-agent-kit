---
name: atg-lifecycle
description: Use when any /atg:* command finishes and needs to name the next step, when the user asks what to run next for a story, or when deciding whether a step is automatic, manual, blocking, or advisory. The one place the /atg:* command graph is defined.
---

# ATG command lifecycle

One story moves through these commands. Each command's own file ends with a single "Next" line
that names its successor from this table. Do not restate the whole chain elsewhere.

## Order

| Stage | Command | Gate behaviour |
|---|---|---|
| Groom | `scout` | Read-only. Verdict: pointable, pointable after edits, needs a decision, blocked |
| Plan | `brief` (optional) | Writes `## Pre-Analysis`. Use for vague ACs, shared infra, >8 points or >500 LOC |
| Plan | `story-plan` | Writes the plan. Skips its own analysis when Pre-Analysis exists |
| Implement | `story-impl` | Implements one branch from `### Branch N:` |
| Implement | `feature-flag` | Only when the plan calls for one. Always Branch 1 |
| Quality gate | `verify` | Blocks. Runs the profile's quality-gate table in order, auto-fix, max 3 cycles per gate |
| Quality gate | `pattern-check` | Advisory. Never blocks |
| Quality gate | `changeset` | Conditional. Required when the profile's `changeset` value is not `none` and the diff touches its declared paths. No-ops otherwise |
| Pre-ship | `story-gap` | Blocks on any ❌ Missing AC |
| Pre-ship | `testing-doc` | Last branch only. Writes `testing/TESTING-GUIDE.md` |
| Pre-ship (optional) | `test-run` | Executes the guide locally. Catches what unit tests miss |
| Ship | `ship` | Manual. Never chained. Creates the PR, transitions Jira |
| Review | `review-feedback` | Classify → confirm → fix → verify → confirm → reply → confirm → push |
| Review | `pr-comment` | Post one inline finding on someone's PR |
| Post-merge | `qa-comment` | Manual. Draft → approve → post to Jira |
| Wrap-up | `retro` | Run right after qa-comment. Presents patterns, writes nothing unasked |

Cross-cutting, any time: `status` (text table), `story-view` (published dashboard), `explain`
(plain-language "what am I merging").

## Successor table

| After | Next |
|---|---|
| `scout` pointable | point it; `brief` only if large or risky |
| `brief` | `story-plan {TICKET}` |
| `story-plan` | `story-impl {TICKET}` (`feature-flag` first if the plan says Branch 1 needs one) |
| `feature-flag` | `story-impl` or `verify` |
| `story-impl` | `verify` |
| `verify` | `pattern-check {TICKET} [--branch N]` |
| `pattern-check` | `story-gap {TICKET} [--branch N]` |
| `story-gap` | last branch: fill `## As-built`, `testing-doc {TICKET}`; else `ship {TICKET} --branch N` |
| `testing-doc` | `test-run {TICKET}` (optional), then `ship {TICKET} [--branch N]` |
| `test-run` | fix bugs and `--retest-only`; else `ship` or `qa-comment` |
| `ship` | `review-feedback {PR}` as comments arrive; merged → next branch or `qa-comment` |
| `review-feedback` | `verify` if code changed; re-request review |
| `qa-comment` | `retro {TICKET}` immediately, do not wait for QA sign-off |
| `retro` | next story: `scout` or `brief` |

## `story-auto-run`

Runs `brief --auto → story-plan → feature-flag → story-impl → verify → pattern-check → changeset
→ story-gap → As-built → testing-doc` for one branch, unattended, stopping only at a hard
blocker (verify does not converge, or story-gap finds a missing AC). It never runs `ship` or
`qa-comment`. Resume after a manual fix with `--from {step}`; re-running without it restarts
from the top and may re-apply changes.

## Manual by design

`ship`, `qa-comment`, and `pr-comment` are outward-facing and stay manual. `review-feedback`
stops for confirmation before fixes, before replies, and before push unless flags say otherwise.
`retro` writes only what the user picks.
