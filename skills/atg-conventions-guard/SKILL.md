---
name: atg-conventions-guard
description: Use when editing .kt or .groovy files in wavebid-a2o-service, after backend edits, or reviewing a service PR diff before /atg:verify.
---

# ATG Conventions Guard

Use this skill as a fast, pre-verify guardrail for common service-level style and correctness conventions. This skill is not a replacement for `/atg:verify`; it is a quick pass before Gradle gates.

## Use when

- Working in `wavebid-a2o-service` Kotlin or Groovy files
- You just finished backend edits and want a fast quality pass
- You are reviewing a service PR diff and want common convention violations highlighted early

## Checks to run (quick, non-Gradle first)

1. Kotlin style patterns:
   - Prefer expression body syntax for one-line return functions
   - Use explicit `OrThrow` / `OrNull` naming for finder/lookup behavior
   - Avoid wildcard imports
   - Prefer `mu.KotlinLogging` for logging in service code
2. Spring/JPA patterns:
   - Do not add `@Param` unless there is a specific, documented need
   - Keep controller/service null handling patterns consistent with project conventions
   - REST controller methods returning a collection or page must wrap it in the project's
     `OneIndexedPage` pattern (see e.g. `getChoices`), never a bare `ResponseEntity<Collection<...>>`
     or `List<...>`. A repo Konsist guardrail test ("rest functions do not return a ResponseEntity
     containing a Collection or Page") blocks the build on this — catch it here, before the gate does.
3. Groovy/Spock patterns:
   - Single quotes unless interpolation is required
   - Prefer concrete types over `def`
   - Keep one blank line before final `}` in class files
   - Use map spacing style `[key : value]`
4. Feature-flag file patterns:
   - Interface + noop + enabled + proxy factory in one file
   - Include `@KoverIgnore` on proxy factory when applicable
5. File hygiene:
   - Ensure files end with a newline

## Escalation

- If violations are substantial or uncertain, advise running `/atg:verify` immediately
- If cross-cutting concerns are detected (migration, events, transactional boundaries), suggest `atg-cross-cutting-spotter`

## Output format

Provide:
- Quick list of violations grouped by file
- Suggested fix per violation
- A final recommendation: "safe to run `/atg:verify`" or "fix these first"
