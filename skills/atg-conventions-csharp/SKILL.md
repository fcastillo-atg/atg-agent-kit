---
name: atg-conventions-csharp
description: Use when editing .cs files in invoices-service, after generating C# code, and before committing C# changes. Portable copy of the C#, ASP.NET Core, MediatR and xUnit conventions for harnesses that do not load the repo's rules directory.
---

# C# conventions guard

## Use when

- Working in `.cs` files in a service whose profile names this skill
- Reviewing generated C# before it is committed

## Layering

Three projects, each with a `*.Tests` twin. The infrastructure project is spelled
`InvoicesService.Infraestructure` — a consistent misspelling. Match it; never "correct" it.

| Project | Owns |
|---|---|
| `InvoicesService` | Controllers, middleware, filters, Serilog and OpenAPI wiring |
| `InvoicesService.Core` | MediatR queries and handlers, ports under `Application/Abstractions/`, `Guard`, business rules |
| `InvoicesService.Infraestructure` | All I/O: HTTP clients, RabbitMQ publisher, marketplace facades |

A controller calls `mediator.Send(query)`. It does not reach into Infraestructure.

## Error contract

`ExceptionFilterHandler`, registered globally in `Program.cs`, is the only place that shapes
errors, and it maps by exception **type**:

- `ArgumentException` and subtypes → **400**, with `exception.Message` returned verbatim
- everything else → **500**, generic message, real exception logged server-side only

So `Core/Guards/Guard` throws `ArgumentException` with a fully-formed, caller-ready message
rather than a parameter name — that message becomes the response body. Validate caller input
with `Guard.*` in handlers, or `InvoiceQueryRules.GuardPaging`/`GuardSort`. Use
`InvalidOperationException` for configuration and upstream failures that should surface as 500.

## Tests

- xUnit, Moq, FluentAssertions for unit tests; one `*.Tests` project per production project.
- `[Trait("Category", "Live")]` tests hit a real environment and silently no-op without
  `AtgPay:MarketplaceToken`. They prove nothing in CI by design — never cite one as coverage.
- Integration coverage is Playwright in TypeScript under `tests/`, not another xUnit project.

## Hygiene

- CSharpier is enforced in CI and by the pre-commit hook. Run the profile's format gate before
  committing; unformatted C# fails the build.
- Never imitate `WeatherForecast.cs`, `WeatherForecastController.cs`, `Class1.cs` or the
  `UnitTest1.cs` placeholders — untouched `dotnet new` scaffolding. Use `HealthController` +
  `GetHealthQuery`, or the `Invoices` slice.
- Scan for leftover `TODO`, `FIXME`, `Console.WriteLine`, `Debug.WriteLine` before shipping.
