---
topic: dotnet
rules:
  - id: NET-001
    statement: "Manage HttpClient lifetime with either long-lived clients that set PooledConnectionLifetime or short-lived clients created by IHttpClientFactory; never create and dispose a client per request."
    why: "Each HttpClient holds a connection pool, so a client created and disposed per request wastes connections and can exhaust ports; Microsoft's HttpClient guidelines name the two lifetime strategies."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines"
        retrieved: "2026-11-17"
        text: "To summarize recommended HttpClient use in terms of lifetime management, you should use either long-lived clients and set PooledConnectionLifetime (.NET Core and .NET 5+) or short-lived clients created by IHttpClientFactory."
    projectTypes: [all]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every HttpClient is long-lived with PooledConnectionLifetime set or comes from IHttpClientFactory (OPS-003 is the stricter kit rule for web, Blazor and worker apps, and gates it)"
    paths: ["**/*.cs"]
  - id: NET-002
    statement: "When adding resilience to an HTTP client, add only one resilience handler and avoid stacking handlers; to combine several strategies, consider the AddResilienceHandler extension method."
    why: "Stacked resilience handlers multiply retries and timeouts; Microsoft's resilience guidance says to add one."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/core/resilience/http-resilience, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/resilience/http-resilience"
        retrieved: "2026-11-17"
        text: "When adding resilience, you should only add one resilience handler and avoid stacking handlers."
      - source: "https://learn.microsoft.com/dotnet/core/resilience/http-resilience"
        retrieved: "2026-11-17"
        text: "If you need to add multiple resilience handlers, you should consider using the AddResilienceHandler extension method, which allows you to customize the resilience strategies."
    projectTypes: [web-api, blazor, razor-pages-mvc, console-worker]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks each HTTP client has one resilience handler (OPS-003 gates the standard handler)"
    paths: ["**/*.cs"]
  - id: NET-003
    statement: "An app that requires cookies avoids IHttpClientFactory for the client that uses them."
    why: "The factory pools handlers, so cookie containers are shared between unrelated parts of the app and lost when a handler is recycled."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines"
        retrieved: "2026-11-17"
        text: "If your app requires cookies, it's recommended to avoid using IHttpClientFactory."
    projectTypes: [all]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks a client that needs cookies is built by hand with its own handler (OPS-003 allows this case with an ADR)"
    paths: ["**/*.cs"]
---

# .NET fundamentals

Rules from Microsoft's .NET fundamentals and runtime pages that no other standards file covers: HttpClient lifetime
and resilience. Most of what these pages say is already enforced elsewhere (analyzer rules by STY-003, STY-009 and
SEC-014; ASP.NET Core practices by OPS-007), so it isn't repeated here.

All rules are proposed until the owner accepts them.
