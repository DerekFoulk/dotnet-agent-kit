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
        how: "ci: the sample's Bookmarks.ServiceDefaults project and its FunctionalTests (TelemetryTests, which also sees a trace exported over OTLP only when an endpoint is set) in dotnet-ci.reusable.yml"
      - kind: advisory
        in: [app]
        how: "until it has its own ServiceDefaults project, following the sample"
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
        how: "ci: the sample's FunctionalTests check both endpoints, the database and live checks, the production status-only reply, the cache and the timeout"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: core
    paths: ["**/Program.cs", "**/*ServiceDefaults*/**", "**/*Infrastructure*/**"]
  - id: OPS-003
    statement: "Every HttpClient gets the standard resilience handler (timeouts, retries with backoff, circuit breaker) from the ServiceDefaults project, retrying only safe methods; a client that needs other settings removes the default handler (RemoveAllResilienceHandlers, experimental: suppress EXTEXP0001 with a reason) before adding its own."
    why: "A call to another service without a timeout can hang a request forever, and a retry without backoff can overload a service that is already struggling (GAP-007)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["ADR-0037", "https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience, retrieved 2026-11-08", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's FunctionalTests check that a client from IHttpClientFactory has the resilience handler and doesn't retry a failed POST"
      - kind: advisory
        in: [app]
        how: "until the app follows the sample"
    scope: core
    paths: ["**/*ServiceDefaults*/**"]
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
        how: "that the status turns In use before the first production deployment, until the production workflow (GAP-015) refuses a Draft, and whether the steps are right, which the reviewer and a practised restore check"
    scope: core
    paths: ["**/docs/runbook.md"]
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

## Pending ratification

OPS-004 was added in auto mode (ADR-0035), so it stays `proposed` until you accept it.
