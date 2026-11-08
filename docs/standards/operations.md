---
topic: operations
rules:
  - id: OPS-001
    statement: "Every ASP.NET Core app sends its logs, metrics and traces through OpenTelemetry, set up in one ServiceDefaults project, and exports them over OTLP when OTEL_EXPORTER_OTLP_ENDPOINT is set."
    why: "Structured telemetry with one ID following a request is how an app is diagnosed in production; Microsoft recommends the Aspire ServiceDefaults project for it even without the rest of Aspire (GAP-009)."
    layer: outside
    status: proposed
    sources: ["ADR-0037", "https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel, retrieved 2026-11-08"]
    enforcement: "ci: the sample's Bookmarks.ServiceDefaults project and its FunctionalTests (ServiceDefaultsTests) in dotnet-ci.reusable.yml; advisory in an app until it has its own ServiceDefaults project, following the sample"
    scope: core
    paths: ["**/*.csproj", "**/Program.cs", "**/*ServiceDefaults*/**"]
  - id: OPS-002
    statement: "Every ASP.NET Core app maps /health (readiness: every check, its database included) and /alive (liveness: only checks tagged live) in every environment, answering with the status word only, cached briefly and cut off when a check is slow."
    why: "Probes restart a dead app and keep traffic from one that isn't ready; a liveness check that touched the database would restart the app whenever the database is slow, and details in the reply would tell an attacker what the app depends on (GAP-007)."
    layer: outside
    status: proposed
    sources: ["ADR-0037", "https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks, retrieved 2026-11-08", "https://aspire.dev/fundamentals/health-checks/, retrieved 2026-11-08"]
    enforcement: "ci: the sample's FunctionalTests check both endpoints, the database and live checks, the production status-only reply, the cache and the timeout; advisory in an app until it follows the sample"
    scope: core
    paths: ["**/Program.cs", "**/*ServiceDefaults*/**", "**/*Infrastructure*/**"]
  - id: OPS-003
    statement: "Every HttpClient gets the standard resilience handler (timeouts, retries with backoff, circuit breaker) from the ServiceDefaults project, retrying only safe methods; a client that needs other settings removes the default handler (RemoveAllResilienceHandlers) before adding its own."
    why: "A call to another service without a timeout can hang a request forever, and a retry without backoff can overload a service that is already struggling (GAP-007)."
    layer: outside
    status: proposed
    sources: ["ADR-0037", "https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience, retrieved 2026-11-08"]
    enforcement: "ci: the sample's FunctionalTests check that a client from IHttpClientFactory has the resilience handler and doesn't retry a failed POST; advisory in an app until it follows the sample"
    scope: core
    paths: ["**/*ServiceDefaults*/**"]
---

# Operations

How an app behaves once it runs: what it reports about itself, and how it copes when what it calls misbehaves (GAP-007 and GAP-009, ADR-0037).

The kit gives apps no starter projects, so the reference is the sample: `sample/src/Bookmarks.ServiceDefaults`, adapted from Microsoft's `aspire-servicedefaults` template. An app that gets a web project adds its own ServiceDefaults project the same way, calls `builder.AddServiceDefaults()` and `app.MapDefaultEndpoints()` in `Program.cs`, and registers a readiness check for each dependency it can't work without, as the sample's Infrastructure does for its database.

## Pending ratification

OPS-001 to OPS-003 were added in auto mode (ADR-0035), so they stay `proposed` until the owner accepts them.
