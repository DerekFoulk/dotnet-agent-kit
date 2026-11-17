---
topic: operations
rules:
  - id: OPS-001
    statement: "Every ASP.NET Core app sends its logs, metrics and traces through OpenTelemetry, set up in one ServiceDefaults project, and exports them over OTLP when OTEL_EXPORTER_OTLP_ENDPOINT is set."
    why: "Structured telemetry with one ID following a request is how an app is diagnosed in production; Microsoft recommends the Aspire ServiceDefaults project for it even without the rest of Aspire (GAP-009)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["ADR-0037", "https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel, retrieved 2026-11-08", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's Bookmarks.ServiceDefaults project, in dotnet-ci.reusable.yml"
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): TelemetryTests checks that OpenTelemetry collects traces, metrics and logs, keeps each log's message and scopes, leaves the health probes out of traces, and exports a trace over OTLP only when an endpoint is set; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: advisory
        in: [app]
        how: "that the setup lives in one ServiceDefaults project, which code review checks"
    scope: core
    paths: ["**/*.csproj", "**/Program.cs", "**/*ServiceDefaults*/**"]
  - id: OPS-002
    statement: "Every ASP.NET Core app maps /health (readiness: every check, its database included) and /alive (liveness: only checks tagged live) in every environment, answering with the status word only; a Healthy answer is cached briefly, and a slow check is cut off with a 504."
    why: "Probes restart a dead app and keep traffic from one that isn't ready; a liveness check that touched the database would restart the app whenever the database is slow, and details in the reply would tell an attacker what the app depends on (GAP-007)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["ADR-0037", "https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks, retrieved 2026-11-08", "https://aspire.dev/fundamentals/health-checks/, retrieved 2026-11-08", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check its database check, its live check and its 5-second timeout"
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): HealthTests checks that /health and /alive answer an anonymous probe with the status only in Production, that a second probe is served from the cache, that a slow check is cut off with a 504, and that /alive stays healthy while a readiness check fails; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: advisory
        in: [app]
        how: "that /health includes the app's database, until its own FunctionalTests check it, as the sample's do"
    scope: core
    paths: ["**/Program.cs", "**/*ServiceDefaults*/**", "**/*Infrastructure*/**"]
  - id: OPS-003
    statement: "Every HttpClient comes from IHttpClientFactory and gets the standard resilience handler (timeouts, retries with backoff, circuit breaker) from the ServiceDefaults project, retrying only safe methods; a client that needs other settings removes the default handler (RemoveAllResilienceHandlers, experimental: suppress EXTEXP0001 with a reason) before adding its own. An app that needs cookies, which the factory's pooled handlers would share, keeps a long-lived HttpClient for each cookie container instead, over a SocketsHttpHandler with a PooledConnectionLifetime and wrapped in a ResilienceHandler, as the HttpClient guidelines page shows, decided by an ADR that also lifts the constructor ban there (CRF-010)."
    why: "A call to another service without a timeout can hang a request forever, and a retry without backoff can overload a service that is already struggling (GAP-007). A client built and disposed per request exhausts sockets and never sees a DNS change, and CA2000's fix for an undisposed client is that very pattern, so the constructors are banned (.NET best-practices pass, owner 2026-11-16)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["ADR-0037", "https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience, retrieved 2026-11-08", "owner, 2026-11-09", "owner, 2026-11-16", "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines, retrieved 2026-11-15"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): ResilienceTests checks that a client from IHttpClientFactory has the resilience handler and doesn't retry a failed POST; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: gate
        in: [kit, app]
        how: "build: BannedSymbols.txt bans HttpClient's constructors (RS0030), so a client comes from the factory or, for the cookie case, from the ADR that lifts the ban at that client (CRF-010); tools/tests/BuildConfig.Tests.ps1 has a failing fixture"
      - kind: advisory
        in: [kit, app]
        how: "a client that removes the default handler for settings of its own, and the cookie case, which code review checks"
    scope: core
    paths: ["**/*ServiceDefaults*/**", "**/*.cs", "BannedSymbols.txt"]
  - id: OPS-004
    statement: "Every app keeps a runbook at docs/runbook.md, started from the kit's template: a Status line (Draft or In use), a Last reviewed date, a reference section on where it runs, and one how-to guide each for deploying a release, rolling one back, checking its health, reading its telemetry, restoring its data and responding to an incident; before the app's first production deployment every placeholder is filled in and the status set to In use, and the runbook is reviewed whenever how the app is deployed, hosted or stores data changes."
    why: "Under pressure, whoever is on call follows written, tested steps instead of improvising; the Well-Architected Framework asks for version-controlled runbooks with review dates, a rollback to the last known good release, and a documented incident process (GAP-017)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0047", "https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/formalize-operations-tasks, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/incident-response, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/safe-deployments, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/manage/ready-cloud-operations, retrieved 2026-11-11", "https://diataxis.fr/how-to-guides/, retrieved 2026-11-11"]
    enforcement:
      - kind: gate
        in: [app]
        how: "ci: Test-Runbook.ps1 in app-checks.reusable.yml fails on a missing runbook, status or review date, a missing or empty section, and a placeholder left once In use"
      - kind: advisory
        in: [app]
        how: "that the status turns In use before the first production deployment, until the production workflow (GAP-015) refuses a Draft, and whether the steps are right, which code review and a practised restore check"
    scope: core
    paths: ["**/docs/runbook.md"]
  - id: OPS-005
    statement: "An app shuts down gracefully: on SIGTERM its host stops taking requests and gives in-flight work a shutdown timeout that ends before the platform's grace period (25 seconds where the platform allows 30, Kubernetes' default), and long-running work stops on the host's stopping token or the request's cancellation token, which every call passes on."
    why: "A container platform sends SIGTERM and kills the process when its grace period ends; work still running then is cut off mid-write. The generic host's stopping token and ShutdownTimeout are how .NET finishes in time (rules audit, owner 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/dotnet/core/extensions/generic-host#host-shutdown, retrieved 2026-11-15"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's ServiceDefaults sets HostOptions.ShutdownTimeout to 25 seconds"
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): ShutdownTests checks that the shutdown timeout is positive and ends before 30 seconds, in Production; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: gate
        in: [kit, app]
        how: "build: CA2016 makes every call pass on the cancellation token it has"
      - kind: advisory
        in: [app]
        how: "that the timeout ends before the app's own platform's grace period, where that isn't 30 seconds, which code review checks"
    scope: core
    paths: ["**/*ServiceDefaults*/**", "**/Program.cs"]
  - id: OPS-006
    statement: "An app's settings are options validated when it starts (ValidateDataAnnotations or a validator, and ValidateOnStart), so bad configuration stops it at startup instead of failing requests later."
    why: "A setting read lazily fails on the first request that needs it, in production; validating at startup makes a bad deployment fail its health check before it takes traffic (rules audit, owner 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/dotnet/core/extensions/options#options-validation, retrieved 2026-11-15"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample binds its rate limit's settings as validated options, and its FunctionalTests check that a limit below one stops the app at startup with an OptionsValidationException"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
      - kind: advisory
        in: [kit, app]
        how: "code review checks that every settings section the app binds is validated on start, nested options and collections included, with [ValidateObjectMembers] and [ValidateEnumeratedItems], which the options validation source generator honors too, as the options page shows"
    scope: core
    paths: ["**/Program.cs", "**/*Extensions*.cs", "**/appsettings*.json"]
  - id: OPS-007
    statement: "An ASP.NET Core app follows Microsoft's ASP.NET Core best practices: async all the way, no blocking calls, no large objects or whole request bodies buffered without need, HttpClient through IHttpClientFactory (OPS-003, which names the one exception, for cookies), no access to HttpContext after the request or from another thread, and logging through the generated, high-performance logger."
    why: "The owner asked for Microsoft Learn's performance guidance (owner O7, 2026-11-12); the best-practices page names the mistakes that hurt a server under load, and its analyzers catch some of them (rules audit, 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/core/extensions/logging/high-performance-logging, retrieved 2026-11-15"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: CA1849 (a blocking call where an async one exists), BannedSymbols.txt's bans of blocking waits (STY-011) and of HttpClient's constructors (OPS-003), CA2016 (cancellation tokens) and CA1848 (LoggerMessage-based logging), which AnalysisLevel latest-all turns on"
      - kind: advisory
        in: [kit, app]
        how: "code review checks the rest with the analyzing-dotnet-performance skill, and TST-009's benchmarks and load test measure it"
    scope: core
    paths: ["**/*.cs"]
---

# Operations

How an app behaves once it runs: what it reports about itself, how it copes when what it calls misbehaves (GAP-007 and GAP-009, ADR-0037), and how people operate it (GAP-017, ADR-0047).

The kit gives apps no starter projects, so the reference is the sample: `sample/src/Bookmarks.ServiceDefaults`, adapted from Microsoft's `aspire-servicedefaults` template. An app that gets a web project adds its own ServiceDefaults project the same way, calls `builder.AddServiceDefaults()` and `app.MapDefaultEndpoints()` in `Program.cs`, and registers a readiness check for each dependency it can't work without, as the sample's Infrastructure does for its database.

## The runbook

Every app starts with `docs/runbook.md`, from the kit's `templates/app/docs/runbook.md` (OPS-004, ADR-0047). The app owns it: the kit's sync job adds it to an app made before it existed, and never changes it after that. "Where it runs" is reference: the URLs, hosting and data stores the other sections use. Each section after it is a how-to guide in Diátaxis's sense: one task, written as steps for someone who already knows the app, with no background. The template writes out what's true for every kit app, such as the `/health` and `/alive` endpoints (OPS-002) and the `OTEL_EXPORTER_OTLP_ENDPOINT` variable (OPS-001), and marks the rest `[fill in: ...]`.

- **Draft** is the status from the start. A Draft may keep its placeholders, so a new app passes CI.
- **In use** is the status from the app's first production deployment on. The agent preparing that deployment fills in every placeholder, practises the restore on staging, and sets the status and review date. From then on, CI fails on any placeholder left.
- **Reviewing it:** whenever how the app is deployed, hosted or stores data changes, update the runbook in the same PR and set the review date.
- **Secrets:** the runbook names where a secret is kept, never its value (SEC-001).

`Test-Runbook.ps1` checks the shape in CI (`app-checks.reusable.yml`). An app runs it as `./.kit/tools/Test-Runbook.ps1 -Path ./docs/runbook.md`. It can't tell whether the app has been deployed, or whether a step works; the production workflow GAP-015 builds should refuse to deploy while the runbook is a Draft.

## Shutdown, settings and performance (OPS-005 to OPS-007)

- **Shutdown.** `AddServiceDefaults` sets `HostOptions.ShutdownTimeout` to 25 seconds. On SIGTERM the host stops taking requests, cancels the stopping token and waits that long for in-flight work, which passes the token on (CA2016). A platform with another grace period gets a timeout a few seconds under it.
- **Settings.** Bind each settings section as options with `AddOptions<T>().BindConfiguration(...).ValidateDataAnnotations().ValidateOnStart()`. The sample's rate limit (`RateLimiting:BurstLimit` and `RequestsPerSecond`, each `[Range(1, int.MaxValue)]`) is the example: a 0 stops the app at startup with an `OptionsValidationException`.
- **Performance.** Microsoft's [ASP.NET Core best practices](https://learn.microsoft.com/aspnet/core/fundamentals/best-practices). CA1849 and CA2016 catch blocking calls and dropped tokens, and CA1848 slow logging (from the [high-performance logging](https://learn.microsoft.com/dotnet/core/extensions/logging/high-performance-logging) page); code review checks the rest with the analyzing-dotnet-performance skill; the benchmarks and load test (TST-009) measure it.

## Pending ratification

OPS-004 was added in auto mode (ADR-0035), so it stays `proposed` until you accept it.
