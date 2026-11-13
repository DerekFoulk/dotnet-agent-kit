---
topic: api-design
rules:
  - id: API-001
    statement: "An app's API style is chosen in its plan: an HTTP API with Minimal APIs by default; gRPC for calls between the app's own services that need streaming or high throughput, never called straight from a browser; SignalR for pushing messages to many connected clients; controllers or GraphQL only with an ADR."
    why: "Each style fits different callers, and switching later rewrites every client. Microsoft recommends Minimal APIs for new projects, and says gRPC suits microservices and point-to-point streaming but not browsers or broadcast (GAP-010)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/apis, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/grpc/comparison, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction, retrieved 2026-11-08"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the plan-checklist skill asks for the API style; the sample is a Minimal API"
    scope: core
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/*.proto", "**/*Hub*.cs"]
  - id: API-002
    statement: "Every HTTP API error response is Problem Details (RFC 9457): AddProblemDetails, UseExceptionHandler and UseStatusCodePages; a client error such as malformed input stays a 400 in every environment, and outside Development a 500 never carries the exception's message or stack."
    why: "Clients handle one error format whichever error it is, and exception details would tell an attacker how the app is built (GAP-011)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["ADR-0038", "https://www.rfc-editor.org/rfc/rfc9457, retrieved 2026-11-07", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api, retrieved 2026-11-08", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check that a 400, 404, 409, 415 and 500 are Problem Details, that malformed input is a 400 in Development, that a 500 in Production hides the exception, and that every error the OpenAPI document declares is Problem Details"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: core
    paths: ["**/Program.cs", "**/*Endpoints*.cs"]
  - id: API-003
    statement: "An HTTP API describes itself with the built-in OpenAPI document (Microsoft.AspNetCore.OpenApi) and typed results; the document, and any UI for it such as Scalar or Swagger UI, is mapped in Development only; a contract test snapshots the document, so every change to the API shows in review."
    why: "The document is the API's contract and the source for generated clients, but published in production it maps the whole API for an attacker; Microsoft's templates map it in Development only (GAP-011)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/overview, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/using-openapi-documents, retrieved 2026-11-08", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's ContractTests compare the document with its snapshot and check it isn't served in Production"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: core
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/Contract/**"]
  - id: API-004
    statement: "Every HTTP endpoint that lists a collection pages it in the data store, in a deterministic order, with limit (default 25, at most 100) and offset (at most 10,000) query parameters, and answers an object with the page's items and a nextLink to the next page, null on the last page or the last one the offset cap allows."
    why: "A list without a cap returns the whole table, which is slow and an easy denial of service; Azure's API design guidance asks for limit and offset with meaningful defaults, an upper limit, and a next-page link (GAP-011)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design#implement-data-pagination-and-filtering, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-implementation#handling-large-requests-and-responses, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/sql/connect/ado-net/sql/compare-guid-uniqueidentifier-values, retrieved 2026-11-08", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's tests check the pages and nextLink (FunctionalTests), the extra row that says another page follows, a full last page, the last page the offset cap allows and the service's own limits at and past their edges (Application.Tests), pages in creation order whatever order the rows were saved in (IntegrationTests) and time-ordered ids (Domain.Tests)"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: core
    paths: ["**/*Endpoints*.cs", "**/*Repository*.cs", "**/*Contracts*/**"]
  - id: API-005
    statement: "An HTTP API isn't versioned until its first breaking change to a contract that another app or a released client depends on; that change gets an ADR that picks how versions are told apart (URI, query string or header) and the package, a new version, and the earlier version stays until its callers move."
    why: "Versioning from day one adds a package and routes nobody uses yet, but a breaking change without a new version breaks every existing client; Azure's guidance allows no versioning for internal APIs and asks for a new version on a breaking change (GAP-011)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design#implement-versioning, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/azure/architecture/microservices/design/api-design#api-versioning, retrieved 2026-11-08"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the contract snapshot test (API-003) shows every change to the API in review, where a breaking one is caught; no tool can tell which change breaks a caller"
    scope: core
    paths: ["**/*Endpoints*.cs", "**/Contract/**"]
  - id: API-006
    statement: "A Minimal API validates its inputs with the built-in validation (AddValidation and DataAnnotations attributes on parameters and request types), so invalid input gets a 400 validation problem before the handler runs; a domain rule (such as a bookmark's URL being http or https) stays in the domain, and the endpoint turns its exception into a 400 Problem."
    why: "Validation in one place, from attributes the OpenAPI document also shows, instead of checks scattered through handlers; it is built into .NET 10, so it needs no package (GAP-011)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis#validation-support-in-minimal-apis, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/validation, retrieved 2026-11-08"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check that an out-of-range limit or offset, and a create request with a missing, blank or too-long field, are validation problems"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: core
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/*Contracts*/**"]
---

# API design

How an app exposes itself to callers: which kind of API, and the conventions every HTTP API follows (GAP-010 and GAP-011, ADR-0038).

The reference is the sample's API, `sample/src/Bookmarks.Api`. Everything it uses is built into .NET 10, so following it adds no package.

## Choosing the style (API-001)

| Callers | Style |
|---|---|
| Browsers, mobile apps, other teams, anything over the internet | HTTP API with Minimal APIs |
| The app's own services calling each other, with streaming or high throughput | gRPC |
| Many clients that the server pushes messages to (chat, live dashboards, notifications) | SignalR |
| A need that Minimal APIs don't cover, such as OData or MVC filters and conventions | Controllers, with an ADR |
| Clients that each shape their own queries over a large graph of data | GraphQL, with an ADR (Microsoft ships no GraphQL server, so it means a third-party package) |

An app can mix them, for example an HTTP API for its UI and SignalR for live updates.

## HTTP API conventions

- **Errors (API-002):** register `AddProblemDetails()`, then call `UseExceptionHandler()` and `UseStatusCodePages()` early in the pipeline. In .NET 10, give the exception handler a `StatusCodeSelector` that keeps a `BadHttpRequestException`'s own status: in Development a binding failure (malformed JSON, `?limit=abc`) throws one, and the handler would otherwise answer 500. ASP.NET Core 11 keeps that status by itself. Declare each error with `ProducesProblem`, so the OpenAPI document shows its body. A handler returns `TypedResults.Problem`, `ValidationProblem`, `NotFound` or `Conflict`; status code pages give an empty error response its Problem Details body.
- **OpenAPI (API-003):** `AddOpenApi()`, and `MapOpenApi()` inside `if (app.Environment.IsDevelopment())`. Typed results (`Results<Ok<T>, NotFound>`) describe each success; `ProducesProblem` and `ProducesValidationProblem` describe each error body. A contract test checks that every error in the document is Problem Details. A UI such as Scalar is a package; add it in Development only.
- **Pages (API-004):** the sample's `GET /bookmarks?offset=0&limit=25` answers `{ "items": [...], "nextLink": "/bookmarks?offset=25&limit=25" }`. The service asks the repository for one row more than the page, so it knows whether another page follows without counting the table, and refuses a page outside the limits even when the endpoint's check is bypassed. Order by something that sorts in creation order, so a new row lands on the last page instead of shifting earlier ones. On SQLite, which stores Guids as text, a UUID version 7 key does that (`Guid.CreateVersion7`), as in the sample, to the millisecond. On SQL Server it doesn't: `uniqueidentifier` treats the last six bytes as the most significant, so order by a creation-time column with the key as the tie-breaker. On any other database, check how it compares Guids before relying on the key. Either way, rows with the same timestamp, or written on clocks that disagree, can come in either order; for a collection where that matters, use cursor paging. The last page reachable within the offset cap links nowhere, even when more rows exist; reading deeper needs cursor paging too. The sample's `nextLink` is a relative path; behind a proxy that adds a path prefix, or with filters or sorting, build it with `LinkGenerator` and carry those query values, as Azure's guide asks. For a large or fast-changing collection, Azure's guide suggests cursor-based paging instead, with an ADR.
- **Versioning (API-005):** none until the first breaking change that a caller depends on. Adding a field isn't breaking; removing or renaming one is. The contract test makes every change visible, so the review decides. The likely package then is `Asp.Versioning.Http`, from the .NET Foundation's `dotnet/aspnet-api-versioning`; Microsoft Learn doesn't cover it, so its ADR checks it first.
- **Validation (API-006):** `AddValidation()`, then `[Range]`, `[Required]` and the other DataAnnotations attributes on parameters and request records. In .NET 10, attributes on a nullable value-type parameter are ignored when the client passes no value (dotnet/aspnetcore#67033, fixed for .NET 11, retrieved 2026-11-08), so give such parameters a default instead of making them nullable. On a record, target the properties (`[property: Required, MaxLength(500)] string Title`): the validation reads them there, and so does the OpenAPI document, which then shows `maxLength`. `[MaxLength]` throws on a `Uri`, so the sample adds a `UriLength` attribute. SEC-010 says every input gets a bound.

## Calling other APIs

- **Generated clients:** when an app calls an HTTP API that publishes an OpenAPI document, generate the client with Kiota (Microsoft's generator, a .NET tool). Installing a tool is the owner's call. Register the client through `IHttpClientFactory`, so it gets the resilience defaults (OPS-003).
- **Calls between the app's own services** follow the same rules as any other client.

## Pending ratification

API-001, API-005 and API-006 were added in auto mode (ADR-0035), so they stay `proposed` until you accept them. You accepted API-002 to API-004 on 2026-11-09, and chose to wait on these three until the first real app uses them.
