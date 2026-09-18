---
description: Run this service's quality gates in order and auto-fix violations — the gate before /atg:ship
---

# Verify: quality gates

Run the service's quality gates in order, fix what fails, and stop only when every gate is green.
Start immediately; do not wait for confirmation.

## Usage

```bash
/atg:verify
```

## Gates

Read the `## Quality gates` table from the **atg-repo-profile** skill. It gives, per gate: step
number, name, command, working directory, and what to do on failure. Run them in the order
listed. Each gate's working directory is relative to the git toplevel.

Sequential. Do not start a gate until the previous one passes. 15-minute timeout per command.
Never invent a gate the profile does not list — in particular, never add a coverage gate to a
service whose profile declares none.

## Steps

1. **Resolve the profile.** Per **atg-repo-profile**. Print the profile `id` and the gate list
   you are about to run, one line, before starting. No profile matches: stop and say so.

2. **Freshness check, per gate.** Skip a gate only when both hold: you personally ran that exact
   command earlier in this conversation and saw it pass, and `git status --short` shows nothing
   changed under the profile's `code-root` since that run. Any change, even one unrelated-looking
   file, means re-run. Never carry a result across sessions; a fresh session runs everything.
   When unsure, re-run.

3. **Conditional gates.** A gate whose row names a condition ("only when the diff touches X")
   runs only when `git status --short` or the branch diff shows a matching path. Otherwise print
   it as `SKIPPED (not applicable)` and move on.

4. **Run each gate.** On failure, apply that row's **On failure** guidance, fix, and re-run that
   gate, max 3 cycles. Do not move on until it passes. Apply a row's recovery procedure at most
   once per verify session; never loop it.

5. **Report.** After all gates pass, print the summary below, one line per gate from the profile
   table. Mark a skipped gate as `PASSED (cached — no changes since last run in this session)`
   with 0s duration.

```
Verification complete  [{profile id}]

Step {n} {gate name}  ✅ PASSED ({detail}, {t}s)
...

Total: {t}s. All quality gates passed. Ready to commit.
```

On a gate that does not converge after 3 cycles, stop, print which gate failed with the
remaining violations or failures, and ask for guidance.

## Failures

| Situation | Action |
|---|---|
| No profile matches this repo | Stop. Do not guess a build command |
| A gate's tool is missing from `PATH` | Check the profile's `## Notes` for its location before reporting it absent |
| Tests pass in CI but fail locally | Suspect seed data or ordering; report as flaky candidate |
| Gate cannot be auto-fixed | Stop after 3 cycles and report |

**Next:** `/atg:pattern-check {TICKET} [--branch N]`
