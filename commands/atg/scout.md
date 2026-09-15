---
description: Audit a ticket against reality before pointing it. Verifies cited claims, dependencies, and tags, then returns a pointable/blocked verdict with a drafted question.
---

# Scout: Ticket Readiness Audit

**Purpose:** Check whether a ticket survives contact with the codebase before the team points it.
Built for live grooming. Returns a one-line verdict plus the evidence behind it.

`/atg:scout` answers "is this ticket true, and can we point it?"
`/atg:brief` answers "how do we build it?" Run scout first. Most tickets never need brief.

## Usage

```bash
/atg:scout {TICKET}              # full audit
/atg:scout {TICKET} --fast       # checks 1-3 only, for a timeboxed call
/atg:scout {TICKET} --no-write   # chat only, skip the scout file
```

## Rules

1. **Read-only against Jira.** Never post a comment, never edit a ticket, never transition anything.
   This runs live in a call. Surprise mutations there are bad. Suggest edits as text the user applies.
2. **Verify, do not paraphrase.** Every claim you repeat must be one you checked. If you could not
   check it, say so and mark the finding provisional.
3. **Quote the evidence.** `file:line` for code, verbatim for ticket and PRD text. A grooming call
   will not accept "I think the endpoint is different."
4. **No speculative scoping.** You are auditing the ticket, not redesigning the work.

## Execution

### Step 0: Gather

```bash
acli jira workitem view {TICKET} --fields summary,description,status,comment
acli jira workitem view {TICKET} --fields issuelinks,parent,labels --json
```

`issuelinks` and `parent` come back null unless you ask for them by name. Always request them
explicitly. Then read the parent epic's children to place the ticket among its siblings.

For each sibling named in the description, dependencies, or open questions, read it too. Tickets in
one epic contradict each other often, and that contradiction is usually the finding.

### Step 1: Verify every cited claim

Walk the ticket for anything checkable. Endpoints, file paths, line numbers, constants, enum values,
field names, status codes, method signatures.

Check each one:

- Local repo: `grep`, `sed -n 'N,Mp'`, read the file.
- Another ATG repo not checked out: `gh api repos/{org}/{repo}/contents/{path} --jq '.content' | base64 -d`
  Works for LIVEauctioneers and wavebid-ATG. Use `gh search code "<term> repo:{org}/{repo}"` to locate first.

Record three outcomes per claim: **confirmed**, **drifted** (right idea, wrong line numbers or names),
or **false**.

Line-number drift is common and usually harmless. Say so, and correct it. A false claim about
behaviour is not harmless and belongs in the verdict.

Look specifically for:

- An endpoint that exists but on a different verb, path, or content type than the ticket assumes.
- A field the ticket assumes is exposed that the entity persists but the response model drops.
- A named capability that turns out to be a definition with no evaluator behind it. Grep for the
  enum value or constant in use, not just where it is declared. One hit means nothing consumes it.
- A response shape the ticket calls a list when it is a single item, or per-lot when the ticket needs
  per-bidder.
- A downstream service that rewrites what you send it. If the ticket posts a payload somewhere,
  check what the receiver normalizes, strips, or merges before persisting. Silent deletion returns
  a success status.

### Step 2: Verify dependencies

For each dependency, whether it is a Jira link or prose in the description:

- **Does it exist as a ticket?** If the blocker is only a sentence in an open-question section, that
  is the finding. Prose has no owner, cannot be scheduled, and cannot be refused, so it never
  resolves. Recommend raising it.
- **Is it satisfied?** Check status. A Done dependency is not a blocker.
- **Is the link direction right?** `has to be done before` pointing outward means this ticket blocks
  the other one, not the reverse. Teams read these backwards constantly.
- **Is it duplicated?** The same ticket linked twice with contradictory types is a data-quality bug.
- **Does a sibling carry the same blocker?** If two tickets are parked on one missing thing, neither
  owns it. Say that plainly rather than nominating one as the owner.
- **Is the escape hatch already closed?** A dependency worded "X exists, or product names another
  source" is only open if product has not already answered. Check Step 4 before escalating.

### Step 3: Verify the tag matches the repo

ATG tags name the service: `[BE]` is wavebid-a2o-service, `[IS]` is invoices-service, `[SP]` is the
Seller Portal half of a cross-service interaction, `[FE]` is wavebid-a2o-ui. Epics may differ, so
confirm the convention from a sibling that states its own project area.

Then read the functional requirements and ask which repo the described work lands in. A ticket whose
every requirement names a different service than its tag is mis-scoped, and pointing it means one
team estimates another team's work.

### Step 4: Check the ticket against its own decisions

A ticket that records a decision and then describes the opposite is worse than one that never
decided, because a reader can act on either half.

Look for a resolved open question, an inline marker like "decided in planning", or a comment
recording a call. Then reread the overview, requirements, and acceptance criteria against it. If any
still describe the rejected option, that is the top finding. It outranks code drift.

This happens because deciding is cheap and rewriting is not, so the decision gets appended and the
body never catches up.

Two things to check once you find one:

- **Was the choice framed honestly?** If the open question offered two options and neither exists,
  whoever decided picked on bad information. The decision is usually still right, since it assigns
  ownership. The cost estimate behind it is not. Report it as "the call stands, here is what it
  actually costs", never as "reconsider".
- **Did the decision propagate to siblings?** The consumer ticket usually carries the same open
  question and no marker at all.

### Step 5: Check for stale asks

A ticket blocked on "product to confirm X" is worthless if product already confirmed X. Before
escalating anything, check whether it is already answered in:

- The PRD, including its open-question tables. Resolution columns are where decisions land.
- Jira comments on this ticket and its siblings.
- A sibling ticket's description, which often records a decision from a call.

Confluence needs its own auth: `acli confluence auth login --web`, then
`acli confluence page view --id {ID} --body-format storage --json`. Strip the storage HTML before
reading.

Flag both directions. A stale ask that product already closed, and a PRD line superseded by a later
Jira decision. The ticket wins when they disagree.

### Step 6: Can the open question be answered from code?

Read the ticket's own open questions and try to close them by reading the codebase. Many are
"which of these two things is true" and the answer is on disk.

Watch for the case where the answer is neither, because the question assumed a capability that does
not exist. That reframes the ticket from "needs a decision" to "blocked on unbuilt work", which is a
very different conversation in a grooming call.

### Step 7: Verdict

Pick one:

| Verdict | Meaning |
|---|---|
| **Pointable** | Claims hold, dependencies satisfied, tag correct. Point it. |
| **Pointable after edits** | Substance is right, specifics are wrong. List the edits. Point it today. |
| **Needs a decision** | One human has to answer one question. Name the person and draft the question. |
| **Blocked** | Depends on work that does not exist. Name what is missing and whether it has a ticket. |

Do not soften a blocked verdict to keep a sprint moving. Do not inflate a line-number correction into
a blocker.

## Proposing edits

Separate findings by cause, because they have different owners and different fixes:

- **Wrong against the code.** True regardless of any decision. Engineering fixes it.
- **Wrong against a decision.** The code is fine; the ticket did not catch up.

Propose surgical edits, never a replacement description. Name the paragraphs that go, the sentences
that change, and the parts that stay verbatim. A rewrite encodes your interpretation of someone
else's ticket and buries what the team already agreed. Say what survives as explicitly as what does
not, and expect the result to be a smaller ticket, not a bigger one.

## Picking the right person to ask

Route the question by what kind of answer it needs, not by who is nearest:

- **Scope, priority, user behaviour, and what counts as done** go to product.
- **Whether another service will expose a field, or what its code does** goes to that service's owner.
- **Where data lives, which repo owns a capability, and transport direction** are engineering calls.

A question sent to product that only engineering can answer comes back as a restatement of the
requirement, and costs a week. When a product answer already exists in writing, quote it and say the
ask is closed rather than re-opening it.

Ask one question. If you have three, the other two are usually engineering's, already answered, or
not blocking.

## Output

Lead the chat reply with the verdict line, because that is what the call needs:

```
{TICKET}: {VERDICT}. {One sentence why.}
```

Then, in order:

1. **What is wrong**, split into wrong-against-code and wrong-against-decision, each finding with its
   `file:line` or verbatim quote.
2. **Ticket edits to make**, surgical, as text ready to paste.
3. **The question, and who answers it.** One question. Name the person or role. If the answer is
   already in writing somewhere, say that instead and skip the escalation.
4. **What you could not verify**, and which findings depend on it.

Unless `--no-write`, save the full audit to
`bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-scout.md`. Never `git add` anything under `bin/`.

## Worked example

```
{TICKET}: BLOCKED. Nothing stores the value this ticket filters on, so there is nothing to filter.

Wrong against the code
  The cited store filters on a lifecycle status, not a payment one. Neither status enum
    has the concept (constants/invoice.go, constants/sales_order.go).
  Trap: an IsPaid() does exist, but per line item and derived from a provider transaction
    id. Wrong grain, and it is payment state, which the PRD rules out.
  Drift: the cited line range is the shipping-method filter. The real one is four lines down.

Wrong against a decision
  None. No decision has been recorded on this ticket.

Dependencies
  First one satisfied (Done). The second is prose in an open-question section, not a
    ticket, so nobody owns it and it cannot resolve. Raise it.

Stale ask
  "or product names another source in writing" is closed. The PRD answered it twice.

Edits
  Strike the "or product names another source" clause.
  Correct the cited line range.

The question, and who answers it
  Product, scope only: this needs a store built first, which is in no ticket. Still MVP,
  or deferred until it exists?
  Not a product question: where the value lives. That is ours.

Could not verify
  A PRD comment thread cited by a sibling ticket.
```

## Next steps

- **Pointable** or **pointable after edits**: point it. `/atg:brief` only if it is large or risky.
- **Needs a decision** or **blocked**: apply the edits, send the question, move on in the call.
