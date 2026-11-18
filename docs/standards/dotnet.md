---
topic: dotnet
rules:
  - id: NET-002
    statement: "If you need to add multiple resilience handlers to an HTTP client, you should consider using the AddResilienceHandler extension method."
    why: "Stacked resilience handlers multiply retries and timeouts. OPS-008 holds the page's advice to add only one resilience handler and avoid stacking handlers; this rule holds what the page says to consider when one isn't enough."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/core/resilience/http-resilience, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/resilience/http-resilience"
        retrieved: "2026-11-17"
        text: "If you need to add multiple resilience handlers, you should consider using the AddResilienceHandler extension method, which allows you to customize the resilience strategies."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how a client that needs more than one resilience handler adds them (OPS-008 and OPS-003 cover the single standard handler)"
    paths: ["**/*.cs"]
---

# .NET fundamentals

Rules from Microsoft's .NET fundamentals and runtime pages that no other standards file covers. Most of what these
pages say is already held elsewhere (analyzer rules by STY-003, STY-009 and SEC-014; ASP.NET Core practices by OPS-007;
HttpClient lifetime, the cookie case and a single resilience handler by OPS-008), so it isn't repeated here.

All rules are proposed until the owner accepts them.
