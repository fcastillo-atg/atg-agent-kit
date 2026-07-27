---
name: atg-pr-self-review
description: Use when ready to ship a branch, user says "prepare PR" or "ready to ship", or after /atg:verify succeeds and before push or PR creation.
---

# ATG PR Self Review

This skill performs a lightweight final check between implementation and PR creation.

## Use when

- User says "ready to ship" or "prepare PR"
- Right before `/atg:ship`
- After `/atg:verify` succeeded and before push/PR creation

## Quick review checklist

1. Git hygiene
   - `git status --short` is clean or intentionally staged
   - Diff scope is expected for the active branch
2. Branch strategy alignment
   - Changed files roughly match current branch slice in `implementation-plan.md` (`## Branch strategy` / `### Branch N:`)
3. Obvious leftovers
   - Scan for `TODO`, `FIXME`, `println`, `System.out`
4. Changeset gate
   - If diff touches `wavebid-a2o-service/` or `wavebid-a2o-ui`, ensure `.changeset/*.md` exists or user confirms `skip-changelog`
5. PR readiness pointers
   - If concerns found, list exact blockers before `/atg:ship`

## Output

Provide:
- "Ready to ship" or "Blocked"
- Numbered blocker list (if blocked)
- Next command recommendation
  - `/gsd/changeset-wavebid-a2o` or `/atg:changeset` for missing changeset
  - `/atg:ship {TICKET} --branch {N}` when clear

## Guardrails

- This is a fast sanity pass, not a replacement for `/atg:verify`
- Do not hide blockers; fail fast with explicit actionable items
