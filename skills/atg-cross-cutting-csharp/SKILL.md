---
name: atg-cross-cutting-csharp
description: Use when adding an endpoint, a handler, a marketplace-aware code path, an outbound HTTP call, or a published message in invoices-service — the things whose blast radius reaches past the file being edited.
---

# C# cross-cutting spotter

Walk this list before calling a change done. Each item is something that bites outside the file
you edited.

| Adding | Check |
|---|---|
| A controller endpoint | The marketplace header set is already handled globally by `CallerContextMiddleware` and `MarketplaceHeadersAuthorizationFilter`. Do not re-parse headers with `[FromHeader]`. Health-style endpoints opt out with `[SkipMarketplaceHeaders]` |
| Any endpoint | Playwright integration coverage under `tests/` is required per endpoint, not optional |
| Marketplace-aware logic | Marketplace never defaults to PXB. `MarketplaceResolver` holds it as ambient scoped state set by `MarketplaceMiddleware`; the `"default"` fallback matches no registered facade and throws `InvalidOperationException` → 500 |
| Marketplace-specific I/O | It belongs in an Infraestructure facade, not in a handler |
| An outbound Sales Order call | `SalesOrderRequestHandler` already adds the bearer token, `platformCode=SP` and `marketplaceCode` as **query parameters**, the `invoices-service` user agent, and the correlation id. Do not add them again |
| A published message | Which layer publishes decides the kind: handler-published domain events versus Infraestructure-published legacy-sync messages. They are not interchangeable |
| New middleware | Order matters — correlation id → marketplace → caller context → authorization filter → controller. Inserting out of order silently breaks the ones after it |
| New configuration | `AtgPay:MarketplaceToken` has no default and is absent from every `appsettings*.json`. Anything depending on it fails with a 500 locally until user secrets are set |
| A money value | Confirm the serialized shape. Invoice money fields are returned as JSON **strings**, and unset ones default to empty |
