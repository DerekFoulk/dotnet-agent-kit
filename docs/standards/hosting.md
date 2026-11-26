---
topic: hosting
rules:
  - id: HST-001
    statement: "Services with a scoped or transient lifetime should not be auto-activated, and auto-activated services should complete their initialization quickly to avoid delaying application startup; for longer-running initialization, consider background services or hosted services."
    why: "Microsoft's auto-activation page gives these as best practices for services the host creates at startup."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/auto-activation, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/auto-activation"
        retrieved: "2026-11-17"
        text: "Services with shorter lifetimes (scoped or transient) should not be auto-activated."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/auto-activation"
        retrieved: "2026-11-17"
        text: "Keep startup fast: Auto-activated services should complete their initialization quickly to avoid delaying application startup."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/auto-activation"
        retrieved: "2026-11-17"
        text: "For longer-running initialization, consider using background services or hosted services."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks what is auto-activated and how long its startup work takes"
    paths: ["**/*.cs"]
  - id: HST-002
    statement: "Don't cache an HttpClient that IHttpClientFactory created for a long time, and don't inject a typed client into a singleton service; consider requesting a client from IHttpClientFactory in a timely manner or each time you need one. Don't cache scope-related information (such as data from HttpContext) inside HttpMessageHandler instances or their dependencies. Don't register a typed client separately, because AddHttpClient already registers it. Don't start a large number of HTTP/1.1 requests at once without specifying limits."
    why: "Microsoft's IHttpClientFactory troubleshooting page lists these as DO NOT and CONSIDER items: a client captured for longer than its handler's lifetime misses DNS changes, scope data in a handler can leak sensitive information, and a second registration of a typed client overwrites the one the factory added. OPS-003 covers using the factory at all, and its cookie exception."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting"
        retrieved: "2026-11-17"
        text: "DO NOT cache HttpClient instances created by IHttpClientFactory for prolonged periods of time."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting"
        retrieved: "2026-11-17"
        text: "DO NOT inject typed client instances into Singleton services."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting"
        retrieved: "2026-11-17"
        text: "CONSIDER requesting a client from IHttpClientFactory in a timely manner or each time you need one."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting"
        retrieved: "2026-11-17"
        text: "DO NOT cache any scope-related information (such as data from HttpContext) inside HttpMessageHandler instances or its dependencies to avoid leaking sensitive information."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting"
        retrieved: "2026-11-17"
        text: "DO NOT register the typed client separately — it is already registered automatically by the AddHttpClient<T> call."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting"
        retrieved: "2026-11-17"
        text: "DO NOT start a large number of HTTP/1.1 requests concurrently at the same time without specifying the limits."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how typed clients are registered and injected, and that concurrent request volume has a limit; BannedSymbols.txt's ban of HttpClient's constructors (OPS-003) keeps clients coming from the factory"
    paths: ["**/*.cs"]
  - id: HST-003
    statement: "Using the fully qualified name of the class that creates a log message as its category name is the recommended practice; in most cases, you should use log message template formatting when logging; and if a logging data store is slow, don't write to it directly."
    why: "Microsoft's logging page recommends the category name so logs relate back to the code that produced them, and says string interpolation can cause performance issues. OPS-007 covers the generated, high-performance logger."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/dotnet/core/extensions/logging/overview, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/logging/overview"
        retrieved: "2026-11-17"
        text: "The recommended practice for choosing a log category name is to use the fully qualified name of the class that's creating the log message."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/logging/overview"
        retrieved: "2026-11-17"
        text: "In most cases, you should use log message template formatting when logging. Use of string interpolation can cause performance issues."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/logging/overview"
        retrieved: "2026-11-17"
        text: "If a logging datastore is slow, don't write to it directly."
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: CA2254 (a log message template must be a static expression), which AnalysisLevel latest-all turns on"
      - kind: advisory
        in: [kit, app]
        how: "code review checks the category and that logging doesn't write straight to a slow store"
    paths: ["**/*.cs"]
  - id: HST-004
    statement: "AddDistributedMemoryCache should only be used in development or testing scenarios; it isn't a viable production implementation of IDistributedCache."
    why: "Microsoft's caching page says so in a caution. It is an in-process cache that doesn't share entries across servers."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/core/extensions/caching, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/caching"
        retrieved: "2026-11-17"
        text: "AddDistributedMemoryCache should only be used in development or testing scenarios and is not a viable production implementation."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that production registrations of IDistributedCache aren't the in-memory one"
    paths: ["**/*.cs"]
  - id: HST-005
    statement: "In a library that isn't an official Microsoft package, don't use the Microsoft.Extensions.DependencyInjection namespace, and don't give its service registration extension methods names that are already part of the .NET ecosystem from official Microsoft packages."
    why: "Microsoft's options guidance for library authors gives both as DO NOT items, so a library's extensions don't collide with or pose as Microsoft's."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/dotnet/core/extensions/options-library-authors, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/options-library-authors"
        retrieved: "2026-11-17"
        text: "DO NOT use the Microsoft.Extensions.DependencyInjection namespace for non-official Microsoft packages."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/options-library-authors"
        retrieved: "2026-11-17"
        text: "DO NOT use names that are already part of the .NET ecosystem from official Microsoft packages."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the namespace and names of a library's registration extensions"
    paths: ["**/*.cs"]
---

# Hosting and background services

Rules for apps built on the .NET generic host and the Microsoft.Extensions libraries: dependency injection, logging, caching, the HTTP client factory, and options for libraries. The generic host runs web apps (and Worker Services and console apps, which aren't supported app types yet), so a rule about hosting is scoped to `web-api` and `blazor`, and one about a library MAUI's builder offers too (`AddHttpClient`, `builder.Logging`) is `core`.

Every rule here is proposed, and stays proposed until the owner accepts it. Each states only what its cited Microsoft page says, at the page's own strength.

Other pages on this topic already have a rule: the DI guidelines are CRF-013 and CRF-009, options validation is OPS-006, HttpClient through the factory and its resilience defaults are OPS-003, and the generated logger is OPS-007.
