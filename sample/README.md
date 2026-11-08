# Bookmarks sample

A small, deliberately dull web API for the kit's practice tasks (`practice/`, checkpoint §4). It's built with every kit rule applied and every gate green.

## Layout

One module in Clean Architecture (ARC-001):

| Project | What it holds |
|---|---|
| `src/Bookmarks.Domain` | The `Bookmark` entity and its rules |
| `src/Bookmarks.Contracts` | The API's request and response types |
| `src/Bookmarks.Application` | Use cases, grouped by feature (`Features/Bookmarks`) |
| `src/Bookmarks.Infrastructure` | EF Core with SQLite |
| `src/Bookmarks.Api` | Minimal API endpoints and OpenAPI |
| `src/Bookmarks.ServiceDefaults` | OpenTelemetry logs, metrics and traces; the `/health` and `/alive` endpoints; resilience on every `HttpClient` (OPS-001 to OPS-003, ADR-0037). The reference for an app's own ServiceDefaults project |

| Test project | Kind (brief §6.7) |
|---|---|
| `tests/Bookmarks.Domain.Tests` | Unit |
| `tests/Bookmarks.Application.Tests` | Unit, with Moq |
| `tests/Bookmarks.IntegrationTests` | Integration: the repository against real in-memory SQLite |
| `tests/Bookmarks.FunctionalTests` | Functional: the whole API in memory (`WebApplicationFactory`), plus the OpenAPI contract snapshot |
| `tests/Bookmarks.Architecture.Tests` | Architecture: layers depend only inward (ArchUnitNET) |

## Run it

From the repo root:

```powershell
# The gate merges every report under TestResults, so start from an empty folder.
if (Test-Path TestResults) { Remove-Item -Recurse TestResults }
dotnet test --coverage --coverage-output-format cobertura --results-directory TestResults
./tools/Test-CoverageGate.ps1 -Path TestResults -Solution dotnet-agent-kit.slnx
dotnet run --project sample/src/Bookmarks.Api
```

The API keeps its data in `bookmarks.db` (SQLite) next to where it runs. In Development it serves its OpenAPI document at `/openapi/v1.json`; other environments don't (API-003). `GET /bookmarks` answers one page at a time (`?offset=0&limit=25`, at most 100) with a `nextLink` to the next, and every error is Problem Details (`docs/standards/api-design.md`). `/health` answers `Healthy` once the database is reachable, and `/alive` while the process runs. To see its telemetry, set `OTEL_EXPORTER_OTLP_ENDPOINT` to an OTLP endpoint, such as the Aspire dashboard's.

## The API contract

`tests/Bookmarks.FunctionalTests/Contract/openapi-v1.json` is the committed contract. When the API changes, the contract test fails and writes `openapi-v1.received.json` beside it; review the difference, then copy it over the snapshot to accept it.
