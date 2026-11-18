---
topic: aspnetcore
rules:
  - id: ASP-001
    statement: "Prefer requesting dependencies as constructor parameters over resolving services from RequestServices. Services resolved from the container should never be disposed by the developer. CRF-020 carries the rest of Microsoft's dependency injection guidance (the service locator pattern, stateful static classes and members, direct instantiation of dependent classes)."
    why: "Constructor parameters show what a class needs and make it easier to test, and the container already disposes the IDisposable services it creates, so disposing one by hand breaks the container's ownership of its lifetime."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer requesting dependencies as constructor parameters over resolving services from RequestServices."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Services resolved from the container should never be disposed by the developer."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for services resolved from HttpContext.RequestServices where a constructor parameter would do, and for Dispose calls on container-resolved services"
    paths: ["**/*.cs"]

  - id: ASP-002
    statement: "Never store passwords or other sensitive data in configuration provider code or in plain text configuration files, and don't use production secrets in development or test environments. Secrets shouldn't be deployed with the app. Using environment variables to store a production connection string is recommended against, as it's not the most secure approach. In complex app configuration scenarios, grouping and reading related hierarchical configuration data with the Options pattern is recommended."
    why: "A secret in a configuration file, in code or shipped with the app can be read by anyone who gets those files. OPS-006 and SEC-001 cover validating options and keeping secrets out of the repo."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/configuration?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/security/app-secrets?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/security?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/configuration?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Never store passwords or other sensitive data in configuration provider code or in plain text configuration files."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/configuration?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't use production secrets in development or test environments."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/configuration?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In complex app configuration scenarios, we recommend grouping and reading related hierarchical configuration data using the Options pattern."
      - source: "https://learn.microsoft.com/aspnet/core/security/app-secrets?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Secrets shouldn't be deployed with the app."
      - source: "https://learn.microsoft.com/aspnet/core/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend against using environment variables to store a production connection string as it's not the most secure approach."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks configuration files and provider code for secrets, and that settings are read through options classes; SEC-001's secret scan gates secrets in the repo"
    paths: ["**/appsettings*.json", "**/Program.cs", "**/*.cs"]

  - id: ASP-003
    statement: "Setting the minimum default log level in configuration, not in C# code, is recommended, and so is specifying log levels in configuration rather than in code with filter functions. If a logging data store is slow, don't write to it directly: consider writing the log messages to a fast store first and moving them to the slower store later. For example, don't write log messages directly to a SQL Server data store in a Log method, because Log methods are synchronous."
    why: "Levels in configuration can change without a rebuild, and a synchronous Log method that waits on a slow store slows every caller."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/logging?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/logging?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend setting the minimum default log level in configuration, not in C# code."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/logging?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend specifying log levels in configuration and not in code with filter functions."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/logging?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If a logging data store is slow, don't write to it directly."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/logging?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Consider writing the log messages to a fast store initially, then move the logs to the slower data store later."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/logging?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For example, don't write log messages directly to a SQL Server data store in a Log method because Log methods are synchronous."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for SetMinimumLevel, AddFilter with a function and custom logger providers that write synchronously to a slow store"
    paths: ["**/Program.cs", "**/*.cs"]

  - id: ASP-004
    statement: "Don't store sensitive data in session state. The site should continue to function without the session data: critical application data should be stored in the user database and cached in session only as a performance optimization. SignalR apps shouldn't use session state. Never use query strings for sensitive data, and the app must always revalidate the data stored in hidden fields."
    why: "Session data is a cache that can be lost, and the client can read a query string and change a hidden field."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't store sensitive data in session state."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The site should continue to function without the session data."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Critical application data should be stored in the user database and cached in session only as a performance optimization."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "SignalR apps shouldn't use session state and other state management approaches that rely upon a stable HTTP context to store information."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Because URL query strings are public, never use query strings for sensitive data."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Because the client can potentially tamper with the data, the app must always revalidate the data stored in hidden fields."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks session, TempData, query-string and hidden-field use for sensitive or unvalidated data"
    paths: ["**/*.cs", "**/*.cshtml", "**/*.razor"]

  - id: ASP-005
    statement: "A best practice is to never change state on a GET request. Using AutoValidateAntiforgeryToken broadly for non-API scenarios is recommended. Don't disable CSRF protection on browser-accessible endpoints that rely on cookies for authentication."
    why: "Another site can make a browser send a GET, and a cookie-authenticated endpoint without antiforgery validation accepts a forged request as the signed-in user's."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "A best practice is to never change state on a GET request."
      - source: "https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend use of AutoValidateAntiforgeryToken broadly for non-API scenarios."
      - source: "https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't disable CSRF protection on browser-accessible endpoints that rely on cookies for authentication."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that GET handlers don't write, that cookie-authenticated forms validate antiforgery tokens, and every DisableAntiforgery or IgnoreAntiforgeryToken has a reason"
    paths: ["**/*.cs", "**/*.cshtml", "**/*.razor"]

  - id: ASP-006
    statement: "Handle uploaded files safely: never use a client-supplied file name for saving a file to physical storage; when the app stores uploads on physical storage, never grant execute permission on the storage location; set a maximum size limit to prevent large uploads; do not persist uploaded files in the same directory tree as the app; and the uploaded file's extension should be checked against a list of permitted extensions. BLZ-022 adds the Blazor file-upload page's own advice."
    why: "An upload can overwrite files, carry code to run or exhaust the server; each of these closes one of those paths."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Never use a client-supplied file name for saving a file to physical storage."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Never grant execute permission."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Set a maximum size limit to prevent large uploads."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not persist uploaded files in the same directory tree as the app."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The uploaded file's extension should be checked against a list of permitted extensions."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks any IFormFile, IBrowserFile or upload endpoint for a generated storage name, a size limit, a permitted-extension check and a storage location outside the app"
    paths: ["**/*.cs", "**/*.razor"]

  - id: ASP-007
    statement: "Don't store files that require authorization in wwwroot and rely only on MapStaticAssets().RequireAuthorization() to protect them. Disabling directory browsing in production is highly recommended. Don't rely on file extension filtering to protect private files."
    why: "The static file and directory browsing middleware can serve files that weren't meant to be public, so a private file's protection shouldn't rest on where it sits under wwwroot or on its extension."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/static-files?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/static-files?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't store files that require authorization in wwwroot and rely only on MapStaticAssets().RequireAuthorization() to protect them."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/static-files?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Disabling directory browsing in production is highly recommended."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/static-files?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't rely on file extension filtering to protect private files."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks wwwroot for private files and the pipeline for UseDirectoryBrowser or EnableDirectoryBrowsing outside Development"
    paths: ["**/wwwroot/**", "**/Program.cs"]

  - id: ASP-008
    statement: "Apps should be written and tested to never depend on cached data: code should always have a fallback option to fetch the data. Don't insert external input into the cache, and avoid using external user input directly in cache keys. Do not cache user-specific data that may be retrieved by other user requests."
    why: "A cache entry can be missing or evicted at any time, and an entry or key built from untrusted input can grow without bound or reach another user."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/performance/caching/memory?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/performance/caching/hybrid?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/performance/caching/memory?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Apps should be written and tested to never depend on cached data."
      - source: "https://learn.microsoft.com/aspnet/core/performance/caching/memory?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Code should always have a fallback option to fetch data and not depend on the availability of a cached value."
      - source: "https://learn.microsoft.com/aspnet/core/performance/caching/memory?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't insert external input into the cache."
      - source: "https://learn.microsoft.com/aspnet/core/performance/caching/hybrid?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid using external user input directly in cache keys."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not cache user-specific data that may be retrieved by other user requests."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every IMemoryCache, HybridCache and IDistributedCache use for a fetch fallback, keys not built from raw user input, and no cross-user entries"
    paths: ["**/*.cs"]

  - id: ASP-009
    statement: "HTTP response caching should only be enabled for content that doesn't change based on a user's identity or whether a user is signed in. Responses containing content for authenticated clients must be marked as not cacheable, to prevent the response caching middleware from storing and serving them."
    why: "A cached per-user response can be served to a different user."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/performance/caching/response?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/performance/caching/middleware?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/performance/caching/response?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Caching should only be enabled for content that doesn't change based on a user's identity or whether a user is signed in."
      - source: "https://learn.microsoft.com/aspnet/core/performance/caching/middleware?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Responses containing content for authenticated clients must be marked as not cacheable to prevent the middleware from storing and serving those responses."
    scope: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks ResponseCache, UseResponseCaching and output caching on endpoints that return per-user content"
    paths: ["**/*.cs", "**/*.cshtml"]

  - id: ASP-010
    statement: "In controller-based APIs, prefer configuring authorization policies or writing a custom authorization policy over writing a custom filter, and prefer middleware for exception handling. Do not throw exceptions within authorization filters. Avoid creating and using filters purely for logging purposes."
    why: "Authorization, exception handling and logging each already have a place in the framework's pipeline; a filter that repeats one adds a second place to look."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer configuring the authorization policies or writing a custom authorization policy over writing a custom filter."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer middleware for exception handling."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not throw exceptions within authorization filters:"
      - source: "https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "However, avoid creating and using filters purely for logging purposes."
    scope: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks custom filters for authorization, exception handling and logging logic that policies, middleware or the logging pipeline already cover"
    paths: ["**/*Filter*.cs", "**/Controllers/**", "**/Pages/**"]

  - id: ASP-011
    statement: "For protection against overposting, view models are recommended rather than the [Bind] attribute. [BindProperty] should not be used on models containing properties that should not be changed by the client. Don't apply [FromBody] to more than one parameter per action method. For a string-to-type conversion that doesn't require external resources or multiple inputs, creating a type converter or using TryParse is recommended."
    why: "Binding client input straight onto a type lets the client set any property it can name. SEC-013 already keeps domain entities out of endpoints."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/mvc/models/model-binding?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/razor-pages?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/mvc/advanced/custom-model-binding?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/mvc/models/model-binding?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For protection against overposting, view models are recommended rather than the [Bind] attribute."
      - source: "https://learn.microsoft.com/aspnet/core/razor-pages?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "[BindProperty] should not be used on models containing properties that should not be changed by the client."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/models/model-binding?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't apply [FromBody] to more than one parameter per action method."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/advanced/custom-model-binding?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend creating a type converter or using TryParse for a string to SomeType conversion that doesn't require external resources or multiple inputs."
    scope: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks bound types for properties a client shouldn't set, [Bind] used as the overposting defense, more than one [FromBody] parameter and custom binders that a TryParse would do"
    paths: ["**/*.cs"]

  - id: ASP-012
    statement: "Controller-based web API controllers should typically derive from ControllerBase rather than Controller; if the same controller must support views and web APIs, derive from Controller. Don't use [FromRoute] when values might contain %2f (that is /); use [FromQuery] if the value might contain %2f."
    why: "Controller adds view support that a web API doesn't use, and a %2f in a route value isn't unescaped to a slash."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/web-api?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Web API controllers should typically derive from ControllerBase rather from Controller."
      - source: "https://learn.microsoft.com/aspnet/core/web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If the same controller must support views and web APIs, derive from Controller."
      - source: "https://learn.microsoft.com/aspnet/core/web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't use [FromRoute] when values might contain %2f (that is /)."
      - source: "https://learn.microsoft.com/aspnet/core/web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Use [FromQuery] if the value might contain %2f."
    scope: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks API controllers' base class and [FromRoute] parameters that can hold a slash; API-001 keeps Minimal APIs the default style"
    paths: ["**/Controllers/**"]

  - id: ASP-015
    statement: "Don't use route constraints for input validation: if constraints are used for input validation, invalid input results in a 404 Not Found response, and invalid input should produce a 400 Bad Request with an appropriate error message. SEC-010 and API-006 say how input is validated."
    why: "Route constraints are for telling similar routes apart, not for checking a route's input."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/routing?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/routing?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't use constraints for input validation."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/routing?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If constraints are used for input validation, invalid input results in a 404 Not Found response."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/routing?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Invalid input should produce a 400 Bad Request with an appropriate error message."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/routing?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Route constraints are used to disambiguate similar routes, not to validate the inputs for a particular route."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks route templates for range, length or regex constraints that stand in for validation"
    paths: ["**/*.cs", "**/*.razor", "**/*.cshtml"]

  - id: ASP-016
    statement: "Do not suppress a warning from ASP0003, ASP0004, ASP0006, ASP0008, ASP0009, ASP0010 or BL0005. Using the types in the Microsoft.AspNetCore.Components.RenderTree namespace is not recommended in user code."
    why: "Each of these analyzers flags code that doesn't behave the way it reads, and the RenderTree types are part of Blazor's implementation detail and subject to breaking changes."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/diagnostics/asp0003?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/diagnostics/asp0004?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/diagnostics/asp0006?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/diagnostics/asp0008?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/diagnostics/asp0009?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/diagnostics/asp0010?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/diagnostics/bl0005?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/diagnostics/bl0006?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/asp0003?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not suppress a warning from this rule."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/asp0004?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not suppress a warning from this rule."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/asp0006?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not suppress a warning from this rule."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/asp0008?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not suppress a warning from this rule."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/asp0009?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not suppress a warning from this rule."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/asp0010?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not suppress a warning from this rule."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/bl0005?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not suppress a warning from this rule."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/bl0006?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Types in the Microsoft.AspNetCore.Components.RenderTree namespace are part of Blazor's implementation detail and are subject to breaking changes."
      - source: "https://learn.microsoft.com/aspnet/core/diagnostics/bl0006?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Using these types is not recommended in user code."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for #pragma warning disable, SuppressMessage and .editorconfig severity none for these ids, and for Microsoft.AspNetCore.Components.RenderTree types; SEC-014 and the zero-warning build keep other analyzers on"
    paths: ["**/*.cs", "**/*.razor", "**/.editorconfig"]

  - id: ASP-017
    statement: "A gRPC channel should be reused when making gRPC calls. Prefer asynchronous programming with async and await when calling gRPC methods. Always dispose streaming calls once they're no longer needed. Configuring a gRPC call deadline is recommended. When calling gRPC services from an ASP.NET Core app, consider the gRPC client factory integration."
    why: "A new channel per call means new connections and round trips, a streaming call left running holds resources on both ends, and a deadline caps how long a call can run."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/grpc/performance?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/grpc/client?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/grpc/performance?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "A gRPC channel should be reused when making gRPC calls."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/performance?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer using asynchronous programming with async and await when calling gRPC methods."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/performance?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always dispose streaming calls once they're no longer needed."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/client?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Configuring a gRPC call deadline is recommended because it provides an upper limit on how long a call can run for."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/client?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If calling gRPC services from an ASP.NET Core app, consider gRPC client factory integration."
    scope: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks gRPC client code for per-call channels, blocking calls, undisposed streaming calls and calls without a deadline"
    paths: ["**/*.cs"]

  - id: ASP-018
    statement: "gRPC services should only listen and respond over secured ports, and exception messages shouldn't be exposed to the client in production apps. For gRPC services secured by client certificates, the Microsoft.AspNetCore.Authentication.Certificate package is recommended."
    why: "Exception messages are generally sensitive, and an unsecured port sends messages in the clear."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/grpc/security?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/grpc/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "gRPC services should only listen and respond over secured ports."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Exception messages shouldn't be exposed to the client in production apps."
      - source: "https://learn.microsoft.com/aspnet/core/grpc/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend that gRPC services secured by client certificates use the Microsoft.AspNetCore.Authentication.Certificate package."
    scope: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks gRPC endpoints' listeners for TLS and that EnableDetailedErrors is off outside Development"
    paths: ["**/*.cs", "**/appsettings*.json"]

  - id: ASP-019
    statement: "In SignalR hubs, don't store state in a property of the hub class, because each hub method call is executed on a new hub instance, and don't instantiate a hub directly via DI. You must ensure that a hub's methods don't execute concurrent database operations on the same context instance, because DbContext isn't thread-safe."
    why: "State kept on a hub instance is gone at the next call, and two operations at once on one DbContext fail."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/signalr/hubs?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/signalr/hubs?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Because each hub method call is executed on a new hub instance, don't store state in a property of the hub class."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/hubs?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't instantiate a hub directly via DI."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/hubs?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "However, you must ensure that the hub's methods don't execute concurrent database operations on the same context instance because DbContext isn't thread-safe."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks hub classes for instance fields and properties that hold state, and for parallel use of an injected DbContext"
    paths: ["**/*Hub*.cs"]

  - id: ASP-020
    statement: "When SignalR runs on a server farm, sticky sessions must be used, and the Redis backplane is the recommended scale-out approach for apps hosted on your own infrastructure. In a SignalR app's CORS policy, allow the specific expected origins: allowing any origin is possible but not secure or recommended. Always use HTTPS between the client and the server, and exception messages should not be exposed to the client in production apps."
    why: "A SignalR connection's state lives on one server, and the origins it accepts, its transport and the errors it returns are what a client can reach."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/signalr/scale?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/signalr/security?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/signalr/scale?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "When SignalR runs on a server farm (multiple servers), \"sticky sessions\" must be used."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/scale?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The Redis backplane is the recommended scale-out approach for apps hosted on your own infrastructure."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Allow the specific expected origins."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Allowing any origin is possible but is not secure or recommended."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always use HTTPS to ensure a secure end-to-end connection between the client and the server."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Exception messages should not be exposed to the client in production apps."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks a SignalR app's hosting for session affinity, its CORS policy for named origins and EnableDetailedErrors being off in production"
    paths: ["**/Program.cs", "**/*Hub*.cs"]

  - id: ASP-021
    statement: "For a web app that signs users in with OpenID Connect, the recommended way is a confidential client using the code flow, and using PKCE with it is recommended. Public OpenID Connect/OAuth clients are no longer recommended for web applications. For a web app with no independent backend, the Backend for Frontend (BFF) pattern is recommended. When authenticating with one of the Microsoft identity providers, the Microsoft.Identity.Web NuGet packages are recommended. Don't deploy an app with IdentityModelEventSource.ShowPII to productive servers."
    why: "A confidential client keeps its credential on the server, where the browser can't read it, and ShowPII writes personal data to logs. SEC-008 already picks the OIDC provider."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The recommended way is to use an OpenID Connect confidential client using the code flow."
      - source: "https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Using the Proof Key for Code Exchange by OAuth Public Clients (PKCE) is recommended for this implementation."
      - source: "https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Public OpenID Connect/OAuth clients are no longer recommended for web applications."
      - source: "https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If implementing web applications which have no independent backend, we recommend using the Backend for Frontend (BFF) pattern security architecture."
      - source: "https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If authenticating using one of the Microsoft identity providers in ASP.NET Core, it is recommended to use the Microsoft.Identity.Web Nuget packages."
      - source: "https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't deploy an app with IdentityModelEventSource.ShowPII to productive servers."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks AddOpenIdConnect for a client secret or assertion with the code flow and PKCE, and for ShowPII outside Development"
    paths: ["**/Program.cs", "**/*.cs"]

  - id: ASP-023
    statement: "The Data Protection key ring should be protected using appropriate permissions, and its storage location should have its access limited to the app itself. When the app specifies an explicit key persistence location, specifying an explicit key encryption mechanism for production deployments is also recommended. The data protection stack must be configured to work in a server farm, and components that consume IDataProtectionProvider must pass a unique purposes parameter to the CreateProtector method."
    why: "Whoever can read or write the key ring can read or forge the data it protects. SEC-015 already makes Data Protection the way to protect data."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/security/data-protection/configuration/overview?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/security/data-protection/implementation/key-storage-providers?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/security/data-protection/consumer-apis/purpose-strings?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/security/data-protection/configuration/overview?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Similar to configuration files, the data protection key ring should be protected using appropriate permissions."
      - source: "https://learn.microsoft.com/aspnet/core/security/data-protection/configuration/overview?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The storage location configured with Data Protection should have its access limited to the app itself, similar to the way you would protect configuration files."
      - source: "https://learn.microsoft.com/aspnet/core/security/data-protection/implementation/key-storage-providers?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If you specify an explicit key persistence location, the data protection system deregisters the default key encryption at rest mechanism, so keys are no longer encrypted at rest."
      - source: "https://learn.microsoft.com/aspnet/core/security/data-protection/implementation/key-storage-providers?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "It's recommended that you additionally specify an explicit key encryption mechanism for production deployments."
      - source: "https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The data protection stack must be configured to work in a server farm."
      - source: "https://learn.microsoft.com/aspnet/core/security/data-protection/consumer-apis/purpose-strings?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Components which consume IDataProtectionProvider must pass a unique purposes parameter to the CreateProtector method."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks AddDataProtection for a persisted, access-limited and encrypted key store in production, shared across instances, and CreateProtector calls for a unique purpose"
    paths: ["**/Program.cs", "**/*.cs"]

  - id: ASP-024
    statement: "A delegating handler for an HttpClient must be registered in DI as a transient service, rather than singleton or scoped."
    why: "A delegating handler can't be reused across HTTP client pipelines, so a singleton one throws when it's reused. OPS-003 already requires IHttpClientFactory."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/http-requests?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/http-requests?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "A delegating handler must be registered in DI as a transient service, rather than singleton or scoped."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/http-requests?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Delegating handlers can't be reused across multiple HTTP client pipelines, and registering a handler as a singleton results in an InvalidOperationException when the handler is reused."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the lifetime of every DelegatingHandler registration"
    paths: ["**/*.cs"]
---

# ASP.NET Core

What Microsoft's ASP.NET Core documentation says an app should do, beyond what the kit's API (API-), security (SEC-), operations (OPS-), data (DAT-) and craft (CRF-) rules already state. Each rule says only what its cited page says, at that page's strength, and stores the sentence that says it.

Every rule here is proposed until the owner accepts it. Pages whose guidance an existing rule already carries are not repeated: the best practices page (OPS-007), the Kestrel and HTTPS pages (SEC-011), JWT bearer tokens (SEC-008), error handling (API-002), the options and HttpClient pages (OPS-006, OPS-003) and the general dependency injection guidelines (CRF-020). The Identity UI rule for Blazor apps is BLZ-015.
