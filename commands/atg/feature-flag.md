---
description: Generate a single-file feature flag (interface + Noop + Enabled + ProxyFactory) and wire it into the service
---

# Feature flag

Create a production-ready feature flag in this service's pattern and inject it where the new
behaviour lives. The pattern itself is service-specific and lives with the profile, not here.

## Usage

```bash
/atg:feature-flag {description of the behaviour to gate}
```

Requirements: $ARGUMENTS

## Steps

1. **Check the mechanism exists.** Read `feature-flag` from **atg-repo-profile**. Value `none`:
   print "This service has no feature-flag mechanism. Gate the behaviour another way (config, a
   query parameter, or a separate deploy) or add a mechanism as its own story." and stop. Do not
   invent a flag pattern.

2. **Load the recipe.** The `feature-flag` value names the recipe file under the profile skill's
   `recipes/`. Read it and follow it exactly: naming, file layout, wiring, fixtures, the
   per-request toggle, and the removal procedure all live there.

3. **Run the gates.** `/atg:verify`, per the profile's quality-gate table.

## Failures

| Situation | Action |
|---|---|
| Profile declares `feature-flag: none` | Stop at step 1. Never improvise a pattern |
| Recipe file named by the profile is missing | Stop; the profile is wrong, fix it before coding |

**Next:** `/atg:story-impl {TICKET}` or `/atg:verify`
