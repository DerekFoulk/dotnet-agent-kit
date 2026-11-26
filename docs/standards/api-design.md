---
topic: api-design
rules:
  - id: API-001
    statement: "An app's API style is chosen in its plan: an HTTP API with Minimal APIs by default; gRPC, SignalR, controllers or GraphQL only where a Microsoft page recommends that style for the app's scenario (API-008) or the owner asks for it by name, and the plan says which."
    why: "Each style fits different callers, and switching later rewrites every client (GAP-010). The owner, 2026-11-17: gRPC, SignalR, controllers or GraphQL only \"if recommended or asked for specifically\"."
    layer: owner
    basis: preference
    status: accepted
    strength: should
    sources: ["owner, 2026-11-17", "ADR-0038"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the plan-checklist skill asks for the API style; the sample is a Minimal API"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/*.proto", "**/*Hub*.cs"]
  - id: API-008
    statement: "For new ASP.NET Core API projects, Minimal APIs are recommended; consider controller-based APIs if you need model binding extensibility, form binding support (including IFormFile), advanced validation features, application parts or the application model, or OData support. gRPC is well suited to microservices, point-to-point real-time communication, polyglot environments, network-constrained environments and inter-process communication; other frameworks are recommended over gRPC for browser-accessible APIs and for broadcast real-time communication, and SignalR is a useful framework for broadcasting."
    why: "Each style fits different callers; Microsoft's pages name the scenarios each one suits, and the kit's choice among them (API-001) starts from these."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For new projects, we recommend using Minimal APIs as they provide a simplified, high-performance approach for building APIs with minimal code and configuration."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Consider controller-based APIs if you need:"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Model binding extensibility (IModelBinderProvider, IModelBinder)"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Form binding support, including IFormFile"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Advanced validation features (IModelValidator)"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Application parts or the application model"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/apis?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "OData support"
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "gRPC is well suited to the following scenarios:"
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Microservices: gRPC is designed for low latency and high throughput communication."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Point-to-point real-time communication: gRPC has excellent support for bi-directional streaming."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Polyglot environments: gRPC tooling supports all popular development languages, making gRPC a good choice for multi-language environments."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Network constrained environments: gRPC messages are serialized with Protobuf, a lightweight message format."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Inter-process communication (IPC): IPC transports such as Unix domain sockets and named pipes can be used with gRPC to communicate between apps on the same machine."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Other frameworks are recommended over gRPC in the following scenarios:"
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Browser accessible APIs: gRPC isn't fully supported in the browser."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Broadcast real-time communication: gRPC supports real-time communication via streaming, but the concept of broadcasting a message out to registered connections doesn't exist."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/comparison?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "SignalR is a useful framework for this scenario. SignalR has the concept of persistent connections and built-in support for broadcasting messages."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the plan-checklist skill asks for the API style and the page that recommends it"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/*.proto", "**/*Hub*.cs"]
  - id: API-002
    statement: "Every HTTP API error response is Problem Details (RFC 9457): AddProblemDetails, UseExceptionHandler and UseStatusCodePages; a client error such as malformed input stays a 400 in every environment, and outside Development a 500 never carries the exception's message or stack."
    why: "Clients handle one error format whichever error it is, and exception details would tell an attacker how the app is built (GAP-011)."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["ADR-0038", "owner, 2026-11-09", "https://www.rfc-editor.org/rfc/rfc9457, retrieved 2026-11-07", "https://learn.microsoft.com/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check that a 400, 404, 409, 415 and 500 are Problem Details, that malformed input is a 400 in Development, that a 500 in Production hides the exception, and that every error the OpenAPI document declares is Problem Details"
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): ErrorTests checks that a route that doesn't exist is a 404 Problem, and that an unhandled exception is a 500 Problem without its message in Production, unless the app says it serves no HTTP API; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: advisory
        in: [app]
        how: "the app's own errors (malformed input a 400 in Development too, its other 4xx, and the errors its OpenAPI document declares), until its own FunctionalTests check them, as the sample's do"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/*Error*.cs"]
  - id: API-003
    statement: "An HTTP API describes itself with the built-in OpenAPI document (Microsoft.AspNetCore.OpenApi) and typed results; the document, and any UI for it such as Scalar or Swagger UI, is mapped in Development only; a contract test snapshots the document, so every change to the API shows in review."
    why: "The document is the API's contract and the source for generated clients, but published in production it maps the whole API for an attacker; Microsoft's Web API template restricts the OpenAPI endpoint to Development (GAP-011). What Microsoft says about the UIs for the document is API-009."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["ADR-0038", "owner, 2026-11-09", "https://learn.microsoft.com/aspnet/core/fundamentals/openapi/overview?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/openapi/overview?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The OpenAPI endpoint is restricted to the Development environment to minimize the risk of exposing sensitive information and reduce the vulnerabilities in production."
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's ContractTests compare the document with its snapshot"
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): OpenApiTests checks that the document is served in Development, to an anonymous caller too, and not in Production, unless the app says it serves no HTTP API; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: advisory
        in: [app]
        how: "the snapshot of the document and typed results, until the app's own ContractTests snapshot it, as the sample's do"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/Contract/**"]
  - id: API-004
    statement: "Every HTTP endpoint that lists a collection pages it in the data store, in a deterministic order, with limit (default 25, at most 100) and offset (at most 10,000) query parameters, and answers an object with the page's items and a nextLink to the next page, null on the last page or the last one the offset cap allows."
    why: "A list without a cap returns the whole table, which is slow and an easy denial of service. what Azure's API design guidance says (limit and offset with meaningful defaults such as 25, consider an upper limit, a next-page link) is API-011; the cap of 100, the offset ceiling of 10,000 and the response's shape are the kit's (ADR-0038, GAP-011)."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["ADR-0038", "owner, 2026-11-09", "https://learn.microsoft.com/azure/architecture/best-practices/api-design#implement-data-pagination-and-filtering, retrieved 2026-11-17", "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation#handling-large-requests-and-responses, retrieved 2026-11-17", "https://learn.microsoft.com/sql/connect/ado-net/sql/compare-guid-uniqueidentifier-values, retrieved 2026-11-08"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's tests check the pages and nextLink (FunctionalTests), the extra row that says another page follows, a full last page, the last page the offset cap allows and the service's own limits at and past their edges (Application.Tests), pages in creation order whatever order the rows were saved in (IntegrationTests) and time-ordered ids (Domain.Tests)"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: [web-api, blazor]
    paths: ["**/*Endpoints*.cs", "**/*Repository*.cs", "**/*Contracts*/**"]
  - id: API-005
    statement: "An HTTP API isn't versioned until its first breaking change to a contract that another app or a released client depends on; that change gets an ADR that picks how versions are told apart (URI, query string or header) and the package, a new version, and the earlier version stays until its callers move."
    why: "Versioning from day one adds a package and routes nobody uses yet, but a breaking change without a new version breaks every existing client; Azure's guidance says that no versioning can work for some internal APIs, and to introduce a new version on a breaking change (API-012, GAP-011)."
    layer: owner
    basis: preference
    status: accepted
    strength: should
    sources: ["ADR-0038", "https://learn.microsoft.com/azure/architecture/best-practices/api-design#implement-versioning, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design#implement-versioning"
        retrieved: "2026-11-17"
        text: "This approach is the simplest and can work for some internal APIs."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the contract snapshot test (API-003) shows every change to the API in review, where a breaking one is caught; no tool can tell which change breaks a caller"
    scope: [web-api, blazor]
    paths: ["**/*Endpoints*.cs", "**/Contract/**"]
  - id: API-006
    statement: "A Minimal API validates its inputs with the built-in validation (AddValidation and DataAnnotations attributes on parameters and request types), so invalid input gets a 400 validation problem before the handler runs; a domain rule (such as a bookmark's URL being http or https) stays in the domain, and the endpoint turns its exception into a 400 Problem."
    why: "Validation in one place, from attributes the OpenAPI document also shows, instead of checks scattered through handlers; it is built into .NET 10, so it needs no package (GAP-011). Microsoft's pages describe what the built-in validation does and allows; they don't recommend it over other validation, so this is the kit's choice (ADR-0038)."
    layer: owner
    basis: preference
    status: accepted
    strength: should
    sources: ["ADR-0038", "https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis?view=aspnetcore-10.0#validation-support-in-minimal-apis, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/fundamentals/validation?view=aspnetcore-10.0, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check that an out-of-range limit or offset, and a create request with a missing, blank or too-long field, are validation problems"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: [web-api]
    paths: ["**/Program.cs", "**/*Endpoints*.cs", "**/*Contracts*/**"]
  - id: API-007
    statement: "In an HTTP API, when possible, base resource URIs on nouns and not verbs, and avoid using verbs in URIs to represent operations; a POST that creates a resource synchronously should return 201 Created and identify the resource in the Location header; GET, HEAD, PUT and DELETE must be idempotent; and for work that takes time, consider making the method asynchronous: an asynchronous method should return 202 Accepted, include the status endpoint's URI in the 202's Location header, and if the operation creates a new resource, the status endpoint should return 303 See Other after it completes, with a Location header that gives the new resource's URI."
    why: "Clients, caches and retries rely on what each method and status code promises: a retried PUT must not change anything twice, and a client finds what it created at Location (rules audit, owner 2026-11-12). The kit's naming convention for collections is API-013."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/azure/architecture/best-practices/api-design, retrieved 2026-11-17", "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design"
        retrieved: "2026-11-17"
        text: "When possible, base resource URIs on nouns (the resource) and not verbs (the operations on the resource)."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design"
        retrieved: "2026-11-17"
        text: "Avoid using verbs in URIs to represent operations."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation"
        retrieved: "2026-11-17"
        text: "For example, a POST operation that creates a resource synchronously should return 201 (Created) and identify the resource in the Location response header."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation"
        retrieved: "2026-11-17"
        text: "GET, HEAD, PUT, and DELETE must be idempotent, so repeating an identical request has the same intended effect as performing it once."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design"
        retrieved: "2026-11-17"
        text: "In this scenario, consider making the method asynchronous. An asynchronous method should return HTTP status code 202 (Accepted) to indicate that the request was accepted for processing but is incomplete."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design"
        retrieved: "2026-11-17"
        text: "Include the URI of the status endpoint in the Location header of the 202 response."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design"
        retrieved: "2026-11-17"
        text: "If the asynchronous operation creates a new resource, the status endpoint should return status code 303 (See Other) after the operation completes. In the 303 response, include a Location header that gives the URI of the new resource"
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check that POST /bookmarks answers 201 Created with Location /bookmarks/{id}, and that a GET of that Location returns the same bookmark (BookmarksApiTests)"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
      - kind: advisory
        in: [kit, app]
        how: "code review checks the rest: nouns for resources, idempotent PUT and DELETE, and 202 with a status endpoint for long work (whose status endpoint answers 303 See Other with the new resource's Location once the work is done), none of which an analyzer sees"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Endpoints*.cs"]
  - id: API-009
    statement: "OpenAPI user interfaces (Swagger UI, ReDoc, Scalar) should only be enabled in development environments."
    why: "Microsoft gives it as a security best practice on limiting information disclosure. Split from API-003, which maps the document itself in Development only and snapshots it."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    ratified: "owner, 2026-11-09"
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/openapi/using-openapi-documents?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/openapi/using-openapi-documents?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "OpenAPI user interfaces (Swagger UI, ReDoc, Scalar) should only be enabled in development environments."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that a UI for the document is mapped in Development only"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Endpoints*.cs"]
  - id: API-010
    statement: "In non-development environments, use the exception handler middleware to produce an error payload. Don't enable the Developer Exception Page unless the app is running in the Development environment, and don't share detailed exception information publicly when the app runs in production."
    why: "Microsoft's error-handling page gives both. Split from API-002, which also makes every error Problem Details, keeps a client error a 400 in every environment, and gates a 500's message."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    unconditional: "'unless the app is running in the Development environment' and 'when the app runs in production' name environments every app has; the statement carries them"
    ratified: "owner, 2026-11-09"
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In non-development environments, use the exception handler middleware to produce an error payload."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't enable the Developer Exception Page unless the app is running in the Development environment. Don't share detailed exception information publicly when the app runs in production."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the handler and the Developer Exception Page; API-002's ErrorTests gate that a production 500 hides the exception"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Error*.cs"]
  - id: API-011
    statement: "For an endpoint that returns a collection, use limit and offset query parameters with meaningful defaults, such as limit=25 and offset=0, and consider an upper limit on the number of items returned. Apply pagination in the data store, not after loading the entire collection, with a deterministic sort order; include a next-page link or continuation token in the response, omitted or null on the last page; and for a large or frequently changing collection, evaluate cursor-based pagination."
    why: "Microsoft's API design and implementation guidance give these. Split from API-004, which fixes the kit's numbers (default 25, at most 100, offset at most 10,000) and the response's shape, and gates them."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    ratified: "owner, 2026-11-09"
    sources: ["https://learn.microsoft.com/azure/architecture/best-practices/api-design#implement-data-pagination-and-filtering, retrieved 2026-11-17", "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation#handling-large-requests-and-responses, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design#implement-data-pagination-and-filtering"
        retrieved: "2026-11-17"
        text: "Use query parameters like limit to specify the number of items to return and offset to specify the starting point. Make sure to also provide meaningful defaults for limit and offset, such as limit=25 and offset=0."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-design#implement-data-pagination-and-filtering"
        retrieved: "2026-11-17"
        text: "To help prevent denial-of-service attacks, consider imposing an upper limit on the number of items returned."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation#handling-large-requests-and-responses"
        retrieved: "2026-11-17"
        text: "Beyond the request validation shown in the preceding example, include a next-page link or continuation token in the response contract."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation#handling-large-requests-and-responses"
        retrieved: "2026-11-17"
        text: "Omit nextLink or set it to null on the last page."
      - source: "https://learn.microsoft.com/azure/architecture/best-practices/api-implementation#handling-large-requests-and-responses"
        retrieved: "2026-11-17"
        text: "Apply filtering and pagination in the data store, not after loading the entire collection. Use a deterministic sort order. For large or frequently changing collections, evaluate cursor-based pagination to avoid expensive offsets and unstable page boundaries."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks it; API-004's tests gate the kit's numbers, the page's next link and the paging in the data store"
    scope: [web-api, blazor]
    paths: ["**/*Endpoints*.cs", "**/*Repository*.cs", "**/*Contracts*/**"]
  - id: API-012
    statement: "Support versioning in the API contract: when you introduce a breaking API change, introduce a new API version, continue to support the previous version, and let clients select which version to call. Make API changes backward compatible when possible."
    why: "Microsoft's microservices API design page says so. API-005, the kit's rule, decides when versioning starts and who picks the scheme."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/azure/architecture/microservices/design/api-design#api-versioning, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/architecture/microservices/design/api-design#api-versioning"
        retrieved: "2026-11-17"
        text: "Support versioning in your API contract. If you introduce a breaking API change, introduce a new API version. Continue to support the previous version, and let clients select which version to call."
      - source: "https://learn.microsoft.com/azure/architecture/microservices/design/api-design#api-versioning"
        retrieved: "2026-11-17"
        text: "Make API changes backward compatible when possible."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the contract snapshot test (API-003) shows every change to the API in review, where a breaking one is caught; no tool can tell which change breaks a caller"
    scope: [web-api, blazor]
    paths: ["**/*Endpoints*.cs", "**/Contract/**"]
  - id: API-013
    statement: "An HTTP API's URIs name a collection with a plural noun, and use a verb sparingly, only for an operation that isn't a resource."
    why: "One naming convention for every app's routes (rules audit, owner 2026-11-12). The part of Azure's guidance on nouns and verbs is API-007."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-11-12"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the routes"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", "**/*Endpoints*.cs"]
---

# API design

How an app exposes itself to callers: which kind of API, and the conventions every HTTP API follows (GAP-010 and GAP-011, ADR-0038).

The reference is the sample's API, `sample/src/Bookmarks.Api`. Everything it uses is built into .NET 10, so following it adds no package.

## Choosing the style (API-001, API-008)

API-008 holds what Microsoft says, and API-001 is the owner's rule on top of it.

- **What Microsoft says (API-008):** for new ASP.NET Core API projects, Minimal APIs are recommended. Consider controller-based APIs if you need model binding extensibility, form binding support (including `IFormFile`), advanced validation features, application parts or the application model, or OData support. gRPC is well suited to microservices, point-to-point real-time communication, polyglot environments, network-constrained environments and inter-process communication. Other frameworks are recommended over gRPC for browser-accessible APIs and for broadcast real-time communication, and SignalR is a useful framework for broadcasting. Only Minimal APIs and those other frameworks are recommended in so many words: the page suggests considering controllers and calls gRPC well suited.
- **What the owner decided (API-001, 2026-11-17):** an HTTP API with Minimal APIs is the default. gRPC, SignalR, controllers or GraphQL come only where a Microsoft page recommends that style for the app's scenario (API-008) or the owner asks for it by name, and the plan says which. GraphQL has no Microsoft recommendation in API-008, so it takes the owner's request.

An app can mix styles, for example an HTTP API for its UI and SignalR for live updates, each one chosen as above.

## HTTP API conventions

- **Errors (API-002):** register `AddProblemDetails()`, then call `UseExceptionHandler()` and `UseStatusCodePages()` early in the pipeline. In .NET 10, give the exception handler a `StatusCodeSelector` that keeps a `BadHttpRequestException`'s own status: in Development a binding failure (malformed JSON, `?limit=abc`) throws one, and the handler would otherwise answer 500. ASP.NET Core 11 keeps that status by itself. Declare each error with `ProducesProblem`, so the OpenAPI document shows its body. A handler returns `TypedResults.Problem`, `ValidationProblem`, `NotFound` or `Conflict`; status code pages give an empty error response its Problem Details body.
- **OpenAPI (API-003):** `AddOpenApi()`, and `MapOpenApi()` inside `if (app.Environment.IsDevelopment())`. Typed results (`Results<Ok<T>, NotFound>`) describe each success; `ProducesProblem` and `ProducesValidationProblem` describe each error body. A contract test checks that every error in the document is Problem Details. A UI such as Scalar is a package; add it in Development only.
- **Pages (API-004):** the sample's `GET /bookmarks?offset=0&limit=25` answers `{ "items": [...], "nextLink": "/bookmarks?offset=25&limit=25" }`. The service asks the repository for one row more than the page, so it knows whether another page follows without counting the table, and refuses a page outside the limits even when the endpoint's check is bypassed. Order by something that sorts in creation order, so a new row lands on the last page instead of shifting earlier ones. On SQLite, which stores Guids as text, a UUID version 7 key does that (`Guid.CreateVersion7`), as in the sample, to the millisecond. On SQL Server it doesn't: `uniqueidentifier` treats the last six bytes as the most significant, so order by a creation-time column with the key as the tie-breaker. On any other database, check how it compares Guids before relying on the key. Either way, rows with the same timestamp, or written on clocks that disagree, can come in either order; for a collection where that matters, use cursor paging. The last page reachable within the offset cap links nowhere, even when more rows exist; reading deeper needs cursor paging too. The sample's `nextLink` is a relative path; behind a proxy that adds a path prefix, or with filters or sorting, build it with `LinkGenerator` and carry those query values; Azure's guide says to preserve filters, sort order and API version in the link. For a large or frequently changing collection, Azure's guide says to evaluate cursor-based paging (API-011); the kit asks for an ADR when an app takes it.
- **Versioning (API-005):** none until the first breaking change that a caller depends on. Adding a field isn't breaking; removing or renaming one is. The contract test makes every change visible, so the review decides. The likely package then is `Asp.Versioning.Http`, from the .NET Foundation's `dotnet/aspnet-api-versioning`; Microsoft Learn doesn't cover it, so its ADR checks it first.
- **HTTP semantics (API-007):** the sample's `POST /bookmarks` answers `TypedResults.Created($"/bookmarks/{bookmark.Id}", bookmark)`, so the client finds what it created at `Location`. A `PUT` replaces the whole resource and gives the same result however often it's sent. Long work answers `202 Accepted` with a `Location` that points at a status endpoint, which answers `303 See Other` with the new resource's `Location` once the work is done (Azure's [Asynchronous Request-Reply pattern](https://learn.microsoft.com/azure/architecture/patterns/asynchronous-request-reply)).
- **Validation (API-006):** `AddValidation()`, then `[Range]`, `[Required]` and the other DataAnnotations attributes on parameters and request records. In .NET 10, attributes on a nullable value-type parameter are ignored when the client passes no value (dotnet/aspnetcore#67033, fixed for .NET 11, retrieved 2026-11-08), so give such parameters a default instead of making them nullable. On a record, target the properties (`[property: Required, MaxLength(500)] string Title`): the validation reads them there, and so does the OpenAPI document, which then shows `maxLength`. `[MaxLength]` throws on a `Uri`, so the sample adds a `UriLength` attribute. SEC-010 says every input gets a bound.

## Calling other APIs

- **Generated clients:** when an app calls an HTTP API that publishes an OpenAPI document, generate the client with Kiota (Microsoft's generator, a .NET tool). Installing a tool is the owner's call. Register the client through `IHttpClientFactory`, so it gets the resilience defaults (OPS-003).
- **Calls between the app's own services** follow the same rules as any other client.

## Pending ratification

API-001, API-005, API-006 and API-008 were added in auto mode (ADR-0035), so they stay `proposed` until you accept them, as does API-012, the Microsoft half of API-005. You accepted API-002 to API-004 on 2026-11-09, and chose to wait on API-001, API-005 and API-006 until the first real app uses them. API-009, API-010 and API-011 are the Microsoft halves split from API-003, API-002 and API-004, and carry your acceptance of them. API-007 and API-013 came from the rules audit, which you accepted on 2026-11-12.

A rule with `basis: authority` says only what its cited page says, at the page's strength, and stores the sentence; the kit's own numbers and tightenings are preferences beside it (API-002 and API-010, API-003 and API-009, API-004 and API-011, API-005 and API-012, API-007 and API-013).
