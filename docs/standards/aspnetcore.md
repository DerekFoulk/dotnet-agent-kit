---
topic: aspnetcore
rules:
  - id: ASP-001
    statement: "Avoid the service locator pattern, stateful static classes and members, and direct instantiation of dependent classes within services. Prefer constructor parameters over resolving services from RequestServices, and never dispose a service the container resolved."
    why: "Microsoft's dependency injection page names these as patterns to avoid or never do; each hides a dependency or breaks the container's ownership of lifetimes."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid using the service locator pattern."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid stateful, static classes and members."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid direct instantiation of dependent classes within services."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer requesting dependencies as constructor parameters over resolving services from RequestServices."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Services resolved from the container should never be disposed by the developer."
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for GetService or GetRequiredService calls outside composition code, new on a dependency inside a service, mutable static state, and Dispose calls on container-resolved services"
    paths: ["**/*.cs"]

  - id: ASP-002
    statement: "Never store passwords or other sensitive data in configuration provider code or in plain text configuration files, and don't use production secrets in development or test. Group related hierarchical configuration with the Options pattern (recommended). Don't store a production connection string in an environment variable (recommended against)."
    why: "The configuration, app-secrets and security pages all give these as the baseline for secrets and for reading settings; OPS-006 and SEC-001 cover validating options and keeping secrets out of the repo."
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
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks configuration files and provider code for secrets, and that settings are read through options classes; SEC-001's secret scan gates secrets in the repo"
    paths: ["**/appsettings*.json", "**/Program.cs", "**/*.cs"]

  - id: ASP-003
    statement: "Set minimum log levels in configuration, not in C# code, and don't specify them with filter functions in code. Don't write log messages directly to a slow data store, such as SQL Server, in a Log method."
    why: "The logging page recommends configuration for levels, and warns that Log methods are synchronous, so a slow store should be filled from a fast one."
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
        text: "For example, don't write log messages directly to a SQL Server data store in a Log method because Log methods are synchronous."
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for SetMinimumLevel, AddFilter with a function and custom logger providers that write synchronously to a database"
    paths: ["**/Program.cs", "**/*.cs"]

  - id: ASP-004
    statement: "Don't store sensitive data in session state, and keep the site working without the session data: store critical data in the user database and cache it in session only as a performance optimization. SignalR apps shouldn't use session state. Never put sensitive data in a query string, and always revalidate data read back from hidden fields."
    why: "The session page lists each as a warning or requirement: session is a cache the client can lose, and query strings and hidden fields are visible to and changeable by the client."
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
    projectTypes: [blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks session, TempData, query-string and hidden-field use for sensitive or unvalidated data"
    paths: ["**/*.cs", "**/*.cshtml", "**/*.razor"]

  - id: ASP-005
    statement: "Never change state on a GET request (a best practice). For browser apps that use cookies, use AutoValidateAntiforgeryToken broadly outside API scenarios (recommended). Don't disable CSRF protection on browser-accessible endpoints that rely on cookies for authentication."
    why: "The anti-request-forgery page gives these three together: safe methods stay safe, validation is on by default, and opting out is only for endpoints a browser can't be tricked into calling."
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
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that GET handlers don't write, that cookie-authenticated forms validate antiforgery tokens, and every DisableAntiforgery or IgnoreAntiforgeryToken has a reason"
    paths: ["**/*.cs", "**/*.cshtml", "**/*.razor"]

  - id: ASP-006
    statement: "Handle uploaded files safely: never use a client-supplied file name to save a file to physical storage, never grant execute permission on the upload location, set a maximum size limit, don't persist uploads in the same directory tree as the app, and check the file's extension against a list of permitted extensions (should)."
    why: "The file uploads page lists these protections for the risks uploads bring: overwrites, code execution and large requests."
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
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks any IFormFile or upload endpoint for a generated storage name, a size limit, a permitted-extension check and a storage location outside the app"
    paths: ["**/*.cs"]

  - id: ASP-007
    statement: "Don't store files that require authorization in wwwroot and rely only on MapStaticAssets().RequireAuthorization() to protect them. Disable directory browsing in production (highly recommended). Don't rely on file extension filtering to protect private files."
    why: "The static files page warns that wwwroot content is served as is, so protection must come from where the file lives and how it is served."
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
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks wwwroot for private files and the pipeline for UseDirectoryBrowser or EnableDirectoryBrowsing outside Development"
    paths: ["**/wwwroot/**", "**/Program.cs"]

  - id: ASP-008
    statement: "Write and test apps to never depend on cached data: always have a fallback that fetches the data. Don't insert external input into the cache, and avoid external user input directly in cache keys. Don't cache user-specific data that other users' requests may retrieve."
    why: "The in-memory cache, HybridCache and session pages share this: a cache can be empty or evicted at any time, and a key or entry built from untrusted input is unbounded or can leak across users."
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
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every IMemoryCache, HybridCache and IDistributedCache use for a fetch fallback, keys not built from raw user input, and no cross-user entries"
    paths: ["**/*.cs"]

  - id: ASP-009
    statement: "Enable HTTP response caching only for content that doesn't change based on a user's identity or whether a user is signed in. Mark responses with content for authenticated clients as not cacheable so the response caching middleware doesn't store and serve them."
    why: "The response caching pages say this to stop one user's page being served to another."
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
    projectTypes: [web-api, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks ResponseCache, UseResponseCaching and output caching on endpoints that return per-user content"
    paths: ["**/*.cs", "**/*.cshtml"]

  - id: ASP-010
    statement: "In MVC and controller-based APIs, prefer authorization policies (or a custom authorization policy) over a custom filter, and prefer middleware for exception handling. Don't throw exceptions within authorization filters. Avoid filters used purely for logging."
    why: "The filters page gives these so that cross-cutting behavior sits where the framework already handles it."
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
    projectTypes: [web-api, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks custom filters for authorization, exception handling and logging logic that policies, middleware or the logging pipeline already cover"
    paths: ["**/*Filter*.cs", "**/Controllers/**", "**/Pages/**"]

  - id: ASP-011
    statement: "Protect against overposting with view models rather than the [Bind] attribute (recommended). Don't use [BindProperty] on models containing properties the client shouldn't change. Don't apply [FromBody] to more than one parameter per action method. Create a type converter or use TryParse for a simple string-to-type conversion that needs no external resources (recommended)."
    why: "The model binding and Razor Pages pages say each of these about binding client input to server types; SEC-013 already keeps domain entities out of endpoints."
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
    projectTypes: [web-api, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks bound types for properties a client shouldn't set, [Bind] used as the overposting defense, more than one [FromBody] parameter and custom binders that a TryParse would do"
    paths: ["**/*.cs"]

  - id: ASP-012
    statement: "Controller-based web API controllers should typically derive from ControllerBase rather than Controller; derive from Controller only when the same controller must support views. Don't use [FromRoute] when values might contain %2f."
    why: "The web API page says this: Controller adds view support, and a %2f in a route value isn't unescaped to a slash."
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
        text: "Don't use [FromRoute] when values might contain %2f (that is /)."
    projectTypes: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks API controllers' base class and [FromRoute] parameters that can hold a slash; API-001 keeps Minimal APIs the default style"
    paths: ["**/Controllers/**"]

  - id: ASP-013
    statement: "In MVC views, use POCO view models with little or no behavior (recommended). Avoid HtmlHelper.Raw with user input. Don't use partial views for common layout elements or where complex rendering logic or code execution is needed. Render partial views asynchronously: the synchronous Partial and RenderPartial helpers aren't recommended."
    why: "The views, Razor syntax and partial views pages give these: Raw output isn't encoded, and the synchronous partial helpers can deadlock."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/mvc/views/overview?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/mvc/views/razor?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/mvc/views/partial?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/mvc/views/overview?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend using Plain Old CLR Object (POCO) viewmodels with little or no behavior (methods) defined."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/views/razor?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid using HtmlHelper.Raw with user input."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/views/partial?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Partial views shouldn't be used to maintain common layout elements."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/views/partial?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't use a partial view where complex rendering logic or code execution is required to render the markup."
      - source: "https://learn.microsoft.com/aspnet/core/mvc/views/partial?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The synchronous equivalents aren't recommended because there are scenarios in which they deadlock."
    projectTypes: [razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks views for ViewBag or ViewData in place of a view model, Html.Raw on user input, and Html.Partial or Html.RenderPartial"
    paths: ["**/*.cshtml"]

  - id: ASP-014
    statement: "In Razor Pages apps, put the layout file in Pages/Shared, not Views/Shared (recommended). Avoid setting route Order in production apps, and avoid depending on an established route processing order where possible."
    why: "The Razor Pages pages say Views/Shared is an MVC pattern, and that setting Order is a sign of a confusing routing scheme."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/razor-pages?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/razor-pages/razor-pages-conventions?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/razor-pages?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend you not put the layout file in the Views/Shared folder."
      - source: "https://learn.microsoft.com/aspnet/core/razor-pages/razor-pages-conventions?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If possible, avoid depending on an established route processing order."
      - source: "https://learn.microsoft.com/aspnet/core/razor-pages/razor-pages-conventions?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "However, you should attempt to avoid the practice of setting route Order in production apps."
    projectTypes: [razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the layout's folder and any route Order convention"
    paths: ["**/Pages/**"]

  - id: ASP-015
    statement: "Don't use route constraints for input validation: invalid input should produce a 400 Bad Request with an appropriate error message, not the 404 a failed constraint gives. SEC-010 and API-006 say how input is validated."
    why: "The routing page's warning: constraints disambiguate similar routes, and a failed one returns 404."
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
        text: "Invalid input should produce a 400 Bad Request with an appropriate error message."
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks route templates for range, length or regex constraints that stand in for validation"
    paths: ["**/*.cs", "**/*.razor", "**/*.cshtml"]

  - id: ASP-016
    statement: "Never suppress the warnings ASP0003, ASP0004, ASP0006, ASP0008, ASP0009, ASP0010 and BL0005, and avoid the RenderTree types in user code (not recommended)."
    why: "Each analyzer's page says not to suppress it, because the code it flags misbehaves at runtime; the BL0006 page calls RenderTree types an implementation detail that is subject to breaking changes."
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
        text: "Using these types is not recommended in user code."
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for #pragma warning disable, SuppressMessage and .editorconfig severity none for these ids, and for Microsoft.AspNetCore.Components.RenderTree types; SEC-014 and the zero-warning build keep other analyzers on"
    paths: ["**/*.cs", "**/*.razor", "**/.editorconfig"]

  - id: ASP-017
    statement: "Reuse a gRPC channel for calls, prefer async and await over blocking calls, always dispose streaming calls once they're no longer needed, and configure a call deadline (recommended). From an ASP.NET Core app, consider the gRPC client factory integration."
    why: "The gRPC client and performance pages give these: channels are the expensive object, and a streaming call left running keeps resources on both client and server."
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
    projectTypes: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks gRPC client code for per-call channels, blocking calls, undisposed streaming calls and calls without a deadline"
    paths: ["**/*.cs"]

  - id: ASP-018
    statement: "gRPC services should only listen and respond over secured ports (TLS), and shouldn't expose exception messages to the client in production apps. Services secured by client certificates should use the Microsoft.AspNetCore.Authentication.Certificate package (recommended)."
    why: "The gRPC security page lists these: exception messages are generally sensitive, and TLS protects messages in production."
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
    projectTypes: [web-api]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks gRPC endpoints' listeners for TLS and that EnableDetailedErrors is off outside Development"
    paths: ["**/*.cs", "**/appsettings*.json"]

  - id: ASP-019
    statement: "In SignalR hubs, don't store state in a property of the hub class, because each hub method call runs on a new hub instance, and don't instantiate a hub directly via DI. Make sure hub methods don't execute concurrent database operations on the same context instance."
    why: "The hubs page says these: hubs are transient, and a scoped DbContext injected into a hub isn't thread-safe."
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
    projectTypes: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks hub classes for instance fields and properties that hold state, and for parallel use of an injected DbContext"
    paths: ["**/*Hub*.cs"]

  - id: ASP-020
    statement: "A SignalR app on a server farm must use sticky sessions (session affinity), and the Redis backplane is the recommended scale-out approach on your own infrastructure. Allow only the specific expected origins in CORS (allowing any origin isn't secure or recommended), always use HTTPS, and don't expose exception messages to the client in production apps."
    why: "The SignalR hosting and security pages say these: connections need the same server, and origins, transport and exception details are the exposed surface."
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
        text: "Allowing any origin is possible but is not secure or recommended."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always use HTTPS to ensure a secure end-to-end connection between the client and the server."
      - source: "https://learn.microsoft.com/aspnet/core/signalr/security?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Exception messages should not be exposed to the client in production apps."
    projectTypes: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks a SignalR app's hosting for session affinity, its CORS policy for named origins and EnableDetailedErrors being off in production"
    paths: ["**/Program.cs", "**/*Hub*.cs"]

  - id: ASP-021
    statement: "Web apps that sign users in with OpenID Connect use a confidential client with the code flow (the recommended way), with PKCE (recommended). Public OpenID Connect/OAuth clients aren't recommended for web apps. For a web app with no independent backend, use the Backend for Frontend (BFF) pattern (recommended). With a Microsoft identity provider, use the Microsoft.Identity.Web packages (recommended). Don't deploy an app with IdentityModelEventSource.ShowPII to productive servers."
    why: "The OpenID Connect web authentication page gives these; SEC-008 already picks the OIDC provider."
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
    projectTypes: [blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks AddOpenIdConnect for a client secret or assertion with the code flow and PKCE, and for ShowPII outside Development"
    paths: ["**/Program.cs", "**/*.cs"]

  - id: ASP-022
    statement: "An ASP.NET Core app that uses ASP.NET Core Identity for user management should use Razor Pages, not Razor components, for Identity-related UI such as registration, login and logout."
    why: "The scaffold Identity page says Identity is built for HTTP request and response communication, which isn't Blazor's primary model."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/security/authentication/scaffold-identity?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/security/authentication/scaffold-identity?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "ASP.NET Core apps that use ASP.NET Core Identity for user management should use Razor Pages instead of Razor components for Identity-related UI, such as user registration, login, logout, and other user management tasks."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that sign-in and account pages for an Identity-based Blazor app are Razor Pages"
    paths: ["**/Components/Account/**", "**/Areas/Identity/**"]

  - id: ASP-023
    statement: "Protect the Data Protection key ring with appropriate permissions, limit access to its storage to the app itself, and specify an explicit key encryption mechanism for production deployments (recommended). Configure the data protection stack to work in a server farm. Pass a unique purposes parameter to CreateProtector."
    why: "The Data Protection pages say the key ring is as sensitive as configuration files, and that components consuming IDataProtectionProvider must pass unique purposes; SEC-015 already makes Data Protection the way to protect data."
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
        text: "It's recommended that you additionally specify an explicit key encryption mechanism for production deployments."
      - source: "https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The data protection stack must be configured to work in a server farm."
      - source: "https://learn.microsoft.com/aspnet/core/security/data-protection/consumer-apis/purpose-strings?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Components which consume IDataProtectionProvider must pass a unique purposes parameter to the CreateProtector method."
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks AddDataProtection for a persisted, access-limited and encrypted key store in production, shared across instances, and CreateProtector calls for a unique purpose"
    paths: ["**/Program.cs", "**/*.cs"]

  - id: ASP-024
    statement: "Register a delegating handler for an HttpClient in DI as a transient service, never singleton or scoped."
    why: "The IHttpClientFactory page says the handler must be transient because the factory pools and reuses handler instances on its own schedule; OPS-003 already requires IHttpClientFactory."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/http-requests?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/http-requests?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "A delegating handler must be registered in DI as a transient service, rather than singleton or scoped."
    projectTypes: [web-api, blazor, razor-pages-mvc]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the lifetime of every DelegatingHandler registration"
    paths: ["**/*.cs"]
---

# ASP.NET Core

What Microsoft's ASP.NET Core documentation says an app should do, beyond what the kit's API (API-), security (SEC-), operations (OPS-) and data (DAT-) rules already state. Each rule says only what its cited page says, at that page's strength, and stores the sentence that says it.

Every rule here is proposed until the owner accepts it. Pages whose guidance an existing rule already carries are not repeated: the best practices page (OPS-007), the Kestrel and HTTPS pages (SEC-011), JWT bearer tokens (SEC-008), error handling (API-002) and the options and HttpClient pages (OPS-006, OPS-003).
