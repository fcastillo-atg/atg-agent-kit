---
name: atg-conventions-go
description: Use when editing .go files in sales-order, after generating Go code, and before committing Go changes. Portable copy of the Go, ctxerr, gomock and testify conventions for harnesses that do not load a repo rules directory.
---

# Go conventions guard

## Use when

- Working in `.go` files in a service whose profile names this skill
- Reviewing generated Go before it is committed

## Layering

Everything lives under `internal/`, with the entrypoint and route table in `sales-order.go` at
the repo root. The chain runs one way: handler → service → store or gateway.

| Package | Owns |
|---|---|
| `internal/handlers` | HTTP handlers, param extraction, response shaping, OpenAPI doc funcs |
| `internal/services` | Business logic and orchestration |
| `internal/stores` | Database access (`database/sql`) |
| `internal/gateways` | Outbound HTTP to other services, one subpackage per upstream |
| `internal/interfaces` | Every interface the above depend on, `-er` suffixed |
| `internal/mocks` | Generated only. Never hand-edit |
| `internal/contracts` | Wire shapes: request and response bodies |
| `internal/data` | Domain and persistence shapes |
| `internal/contractconversion` | The mapping between the two. Conversion goes here, not in a handler |

A handler does not reach into a store or a gateway. Depend on the interface from
`internal/interfaces`, never on a concrete service or gateway type.

Each handler pairs a `HandleX` func with a `HandleXDocs` func, registered together via
`rr.GSEndpoint(path, method, handler, docs)`. Adding a route without its docs func breaks the
generated OpenAPI spec.

## Error contract

Two libraries, used together, at every layer:

- **`github.com/mvndaai/ctxerr`** for propagation. Wrap at each boundary you cross:
  `err = ctxerr.QuickWrap(ctx, err)`. This accumulates context fields rather than flattening the
  chain, so do not swap it for `fmt.Errorf("%w")`.
- **`internal/soerrors`** for typed, coded errors: `soerrors.MissingParam(ctx, docs.ParamInvoiceID)`,
  `soerrors.NotFound(ctx, "sales order", "h.SalesOrderService.GetSalesOrderIDByExternalID", err)`.
  Codes are declared as constants in `soerrors/Codes.go` (`ErrorCreateSalesOrder`,
  `ErrorMissingBody`, ...). Add a constant there rather than an inline string.

The `NotFound` second-to-last argument is the **call path that failed**, spelled out like
`h.SalesOrderService.GetTransactionByID`. It appears in logs; keep it accurate when you move or
rename a method.

## Tests

- `testify/assert` for assertions, `go.uber.org/mock/gomock` for mocks.
- Standard opening: `mockCtrl := gomock.NewController(t)`, `defer mockCtrl.Finish()`, then
  `mocks.NewMockAccountingStorer(mockCtrl)`.
- Table-driven, with a local `type args struct` holding the call's inputs.
- **Mocks are generated, not written.** Change an interface in `internal/interfaces/`, then run
  `./generateMocks.sh` (it installs `mockgen` and regenerates every mock). A hand-edited mock is
  wiped on the next run.
- Integration tests live in `internal/testgo/`, are `//go:build integration` tagged, need a
  running server, and are not part of the unit-test gate. They are `/atg:test-run` territory.

## Hygiene

- Lint runs against your diff only (`--new-from-rev=HEAD~` in CI), so a whole-repo
  `golangci-lint run` may show pre-existing findings that are not yours to fix.
- Money is `github.com/ATG-Services/go-common/money`, not a float and not a raw int. Construct
  with `money.Parse`; carry the type through rather than unwrapping to a primitive.
- Commit messages must lead with a Jira key (`UPS-1234 add the thing`); commitlint rejects
  anything else.
- Scan for leftover `TODO`, `FIXME`, `fmt.Println`, and stray `log.Printf` debugging before
  shipping.
