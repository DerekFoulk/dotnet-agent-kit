# Bookmarks sample

A small, deliberately dull web API for the kit's practice tasks (`practice/`, checkpoint §4). It's built with every kit rule applied and every gate green.

## Layout

One module in Clean Architecture (ARC-001):

| Project | What it holds |
|---|---|
| `src/Bookmarks.Domain` | The `Bookmark` entity and its rules |
| `src/Bookmarks.Contracts` | The API's request and response types |
| `src/Bookmarks.Application` | Use cases, grouped by feature (`Features/Bookmarks`) |
| `src/Bookmarks.Infrastructure` | EF Core on SQL Server, with its migrations in `Migrations/` (DAT-002) |
| `src/Bookmarks.Api` | Minimal API endpoints and OpenAPI |
| `src/Bookmarks.ServiceDefaults` | OpenTelemetry logs, metrics and traces; the `/health` and `/alive` endpoints; resilience on every `HttpClient` (OPS-001 to OPS-003, ADR-0037). The reference for an app's own ServiceDefaults project |

| Test project | Kind (brief §6.7) |
|---|---|
| `tests/Bookmarks.Domain.Tests` | Unit |
| `tests/Bookmarks.Application.Tests` | Unit, with Moq |
| `tests/Bookmarks.IntegrationTests` | Integration: the repository and the migrations on SQL Server in a container (Testcontainers), a new database per test (DAT-005) |
| `tests/Bookmarks.FunctionalTests` | Functional: the whole API in memory (`WebApplicationFactory`), each host on a new SQL Server database, and the kit's shared host checks (`tools/AppTests/Functional`): health, errors, the OpenAPI document (in Development only, its contract snapshot, its errors, its bearer scheme, and Contracts types only), tokens, container validation, telemetry, resilience, shutdown, sign-in by default and Kestrel's hardening. Its `AppHost.cs` lists the sample's one host, its API, for them |
| `tests/SqlServer` | Not a project: the SQL Server image the tests and the load test run, pinned by digest (`Dockerfile`), and the helper both test projects compile in (`SqlServerTestDatabase.cs`, ADR-0098) |
| `tests/Bookmarks.Architecture.Tests` | Architecture: the kit's shared tests (`tools/AppTests/Architecture`, ArchUnitNET): layers depend only inward, shared libraries reference no UI or platform package, no namespace cycles. Its `AppLayers.cs` names the sample's assemblies by layer |
| `tests/Bookmarks.Benchmarks` | Performance: BenchmarkDotNet times `Bookmark.Create` against `benchmark-budget.json` (TST-009, ADR-0062). Not a test project; `.github/workflows/performance.yml` runs it |
| `tests/load` | Load: a Locust test of the API (`locustfile.py`), its load (`locust.conf`) and its budget (`load-budget.json`). `.github/workflows/performance.yml` starts SQL Server from the tests' pin, applies the migrations with `dotnet ef database update`, starts the API in Release and Production, and runs it |

## Run it

The integration and functional tests need Docker running: they start SQL Server in a container. Without it, a local run
skips them and says why (CI never does: there they fail), and `./tools/Initialize-DevMachine.ps1` reports whether
Docker is running. Skipped, they cover nothing, so the coverage gate below fails until Docker runs. From the repo root:

```powershell
# The gate merges every report under TestResults, so start from an empty folder.
if (Test-Path TestResults) { Remove-Item -Recurse TestResults }
dotnet test --coverage --coverage-output-format cobertura --results-directory TestResults
./tools/Test-CoverageGate.ps1 -Path TestResults -Solution dotnet-agent-kit.slnx
```

To run the API itself, give it a SQL Server of its own, from the image the tests pin, with its schema from the
migrations. The password is yours: SQL Server wants at least 8 characters from three of upper case, lower case, digits
and symbols, and it stays in your user secrets, never in the repo.

```powershell
$env:MSSQL_SA_PASSWORD = Read-Host -Prompt 'A password for the local SQL Server' -MaskInput
$image = (@(Get-Content sample/tests/SqlServer/Dockerfile) -match '^FROM\s+')[0] -replace '^FROM\s+', ''
docker run --detach --name bookmarks-sql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD --publish 1433:1433 $image
dotnet user-secrets set ConnectionStrings:Bookmarks "Server=localhost,1433;Database=Bookmarks;User Id=sa;Password=$env:MSSQL_SA_PASSWORD;TrustServerCertificate=True" --project sample/src/Bookmarks.Api
dotnet tool restore
dotnet ef database update --project sample/src/Bookmarks.Infrastructure --startup-project sample/src/Bookmarks.Api
dotnet run --project sample/src/Bookmarks.Api
```

Every endpoint except `/health`, `/alive` and the Development OpenAPI document needs a bearer token, and each user sees only their own bookmarks (SEC-007 to SEC-010, ADR-0048). To get a token locally, run `dotnet user-jwts create --project sample/src/Bookmarks.Api`, which keeps its signing key in your user secrets, and send the token it prints as `Authorization: Bearer <token>`. In production the app trusts its OpenID Connect provider instead, set under `Authentication:Schemes:Bearer`.

The API never changes its schema itself (DAT-004): after a change to the model, add a migration with `dotnet ef migrations add <Name> --project sample/src/Bookmarks.Infrastructure --startup-project sample/src/Bookmarks.Api`, read it, and run `dotnet ef database update` again. A test fails while the model has a change no migration covers. In Development it serves its OpenAPI document at `/openapi/v1.json`; other environments don't (API-003). `GET /bookmarks` answers one page at a time (`?offset=0&limit=25`, at most 100) with a `nextLink` to the next, and every error is Problem Details (`docs/standards/api-design.md`). `/health` answers `Healthy` once the database is reachable, and `/alive` while the process runs. Outside Development it answers only for the hosts in `AllowedHosts` (`localhost` in `appsettings.json`), limits each caller's requests (`RateLimiting:BurstLimit` and `RateLimiting:RequestsPerSecond`) with a 429, and sends HSTS (SEC-011, `docs/standards/security.md`). To see its telemetry, set `OTEL_EXPORTER_OTLP_ENDPOINT` to an OTLP endpoint, such as the Aspire dashboard's.

## The API contract

`tests/Bookmarks.FunctionalTests/Contract/Bookmarks.Api/openapi-v1.json` is the committed contract, which the kit's shared `OpenApiTests` compares the document with. When the API changes, the contract test fails and writes `openapi-v1.received.json` beside it; review the difference, then copy it over the snapshot to accept it.
