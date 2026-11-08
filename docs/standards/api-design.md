---
topic: api-design
rules:
  - id: API-001
    statement: "An app's API style is chosen in its plan: an HTTP API with Minimal APIs by default; gRPC for calls between the app's own services that need streaming or high throughput, never called straight from a browser; SignalR for pushing messages to many connected clients; controllers or GraphQL only with an ADR."
    why: "Each style fits different callers, and switching later rewrites every client. Microsoft recommends Minimal APIs for new projects, and says gRPC suits microservices and point-to-point streaming but not browsers or broadcast (GAP-010)."
    layer: outside
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/apis, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/grpc/comparison, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction, retrieved 2026-11-08"]
    enforcement: "advisory: the plan-checklist skill asks for the API style; the sample is a Minimal API"
    scope: core
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/*.proto", "**/*Hub*.cs"]
  - id: API-002
    statement: "Every HTTP API error response is Problem Details (RFC 9457): AddProblemDetails, UseExceptionHandler and UseStatusCodePages; outside Development a 500 never carries the exception's message or stack."
    why: "Clients handle one error format whichever error it is, and exception details would tell an attacker how the app is built (GAP-011)."
    layer: outside
    status: proposed
    sources: ["ADR-0038", "https://www.rfc-editor.org/rfc/rfc9457, retrieved 2026-11-07", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api, retrieved 2026-11-08"]
    enforcement: "ci: the sample's FunctionalTests check that a 400, 404, 409 and 500 are Problem Details, and that a 500 in Production hides the exception; advisory in an app until it follows the sample"
    scope: core
    paths: ["**/Program.cs", "**/*Endpoints*.cs"]
  - id: API-003
    statement: "An HTTP API describes itself with the built-in OpenAPI document (Microsoft.AspNetCore.OpenApi) and typed results; the document, and any UI for it such as Scalar or Swagger UI, is mapped in Development only; a contract test snapshots the document, so every change to the API shows in review."
    why: "The document is the API's contract and the source for generated clients, but published in production it maps the whole API for an attacker; Microsoft's templates map it in Development only (GAP-011)."
    layer: outside
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/overview, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/using-openapi-documents, retrieved 2026-11-08"]
    enforcement: "ci: the sample's ContractTests compare the document with its snapshot and check it isn't served in Production; advisory in an app until it follows the sample"
    scope: core
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/Contract/**"]
  - id: API-004
    statement: "Every HTTP endpoint that lists a collection pages it in the data store, in a deterministic order, with limit (default 25, at most 100) and offset (at most 10,000) query parameters, and answers an object with the page's items and a nextLink to the next page, null on the last."
    why: "A list without a cap returns the whole table, which is slow and an easy denial of service; Azure's API design guidance asks for limit and offset with meaningful defaults, an upper limit, and a next-page link (GAP-011)."
    layer: outside
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design#implement-data-pagination-and-filtering, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-implementation#handling-large-requests-and-responses, retrieved 2026-11-08"]
    enforcement: "ci: the sample's tests check the pages and nextLink (FunctionalTests), the extra row that says another page follows (Application.Tests) and stable, non-overlapping pages (IntegrationTests); advisory in an app until it follows the sample"
    scope: core
    paths: ["**/*Endpoints*.cs", "**/*Repository*.cs", "**/*Contracts*/**"]
  - id: API-005
    statement: "An HTTP API isn't versioned until its first breaking change to a contract that another app or a released client depends on; that change gets an ADR that picks how versions are told apart (URI, query string or header) and the package, a new version, and the earlier version stays until its callers move."
    why: "Versioning from day one adds a package and routes nobody uses yet, but a breaking change without a new version breaks every existing client; Azure's guidance allows no versioning for internal APIs and asks for a new version on a breaking change (GAP-011)."
    layer: outside
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design#implement-versioning, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/azure/architecture/microservices/design/api-design#api-versioning, retrieved 2026-11-08"]
    enforcement: "advisory: the contract snapshot test (API-003) shows every change to the API in review, where a breaking one is caught"
    scope: core
    paths: ["**/*Endpoints*.cs", "**/Contract/**"]
  - id: API-006
    statement: "A Minimal API validates its inputs with the built-in validation (AddValidation and DataAnnotations attributes on parameters and request types), so invalid input gets a 400 validation problem before the handler runs."
    why: "Validation in one place, from attributes the OpenAPI document also shows, instead of checks scattered through handlers; it is built into .NET 10, so it needs no package (GAP-011)."
    layer: outside
    status: proposed
    sources: ["ADR-0038", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis#validation-support-in-minimal-apis, retrieved 2026-11-08", "https://learn.microsoft.com/en-us/aspnet/core/fundamentals/validation, retrieved 2026-11-08"]
    enforcement: "ci: the sample's FunctionalTests check that an out-of-range limit or offset is a validation problem; advisory in an app until it follows the sample"
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

- **Errors (API-002):** register `AddProblemDetails()`, then call `UseExceptionHandler()` and `UseStatusCodePages()` early in the pipeline. A handler returns `TypedResults.Problem`, `ValidationProblem`, `NotFound` or `Conflict`; status code pages give an empty error response its Problem Details body.
- **OpenAPI (API-003):** `AddOpenApi()`, and `MapOpenApi()` inside `if (app.Environment.IsDevelopment())`. Typed results (`Results<Ok<T>, NotFound>`) let the document describe every response without attributes. A UI such as Scalar is a package; add it in Development only.
- **Pages (API-004):** the sample's `GET /bookmarks?offset=0&limit=25` answers `{ "items": [...], "nextLink": "/bookmarks?offset=25&limit=25" }`. The service asks the repository for one row more than the page, so it knows whether another page follows without counting the table. For a large or fast-changing collection, Azure's guide suggests cursor-based paging instead, with an ADR.
- **Versioning (API-005):** none until the first breaking change that a caller depends on. Adding a field isn't breaking; removing or renaming one is. The contract test makes every change visible, so the review decides. The likely package then is `Asp.Versioning.Http`, from the .NET Foundation's `dotnet/aspnet-api-versioning`; Microsoft Learn doesn't cover it, so its ADR checks it first.
- **Validation (API-006):** `AddValidation()`, then `[Range]`, `[Required]` and the other DataAnnotations attributes on parameters and request records. In .NET 10, validation of nullable value-type parameters is a known gap (dotnet/aspnetcore#67033), so give them a default instead of making them nullable.

## Calling other APIs

- **Generated clients:** when an app calls an HTTP API that publishes an OpenAPI document, generate the client with Kiota (Microsoft's generator, a .NET tool). Installing a tool is the owner's call. Register the client through `IHttpClientFactory`, so it gets the resilience defaults (OPS-003).
- **Calls between the app's own services** follow the same rules as any other client.

## Pending ratification

API-001 to API-006 were added in auto mode (ADR-0035), so they stay `proposed` until the owner accepts them.
