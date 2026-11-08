# ADR-0038: Choose the API style in the plan, and give HTTP APIs Microsoft's built-in conventions

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

The quality scorecard lists two API design gaps (ADR-0034):
- **GAP-010:** no guidance on choosing an API style (HTTP APIs, gRPC, SignalR or GraphQL);
- **GAP-011:** no HTTP API conventions (Problem Details, versioning, pagination), and no guidance on API packages (OpenAPI, Scalar, Asp.Versioning, client generation).

The sample's API was a Minimal API with typed results, the built-in OpenAPI document and a contract snapshot test. But:
- its 404 and 409 had empty bodies;
- it served the OpenAPI document in every environment;
- `GET /bookmarks` returned the whole table.

.NET 10 has built-in answers to each: `AddProblemDetails`, the Development-only `MapOpenApi` from Microsoft's templates, and `AddValidation`. Azure's API design guide gives the paging and versioning conventions. The kit gives apps no starter projects (ADR-0032), so the sample is the reference. This ADR was decided in auto mode (ADR-0035).

## Options

### Option 1: The built-in pieces, with Azure's conventions, and no new packages

- **Style (API-001):** chosen in each plan. Minimal APIs are the default, as Microsoft recommends for new projects; gRPC for calls between the app's own services; SignalR for push. Controllers or GraphQL need an ADR.
- **Errors (API-002):** Problem Details for every error.
- **OpenAPI (API-003):** the document in Development only, snapshotted by the contract test.
- **Paging (API-004):** `limit` (default 25, at most 100) and `offset` (at most 10,000), with a `nextLink`, paged in the database.
- **Versioning (API-005):** none until the first breaking change a caller depends on.
- **Validation (API-006):** the built-in `AddValidation`.

Assessment:
- **Trade-offs:** nothing to install or keep up to date, and every piece is in Microsoft's docs, where agents and people look first. Offset paging is simple but slow at deep offsets, so the offset is capped; a large collection can move to cursor paging by ADR.
- **Reversibility:** easy. Each piece is a line or two in `Program.cs` or one endpoint.
- **Risk:** low. The response of `GET /bookmarks` changed from an array to a page object, but the sample has no callers.

### Option 2: Add the popular packages now

That means `Asp.Versioning.Http` for versioning, `Scalar.AspNetCore` for a UI, and FluentValidation or `Hellang.Middleware.ProblemDetails`.

- **Trade-offs:** more features from day one. But that's three or four packages to keep updated, versioning that no caller needs yet, and a UI that may only run in Development anyway. The built-in validation and Problem Details now cover what the last two added.
- **Reversibility:** medium. Removing a package touches every endpoint that uses it.
- **Risk:** medium: more supply chain, and features nobody uses yet.

### Option 3: Leave conventions to each app

- **Trade-offs:** nothing to maintain. But every app answers the same questions again, or doesn't, which is the gap.
- **Reversibility:** easy.
- **Risk:** medium: inconsistent errors, and lists that return whole tables.

## Recommendation

Option 1: Microsoft's built-in pieces cover every convention, with no package to maintain, and the sample proves them with tests.

## Decision

Accepted, in auto mode (ADR-0035). The six rules stay `proposed` until the owner ratifies them. The owner can reverse this, as with any merged change.

## Consequences

- **Rules:** API-001 to API-006, proposed, in `docs/standards/api-design.md`.
- **Plans:** the `plan-checklist` skill asks for the API style.
- **The sample:**
  - every error response is Problem Details, and a 500 in Production hides the exception. A binding failure keeps its 400 in Development too, through the exception handler's `StatusCodeSelector` (review 1 of PR 22), and the OpenAPI document declares each error body;
  - the OpenAPI document is mapped in Development only;
  - `GET /bookmarks` answers a `BookmarkPage`. The repository pages in the database, ordered by key. Bookmarks now get UUID version 7 keys made from their creation time, so on SQLite key order is creation order, to the millisecond (review 1 of PR 22). That holds where Guids compare as text, as on SQLite, or as bytes in RFC 9562 order, but not on SQL Server, whose `uniqueidentifier` puts the last six bytes first; there, an app orders by a creation-time column with the key as tie-breaker (review 2). Ordering by `CreatedAt` would need a converter: SQLite can't order by a `DateTimeOffset`.
  - the last page reachable within the offset cap has no `nextLink`, so a client following the links never gets a 400 (review 3);
  - the service refuses a page outside the limits itself, so a caller that bypasses the endpoint can't overflow `limit + 1` into SQLite's "no limit".
  - `limit` and `offset` are validated by `AddValidation`.
- **Tests:**
  - FunctionalTests: the error formats, the hidden 500, the 400 for malformed input in Development and the 415 for a wrong content type, the error bodies in the document, the document in Production, the pages and their link, and the validation;
  - Application.Tests: the extra row that says another page follows, a full last page, the last page the offset cap allows, and the service's own limits;
  - IntegrationTests: stable, non-overlapping pages in creation order, whatever order the rows were saved in;
  - Domain.Tests: ids that sort in creation order.
- **GAP-010 and GAP-011 are closed** in the scorecard.
- **Packages:** none added. A UI such as Scalar, a client generator such as Kiota, or `Asp.Versioning.Http` is added by an app when needed. In review mode that needs the owner's OK; installing a tool always does.
- **Not checked:** a gRPC or SignalR app, because none exists. API-001 stays advisory until one does.

## Pillars affected

- **Security:** no exception details in production, the OpenAPI document in Development only, and capped pages against an easy denial of service.
- **Reliability:** validation rejects bad input before the handler runs.
- **Performance Efficiency:** pages are cut in the database, and the extra row avoids counting the table.
- **Operational Excellence:** one error format, and a contract snapshot that shows every API change in review.
- **Cost Optimization:** no new package or service.

## Sources

- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/apis, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/aspnet/core/grpc/comparison, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api, retrieved 2026-11-08
- https://www.rfc-editor.org/rfc/rfc9457, retrieved 2026-11-07
- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/overview, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/using-openapi-documents, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-implementation, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/azure/architecture/microservices/design/api-design, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/validation, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/openapi/kiota/overview, retrieved 2026-11-08
- https://github.com/dotnet/aspnetcore/issues/67033, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/sql/connect/ado-net/sql/compare-guid-uniqueidentifier-values, retrieved 2026-11-08
