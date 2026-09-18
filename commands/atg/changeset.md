---
description: Pointer to this service's changeset procedure, or a clean no-op where the service has none
---

# Changeset (pointer)

Some services require a changelog entry on every PR; some have no changeset system at all.
This command does not duplicate either procedure.

## Usage

```bash
/atg:changeset
```

## What to do

1. Read `changeset` from the **atg-repo-profile** skill.
2. Value `none`: print "This service has no changeset system — nothing to do." and stop.
3. Otherwise follow the procedure the profile gives, exactly. Never run an interactive
   changeset CLI from an agent session.

`/atg:ship` runs the same pre-flight and stops without a changeset where one is required.

**Next:** `/atg:ship {TICKET} [--branch N]`
