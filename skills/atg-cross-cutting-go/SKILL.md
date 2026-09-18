---
name: atg-cross-cutting-go
description: Use when adding a route, a service method, a database query, an outbound gateway call, a published RabbitMQ event, or a money calculation in sales-order — the things whose blast radius reaches past the file being edited.
---

# Go cross-cutting spotter

Walk this list before calling a change done. Each item bites outside the file you edited.

| Adding | Check |
|---|---|
| A route | Register it in `sales-order.go` with both the handler and its `*Docs` func. Pick the right subrouter: `/v2/marketplaces/{marketplaceCode}` for versioned public routes, `v2support` for support-only, `/testing` for test-only. The last two sit behind `MiddlewareTestingOrSupport` and are gated by `AllowTestHeaders` — a route added to the wrong one is either unprotected or unreachable in production |
| A database call | `AccountingStore` holds **separate `readDB` and `writeDB` handles**. Picking the wrong one silently sends writes to a replica or reads to the primary. Match the operation |
| A new interface | Add it to `internal/interfaces/`, then run `./generateMocks.sh` and commit the regenerated mock. Tests fail to compile against a stale mock |
| A published event | `PublicRabbitService.PublishReconcileEvent` publishes to the public exchange with a routing key. Publishing is not transactional with the DB write — if the write can roll back after the publish, consumers see an event for state that never landed |
| A consumed event | The consumer lives in `internal/rabbit/Consumer.go`. Local runs set `SKIP_RABBIT=true`, so a change to consumption is not exercised by a plain local run or by the integration job's default env |
| An outbound call | It belongs in `internal/gateways/<upstream>/`, behind an `-er` interface, not inline in a service. Gateways build requests through `simplehttp` and carry auth headers via their own `defaultHeaders` |
| A money value | Use `go-common/money`. Do not round intermediate values or re-derive an amount from a rate — carry the stored value through. Money crosses the wire, the DB, and atgpay, and each hop has its own precision assumptions |
| A response field | Wire shapes live in `internal/contracts`, domain in `internal/data`, and the mapping in `internal/contractconversion`. Adding a field to one without the other two either does not serialize or silently drops |
| A new config value | `internal/config` reads via `envconfig` tags with defaults. A value with no default and no local env fails at runtime, not at startup validation |
| A seller-entitlement check | `AtgPayFeatureGatewayer.GetSellerFeatures` is a live call to the atgpay feature service, per seller. It is an entitlement lookup, not a rollout flag, and it is a network hop — do not put it in a loop |
| Anything touching an invoice total | There is an integrity-check endpoint (`/v2/.../invoices/{invoiceId}/integrity-check`). Use it to confirm a change did not desynchronize totals from details |

## No rollout flags here

This service has no feature-flag mechanism. A risky change ships behind a branch and a review,
or it does not ship. Do not invent a flag pattern, and do not repurpose the seller-features
gateway as one.

## No migrations here

The accounting schema is not owned by this repo — there is no migration directory and no
migration tool. A change that needs a new column is a cross-repo conversation before it is a
code change.
