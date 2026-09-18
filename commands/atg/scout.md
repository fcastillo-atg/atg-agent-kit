---
description: Audit a ticket against reality before pointing it. Verifies cited claims, dependencies, and tags, then returns a pointable/blocked verdict with a drafted question.
---

# Scout

Check whether a ticket survives contact with the codebase before the team points it. Built for
live grooming: one-line verdict plus the evidence. Scout answers "is this ticket true, and can we
point it?"; `/atg:brief` answers "how do we build it?". Most tickets never need brief.

## Usage

```bash
/atg:scout {TICKET}              # full audit
/atg:scout {TICKET} --fast       # checks 1–3 only, for a timeboxed call
/atg:scout {TICKET} --no-write   # chat only, skip the scout file
```

## Rules

1. **Read-only against Jira.** Never comment, edit, or transition. Suggest edits as text.
2. **Verify, do not paraphrase.** Every claim you repeat is one you checked. Mark anything
   unchecked as provisional.
3. **Quote the evidence.** `file:line` for code, verbatim for ticket and PRD text.
4. **No speculative scoping.** Audit the ticket; do not redesign the work.
5. **Check who wrote it.** A gap in text your own team drafted is a defect to fix, not a question to
   route. Only questions needing product or another service's owner stay open.

## Steps

### 0. Gather

Fetch summary, description, status, and comments per the **jira-cli** skill, and separately
request `--fields issuelinks,parent,labels --json`: those come back null unless named
explicitly. Read the parent epic's children to place the ticket among its siblings, and read
every sibling named in the description, dependencies, or open questions. Tickets in one epic
contradict each other often, and that contradiction is usually the finding.

### 1. Verify every cited claim

Endpoints, paths, line numbers, constants, enum values, field names, status codes, signatures.
Check locally with grep and the file; for another ATG repo, `gh search code "<term>
repo:{org}/{repo}"` then `gh api repos/{org}/{repo}/contents/{path} --jq '.content' | base64 -d`.

Record each as **confirmed**, **drifted** (right idea, wrong names or lines; usually harmless,
say so and correct it), or **false** (a false behaviour claim belongs in the verdict).

Look especially for: an endpoint on a different verb, path, or content type; a field the entity
persists but the response model drops; a capability that is a definition with no evaluator
(grep the constant in use, not where declared); a response shape that is single when the ticket
says list, or per-lot when it needs per-bidder; a downstream service that rewrites what you send
(silent deletion returns a success status); a count or list that drifted from its source, because an
enum gained a value or a compression pass dropped one.

Re-count every enumeration against the code rather than trusting the prose. Compression is where stale
numbers are born: when a ticket was shortened, each surviving number was carried over, not recomputed.

### 2. Verify dependencies

For each dependency, Jira link or prose:

- Does it exist as a ticket? Prose in an open-question section has no owner, cannot be scheduled,
  and never resolves. Recommend raising it.
- Is it satisfied? A Done dependency is not a blocker.
- Is the link direction right? `has to be done before` pointing outward means this ticket blocks
  the other. Teams read these backwards constantly.
- Is it duplicated with contradictory link types? Data-quality bug.
- Does a sibling carry the same blocker? Then neither owns it; say so plainly.
- Is the escape hatch already closed? "X exists, or product names another source" is only open
  if product has not already answered (Step 5).

### 3. Verify the tag matches the repo

`[BE]` the backend monorepo service, `[IS]` invoices-service, `[SP]` the Seller Portal half of
a cross-service interaction, `[FE]` the monorepo UI. Confirm from a sibling that states its area.
Then ask which repo the functional requirements actually land in. A ticket whose every
requirement names a different service than its tag is mis-scoped.

### 4. Check the ticket against its own decisions

Look for a resolved open question, a "decided in planning" marker, or a comment recording a call.
Reread overview, requirements, and ACs against it. Any part still describing the rejected option
is the top finding; it outranks code drift. Deciding is cheap and rewriting is not, so the
decision gets appended and the body never catches up.

Then: was the choice framed honestly? If neither offered option exists, the decision is usually
still right (it assigns ownership) but the cost estimate is not. Report "the call stands, here is
what it actually costs", never "reconsider". Did the decision propagate to siblings? The consumer
ticket usually carries the same open question and no marker.

### 5. Check for stale asks

Before escalating "product to confirm X", check the PRD (including open-question tables and
resolution columns), Jira comments on this ticket and siblings, and sibling descriptions.
Confluence needs its own auth: `acli confluence auth login --web`, then
`acli confluence page view --id {ID} --body-format storage --json`; strip the storage HTML.
Flag both directions: a stale ask product already closed, and a PRD line superseded by a later
Jira decision. The ticket wins when they disagree.

### 6. Answer open questions from code

Try to close the ticket's own open questions by reading the codebase; many are "which of these
two is true" with the answer on disk. Watch for "neither", where the question assumed a
capability that does not exist. That reframes "needs a decision" as "blocked on unbuilt work".

The codebase means every repo the answer could live in, not just the one checked out. Another ATG
repo is readable with the `gh` commands in step 1; never call something unverifiable until you have
tried that. A field's own KDoc and the service validation around it settle most "what are the
semantics" questions.

Also grep any term the ticket introduces. If the only hit is the ticket itself or your own draft, the
term is invented, and the fix is rewriting the line, not asking what it means.

### 7. Verdict

| Verdict | Meaning |
|---|---|
| **Pointable** | Claims hold, dependencies satisfied, tag correct |
| **Pointable after edits** | Substance right, specifics wrong. List the edits. Point it today |
| **Needs a decision** | One human answers one question. Name them, draft it |
| **Blocked** | Depends on work that does not exist. Name what and whether it has a ticket |

Do not soften a blocked verdict to keep a sprint moving. Do not inflate a line-number fix into a
blocker.

## Proposing edits

Split findings by cause: **wrong against the code** (engineering fixes it) versus **wrong against
a decision** (the ticket did not catch up). Propose surgical edits, never a replacement
description: name the paragraphs that go, the sentences that change, and what stays verbatim.
Expect a smaller ticket, not a bigger one.

## Picking the right person

Scope, priority, user behaviour, and done-ness go to product. What another service exposes or
does goes to its owner. Where data lives, which repo owns a capability, and transport direction
are engineering calls. When a product answer already exists in writing, quote it and call the ask
closed. Ask one question; if you have three, the other two are engineering's, answered, or not
blocking.

## Output

Lead with `{TICKET}: {VERDICT}. {One sentence why.}` Then, in order: what is wrong (split by
cause, each with `file:line` or a quote); ticket edits as paste-ready text; the one question and
who answers it (or that it is already answered); what you could not verify and which findings
depend on it.

What you could not verify goes in the proposed ticket edit too, not only in the audit, so the next
reader does not repeat the search.

```
WBPR-0000: BLOCKED. Nothing stores the value this ticket filters on.

Wrong against the code
  Cited store filters on lifecycle status, not payment (constants/invoice.go:41).
  Drift: cited line range is the shipping filter; real one is four lines down.
Dependencies
  Second dependency is prose, not a ticket. Nobody owns it. Raise it.
Stale ask
  "or product names another source" is closed; the PRD answered it twice.
Edits
  Strike that clause. Correct the line range.
The question (product, scope only)
  Needs a store built first, in no ticket. Still MVP, or deferred?
Could not verify
  PRD comment thread cited by a sibling.
```

Unless `--no-write`, save the full audit to `{TICKET}-scout.md` in the story directory per
**atg-story-artifacts**. Never `git add` under `bin/`.

**Next:** pointable → point it, `/atg:brief {TICKET}` only if large or risky; otherwise apply the
edits, send the question, move on.
