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
- A named capability that turns out to be a definition with no evaluator behind it.
- A response shape the ticket calls a list when it is a single item, or per-lot when the ticket needs
  per-bidder.

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

### Step 3: Verify the tag matches the repo

ATG tags name the service: `[BE]` is wavebid-a2o-service, `[IS]` is invoices-service, `[SP]` is the
Seller Portal half of a cross-service interaction, `[FE]` is wavebid-a2o-ui. Epics may differ, so
confirm the convention from a sibling that states its own project area.

Then read the functional requirements and ask which repo the described work lands in. A ticket whose
every requirement names a different service than its tag is mis-scoped, and pointing it means one
team estimates another team's work.

### Step 4: Check for stale asks

A ticket blocked on "product to confirm X" is worthless if product already confirmed X. Before
escalating anything, check whether it is already answered in:

- The PRD, including its open-question tables. Resolution columns are where decisions land.
- Jira comments on this ticket and its siblings.
- A sibling ticket's description, which often records a decision from a call.

Confluence needs its own auth: `acli confluence auth login --web`, then
`acli confluence page view --id {ID} --body-format storage --json`. Strip the storage HTML before
reading.

Flag both directions. A stale ask that product already closed, and a PRD line superseded by a later
Jira decision. Both send people to the wrong conclusion.

### Step 5: Can the open question be answered from code?

Read the ticket's own open questions and try to close them by reading the codebase. Many are
"which of these two things is true" and the answer is on disk.

Watch for the case where the answer is neither, because the question assumed a capability that does
not exist. That reframes the ticket from "needs a decision" to "blocked on unbuilt work", which is a
very different conversation in a grooming call.

### Step 6: Verdict

Pick one:

| Verdict | Meaning |
|---|---|
| **Pointable** | Claims hold, dependencies satisfied, tag correct. Point it. |
| **Pointable after edits** | Substance is right, specifics are wrong. List the edits. Point it today. |
| **Needs a decision** | One human has to answer one question. Name the person and draft the question. |
| **Blocked** | Depends on work that does not exist. Name what is missing and whether it has a ticket. |

Do not soften a blocked verdict to keep a sprint moving. Do not inflate a line-number correction into
a blocker.

## Output

Lead the chat reply with the verdict line, because that is what the call needs:

```
{TICKET}: {VERDICT}. {One sentence why.}
```

Then, in order:

1. **What is wrong**, each finding with its `file:line` or verbatim quote.
2. **Ticket edits to make**, as text ready to paste.
3. **The question, and who answers it.** One question. Name the person or role. If the answer is
   already in writing somewhere, say that instead and skip the escalation.
4. **What you could not verify**, and which findings depend on it.

Unless `--no-write`, save the full audit to
`bin/stories/{year}/{month}/{TICKET}-{slug}/{TICKET}-scout.md`. Never `git add` anything under `bin/`.

## Picking the right person to ask

Route the question by what kind of answer it needs, not by who is nearest:

- **Scope, priority, user behaviour, and what counts as done** go to product.
- **Whether another service will expose a field, or what its code does** goes to that service's owner.
- **Where data lives and which repo owns a capability** is an engineering call, not a product one.

A question sent to product that only engineering can answer comes back as a restatement of the
requirement, and costs a week. When a product answer already exists in writing, quote it and say the
ask is closed rather than re-opening it.

## Worked example

```
/atg:scout WBPR-4923

WBPR-4923: BLOCKED. Nothing anywhere stores a Paid/Unpaid value, so there is nothing to filter.

What is wrong
  Claims: all verified, one drift. AccountingStore.go 4970-4973 is the shipping-method
    filter; the InvoiceStatus filter is 4975-4979.
  Dependencies: WBPR-4674 satisfied (Done). The second dependency is prose, not a ticket,
    so nobody owns it and it cannot resolve.
  Trap: SalesOrderDetail.IsPaid() exists but is per line item and derives from a provider
    transaction id. Wrong grain, and it is payment state, which PRD Q24 rules out.
  Stale ask: "or product names another source in writing" is closed. PRD Q24 and Q4 answered it.

Edits
  Strike the "or product names another source" clause.
  Correct the AccountingStore.go line range.

The question, and who answers it
  Product, scope only: Paid/Unpaid filtering needs a store built first, which is in no ticket.
  Still MVP, or deferred until it exists?
  Not a product question: where the value lives. That is ours.

Could not verify
  The 2026-08-06 PRD comment thread cited by WBPR-4955.
```

## Next steps

- **Pointable** or **pointable after edits**: point it. `/atg:brief` only if it is large or risky.
- **Needs a decision** or **blocked**: apply the edits, send the question, move on in the call.
