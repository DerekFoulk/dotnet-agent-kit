---
# The quality scorecard (ADR-0034). Each area says what a "perfect" .NET app looks like there, where that comes
# from, which kit rules cover it, and what's still missing. tools/Test-Scorecard.ps1 checks it against
# docs/standards and writes the table below; run it with -Update after changing a rule or an area.
areas:
  - id: architecture
    name: Architecture
    perfect: "Clear boundaries with dependencies pointing inward, code grouped by feature, boundaries enforced by tests rather than convention, and every significant choice recorded with its alternatives."
    sources:
      - "https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-07"
      - "ADR-0008"
    rules: [ARC-001, ARC-002, ARC-003, ARC-004, ARC-007, ARC-008]
    gaps:
      - id: GAP-001
        gap: "No architecture rules for MAUI and desktop apps yet: ARC-001 covers web apps only."
        status: proposed
  - id: proportion
    name: Proportion
    perfect: "The smallest design that meets today's requirements: no layer, pattern, package or project the app doesn't need yet. Over-engineering is a defect too."
    sources:
      - "owner, 2026-11-06"
      - "https://martinfowler.com/bliki/Yagni.html, retrieved 2026-11-07"
    rules: []
    gaps:
      - id: GAP-002
        gap: "No rule says how much structure a small app should get, so an agent can build every layer for a tiny app."
        status: proposed
  - id: code
    name: Code
    perfect: "Idiomatic C# that follows Microsoft's conventions, with nullable on, every analyzer on and no warnings; async code that is correct and passes cancellation tokens; small, cohesive types."
    sources:
      - "https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-07"
      - "ADR-0009"
    rules: [STY-001, STY-002, STY-003, STY-004, STY-005, STY-006]
    gaps: []
  - id: tests
    name: Tests
    perfect: "Test-first; fast unit tests, integration tests against a real database, API tests in memory, plus contract, browser and accessibility tests; mutation testing that proves the tests catch bugs; deterministic tests, with no sleeps or real clocks."
    sources:
      - "https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices, retrieved 2026-11-07"
      - "ADR-0003"
      - "ADR-0018"
    rules: [TST-001, TST-002, TST-003, TST-004, TST-005, TST-006, GIT-005]
    gaps:
      - id: GAP-003
        gap: "Mutation testing (Stryker, TST-004's 85% score) isn't run yet; it's planned as a nightly job after v0.1."
        status: planned
        needs: "a CI change"
      - id: GAP-004
        gap: "Browser and accessibility tests (Playwright with axe) aren't set up for apps with a UI."
        status: proposed
        needs: "packages and a CI change"
  - id: security
    name: Security
    perfect: "A threat model for anything touching data or sign-in; authentication and authorization by default; validated input; no secrets in code; dependencies, code and history all scanned."
    sources:
      - "https://asvs.owasp.org/, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/azure/well-architected/security/, retrieved 2026-11-07"
    rules: [SEC-001, SEC-002, SEC-003, SEC-004, SEC-005, ARC-006]
    gaps:
      - id: GAP-005
        gap: "No code scanning: CodeQL is free on public repos but isn't set up."
        status: proposed
        needs: "a CI change"
      - id: GAP-006
        gap: "No rules for authentication, authorization or input validation defaults beyond the threat model in plans."
        status: proposed
  - id: reliability
    name: Reliability
    perfect: "Timeouts everywhere, retries only where they're safe, health checks, graceful shutdown and safe database migrations."
    sources:
      - "https://learn.microsoft.com/en-us/azure/well-architected/reliability/, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks, retrieved 2026-11-07"
    rules: [ARC-006]
    gaps:
      - id: GAP-007
        gap: "No service defaults: apps don't get health checks or HTTP resilience (timeouts and retries) from the kit."
        status: proposed
        needs: "packages"
      - id: GAP-008
        gap: "No rule for safe database migrations (backward-compatible steps, tested before deploy)."
        status: proposed
  - id: observability
    name: Observability
    perfect: "Structured logs, metrics and traces through OpenTelemetry, with one ID following a request from end to end."
    sources:
      - "https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel, retrieved 2026-11-07"
      - "https://aspire.dev/get-started/csharp-service-defaults/, retrieved 2026-11-07"
    rules: [ARC-006]
    gaps:
      - id: GAP-009
        gap: "No OpenTelemetry defaults for logs, metrics and traces; plans name observability (ARC-006) but nothing sets it up."
        status: proposed
        needs: "packages"
  - id: api-design
    name: API design
    perfect: "The right API style for the job (HTTP APIs, gRPC or SignalR), and for HTTP APIs: consistent resources, errors as Problem Details (RFC 9457), versioning, pagination and an OpenAPI contract."
    sources:
      - "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design, retrieved 2026-11-07"
      - "https://www.rfc-editor.org/rfc/rfc9457, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/aspnet/core/grpc/comparison, retrieved 2026-11-07"
      - "owner, 2026-11-06"
    rules: []
    gaps:
      - id: GAP-010
        gap: "No guidance on choosing an API style: when HTTP APIs, gRPC, SignalR or GraphQL fit."
        status: proposed
      - id: GAP-011
        gap: "No HTTP API conventions (Problem Details, versioning, pagination) and no guidance on API packages (OpenAPI, Scalar, Asp.Versioning, client generation)."
        status: proposed
  - id: performance
    name: Performance
    perfect: "Hot paths benchmarked, database queries checked, caching only where measured, and load tests before a release."
    sources:
      - "https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/, retrieved 2026-11-07"
      - "https://benchmarkdotnet.org/, retrieved 2026-11-07"
    rules: [ARC-006]
    gaps:
      - id: GAP-012
        gap: "No benchmarks or performance budgets for hot paths, and no load tests."
        status: proposed
        needs: "packages"
  - id: supply-chain
    name: Supply chain and build
    perfect: "A pinned SDK and pinned packages, lock files, a vulnerability audit, reproducible builds, versions from release tags, and a software bill of materials (SBOM: a list of every component the app ships)."
    sources:
      - "https://learn.microsoft.com/en-us/nuget/concepts/security-best-practices, retrieved 2026-11-07"
      - "https://slsa.dev/, retrieved 2026-11-07"
      - "ADR-0020"
    rules: [SUP-001, SUP-002, SUP-003, SUP-004, SUP-005, SUP-006, SUP-007, SUP-008]
    gaps:
      - id: GAP-013
        gap: "No SBOM is produced for an app's build."
        status: proposed
        needs: "a CI change"
      - id: GAP-014
        gap: "OpenSSF Scorecard, a tool that scores a repo's supply-chain security practices, isn't run; it would check this area from outside."
        status: proposed
        needs: "a GitHub Action and a CI change"
  - id: delivery
    name: Delivery
    perfect: "Every merge builds a release candidate; deploys go to staging, then production, with a tested rollback and no downtime; infrastructure is code."
    sources:
      - "https://dora.dev/, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/, retrieved 2026-11-07"
      - "ADR-0023"
    rules: [SUP-006]
    gaps:
      - id: GAP-015
        gap: "No deployment pipeline: ADR-0023 decided on manual promotion to production, but nothing deploys an app yet."
        status: proposed
        needs: "cloud resources and cost"
      - id: GAP-016
        gap: "No infrastructure as code for an app's cloud resources."
        status: proposed
        needs: "cloud resources and cost"
  - id: docs
    name: Docs and decisions
    perfect: "A README a stranger can follow, an ADR for every significant choice, runbooks for operating the app, and API docs; each kind written for its purpose (tutorial, how-to, reference or explanation)."
    sources:
      - "https://diataxis.fr/, retrieved 2026-11-07"
      - "ADR-0016"
    rules: [ARC-005, DOD-001, DOD-004]
    gaps:
      - id: GAP-017
        gap: "No runbooks: nothing says how to operate, recover or roll back an app."
        status: proposed
  - id: ui
    name: UI and accessibility
    perfect: "Every UI meets WCAG 2.2 AA; UI logic lives in testable code (MVVM for MAUI), not in pages."
    sources:
      - "https://www.w3.org/TR/WCAG22/, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/dotnet/architecture/maui/mvvm, retrieved 2026-11-07"
      - "ADR-0008"
    rules: [ARC-003, ARC-004]
    gaps:
      - id: GAP-018
        gap: "No accessibility rule: nothing requires WCAG 2.2 AA or checks it (GAP-004 adds the tests)."
        status: proposed
  - id: process
    name: Process
    perfect: "Short-lived branches merged by pull request with a merge commit, readable commit history, an independent review before the owner's, and an agent that reports with evidence and asks before risky steps."
    sources:
      - "ADR-0007"
      - "ADR-0010"
      - "ADR-0026"
      - "owner, 2026-10-26"
    rules: [GIT-001, GIT-002, GIT-003, GIT-004, GIT-005, COM-001, COM-002, COM-003, COM-004, COM-005, COM-006, DOD-002, DOD-003, DOD-005]
    gaps: []
---

# Quality scorecard

The kit's goal is that an app built with it ends up as close to a "perfect" .NET app as possible (owner, 2026-11-06). This page says what "perfect" means, area by area, and how far the kit's rules get an app there (ADR-0034).

Each area in the front matter above has:

- **perfect:** what a perfect app looks like in that area, from the sources listed with it;
- **rules:** the kit rules in `docs/standards/` that cover it;
- **gaps:** what's missing, each with an id, a status (`proposed`, `planned` or `closed`) and, where it applies, what it needs from the owner (a package, a CI change, cost).

## The score

`tools/Test-Scorecard.ps1 -Update` writes this table from the rules. A rule counts as **checked by a tool** when its `enforcement` names one (build, CI, ruleset, hook, settings), and as **advisory** when only the agents' instructions and the reviewer stand behind it. Proposed rules aren't in force yet, so they're counted apart. A rule can serve more than one area, so the rows add up to more than the overall line, which counts each rule once.

<!-- scorecard-table:start -->
| Area | Rules in force | Checked by a tool | Advisory | Proposed rules | Open gaps |
|---|---|---|---|---|---|
| Architecture | 5 | 2 | 3 | 1 | 1 |
| Proportion | 0 | 0 | 0 | 0 | 1 |
| Code | 4 | 3 | 1 | 2 | 0 |
| Tests | 7 | 4 | 3 | 0 | 2 |
| Security | 6 | 4 | 2 | 0 | 2 |
| Reliability | 1 | 0 | 1 | 0 | 2 |
| Observability | 1 | 0 | 1 | 0 | 1 |
| API design | 0 | 0 | 0 | 0 | 2 |
| Performance | 1 | 0 | 1 | 0 | 1 |
| Supply chain and build | 4 | 4 | 0 | 4 | 2 |
| Delivery | 1 | 1 | 0 | 0 | 2 |
| Docs and decisions | 2 | 1 | 1 | 1 | 1 |
| UI and accessibility | 2 | 1 | 1 | 0 | 1 |
| Process | 13 | 4 | 9 | 1 | 0 |

**Overall:** 40 rules in force, 21 checked by a tool and 19 advisory; 9 proposed; 18 open gaps.
<!-- scorecard-table:end -->

## Keeping it current

- A new rule must name at least one area here, or the check fails in CI.
- Closing a gap is its own pull request: it adds or changes rules and marks the gap `closed`. Gaps that need a package, a CI change or cost wait for the owner's OK.
- After changing a rule or an area, run `./tools/Test-Scorecard.ps1 -Update` and commit the table.

Checks catch mechanical mistakes, not design. A well-tested, warning-free app can still be over-engineered or awkward to use; that judgment stays with the reviewer agent and the owner.
