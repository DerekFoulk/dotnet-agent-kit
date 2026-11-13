---
topic: craft
rules:
  - id: CRF-001
    statement: "Fix the root cause of every defect, never work around it; a safety net that stays (a retry, a guard for a case that shouldn't happen, a suppressed warning) is labelled as one where it lives, with the reason it's needed."
    why: "The owner: never \"a janky fix, a 'work-around' or otherwise 'settle' for a suboptimal change\"; a workaround hides the defect it leaves behind."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-08"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "no tool can tell a fix from a workaround; the plan-checklist skill asks for the root cause, and code review checks it"
    scope: core
    paths: ["**"]
  - id: CRF-002
    statement: "Never ship a design known to be worse as good enough without saying so: name the better design and why it waits, and plan it in the same PR (a scorecard gap, or a follow-up PR or session)."
    why: "Settling quietly is how a known defect becomes permanent; saying so and planning it keeps the aim at the best design."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-08"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "only a person or code review can know a better design exists; the PR template's 'For the owner' and 'Not verified' sections carry it"
    scope: core
    paths: ["**"]
  - id: CRF-003
    statement: "Every piece of knowledge has one authoritative source (DRY is about knowledge, not text): any other place that states a rule, value or behavior is generated from that source, checked against it or points to it, while code that only looks alike but changes for different reasons stays apart."
    why: "A fact stated twice is eventually updated once, and the system disagrees with itself; binding together what only looks alike couples it to the wrong abstraction."
    layer: owner
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-08", "https://pragprog.com/tips/, retrieved 2026-11-10", "https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles, retrieved 2026-11-10"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: tools/Test-Duplication.ps1 runs PMD CPD in dotnet-ci.reusable.yml and fails when 100 tokens or more repeat in hand-written C#, outside a CPD-OFF region (ADR-0051)"
      - kind: advisory
        in: [kit, app]
        how: "checked by code review: each CPD-OFF region's reason, whether a repeat is knowledge or code that only looks alike, and duplication outside C# (docs, config, scripts) or in a file CPD can't read, or a copy with renamed variables or changed literals"
    scope: core
    paths: ["**"]
  - id: CRF-004
    statement: "Build the simplest design that is fully correct for today's requirements (KISS, YAGNI): no speculative layer, option or abstraction and no big design up front, and never a simpler design that's less correct; how much structure an app gets is ARC-009's (proposed) to settle."
    why: "Speculative design costs now and is usually wrong later; design that grows test by test fits the requirements it meets. Simple never means cutting a corner."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-08", "ADR-0018", "https://martinfowler.com/bliki/Yagni.html, retrieved 2026-11-10", "https://martinfowler.com/articles/designDead.html, retrieved 2026-11-10"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "no tool can judge what a requirement needs; the plan-checklist skill asks, and code review checks"
    scope: core
    paths: ["**"]
  - id: CRF-005
    statement: "Classes follow SOLID: one reason to change (single responsibility), extended without being edited (open-closed), usable wherever their base type is (Liskov substitution), small interfaces shaped by their clients (interface segregation), and every dependency explicit, passed in as a constructor or method parameter, and pointing toward abstractions, never from business code to infrastructure details (dependency inversion, explicit dependencies)."
    why: "Each principle keeps a change local: a class with one job, honest dependencies and substitutable subtypes can change or be replaced without breaking its callers."
    layer: owner
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-08", "https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles, retrieved 2026-11-10", "https://web.archive.org/web/20220121055640/http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod, retrieved 2026-11-10", "https://en.wikipedia.org/wiki/SOLID, retrieved 2026-11-10", "https://en.wikipedia.org/wiki/Liskov_substitution_principle, retrieved 2026-11-10"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "CA1506 and CA1501 (CRF-008) fail the build on a class with too many collaborators or too deep a hierarchy, which often signals a broken principle, but only code review can judge the principles themselves"
    scope: core
    paths: ["**/*.cs"]
  - id: CRF-006
    statement: "Keep concerns apart: business rules know nothing of UI, persistence or transport, and input is validated where it enters the system (a request, a message, a file, configuration), so the code inside can trust it; SEC-010 (proposed) says how an API validates a request."
    why: "Business logic that doesn't depend on details is easy to test and change; validating at the boundary stops bad input before it spreads (garbage in, garbage out), and OWASP asks for it as early as possible in the data flow."
    layer: owner
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-08", "https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles, retrieved 2026-11-10", "https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html, retrieved 2026-11-13"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's LayerTests and SharedLibraryTests (ArchUnitNET) fail when business code depends on infrastructure, UI or the API (ARC-001, ARC-003)"
      - kind: advisory
        in: [app]
        how: "until the app's Architecture.Tests carries the same tests, following the sample"
      - kind: advisory
        in: [kit, app]
        how: "validation at the boundary, checked by code review; for an API request, SEC-010's tests once it's accepted"
    scope: core
    paths: ["**/*.cs"]
  - id: CRF-007
    statement: "Namespaces depend on each other without cycles; dependencies point toward the more stable, more abstract code; and each project holds classes that change together and are reused together (high cohesion, low coupling)."
    why: "A cycle makes every namespace in it change and test as one; depending on stable abstractions keeps volatile details from rippling inward."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-08", "ADR-0043", "https://web.archive.org/web/20220121055640/http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod, retrieved 2026-11-10", "https://en.wikipedia.org/wiki/Acyclic_dependencies_principle, retrieved 2026-11-10"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's NamespaceCycleTests (ArchUnitNET slices) fail on a cycle among the Bookmarks namespace and the namespaces under it, in the five production assemblies that hold them"
      - kind: advisory
        in: [app]
        how: "until its own Architecture.Tests (TST-003) carries the same test, following the sample"
      - kind: advisory
        in: [kit, app]
        how: "stable dependencies and component cohesion, checked by code review"
    scope: core
    paths: ["**/*.cs", "**/*.csproj"]
  - id: CRF-008
    statement: "Stay within the metric limits: cyclomatic complexity 15 per method, class coupling 40 types per member and 95 per type, inheritance 5 levels deep, and a maintainability index of at least 10; raising a limit, or suppressing a metric rule for a whole project, needs an ADR."
    why: "Complex, tightly coupled or deeply inherited code is where defects collect; a few limits a tool enforces beat many that people ignore. NIST, as Microsoft's complexity page quotes it, accepts a limit of 15 instead of McCabe's 10 for projects with advantages such as structured programming, code walkthroughs and a comprehensive test plan, which the kit's test-first rules and gates provide. Nesting, statement and file-size limits are CRF-011's."
    layer: owner
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-08", "ADR-0043", "https://learn.microsoft.com/en-us/visualstudio/code-quality/code-metrics-cyclomatic-complexity, retrieved 2026-11-10", "https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1506, retrieved 2026-11-10"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: .globalconfig turns on CA1501, CA1502, CA1505, CA1506 and CA1509 at warning, and CodeMetricsConfig.txt sets the limits, so a breach or a malformed limit fails the build (tools/tests/BuildConfig.Tests.ps1, which also checks this statement's numbers against the file)"
    scope: core
    paths: ["**/*.cs", ".globalconfig", "CodeMetricsConfig.txt"]
  - id: CRF-009
    statement: "Avoid the STUPID anti-patterns (Singletons and other mutable global state, tight coupling, untestable code, premature optimization, names that don't say what a thing is, duplication), and design each part to be tested in isolation and each module separable enough to be deployed on its own later (ARC-001: one deployable app, with modules that can become services)."
    why: "Each of these makes code hard to change or to test; designing for testability and deployability keeps it honest."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-08", "ADR-0008", "https://williamdurand.fr/2013/07/30/from-stupid-to-solid-code/, retrieved 2026-11-10", "https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles, retrieved 2026-11-10", "https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/guidelines, retrieved 2026-11-13"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the coverage and mutation gates (TST-004) expose untestable code, CA1506 tight coupling, and the naming rules (CA17xx) some names, but no tool judges the design as a whole; code review checks"
    scope: core
    paths: ["**"]
  - id: CRF-010
    statement: "Use every library, tool and service as its authors document for the version in use, through its public API and documented extension points; never reach into non-public members or rely on undocumented behavior; lifting a ban in BannedSymbols.txt, even for one member, needs an ADR."
    why: "Internals and undocumented behavior change without notice in any release; the documented surface is what the authors promise to keep working. Microsoft's unsafe-code guidance says relying on .NET's internals isn't supported and that non-public BCL members change even in servicing releases; it covers BCL types and still allows UnsafeAccessor for serialization, so extending the ban to every library and to UnsafeAccessor is the owner's choice (ADR-0043)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-08", "ADR-0043", "https://learn.microsoft.com/dotnet/standard/unsafe-code/best-practices, retrieved 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: Microsoft.CodeAnalysis.BannedApiAnalyzers rejects the APIs in BannedSymbols.txt (BindingFlags.NonPublic, UnsafeAccessor, and the routes found so far that reach non-public members without it) with RS0030 in every project (tools/tests/BuildConfig.Tests.ps1)"
      - kind: advisory
        in: [kit, app]
        how: "relying on undocumented behavior, checked by code review"
    scope: core
    paths: ["**"]
  - id: CRF-011
    statement: "Keep nesting to 4 levels deep at most, 100 statements per member, 800 lines per file, and classes whose methods all share state (LCOM4 of 1); a member, type or file that needs more carries the comment // CRF-011 exception: <reason>, where it lives."
    why: "Deep nesting, long members and files, and classes whose members don't work together are where code gets hard to read and change (CRF-008's metrics don't measure them); a tool that enforces them keeps them from drifting, and an exception that carries its reason keeps a rare real case possible without hiding it (CRF-001)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-11", "ADR-0050"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: tools/Test-CodeShape.ps1 runs the kit's Kit.CodeShape tool in dotnet-ci.reusable.yml and fails on a breach outside generated code and outside a reasoned exception; tools/CodeShape/src/Kit.CodeShape/Limits.cs is the one source of the numbers, and tools/tests/Test-CodeShape.Tests.ps1 checks this statement against it"
    scope: core
    paths: ["**/*.cs"]
---

# Craft

The owner treats his work as a craft, not a job (owner, 2026-11-08): good fundamentals, no workarounds, no settling for a suboptimal change, and the aim of perfection in everything. These rules hold in the kit and in every repo that uses it.

Where Microsoft's [Architectural principles](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles) covers a principle, it's the source: separation of concerns, encapsulation (no mutable global state), dependency inversion, explicit dependencies, single responsibility and DRY.

## What each principle means here

- **Root causes (CRF-001, CRF-002).** A fix removes the cause; a workaround makes the symptom go away and leaves the cause in place. A safety net that stays, such as a retry around a call that shouldn't fail, is labelled as a safety net in the code, with the reason, so nobody mistakes it for the fix. An argument check on a public method (CA1062 asks for one) isn't a safety net either: it's part of the method's contract. A better design that has to wait is named and planned in the same PR, never left as "good enough".
- **DRY (CRF-003).** From *The Pragmatic Programmer* (Hunt and Thomas, tip 15): each piece of knowledge has one unambiguous, authoritative representation in the system. It's about knowledge, not text. Two constants with the same value but different meanings stay two constants; Microsoft's page puts it as "duplication is always preferable to coupling to the wrong abstraction".
- **KISS, YAGNI, no big design up front (CRF-004).** YAGNI ("you aren't gonna need it") comes from Extreme Programming. The simplest design means the simplest one that's fully correct, never the quickest one. How much structure a small app gets (modules, projects, patterns) is ARC-009's (proposed) to settle, in `docs/standards/architecture.md`.
- **SOLID (CRF-005).** Robert C. Martin set out the principles around 2000 ("Design Principles and Design Patterns"); Michael Feathers coined the acronym later. Dependencies are explicit: a class asks for what it needs through its constructor, and a Minimal API handler through its parameters, as the sample's endpoints do. They point toward abstractions where the direction matters, from business code toward its own interfaces, never toward infrastructure; an interface with one implementation and no such reason is speculation (CRF-004). Martin's own page lists the principles: [Principles of OOD](https://web.archive.org/web/20220121055640/http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod) (archived copy). The Liskov substitution principle is Barbara Liskov's (1987; with Jeannette Wing, "A behavioral notion of subtyping", 1994).
- **Separation of concerns and validation at the boundary (CRF-006).** Business rules sit in projects that depend on no infrastructure (ARC-001). Input is checked where it enters, once; code inside trusts its types.
- **Dependencies and cohesion (CRF-007).** Martin's package principles (*Agile Software Development, Principles, Patterns, and Practices*, 2002): the acyclic dependencies, stable dependencies and stable abstractions principles for how components depend on each other, and the reuse/release equivalence, common closure and common reuse principles (REP, CCP, CRP) for what goes in a component. The same page of Martin's lists all six. Martin states them for packages, meaning deployable binaries such as a .dll, not namespaces. In .NET the build already rejects a cycle between projects: restore fails with [MSB4006](https://learn.microsoft.com/en-us/visualstudio/msbuild/errors/msb4006), a circular dependency in its target graph (measured with SDK 10.0.404). So the kit applies the acyclic dependencies principle to namespaces, where cycles can still form unnoticed.
- **Metric limits (CRF-008), and the limits no analyzer checks (CRF-011, proposed).** See below.
- **STUPID (CRF-009).** William Durand's name (2013) for six habits that make code hard to change: Singleton, Tight coupling, Untestability, Premature optimization, Indescriptive naming, Duplication. Testability and deployability are design drivers: if a part can't be tested in isolation, the design changes, not the test.
- **Documented use (CRF-010).** Use each library, tool and service the way its documentation describes for the version in use. Where there's no documented way to do something, ask its authors for one; don't reach into its internals. The ban covers an app's own code too, since the analyzer can't tell whose type a call reaches. In an app's own code the way forward is to register each type explicitly, as the built-in container requires: Microsoft's dependency injection guidance registers each service by its type, and its [guidelines](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/guidelines) list convention-based (scanning) registration among the features the built-in container doesn't have. Making a type public is the way forward only when it belongs to a library's public API; in an executable project (the API, a worker), CA1515 keeps types internal. Against a library, a banned member has a public alternative, which its message names: for example, a dynamic `OrderBy` over an `IQueryable` builds its expression from `type.GetProperty(name)` and a `MethodInfo` taken from `typeof(Queryable).GetMethods()`, not from the by-name `Expression` factories.

## Checks

| Check | Where | What fails |
|---|---|---|
| CA1502, cyclomatic complexity | `.globalconfig` turns it on; `CodeMetricsConfig.txt` sets the limit | a method over the limit |
| CA1506, class coupling | same | a type or one of its members coupled to more types than its limit |
| CA1501, inheritance depth | same | a class deeper than the limit, counting base classes in its own module |
| CA1505, maintainability index | same | a type or one of its members under the limit |
| CA1509, the limits file itself | `.globalconfig` | an entry in `CodeMetricsConfig.txt` the rules can't read |
| The other rules `latest-all` leaves off | `.globalconfig` (which lists them), and `Directory.Build.props` for CA1017's `ComVisible(false)` and CA1014's `CLSCompliant(false)` | code that breaks one of them (STY-003) |
| RS0030, banned APIs | `BannedSymbols.txt`, read by `Microsoft.CodeAnalysis.BannedApiAnalyzers` | `BindingFlags.NonPublic`, `[UnsafeAccessor]`, and the other routes into non-public members found so far |
| Duplicate code (CRF-003) | `tools/Test-Duplication.ps1`, which runs PMD's copy-paste detector (CPD) in `dotnet-ci.reusable.yml` | a run of tokens repeated in hand-written C#, ignoring using directives, attributes and runs of literals; ADR-0051 sets the length |
| Nesting, statements per member, file length and LCOM4 (CRF-011, proposed) | `tools/Test-CodeShape.ps1`, which runs the kit's Kit.CodeShape tool in `dotnet-ci.reusable.yml` | a member nested too deep or with too many statements, a file too long, or a type whose methods form more than one group that shares no state |
| Namespace cycles | the sample's `NamespaceCycleTests` (ArchUnitNET) | a cycle among the root namespace and the namespaces under it; an app copies the test into its own Architecture.Tests |

`CodeMetricsConfig.txt` is the one source of the limits; CRF-008 states them for readers, and a Pester test fails if the two disagree. `tools/CodeShape/src/Kit.CodeShape/Limits.cs` is the one source of CRF-011's four, checked against its statement the same way. `.globalconfig` is the one list of the rules `latest-all` leaves off and the kit turns on; each has a fixture in `tools/tests/BuildConfig.Tests.ps1`. CA1509 can only be turned on in a global config, which is why these rules live there and not in `.editorconfig`. All of them are on; for CA1014, `Directory.Build.props` declares every assembly not CLS-compliant (ADR-0049). ADR-0043 records the limits and why each is where it is.

**What the checks miss.** CA1502 doesn't count the arms of a switch expression (measured with SDK 10.0.404), so a long one passes. The ban stops the routes into internals found so far, not every route: a cast such as `(BindingFlags)32`, `Type.GetType`, `Assembly.GetType` or `Module.GetType` with an internal type's name, `Module.ResolveField`, `ResolveMethod` and the other `Resolve` methods with a metadata token, `Type.GetInterfaceMap` and `GetRuntimeInterfaceMap` still get through. So do `PropertyInfo.GetValue` through a private getter and `SetValue` through a private setter, `GetType()` on an instance of an internal type (one handed back through a public interface, say), and `Type.GetInterfaces` or `GetInterface`, which also return internal interfaces a public type implements. None of these four can be banned without blocking their public use. CPD finds repeated code, not repeated knowledge: a rule stated in two shapes passes, and so does duplication in docs, config and scripts. For C# it can't ignore names or literals, so a copy with its variables renamed or its numbers changed, the commonest copy-paste, passes too. CPD takes any comment holding `CPD-OFF` as the start of a region, with or without a reason, and one with no `CPD-ON` runs to the end of the file. It can't read some newer C# (a raw string literal, for one), so it skips such a file with a warning in the CI log. Code review checks all of these. ADR-0051 records how CPD is tuned. The code shape check reads the code with Roslyn, the C# compiler's own parser. It works out what each name refers to (binding) only within a project's own files, with no package or project references, so a call it can't resolve counts as every member it could mean, or as none when nothing in view could match. It doesn't measure lambdas in field initializers, and it reads code under the SDK's implicit `#if` symbols (such as `NET10_0_OR_GREATER`) as if they weren't defined. Apps run it only in CI for now (GAP-022). ADR-0050 records how each limit is measured. Code in a `.razor` file reaches the compiler as generated code, so the metric analyzers, the code shape and duplicate code checks, and Stryker's mutation testing all skip it: an `@code` block of any size passes them. Keep logic in a `.razor.cs` code-behind file or a plain class, where every check reads it (ADR-0061).

**Exceptions.** Suppressing a metric or design rule for one member is a safety net under CRF-001: the suppression carries its reason (`Justification` on `[SuppressMessage]`, or a comment beside `#pragma warning disable`), and code review checks the reason holds. Raising a limit needs an ADR (CRF-008), and so does turning a rule off for a whole project (STY-003). RS0030 is never suppressed without an ADR, even for one member (CRF-010). The code shape check (CRF-011) has no analyzer to suppress, so its exception is a comment, `// CRF-011 exception: <reason>`, and where it sits says what it covers. As the last comment right before a member or type (before its attributes, with no blank line between), it covers that member, or that type's cohesion but not its members; before a property, its accessors too. As the file's first comment, with a blank line below it, it covers the file's length and its top-level statements. A marker with no reason covers nothing. Generated code is skipped by the compiler's own test (an `<auto-generated>` header, or a name such as `.g.cs` or `.designer.cs`); unlike the analyzers, the check doesn't read `generated_code` in `.editorconfig`, so such a file takes the exception comment. Both checks skip generated code this way. Code that looks alike but changes for different reasons, which CRF-003 keeps apart, goes between `// CPD-OFF <reason>` and `// CPD-ON`, CPD's own markers; code review checks the reason.
