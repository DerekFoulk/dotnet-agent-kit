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
    rules: [ARC-001, ARC-002, ARC-003, ARC-004, ARC-007, ARC-008, CRF-006, CRF-007]
    gaps:
      - id: GAP-001
        gap: "No architecture rules for MAUI and desktop apps yet: ARC-001 covers web apps only."
        status: proposed
  - id: craft
    name: Craft
    perfect: "Code built on the fundamentals (SOLID, DRY, KISS, YAGNI, separation of concerns, acyclic dependencies), within metric limits a tool enforces, using every library only through its documented API; every defect fixed at its root, and no known-worse design left unnamed."
    sources:
      - "owner, 2026-11-08"
      - "https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles, retrieved 2026-11-10"
      - "ADR-0043"
    rules: [CRF-001, CRF-002, CRF-003, CRF-004, CRF-005, CRF-006, CRF-007, CRF-008, CRF-009, CRF-010]
    gaps:
      - id: GAP-019
        gap: "No tool checks nesting depth, statements per method, file length or class cohesion (LCOM4); CRF-008 leaves them to the reviewer agent."
        status: proposed
        needs: "an analyzer package or a kit check, and a CI change"
      - id: GAP-020
        gap: "No tool finds duplicated code, so DRY (CRF-003) rests on the reviewer agent."
        status: proposed
        needs: "a tool and a CI change"
  - id: proportion
    name: Proportion
    perfect: "The smallest design that meets today's requirements: no layer, pattern, package or project the app doesn't need yet. Over-engineering is a defect too."
    sources:
      - "owner, 2026-11-06"
      - "https://martinfowler.com/bliki/Yagni.html, retrieved 2026-11-07"
    rules: [CRF-004]
    gaps:
      - id: GAP-002
        gap: "No rule says how much structure a small app should get, so an agent can build every layer for a tiny app."
        status: proposed
  - id: code
    name: Code
    perfect: "Idiomatic C# that follows Microsoft's conventions, with nullable on, every analyzer on and no warnings; async code that passes cancellation tokens on to the methods it calls."
    sources:
      - "https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2016, retrieved 2026-11-07"
      - "ADR-0009"
    rules: [STY-001, STY-002, STY-003, STY-004, STY-005, STY-006, CRF-008, CRF-010]
    gaps:
      - id: GAP-021
        gap: "CA1014 (mark assemblies CLS-compliant), a rule latest-all leaves off, is still off, though STY-003 says every rule is on. Declaring CLS compliance makes the compiler check it, and the sample then breaks it in 48 places; whether apps should declare it is a decision of its own. Microsoft's code analysis overview (https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/overview) says the eleven rules it lists as left off by latest-all, CA1014 among them, might be deprecated in a future version."
        status: proposed
        needs: "an ADR, and a change to every project or a recorded opt-out"
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
        gap: "Mutation testing (Stryker, TST-004's 85% score) isn't run yet; it's planned as a nightly job after v0.1. Closed by ADR-0039: a shared nightly Stryker.NET workflow for the kit and every app, failing below 85%."
        status: closed
        needs: "a dotnet tool (Stryker) and a CI change"
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
    rules: [SEC-001, SEC-002, SEC-003, SEC-004, SEC-005, SEC-006, SEC-007, SEC-008, SEC-009, SEC-010, ARC-006]
    gaps:
      - id: GAP-005
        gap: "No code scanning: CodeQL is free on public repos but isn't set up. Closed by ADR-0036: codeql.reusable.yml runs in the kit's and every public app's CI (SEC-006, accepted 2026-11-09), and the kit's ruleset requires its results before merging."
        status: closed
        needs: "a GitHub Action (CodeQL) and a CI change"
      - id: GAP-006
        gap: "No rules for authentication, authorization or input validation defaults beyond the threat model in plans. Closed by ADR-0048: SEC-007 to SEC-010 (proposed) and the sample's API, which requires a signed-in user everywhere, validates tokens with JWT bearer, keeps each user's bookmarks apart and bounds every input."
        status: closed
  - id: reliability
    name: Reliability
    perfect: "Timeouts everywhere, retries only where they're safe, health checks, graceful shutdown and safe database migrations."
    sources:
      - "https://learn.microsoft.com/en-us/azure/well-architected/reliability/, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks, retrieved 2026-11-07"
    rules: [ARC-006, OPS-002, OPS-003]
    gaps:
      - id: GAP-007
        gap: "No service defaults: apps don't get health checks or HTTP resilience (timeouts and retries) from the kit. Closed by ADR-0037: the sample's ServiceDefaults project and OPS-002, OPS-003 (accepted 2026-11-09)."
        status: closed
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
    rules: [ARC-006, OPS-001]
    gaps:
      - id: GAP-009
        gap: "No OpenTelemetry defaults for logs, metrics and traces; plans name observability (ARC-006) but nothing sets it up. Closed by ADR-0037: the sample's ServiceDefaults project and OPS-001 (accepted 2026-11-09)."
        status: closed
        needs: "packages"
  - id: api-design
    name: API design
    perfect: "The right API style for the job (HTTP APIs, gRPC or SignalR), and for HTTP APIs: consistent resources, errors as Problem Details (RFC 9457), versioning, pagination and an OpenAPI contract."
    sources:
      - "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design, retrieved 2026-11-07"
      - "https://www.rfc-editor.org/rfc/rfc9457, retrieved 2026-11-07"
      - "https://learn.microsoft.com/en-us/aspnet/core/grpc/comparison, retrieved 2026-11-07"
      - "owner, 2026-11-06"
    rules: [API-001, API-002, API-003, API-004, API-005, API-006]
    gaps:
      - id: GAP-010
        gap: "No guidance on choosing an API style: when HTTP APIs, gRPC, SignalR or GraphQL fit. Closed by ADR-0038: API-001 (proposed) and the plan-checklist skill."
        status: closed
      - id: GAP-011
        gap: "No HTTP API conventions (Problem Details, versioning, pagination) and no guidance on API packages (OpenAPI, Scalar, Asp.Versioning, client generation). Closed by ADR-0038: API-002 to API-004 (accepted 2026-11-09) and API-005, API-006 (proposed), the sample's API and docs/standards/api-design.md."
        status: closed
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
        needs: "a tool or GitHub Action, and a CI change"
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
    rules: [ARC-005, ARC-006, DOD-001]
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
    rules: [ARC-003, ARC-004, ARC-006]
    gaps:
      - id: GAP-018
        gap: "No rule requires WCAG 2.2 AA or checks it: only the plan checklist asks about accessibility (ARC-006, the plan-checklist skill). GAP-004 adds the tests."
        status: proposed
  - id: process
    name: Process
    perfect: "Short-lived branches merged by pull request with a merge commit, readable commit history, an independent review before the owner's, and an agent that reports with evidence and asks before risky steps."
    sources:
      - "ADR-0007"
      - "ADR-0010"
      - "ADR-0026"
      - "owner, 2026-10-26"
    rules: [GIT-001, GIT-002, GIT-003, GIT-004, GIT-005, COM-001, COM-002, COM-003, COM-004, COM-005, COM-006, COM-007, DOD-002, DOD-003, DOD-004, DOD-005, DOD-006]
    gaps: []
---

# Quality scorecard

The kit's goal is that an app built with it ends up as close to a "perfect" .NET app as possible (owner, 2026-11-06). This page says what "perfect" means, area by area, and how far the kit's rules get an app there (ADR-0034).

Each area in the front matter above has:

- **perfect:** what a perfect app looks like in that area, from the sources listed with it;
- **rules:** the kit rules in `docs/standards/` that cover it;
- **gaps:** what's missing, each with an id, a status (`proposed`, `planned` or `closed`) and, where it applies, what it needs from the owner (a package, a CI change, cost).

## The score

`tools/Test-Scorecard.ps1 -Update` writes this table from the rules. A rule counts as **advisory** when its `enforcement` starts with `advisory`: only the agents' instructions and the reviewer stand behind it. Any other start (build, ci, ruleset, check, restore, settings) counts as **checked by a tool**, even when the text adds that part of the rule is advisory, so that number is an upper bound. Proposed rules aren't in force yet, so they're counted apart. A rule can serve more than one area, so the rows add up to more than the overall line, which counts each rule once.

<!-- scorecard-table:start -->
| Area | Rules in force | Checked by a tool | Advisory | Proposed rules | Open gaps |
|---|---|---|---|---|---|
| Architecture | 8 | 4 | 4 | 0 | 1 |
| Craft | 10 | 4 | 6 | 0 | 2 |
| Proportion | 1 | 0 | 1 | 0 | 1 |
| Code | 8 | 7 | 1 | 0 | 1 |
| Tests | 7 | 4 | 3 | 0 | 1 |
| Security | 7 | 5 | 2 | 4 | 0 |
| Reliability | 3 | 2 | 1 | 0 | 1 |
| Observability | 2 | 1 | 1 | 0 | 0 |
| API design | 3 | 3 | 0 | 3 | 0 |
| Performance | 1 | 0 | 1 | 0 | 1 |
| Supply chain and build | 8 | 8 | 0 | 0 | 2 |
| Delivery | 1 | 1 | 0 | 0 | 2 |
| Docs and decisions | 3 | 2 | 1 | 0 | 1 |
| UI and accessibility | 3 | 1 | 2 | 0 | 1 |
| Process | 17 | 6 | 11 | 0 | 0 |

**Overall:** 68 rules in force, 41 checked by a tool and 27 advisory; 7 proposed; 14 open gaps.

Open gaps:

- **GAP-001** (Architecture, proposed): No architecture rules for MAUI and desktop apps yet: ARC-001 covers web apps only.
- **GAP-019** (Craft, proposed; needs an analyzer package or a kit check, and a CI change): No tool checks nesting depth, statements per method, file length or class cohesion (LCOM4); CRF-008 leaves them to the reviewer agent.
- **GAP-020** (Craft, proposed; needs a tool and a CI change): No tool finds duplicated code, so DRY (CRF-003) rests on the reviewer agent.
- **GAP-002** (Proportion, proposed): No rule says how much structure a small app should get, so an agent can build every layer for a tiny app.
- **GAP-021** (Code, proposed; needs an ADR, and a change to every project or a recorded opt-out): CA1014 (mark assemblies CLS-compliant), a rule latest-all leaves off, is still off, though STY-003 says every rule is on. Declaring CLS compliance makes the compiler check it, and the sample then breaks it in 48 places; whether apps should declare it is a decision of its own. Microsoft's code analysis overview (https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/overview) says the eleven rules it lists as left off by latest-all, CA1014 among them, might be deprecated in a future version.
- **GAP-004** (Tests, proposed; needs packages and a CI change): Browser and accessibility tests (Playwright with axe) aren't set up for apps with a UI.
- **GAP-008** (Reliability, proposed): No rule for safe database migrations (backward-compatible steps, tested before deploy).
- **GAP-012** (Performance, proposed; needs packages): No benchmarks or performance budgets for hot paths, and no load tests.
- **GAP-013** (Supply chain and build, proposed; needs a tool or GitHub Action, and a CI change): No SBOM is produced for an app's build.
- **GAP-014** (Supply chain and build, proposed; needs a GitHub Action and a CI change): OpenSSF Scorecard, a tool that scores a repo's supply-chain security practices, isn't run; it would check this area from outside.
- **GAP-015** (Delivery, proposed; needs cloud resources and cost): No deployment pipeline: ADR-0023 decided on manual promotion to production, but nothing deploys an app yet.
- **GAP-016** (Delivery, proposed; needs cloud resources and cost): No infrastructure as code for an app's cloud resources.
- **GAP-017** (Docs and decisions, proposed): No runbooks: nothing says how to operate, recover or roll back an app.
- **GAP-018** (UI and accessibility, proposed): No rule requires WCAG 2.2 AA or checks it: only the plan checklist asks about accessibility (ARC-006, the plan-checklist skill). GAP-004 adds the tests.
<!-- scorecard-table:end -->

## Keeping it current

- Every rule in force must be named by at least one area here, or the check fails in CI. A proposed rule can wait until it's accepted.
- Closing a gap is its own pull request: it adds or changes rules and marks the gap `closed`. Gaps that need cost or cloud resources wait for the owner's OK in both modes; in review mode, so do gaps that need a package or a CI change (ADR-0035).
- After changing a rule or an area, run `./tools/Test-Scorecard.ps1 -Update` and commit the table.

Checks catch mechanical mistakes, not design. A well-tested, warning-free app can still be over-engineered or awkward to use; that judgment stays with the reviewer agent and the owner.
