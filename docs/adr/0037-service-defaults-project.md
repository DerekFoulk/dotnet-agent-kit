# ADR-0037: Give each ASP.NET Core app a ServiceDefaults project, after Microsoft's Aspire template

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

The quality scorecard lists two gaps here (ADR-0034):
- **GAP-007:** apps get no health checks or HTTP resilience from the kit;
- **GAP-009:** no OpenTelemetry defaults for logs, metrics and traces.

Plans already have to cover reliability and observability (ARC-006), but nothing sets either up.

Microsoft's ".NET observability with OpenTelemetry" guide calls the Aspire ServiceDefaults project "probably the easiest way to configure OTel for ASP.NET projects", even when the rest of Aspire isn't used. Its `dotnet new aspire-servicedefaults` template sets up:
- OpenTelemetry, with OTLP export when `OTEL_EXPORTER_OTLP_ENDPOINT` is set;
- `/health` and `/alive` endpoints;
- the standard resilience handler on every `HttpClient`;
- service discovery.

The kit gives apps no starter projects (ADR-0032), so the reference implementation lives in the kit's sample app. This ADR was decided in auto mode (ADR-0035).

## Options

### Option 1: A ServiceDefaults project per app, adapted from Microsoft's template

The sample gets `Bookmarks.ServiceDefaults`, and the API calls `AddServiceDefaults()` and `MapDefaultEndpoints()`. The kit changes the template in three ways:
- **No service discovery:** the sample calls no other service. Outside Aspire it would still resolve endpoints from configuration, so an app that calls other services can add it back.
- **Health endpoints in every environment:** the template maps them only in Development, but production probes need them. Microsoft's Aspire health-check page asks that endpoints exposed outside Development be protected: with a request timeout and output caching against abuse, and with host filtering or authorization. So each reply is cached for 10 seconds, a check that takes over 5 seconds is cut off, and the reply is the status word only, never the checks' details (review 1 of PR 21).
- **Retries only for safe methods:** the standard handler retries every method by default. Microsoft's resilience page warns that this can be harmful, so the kit turns retries off for POST, PUT, PATCH and DELETE (`DisableForUnsafeHttpMethods`), and a payment can't be sent twice (review 1 of PR 21).
- **The kit's code style:** explicit types, null checks, comments.

Each dependency registers its own readiness check where it's set up. The sample's Infrastructure, for example, adds `AddDbContextCheck` for its database.

- **Trade-offs:** it's Microsoft's recommended pattern, so agents and people meet it in the docs and in other repos. It keeps all the setup in one project. The packages are Microsoft's and OpenTelemetry's own. Every web app gets one more project, about 80 lines.
- **Reversibility:** easy. It's one project and two calls.
- **Risk:** low. The functional tests check every default the kit sets: the endpoints and their cache and timeout, the database and live checks, the trace filter, OTLP export when it's configured, the resilience handler, and that a failed POST isn't retried.

### Option 2: Put the setup in each app's API project

- **Trade-offs:** one project fewer. But a second host, such as a worker, would copy the setup, and it would mix with the app's own startup code.
- **Reversibility:** easy.
- **Risk:** low, but it drifts once there are two hosts.

### Option 3: Leave it to each plan (ARC-006 as it is)

- **Trade-offs:** nothing to maintain. But every app solves it again, or doesn't, which is the gap.
- **Reversibility:** easy.
- **Risk:** medium: production apps without probes or telemetry.

## Recommendation

Option 1: it's Microsoft's documented pattern, and the sample proves it with tests.

## Decision

Accepted, in auto mode (ADR-0035). The packages are the ones the template and Microsoft's health-check, OpenTelemetry and resilience docs name. The owner can reverse it, as with any merged change.

## Consequences

- **The sample** gets `sample/src/Bookmarks.ServiceDefaults`. Its packages join the "Sample app" group in `Directory.Packages.props`, so a new app's copy doesn't get them (ADR-0032):
  - `Microsoft.Extensions.Http.Resilience` 10.11.0;
  - `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore` 10.0.14;
  - `OpenTelemetry.Extensions.Hosting` and `OpenTelemetry.Exporter.OpenTelemetryProtocol` 1.20.1;
  - the OpenTelemetry instrumentation packages for ASP.NET Core and HTTP (1.20.2) and the runtime (1.20.1).
- **Three rules, proposed** in `docs/standards/operations.md`:
  - OPS-001: OpenTelemetry through one ServiceDefaults project;
  - OPS-002: `/health` and `/alive`;
  - OPS-003: resilience on every `HttpClient`.

  An app with a web project follows the sample.
- **GAP-007 and GAP-009 are closed** in the scorecard. GAP-008, safe database migrations, stays open.
- **Tests:** `ServiceDefaultsTests` in the sample's FunctionalTests checks:
  - both endpoints, and the database check;
  - the status-only reply in Production;
  - the OpenTelemetry providers;
  - a start with an OTLP endpoint set;
  - the resilience handler.
- **Retries:** they're on for safe methods only. A client that needs other resilience settings calls `RemoveAllResilienceHandlers()` before adding its own. Adding a second handler on top would keep the default one's retries.
- **Security:** the health endpoints are anonymous, reply with the status word only, and are cached and time-boxed. An app that wants them reachable only from its platform's probes adds authorization (`RequireAuthorization`) or a network rule. ASP.NET Core's health-check page warns that host-based filters such as `RequireHost` can be spoofed, so they're never enough on their own.
- **Not checked:** the exported telemetry itself isn't asserted, which would need a test collector. Nor is `/health` turning Unhealthy when the database can't be reached: an in-memory SQLite database can't be made unreachable from a test.

## Pillars affected

- **Reliability:** readiness and liveness probes, plus timeouts, retries and a circuit breaker on every outbound call.
- **Operational Excellence:** logs, metrics and traces through one standard.
- **Security:** status-only health replies.
- **Performance Efficiency:** health checks aren't traced, and the resilience handler adds little overhead.
- **Cost Optimization:** no new service; the OTLP export goes wherever the app is pointed.

## Sources

- https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks, retrieved 2026-11-08
- https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience, retrieved 2026-11-08
- https://aspire.dev/fundamentals/health-checks/, retrieved 2026-11-08
- https://github.com/microsoft/aspire/blob/569ddf47bac85516bef73fa838d4558fe08f3f0c/src/Aspire.ProjectTemplates/templates/aspire-servicedefaults/Extensions.cs, retrieved 2026-11-08 (MIT; THIRD-PARTY-NOTICES.md)
