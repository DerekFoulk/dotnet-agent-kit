---
topic: operations
rules:
  - id: OPS-001
    statement: "Every ASP.NET Core app sends its logs, metrics and traces through OpenTelemetry, set up in one ServiceDefaults project, and exports them over OTLP when OTEL_EXPORTER_OTLP_ENDPOINT is set."
    why: "Structured telemetry with one ID following a request is how an app is diagnosed in production. Microsoft's observability page calls the Aspire Service Defaults project probably the easiest way to configure OpenTelemetry for ASP.NET, even without the rest of Aspire; the owner chose it as the kit's one setup (GAP-009)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0037", "https://learn.microsoft.com/dotnet/core/diagnostics/observability-with-otel, retrieved 2026-11-17", "owner, 2026-11-09"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/diagnostics/observability-with-otel"
        retrieved: "2026-11-17"
        text: "Probably the easiest way to configure OTel for ASP.NET projects is to use the Aspire Service Defaults project, even if not using the rest of Aspire such as the AppHost for orchestration."
    scope: [web-api, blazor]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): TelemetryTests checks that OpenTelemetry collects traces, metrics and logs, keeps each log's message and scopes, leaves the health probes out of traces, and exports a trace over OTLP only when an endpoint is set; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: advisory
        in: [app]
        how: "that the setup lives in one ServiceDefaults project, which code review checks"
    paths: ["**/*.csproj", "**/Program.cs", "**/*ServiceDefaults*/**"]
  - id: OPS-002
    statement: "Every ASP.NET Core app maps /health (readiness: every check, its database included) and /alive (liveness: only checks tagged live) in every environment, answering with the status word only; a Healthy answer is cached briefly, and a slow check is cut off with a 504."
    why: "Probes restart a dead app and keep traffic from one that isn't ready; a liveness check that touched the database would restart the app whenever the database is slow, and details in the reply would tell an attacker what the app depends on (GAP-007). The Aspire page's default endpoints are the model, and the kit goes further than it by mapping them in every environment (see OPS-017)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0037", "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0, retrieved 2026-11-17", "https://aspire.dev/fundamentals/health-checks/, retrieved 2026-11-17", "owner, 2026-11-09"]
    scope: [web-api, blazor]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check its database check, its live check and its 5-second timeout"
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): HealthTests checks that /health and /alive answer an anonymous probe with the status only in Production, that a second probe is served from the cache, that both are time-boxed and a slow check is cut off with a 504, and that /alive stays healthy while a readiness check fails; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: advisory
        in: [app]
        how: "that /health includes the app's database, until its own FunctionalTests check it, as the sample's do"
    paths: ["**/Program.cs", "**/*ServiceDefaults*/**", "**/*Infrastructure*/**"]
  - id: OPS-003
    statement: "Every HttpClient comes from IHttpClientFactory and gets the standard resilience handler (timeouts, retries with backoff, circuit breaker) from the ServiceDefaults project, retrying only safe methods; a client that needs other settings removes the default handler (RemoveAllResilienceHandlers, experimental: suppress EXTEXP0001 with a reason) before adding its own. An app that needs cookies, which the factory's pooled handlers would share, keeps a long-lived HttpClient for each cookie container instead, over a SocketsHttpHandler with a PooledConnectionLifetime and wrapped in a ResilienceHandler, as the HttpClient guidelines page shows, decided by an ADR that also lifts the constructor ban there (CRF-010)."
    why: "A call to another service without a timeout can hang a request forever, and a retry without backoff can overload a service that is already struggling (GAP-007). The owner made the factory the only way to get a client and banned HttpClient's constructors, because CA2000's fix for an undisposed client is a client built and disposed per request (.NET best-practices pass, owner 2026-11-16). OPS-008 holds what Microsoft's pages say about client lifetime."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0037", "owner, 2026-11-09", "owner, 2026-11-16", "https://learn.microsoft.com/dotnet/core/resilience/http-resilience, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/resilience/http-resilience"
        retrieved: "2026-11-17"
        text: "By default, the standard resilience handler is configured to make retries for all HTTP methods. For some applications, such behavior could be undesirable or even harmful."
    scope: [web-api, blazor]
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
    paths: ["**/*ServiceDefaults*/**", "**/*.cs", "BannedSymbols.txt"]
  - id: OPS-004
    statement: "Every app keeps a runbook at docs/runbook.md, started from the kit's template: a Status line (Draft or In use), a Last reviewed date, a reference section on where it runs, and one how-to guide each for deploying a release, rolling one back, checking its health, reading its telemetry, restoring its data and responding to an incident; before the app's first production deployment every placeholder is filled in and the status set to In use, and the runbook is reviewed whenever how the app is deployed, hosted or stores data changes."
    why: "Under pressure, whoever is on call follows written, tested steps instead of improvising (GAP-017). The kit's layout is the owner's choice; OPS-012 holds what the Well-Architected Framework says about documenting operations."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0047", "https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/manage/ready-cloud-operations, retrieved 2026-11-11", "https://diataxis.fr/how-to-guides/, retrieved 2026-11-11"]
    scope: [web-api, blazor]
    enforcement:
      - kind: gate
        in: [app]
        how: "ci: Test-Runbook.ps1 in app-checks.reusable.yml fails on a missing runbook, status or review date, a missing or empty section, and a placeholder left once In use"
      - kind: advisory
        in: [app]
        how: "that the status turns In use before the first production deployment, until the production workflow (GAP-015) refuses a Draft, and whether the steps are right, which code review and a practised restore check"
      - kind: advisory
        in: [app]
        how: "the runbook's sections fit an app the team hosts and deploys, not a .NET MAUI app released through app stores, whose rollback, health and incident steps differ; app-checks.reusable.yml still runs Test-Runbook.ps1 on every app, a MAUI app included, until the check reads the app's type"
    paths: ["**/docs/runbook.md"]
  - id: OPS-005
    statement: "An app shuts down gracefully: on SIGTERM its host stops taking requests and gives in-flight work a shutdown timeout that ends before the platform's grace period (25 seconds where the platform allows 30, Kubernetes' default), and long-running work stops on the host's stopping token or the request's cancellation token, which every call passes on."
    why: "A container platform sends SIGTERM and kills the process when its grace period ends; work still running then is cut off mid-write. The generic host's stopping token and ShutdownTimeout are how .NET finishes in time, and the owner set the 25-second margin (rules audit, owner 2026-11-12). OPS-009 holds what Microsoft's page says."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/dotnet/core/extensions/generic-host#host-shutdown, retrieved 2026-11-17"]
    scope: [web-api, blazor]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared host checks (tools/AppTests/Functional), which tests/Directory.Build.props compiles into every *.FunctionalTests project, the sample's and an app's, which starts the app in its own part of AppHost (ADR-0081): ShutdownTests checks that the shutdown timeout is positive and ends before 30 seconds, in Production; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: gate
        in: [kit, app]
        how: "build: CA2016 makes every call pass on the cancellation token it has"
      - kind: advisory
        in: [app]
        how: "that the timeout ends before the app's own platform's grace period, where that isn't 30 seconds, which code review checks"
    paths: ["**/*ServiceDefaults*/**", "**/Program.cs"]
  - id: OPS-006
    statement: "An app's settings are options validated when it starts (ValidateDataAnnotations or a validator, and ValidateOnStart), so bad configuration stops it at startup instead of failing requests later."
    why: "A setting read lazily fails on the first request that needs it, in production; validating at startup makes a bad deployment fail its health check before it takes traffic (rules audit, owner 2026-11-12). Microsoft's options page shows how to validate at startup but doesn't call it required."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/dotnet/core/extensions/options#options-validation, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/options#options-validation"
        retrieved: "2026-11-17"
        text: "The validation occurs at runtime, but you can configure it to occur at startup by instead chaining a call to ValidateOnStart:"
    scope: [web-api, blazor]
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
    paths: ["**/Program.cs", "**/*Extensions*.cs", "**/appsettings*.json"]
  - id: OPS-007
    statement: "Avoid blocking calls; make hot code paths asynchronous, and call data access, I/O and long-running operations APIs asynchronously if an asynchronous API is available; avoid reading large request bodies or response bodies into memory; don't create and dispose of HttpClient instances directly, and use HttpClientFactory to retrieve them (OPS-008 names the lifetime options); don't use HttpContext after the request is complete, and don't access it from multiple threads. For high-performance logging scenarios in .NET 6 and later, use LoggerMessageAttribute with compile-time source generation."
    why: "The owner asked for Microsoft Learn's performance guidance (owner O7, 2026-11-12). The best-practices page names blocking calls as a common performance problem, and its analyzers catch some of the mistakes (rules audit, 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/core/extensions/logging/high-performance-logging, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "A common performance problem in ASP.NET Core apps is blocking calls that could be asynchronous."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid blocking calls"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do make hot code paths asynchronous."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do call data access, I/O, and long-running operations APIs asynchronously if an asynchronous API is available."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid reading large request bodies or response bodies into memory"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not create and dispose of HttpClient instances directly."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do use HttpClientFactory to retrieve HttpClient instances."
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not use the HttpContext after the request is complete"
      - source: "https://learn.microsoft.com/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Do not access HttpContext from multiple threads"
      - source: "https://learn.microsoft.com/dotnet/core/extensions/logging/high-performance-logging"
        retrieved: "2026-11-17"
        text: "For high-performance logging scenarios in .NET 6 and later versions, use the LoggerMessageAttribute with compile-time source generation."
    scope: [web-api, blazor]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: CA1849 (a blocking call where an async one exists), BannedSymbols.txt's bans of blocking waits (STY-011) and of HttpClient's constructors (OPS-003), which AnalysisLevel latest-all turns on"
      - kind: advisory
        in: [kit, app]
        how: "code review checks the rest with the analyzing-dotnet-performance skill, and TST-009's benchmarks and load test measure it"
    paths: ["**/*.cs"]
  - id: OPS-008
    statement: "For HttpClient lifetime, you should use either long-lived clients with PooledConnectionLifetime set or short-lived clients created by IHttpClientFactory; what matters is that clients aren't created and disposed with each request. If an app requires cookies, it's recommended to avoid IHttpClientFactory: pooling the HttpMessageHandler instances results in sharing of CookieContainer objects. When adding resilience, you should only add one resilience handler and avoid stacking handlers."
    why: "A client created and disposed per request can exhaust the available ports, a long-lived client without a PooledConnectionLifetime doesn't see DNS changes, and shared cookie containers can mix cookies between unrelated parts of an app (GAP-007). The kit's own, stricter wording is OPS-003."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-09"
    sources: ["https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/core/resilience/http-resilience, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines"
        retrieved: "2026-11-17"
        text: "To summarize recommended HttpClient use in terms of lifetime management, you should use either long-lived clients and set PooledConnectionLifetime (.NET Core and .NET 5+) or short-lived clients created by IHttpClientFactory."
      - source: "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines"
        retrieved: "2026-11-17"
        text: "What matters is that they're not created and disposed with each request, as they each contain a connection pool."
      - source: "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines"
        retrieved: "2026-11-17"
        text: "If your app requires cookies, it's recommended to avoid using IHttpClientFactory."
      - source: "https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines"
        retrieved: "2026-11-17"
        text: "Pooling the HttpMessageHandler instances results in sharing of CookieContainer objects."
      - source: "https://learn.microsoft.com/dotnet/core/resilience/http-resilience"
        retrieved: "2026-11-17"
        text: "When adding resilience, you should only add one resilience handler and avoid stacking handlers."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks client lifetime and the cookie case; OPS-003's checks cover the factory and the resilience handler"
    paths: ["**/*.cs"]
  - id: OPS-009
    statement: "When the host receives a shutdown signal (for example, Ctrl+C or StopAsync), it notifies the app by signaling ApplicationStopping; an app with long-running operations that need to finish gracefully should subscribe to that event."
    why: "Active requests have until the shutdown timeout to complete; if it expires, the pending connections and requests are aborted forcefully, which can cause errors in the logs and to the clients. OPS-005 holds the kit's numbers."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/dotnet/core/extensions/generic-host#host-shutdown, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/generic-host#host-shutdown"
        retrieved: "2026-11-17"
        text: "When the Host receives a shutdown signal (for example, Ctrl+C or StopAsync), it notifies the application by signaling ApplicationStopping."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/generic-host#host-shutdown"
        retrieved: "2026-11-17"
        text: "You should subscribe to this event if you have any long-running operations that need to finish gracefully."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/generic-host#host-shutdown"
        retrieved: "2026-11-17"
        text: "The active requests have until the shutdown timeout to complete."
      - source: "https://learn.microsoft.com/dotnet/core/extensions/generic-host#host-shutdown"
        retrieved: "2026-11-17"
        text: "If the timeout expires, the pending connections and requests are aborted forcefully, which can cause errors in the logs and to the clients."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that long-running work stops on the stopping token; OPS-005's checks cover the timeout and the cancellation tokens"
    paths: ["**/*ServiceDefaults*/**", "**/Program.cs", "**/*.cs"]
  - id: OPS-010
    statement: "In some hosting scenarios, use a pair of health checks to distinguish two app states: readiness (the app is running normally but isn't ready to receive requests) and liveness (the app has crashed and must be restarted)."
    why: "A liveness probe that ran the readiness checks would restart an app that is only waiting to become ready (GAP-007). Microsoft's example is an app that must download a large configuration file before it can process requests: its liveness probe runs no other checks, and its readiness probe reports \"not ready\" until the download succeeds. The page calls separate readiness and liveness checks useful in an environment such as Kubernetes. The kit's endpoints and their details are OPS-002."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-09"
    sources: ["https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In some hosting scenarios, use a pair of health checks to distinguish two app states:"
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Readiness indicates if the app is running normally but isn't ready to receive requests."
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Liveness indicates if an app has crashed and must be restarted."
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "An app must download a large configuration file before it's ready to process requests."
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Use a liveness probe to describe the liveness of the process, no other checks are run."
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Use a readiness probe to indicate a \"not ready\" state until the download succeeds and the app is ready to receive requests."
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Using separate readiness and liveness checks is useful in an environment such as Kubernetes."
    scope: [web-api, blazor]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: OPS-002's HealthTests check that /alive stays healthy while a readiness check fails"
    paths: ["**/Program.cs", "**/*ServiceDefaults*/**"]
  - id: OPS-011
    statement: "Every log call in an app goes through a generated, LoggerMessage-based method, not a logger extension method such as LogInformation."
    why: "Source-generated logging is what Microsoft's page says to use for high-performance logging (OPS-007), and the owner made it the rule for every log call, so there is no hot path to find later (rules audit, owner 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/dotnet/core/extensions/logging/high-performance-logging, retrieved 2026-11-17"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: CA1848 (LoggerMessage-based logging), which AnalysisLevel latest-all turns on"
    paths: ["**/*.cs"]
  - id: OPS-012
    statement: "Documentation should capture standard operating procedures and clearly define how work is done; standards should be regularly reviewed and challenged to ensure that they remain appropriate; use templates and version control to maintain consistency and keep a record of updates, and include authorship and review dates. An incident response plan should define the key roles involved in managing an incident and the responsibilities of each, and must include a communication and escalation structure and the core procedures the team will follow during detection, triage, containment and recovery; regularly test incident response processes using dry runs or chaos engineering exercises. Safe deployment practice (SDP) guidelines should provide clear instructions on how to deal with data changes according to the workload's data estate design."
    why: "Under pressure, whoever is on call follows written steps instead of improvising (GAP-017); the page on safe deployments notes that rolling back changes, especially database, schema or other stateful component changes, can be complex. These fit an app the team hosts and deploys, so the rule is scoped to the web app types. OPS-004 is the kit's own runbook layout."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/azure/well-architected/operational-excellence/formalize-operations-tasks, retrieved 2026-11-17", "https://learn.microsoft.com/azure/well-architected/operational-excellence/incident-response, retrieved 2026-11-17", "https://learn.microsoft.com/azure/well-architected/operational-excellence/safe-deployments, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/formalize-operations-tasks"
        retrieved: "2026-11-17"
        text: "Documentation should capture standard operating procedures and clearly define how work is done."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/formalize-operations-tasks"
        retrieved: "2026-11-17"
        text: "Procedures must evolve as your workload and team evolve, and standards should be regularly reviewed and challenged to ensure that they remain appropriate."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/formalize-operations-tasks"
        retrieved: "2026-11-17"
        text: "Use templates and version control to maintain consistency and keep a record of updates."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/formalize-operations-tasks"
        retrieved: "2026-11-17"
        text: "Include authorship and review dates, and highlight changes in procedures."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/incident-response"
        retrieved: "2026-11-17"
        text: "An incident response plan should define the key roles involved in managing an incident and the responsibilities of each."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/incident-response"
        retrieved: "2026-11-17"
        text: "The plan must include a communication and escalation structure that outlines how incidents are reported, who is notified, and through which channels."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/incident-response"
        retrieved: "2026-11-17"
        text: "The plan must also include the core procedures the team will follow during detection, triage, containment, and recovery."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/incident-response"
        retrieved: "2026-11-17"
        text: "Regularly test your incident response processes using dry runs or chaos engineering exercises."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/safe-deployments"
        retrieved: "2026-11-17"
        text: "Rolling back changes, especially database, schema, or other stateful component changes, can be complex."
      - source: "https://learn.microsoft.com/azure/well-architected/operational-excellence/safe-deployments"
        retrieved: "2026-11-17"
        text: "Your SDP guidelines should provide clear instructions on how to deal with data changes according to the data estate design for your workload."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks that the runbook has each part; OPS-004's Test-Runbook.ps1 checks its shape"
    paths: ["**/docs/runbook.md"]
  - id: OPS-013
    statement: "Even if Data Protection APIs aren't called by user code, data protection should be configured to create a persistent cryptographic key store: the ASP.NET Core Data Protection stack is used by several ASP.NET Core middlewares, including authentication middleware (for example, cookie middleware) and cross-site request forgery (CSRF) protections."
    why: "If data protection isn't configured, the keys are held in memory and discarded when the app restarts; users then have to sign in again, and data protected with the old keys, which can include anti-forgery tokens, can no longer be decrypted."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The ASP.NET Core Data Protection stack is used by several ASP.NET Core middlewares, including authentication middleware (for example, cookie middleware) and cross-site request forgery (CSRF) protections."
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Even if Data Protection APIs aren't called by user code, data protection should be configured to create a persistent cryptographic key store."
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If data protection isn't configured, the keys are held in memory and discarded when the app restarts."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks that an app that signs users in or uses anti-forgery configures a persistent key store"
    paths: ["**/Program.cs", "**/*Extensions*.cs"]
  - id: OPS-015
    statement: "An app that uses trimming shouldn't produce any trim warnings. Don't use SuppressMessage or #pragma warning disable for trim warnings; to suppress one, always use UnconditionalSuppressMessage. With too many trim warnings to address, consider whether trimming is appropriate for the app. When publishing with Native AOT, it's recommended to develop, debug and test as usual and publish with Native AOT as one of the last steps."
    why: "The trimmer works on compiled assemblies, so a compiler-only suppression is invisible to it; an unfixed trim warning can change behavior or crash the app after trimming."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/core/deploying/native-aot/diagnostics, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings"
        retrieved: "2026-11-17"
        text: "An app that uses trimming shouldn't produce any trim warnings."
      - source: "https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings"
        retrieved: "2026-11-17"
        text: "Do not use SuppressMessage or #pragma warning disable for trim warnings."
      - source: "https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings"
        retrieved: "2026-11-17"
        text: "Always use UnconditionalSuppressMessage."
      - source: "https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings"
        retrieved: "2026-11-17"
        text: "Too many warnings to address"
      - source: "https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings"
        retrieved: "2026-11-17"
        text: "Consider if trimming is appropriate for your application."
      - source: "https://learn.microsoft.com/dotnet/core/deploying/native-aot/diagnostics"
        retrieved: "2026-11-17"
        text: "We recommend developing, debugging, and testing the applications as usual and publishing the working app with Native AOT as one of the last steps."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks an app or library that sets PublishTrimmed, PublishAot or IsTrimmable for trim warnings and for suppressions"
    paths: ["**/*.cs", "**/*.csproj"]
  - id: OPS-016
    statement: "When a systemd unit runs a .NET app, avoid setting KillSignal=SIGINT: .NET lifetime integrations listen for SIGTERM to start a graceful shutdown."
    why: "Other signals might result in abrupt termination, which cuts off in-flight work (OPS-005, OPS-009)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid setting KillSignal=SIGINT, as .NET lifetime integrations listen for SIGTERM to initiate graceful shutdown, and other signals might result in abrupt termination."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks a unit file in the app's repo, and the runbook's deploy steps"
    paths: ["**/*.service", "**/docs/runbook.md"]
  - id: OPS-017
    statement: "If the /health and /alive endpoints are enabled outside Development, it's recommended to protect them with routing features such as host filtering or authorization."
    why: "Aspire's service defaults disable the two endpoints in non-development environments by default, and this is what its page recommends if you enable them. The kit's OPS-002 maps them anonymously in every environment, with the status word only, and the owner's decision there goes further than this page."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://aspire.dev/fundamentals/health-checks/, retrieved 2026-11-17"]
    quotes:
      - source: "https://aspire.dev/fundamentals/health-checks/"
        retrieved: "2026-11-17"
        text: "If you need to enable them, its recommended to protect these endpoints with various routing features, such as host filtering and/or authorization."
    scope: [web-api, blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how the health endpoints are exposed; the kit's sample and shared tests don't protect them (OPS-002), which the owner should settle"
    paths: ["**/Program.cs", "**/*ServiceDefaults*/**"]
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

## Sources and strength

An `authority` rule here says only what its cited page says, at the page's strength. Where the kit goes further, a `preference` rule holds the owner's decision: OPS-001, OPS-002, OPS-003, OPS-004, OPS-005, OPS-006 and OPS-011, each beside the authority rule that holds the page's part (OPS-007, OPS-008, OPS-009, OPS-010 and OPS-012).

## Pending ratification

OPS-004 and OPS-012 were added in auto mode (ADR-0035), and OPS-013 to OPS-017 come from the 2026-11-17 review of Microsoft's deployment pages, so they stay `proposed` until you accept them. OPS-017 conflicts with how OPS-002 maps the health endpoints today; settle that when you accept it.
