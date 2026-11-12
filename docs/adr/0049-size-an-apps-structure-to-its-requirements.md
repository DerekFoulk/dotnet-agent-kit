# ADR-0049: Size an app's structure to its requirements

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

CRF-004 says to build the simplest design that's fully correct for today's requirements, and leaves how much structure an app gets to scorecard gap GAP-002: "No rule says how much structure a small app should get, so an agent can build every layer for a tiny app." An agent asked for a small app can follow ARC-001 to the letter and still overbuild: a module per entity, every tactical domain-driven design (DDD) pattern, a mediator, a generic repository and an interface for every class.

What's already decided limits the answer:

- **ARC-001 and ADR-0008** (owner, accepted): a web app is Clean Architecture in one deployable app; each distinct business area is a module with Domain, Application, Infrastructure, Presentation and Contracts projects; Application code is grouped by feature; a project can deviate by ADR. ADR-0008 records why: the owner builds every project as if an enterprise team builds it, and wants the same libraries reused by web and MAUI apps (ARC-003).
- **CRF-009** (owner, accepted): each module is separable enough to be deployed on its own later. **ARC-004**: microservices only by ADR.
- **CRF-004**, in craft.md's SOLID notes: an interface with one implementation and no reason to invert a dependency is speculation.
- **TST-003**: one test project per production project, plus the shared IntegrationTests, FunctionalTests, E2E.Tests and Architecture.Tests projects, so most extra production projects also bring a test project.
- **GAP-001** is still open: ARC-001 covers web apps only, and the structure of MAUI and desktop apps isn't settled.

Microsoft's guidance, checked through the Microsoft Learn MCP server on 2026-11-11:

- *Common web application architectures*: "The smallest possible number of projects for an application architecture is one." A single project keeps concerns apart by folders, which works until size and complexity grow; Clean Architecture is "the most appropriate way to structure non-trivial monolithic applications."
- *Design a microservice-oriented application* and *Design a DDD-oriented microservice*: DDD patterns "should be applied only if you are implementing complex microservices with significant business rules. Simpler responsibilities, like a CRUD service, can be managed with simpler approaches." Applying advanced DDD patterns to simple services is "over-engineering them."
- *Apply CQRS and CQS approaches*: CQRS and DDD patterns aren't top-level architectures; "forcing the same pattern everywhere leads to failure."
- *Design a microservice domain model*: for a simple CRUD context, entities with only data properties aren't an anti-pattern.
- *Creating a simple data-driven CRUD microservice*: eShopOnContainers' catalog service is one ASP.NET Core Web API project that holds its data model, business logic and data access.
- Azure Well-Architected Framework, Reliability, *Keep it simple* and RE:01: "Avoid overengineering the architecture design, application code, and operations"; add components "only if they help you achieve target business values"; "justify every design decision with a business requirement."

## Options

### Option 1: One rule that sizes structure in steps, inside ARC-001, with a check for empty projects

ARC-009 says how to decide, in four steps:

1. A web app keeps ARC-001's structure but starts with one module. It gets another only for a second distinct business area (its own language, data and rules: a bounded context in DDD's terms), never per entity or feature.
2. A console tool, a standalone worker or a library starts as one project and its tests, its concerns kept apart by namespace. It gets a second project only for code that another app must share, or a boundary the compiler must enforce. MAUI and desktop apps stay GAP-001's.
3. No project exists before its first real type, and that includes each of ARC-001's five module projects. This reads ARC-001's list as a module's full shape, reached as each project's first type arrives, not a set to scaffold on day one: a one-module app that no other module calls has no Contracts project yet.
4. Inside a module, some patterns come only with a requirement the plan names. Microsoft keeps aggregates, value objects, domain events and CQRS for complex domains. The kit adds a mediator, a generic repository and an interface that inverts no dependency, which CRF-004 calls speculation until a requirement needs them.

A new script, `Test-EmptyProjects.ps1`, fails CI when a project in the solution has no source of its own, or still holds the class library template's empty `Class1`: the trace an agent leaves when it scaffolds a layer before anything needs it. The plan-checklist skill asks the four questions, and the reviewer agent checks the rest.

- **Trade-offs:** ARC-001's architecture for web apps stays, and proportion governs how many modules there are, when each project appears and what goes inside. Step 3 is a reading of ARC-001 (owner, accepted): it says a module's five projects arrive with their first types, while ARC-001's text can be read as all five from the start. Accepting ARC-009 accepts that reading. One script and one CI step, no package. The judgment calls (what a business area is, whether a pattern pays) stay advisory.
- **Reversibility:** Easy. Drop the CI step and the script; the rule is text.
- **Risk:** Low. The check sees only empty projects, not a project with one pointless class; the reviewer covers that.

### Option 2: Let a small web app be one project, amending ARC-001

Follow Microsoft's sizing literally: a web app starts as one ASP.NET Core project, with folders for its concerns and an architecture test for their direction, and moves to ARC-001's modules when it stops being trivial.

- **Trade-offs:** The least structure for a tiny app, as Microsoft's single-project and CRUD guidance describe. But it reverses part of the owner's accepted ADR-0008: business rules a MAUI app should reuse would sit in the web project (against ARC-003), the compiler would no longer enforce the layers, and someone would have to judge when an app stops being trivial, then split it later, which costs more than starting split.
- **Reversibility:** Moderate. Splitting a grown single project into modules is a large refactor.
- **Risk:** Medium. "Small" is the judgment agents get wrong; the split tends to come late.

### Option 3: Advisory guidance only, with no check

The same text as Option 1, enforced only by the plan checklist and the reviewer.

- **Trade-offs:** Least work. But an empty scaffolded project, the one part a tool can see, would rest on a reader noticing it.
- **Reversibility:** Easy.
- **Risk:** Medium: an agent creates all five projects of a module up front, and nothing stops it.

## Recommendation

Option 1: it settles GAP-002 within the owner's accepted architecture, grounded in Microsoft's sizing guidance, and checks the one part a tool can see. Option 2 changes ADR-0008, which is the owner's call alone.

## Decision

Proposed (auto mode, ADR-0035), with ARC-009. The owner accepts or changes it, including step 3's reading of ARC-001, and decides whether Option 2's single-project web app is worth an amendment to ADR-0008.

## Consequences

- New rule ARC-009 (proposed) in `docs/standards/architecture.md`, in the scorecard's Proportion area. GAP-002 is closed. CRF-004 points at ARC-009 instead of the gap.
- `tools/Test-EmptyProjects.ps1`, with Pester tests. `dotnet-ci.reusable.yml` runs it for the kit and every app, after the deprecated-packages step. Export-KitApp copies it to an app's `.kit/tools/`, and the app's `AGENTS.md` lists it.
- The plan-checklist skill gains a "Proportion" heading with ARC-009's questions.
- An app whose solution holds an empty project, or the class library template's `Class1`, fails CI when its kit pin moves past this change, though ARC-009 is still proposed (as OPS-004's runbook check did, ADR-0047). Removing the project, or the placeholder, fixes it.
- **What the check misses:** a project with one class nobody needs, a pattern nobody needs, a module per entity. It counts C# and Razor files under each project's folder, outside `bin/` and `obj/`, so a project whose folder holds another project's files, or that compiles only linked files, isn't read correctly. The reviewer agent checks these.
- MAUI and desktop apps keep ADR-0008's MVVM defaults; their project structure is GAP-001's to settle.

## Pillars affected

- **Reliability:** fewer components and less code to fail (WAF RE:01, "Keep it simple").
- **Operational Excellence:** less structure to build, test and maintain; each project that exists carries code and its tests (TST-003).
- **Cost Optimization:** no speculative work, and no extra build or CI time for empty projects.
- **Performance Efficiency:** no mediator or extra layer between an endpoint and its work unless a requirement asks for one.

## Sources

- owner, 2026-11-06
- ADR-0008
- https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/dotnet/architecture/microservices/multi-container-microservice-net-applications/microservice-application-design, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/eshoponcontainers-cqrs-ddd-microservice, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/dotnet/architecture/microservices/multi-container-microservice-net-applications/data-driven-crud-microservice, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/well-architected/reliability/principles, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/well-architected/reliability/simplify, retrieved 2026-11-11
