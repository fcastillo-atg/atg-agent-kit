---
name: atg-story-context
description: Use when a WBPR ticket ID appears in conversation, the current branch matches fc/WBPR-*, or the user asks for story status, implementation guidance, or PR readiness.
---

# ATG Story Context

This skill resolves story artifacts up front and summarizes the current branch slice before implementation, review, or shipping discussions.

## Use when

- A ticket like `WBPR-XXXX` appears in conversation
- Current branch matches `fc/WBPR-*`
- User asks status, implementation guidance, or PR readiness for a story

## Resolve context

1. Resolve ticket ID from:
   - Explicit user text (preferred)
   - Current branch name
2. Locate story directory under:
   - `wavebid-a2o-service/bin/stories/{year}/{month}/{TICKET}-{slug}/`
3. Load and summarize, when present:
   - `{TICKET}-story.md` (ACs / story text)
   - `implementation-plan.md` (technical plan, including `## Branch strategy` for branch slices and merge order)
   - `testing/TESTING-GUIDE.md` (manual test docs readiness)

## Behavior

- If all artifacts exist: provide a compact context brief (ACs, active branch slice, expected next step)
- If artifacts are missing: suggest the minimal next command:
  - `/atg:brief {TICKET}` for high-ambiguity stories
  - `/atg:story-plan {TICKET}` to generate missing artifacts

## Guardrails

- Do not regenerate existing artifacts unless user asks
- Prefer read-only context loading unless user requests execution
- Keep summary concise and branch-specific
