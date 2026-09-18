# Profile: invoices-service

| Key | Value |
|---|---|
| `id` | `invoices-service` |
| `detect` | `invoices-service.sln` at the git toplevel |
| `code-root` | `src/` |
| `branch-pattern` | `{TICKET}` or `{TICKET}-{slug}`, no author prefix (e.g. `WBPR-4963`, `WBPR-4536-sales-order-client`) |
| `story-root` | `bin/stories/` at the git toplevel — already ignored by `.gitignore` (`**/[Bb]in/*`) |
| `plans-path` | `.claude/plans/{TICKET}-{slug}.md` |
| `rules-dir` | `.claude/rules/` |
| `pr-template` | `.github/pull_request_template.md` |
| `pr-body-anchor` | `## AI Usage Declaration` |
| `changeset` | `none` — standalone repo, no `.changeset/` infrastructure |
| `feature-flag` | `none` — no flag mechanism exists in this service |
| `source-ext` | `.cs`; integration tests are `.ts` under `tests/` |
| `conventions-skill` | `atg-conventions-csharp` |
| `cross-cutting-skill` | `atg-cross-cutting-csharp` |
| `dynatrace-container` | `invoices-service` |
| `dynatrace-cluster` | `a2o-dev` |
| `dynatrace-filters` | `none` — the namespace is per-environment and per-PR (Octopus `#{Namespace}`), so there is no fixed value to filter on |
| `ticket-prefixes` | `WBPR-*`, `SP2-*` — confirmed against WBPR-4963; the `MTGAP` key in `ci.yml` is a team board, not an issue prefix |
| `service-start` | `cd src && dotnet run --project InvoicesService &`, poll `http://localhost:5099/health` every 5s up to 120s, then fail with the last lines of output |

## Quality gates

| Step | Gate | Command | Working dir | On failure |
|---|---|---|---|---|
| 1 | Format | `dotnet csharpier check .` | `src/` | Run `dotnet csharpier format .`, re-check. CI fails on unformatted C# (`enable-csharpier: true`) |
| 2 | Build | `dotnet build` | `src/` | `NETSDK1045` means a .NET 9 SDK is active; .NET 10 is required |
| 3 | Unit tests | `dotnet test` | `src/` | Fix normally. `[Trait("Category", "Live")]` tests no-op without `AtgPay:MarketplaceToken` and prove nothing |
| 4 | TypeScript lint (only when the diff touches `tests/`) | `pnpm lint` | `tests/` | Run `pnpm lint-fix`, re-check |

No coverage gate. CI declares `coverage-exclusions` but no threshold, so `/atg:verify` does not
invent one. Do not add a coverage step without agreeing a number first.

## Notes

- **`dotnet` is not on `PATH` on the current machine.** It is at `/usr/local/share/dotnet`. Prefix
  gate commands with `export PATH="/usr/local/share/dotnet:$PATH"` when `command -v dotnet` fails.
- Run `dotnet tool restore` in `src/` once per machine before the format gate; CSharpier is a local
  tool (`src/.config/dotnet-tools.json`, pinned to 1.3.0).
- `pnpm test` in `tests/` is a decoy that exits 1 by design. The integration entry point is
  `pnpm test:int`, and it needs a reachable service — that is `/atg:test-run`, not `/atg:verify`.
- Git hooks already cover part of this: pre-commit formats staged files, pre-push runs
  `dotnet build` + `dotnet test` in `src/`. Gates 2 and 3 duplicate pre-push deliberately, because
  `/atg:verify` must not depend on a hook having run.
- The infrastructure project is spelled `InvoicesService.Infraestructure` throughout. Match it.
- `src/InvoicesService/WeatherForecast.cs`, `Controllers/WeatherForecastController.cs`,
  `src/InvoicesService.Core/Class1.cs` and the `UnitTest1.cs` files are untouched `dotnet new`
  scaffolding. Never cite them as a pattern.
