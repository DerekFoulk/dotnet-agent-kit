---
topic: code-style
rules:
  - id: STY-001
    statement: "Follow the Microsoft .editorconfig baseline at the repo root; every rule it adopts is a warning (STY-004 makes warnings fail the build)."
    why: "The owner follows Microsoft's published conventions; when severities weren't enforced, about 185 violations were found late. The baseline is the dotnet/runtime repo's .editorconfig at a pinned commit; making each adopted rule a warning is the owner's choice, since that file sets most of them to suggestion."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-10-27", "ADR-0009", "https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: EnforceCodeStyleInBuild runs the style rules in every build, and STY-004's TreatWarningsAsErrors fails it on any of them; tools/tests/BuildConfig.Tests.ps1"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-002
    statement: "Use var only where the type is named on the right side of the assignment (a new or a cast), as dotnet/runtime does, and never for a built-in type such as int or string; everywhere else, write the type."
    why: "The owner first ruled var out entirely as a Microsoft-convention violation (owner, 2026-10-27). The rules audit found that stricter than Microsoft's own repos: dotnet/runtime leaves var to the author when the type is apparent (csharp_style_var_when_type_is_apparent is none), and only suggests the type elsewhere; the owner chose to follow it and to make the type a warning (owner, 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-10-27", "owner, 2026-11-12", "ADR-0009", "https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: IDE0008 at warning wherever the type isn't apparent (csharp_style_var_for_built_in_types and csharp_style_var_elsewhere false:warning, csharp_style_var_when_type_is_apparent false:none); tools/tests/BuildConfig.Tests.ps1 (the UsesVar and VarForBuiltInType fixtures fail, the VarWhenApparent fixture builds)"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-003
    statement: "Turn on every analyzer rule (AnalysisLevel latest-all, plus the root .globalconfig for the rules it leaves off); an opt-out needs an ADR."
    why: "Analyzer rules catch real defects. By default the SDK enables only some of its code-quality rules as build warnings in each .NET release; turning on all of them is the owner's choice of full rigor (brief §2), not Microsoft's default."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["ADR-0009", "ADR-0043", "ADR-0049", "owner, 2026-11-16", "https://learn.microsoft.com/dotnet/core/project-sdk/msbuild-props#analysislevel, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/base-types/best-practices-regex, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/native-interop/best-practices, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: AnalysisLevel latest-all, and the root .globalconfig for every rule latest-all leaves off, SYSLIB1045 ([GeneratedRegex]) and SYSLIB1054 ([LibraryImport]) among them, which the SDK leaves at info, with Directory.Build.props declaring ComVisible(false) on every assembly for CA1017 (ADR-0043) and CLSCompliant(false) for CA1014 (ADR-0049); tools/tests/BuildConfig.Tests.ps1 (the CatchAll fixture; one fixture per family of rules latest-all turns on that Microsoft's .NET best-practices pages rely on: strings and culture, CA1305, CA1307, CA1309, CA1310, CA1311; dispose, CA2000, CA1063, CA1816, CA1001; async, CA2008, CA2016, CA1849, CA2012, and CS4014, a compiler warning; logging, CA1848, CA2254, CA1727, CA1873; throwing, CA2200, CA2201, CA1510 to CA1513; and fixtures that cover every rule .globalconfig turns on)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props", ".globalconfig"]
  - id: STY-004
    statement: "Zero warnings: warnings are errors in every build."
    why: "A warning nobody must fix becomes noise that hides the next real one."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["ADR-0009", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: TreatWarningsAsErrors (compiler and NuGet warnings) and MSBuildTreatWarningsAsErrors (MSBuild task warnings); tools/tests/BuildConfig.Tests.ps1"
    scope: core
    paths: ["Directory.Build.props"]
  - id: STY-005
    statement: "Nullable reference types are on in every project and stay on in every file: no #nullable directive, no null-forgiving operator (!, null!, default!) outside a test project (a name ending in Tests) without the comment // CRF-001 safety net: <reason> on its line or the line above, and no file marked as generated code (a generated name or an <auto-generated> comment) that a tool didn't write into source; EF Core's migrations, in a Migrations folder, may carry the marker and #nullable disable, and a .resx file's designer the marker."
    why: "The compiler then catches null misuse; part of the platinum standard the owner asked for. STY-013 holds what Microsoft's pages say (a migrated project ends with no #nullable directives, and the operator is used sparingly); the kit goes further: it labels each operator, and it checks that no file is marked generated by hand, since the compiler treats a file marked as generated as nullable-disabled while its analyzers, the code shape check and the coverage gate skip it, so a marker on a hand-written file takes it out of all of them unseen (C# guidance pass, owner 2026-11-16: \"Yes, accept them\"). A test's ! follows an assertion that checked the value, or passes null on purpose to test a guard, so test projects may use the operator unlabelled, as STY-008 and CA2007 leave test projects out (owner, 2026-11-16: \"exempt tests\"). EF Core writes #nullable disable into every migration it generates."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-10-27", "owner, 2026-11-09", "owner, 2026-11-16"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: Nullable enable; tools/tests/BuildConfig.Tests.ps1 (NullableViolation fixture)"
      - kind: gate
        in: [kit, app]
        how: "ci: tools/Test-CodeShape.ps1, in dotnet-ci.reusable.yml's code shape step, reports a #nullable directive outside a Migrations folder, an unlabelled null-forgiving operator outside a test project, and a file marked generated outside a Migrations folder that isn't a .resx file's designer, as error STY005; Kit.CodeShape.Tests covers each rule"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-006
    statement: "Don't loosen a kit rule in a repo's own .editorconfig; an exception needs an ADR."
    why: "An .editorconfig entry overrides settings shipped in a package, so local edits could quietly turn rules off."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["ADR-0009"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "until the sync step's check for local overrides (after v0.1)"
    scope: core
    paths: [".editorconfig"]
  - id: STY-007
    statement: "Naming: by convention, C# programs use PascalCase for type names, namespaces and all public members; use camelCase for method parameters and local variables, and the s_ prefix for private and internal static fields (STY-014 changes this for static readonly and thread-static fields); use the Async suffix for methods that return awaitable types, which doesn't necessarily apply to methods your code doesn't call explicitly, such as event handlers or web controller methods; use meaningful and descriptive names for variables, methods and classes; avoid abbreviations and acronyms in names, except widely known and accepted abbreviations; avoid single-letter names, except simple loop counters; and identifiers shouldn't contain two consecutive underscores. For code: use the using syntax that doesn't need braces, collection expressions to initialize collection types, a concise form of new when the variable type matches the object type, parentheses to make clauses in an expression apparent, a dedicated System.Threading.Lock as the lock object of a lock statement (in .NET 9 and C# 13 or later), && and || instead of & and | in comparisons, Func and Action instead of defining delegate types, a lambda for an event handler you don't need to remove later, int rather than unsigned types, string interpolation to concatenate short strings, a StringBuilder to append strings in loops, required properties instead of constructors to force initialization, static members called through the class name, and meaningful names for query variables; prefer raw string literals to escape sequences or verbatim strings. For layout: one statement and one declaration per line, at least one blank line between method and property definitions, and comments on a separate line, beginning with an uppercase letter and ending with a period."
    why: "The owner asked for the C# documentation's recommendations as rules (owner O7, 2026-11-12: \"adhere to all of the guidance provided by Microsoft Learn\"); the rules audit mapped both pages recommendation by recommendation and made every one an analyzer can check a gate. The identifier names page gives an internal static field the s_ prefix, which the kit changes (STY-014)."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "By convention, C# programs use PascalCase for type names, namespaces, and all public members."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "Use camel casing when naming local variables, including instances of a delegate type."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "When writing method parameters, use camel casing."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "When working with static fields that are private or internal, use the s_ prefix and for thread static use t_."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "Use meaningful and descriptive names for variables, methods, and classes."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "Avoid using abbreviations or acronyms in names, except for widely known and accepted abbreviations."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "Avoid using single-letter names, except for simple loop counters."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names"
        retrieved: "2026-11-17"
        text: "Identifiers shouldn't contain two consecutive underscore (_) characters."
      - source: "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap"
        retrieved: "2026-11-17"
        text: "Use the Async suffix for methods that return awaitable types."
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Certain methods that aren't explicitly called by your code (such as event handlers or web controller methods) don't necessarily apply in this scenario."
      - source: "https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices"
        retrieved: "2026-11-17"
        text: "In .NET 9 and C# 13 or later, use a dedicated System.Threading.Lock instance as your lock object with the C# lock statement."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use the new using syntax that doesn't require braces:"
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use collection expressions to initialize all collection types:"
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use one of the concise forms of object instantiation when the variable type matches the object type, as shown in the following declarations."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use parentheses to make clauses in an expression apparent, as shown in the following code."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use int rather than unsigned types."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use string interpolation to concatenate short strings, as shown in the following code."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "To append strings in loops, especially when you're working with large amounts of text, use a System.Text.StringBuilder object."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Prefer raw string literals to escape sequences or verbatim strings."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use required properties instead of constructors to force initialization of property values:"
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use Func<> and Action<> instead of defining delegate types."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use && instead of & and || instead of | when you perform comparisons, as shown in the following example."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use a lambda expression to define an event handler that you don't need to remove later:"
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Call static members by using the class name: ClassName.StaticMember."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Use meaningful names for query variables."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Write only one statement per line."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Write only one declaration per line."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Add at least one blank line between method definitions and property definitions."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Place the comment on a separate line, not at the end of a line of code."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "Begin comment text with an uppercase letter."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "End comment text with a period."
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: .editorconfig's naming rules with IDE1006 at warning (the build reports a naming rule only at IDE1006's own severity), and IDE0063, IDE0300 to IDE0305, IDE0090, IDE0047, IDE0048 and IDE0330 at warning; tools/tests/BuildConfig.Tests.ps1 has a failing fixture for each"
      - kind: advisory
        in: [kit, app]
        how: "the recommendations no analyzer checks, checked by code review: an Async suffix on a method that returns an awaitable, async or not, except where a framework or the pages say otherwise (STY-014 lists the kit's exceptions); meaningful names, abbreviations only where widely known and accepted and single letters only for simple loop counters, no double underscore, int over unsigned types, string interpolation and StringBuilder in loops, raw string literals, required properties, Func and Action over custom delegates, && and || over & and |, lambdas for event handlers, static members through their declaring type, the LINQ guidance, one statement and one declaration per line, a blank line between members, and comments on their own line, starting with a capital letter and ending with a period"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-008
    statement: "Every publicly visible type and member has an XML documentation comment; STY-015 leaves test projects out."
    why: "The owner asked for the C# documentation's recommendations as rules (owner O7, 2026-11-12), and the coding conventions pass made XML documentation on every public member a gate. That goes beyond Microsoft's page, which says which comment style describes a member (STY-018), not that every public member has one, so it's the kit's decision. A comment on the public surface is what IntelliSense and a reviewer read."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-11-12", "ADR-0069"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: Directory.Build.props sets GenerateDocumentationFile in every project whose name doesn't end in Tests (STY-015), so the compiler reports CS1591 for an undocumented public member and STY-004 fails the build on it; tools/tests/BuildConfig.Tests.ps1 (the UndocumentedPublicMember fixture fails)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-009
    statement: "Code follows the Framework Design Guidelines wherever an analyzer checks them: the Design, Naming and Usage rules, CA1815 and CA1819 check internal APIs as well as public and protected ones, a struct whose members are all read-only is declared readonly, and the non-generic collections (ArrayList, Hashtable, Queue, Stack) give way to the generic ones."
    why: "The owner asked for Microsoft Learn's guidance as rules (owner O7, 2026-11-12); the Framework Design Guidelines pass found that 70 of the guidelines an analyzer gates rest on rules that check only public APIs by default, so they never reach an app, whose types CA1515 makes internal (owner, 2026-11-13: \"Yes, accept them\"; ADR-0070). Making every analyzer-checked guideline a build gate, on internal APIs too, and banning the non-generic collections are the owner's choices; the guidelines themselves are in STY-010."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-11-13", "ADR-0070", "owner, 2026-11-16", "https://learn.microsoft.com/dotnet/standard/design-guidelines/, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/fundamentals/code-analysis/code-quality-rule-options#api_surface, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/collections/thread-safe/, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: BannedSymbols.txt bans ArrayList, Hashtable and the non-generic Queue and Stack (RS0030) wherever code creates or calls one (a parameter or field typed as one isn't flagged, since nothing can fill it), which the thread-safe collections page and the Framework Design Guidelines replace with generic and concurrent collections (.NET best-practices pass, owner 2026-11-16); tools/tests/BuildConfig.Tests.ps1 has a failing fixture row for each"
      - kind: gate
        in: [kit, app]
        how: "build: .editorconfig sets api_surface to public, internal for the Design, Naming and Usage categories and for CA1815 and CA1819, keeps all for CA1068 and CA2208 (their own default), and csharp_style_prefer_readonly_struct to true:warning (IDE0250); tools/tests/BuildConfig.Tests.ps1 has a failing fixture for CA1051, CA1711, CA2225, CA1815, CA1819 and IDE0250 (on a struct and on a record struct), for a private CA2208 and CA1068, and for CA1064 on an internal exception in a class library (an Exe's internal exception builds, as CA1515 asks)"
    scope: core
    paths: ["**/*.cs", ".editorconfig", "BannedSymbols.txt"]
  - id: STY-010
    statement: "Classes and components that extend .NET should follow the Framework Design Guidelines."
    why: "The guidelines are organized as recommendations prefixed with Do, Consider, Avoid and Do not, and Microsoft warns that some of the information in them may be out of date. The owner asked for Microsoft Learn's guidance as rules (owner O7, 2026-11-12). The Framework Design Guidelines pass found 229 of their 369 guidelines are judgment no analyzer checks, and the owner accepted one advisory rule for them, with the themes worth a reviewer's eye in an app listed for code review (owner, 2026-11-13: \"Yes, accept them\"): exceptions, collections, parameters, naming, properties, events and operator overloads, in docs/code-review.md. STY-009 gates the guidelines an analyzer checks. The guidelines are written for public APIs; STY-016 applies them to internal ones too. The themes for libraries a kit app ships (versioning, extensibility, virtual and protected members) wait for the .NET library guidance pass."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    ratified: "owner, 2026-11-13"
    sources: ["https://learn.microsoft.com/dotnet/standard/design-guidelines/, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/exception-throwing, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/exceptions-and-performance, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/guidelines-for-collections, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/parameter-design, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/general-naming-conventions, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/property, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/event, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/design-guidelines/operator-overloads, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/"
        retrieved: "2026-11-17"
        text: "We recommend that you follow these design guidelines when developing classes and components that extend .NET."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/"
        retrieved: "2026-11-17"
        text: "The guidelines are organized as simple recommendations prefixed with the terms Do, Consider, Avoid, and Do not."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/"
        retrieved: "2026-11-17"
        text: "Some of the information in these guidelines may be out-of-date."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/exception-throwing"
        retrieved: "2026-11-17"
        text: "DO report execution failures by throwing exceptions."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/exceptions-and-performance"
        retrieved: "2026-11-17"
        text: "DO NOT use error codes because of concerns that exceptions might affect performance negatively."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/guidelines-for-collections"
        retrieved: "2026-11-17"
        text: "DO NOT use weakly typed collections in public APIs."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/parameter-design"
        retrieved: "2026-11-17"
        text: "DO use the least derived parameter type that provides the functionality required by the member."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/general-naming-conventions"
        retrieved: "2026-11-17"
        text: "DO favor readability over brevity."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/property"
        retrieved: "2026-11-17"
        text: "DO create get-only properties if the caller should not be able to change the value of the property."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/event"
        retrieved: "2026-11-17"
        text: "DO NOT pass null as the sender when raising a nonstatic event."
      - source: "https://learn.microsoft.com/dotnet/standard/design-guidelines/operator-overloads"
        retrieved: "2026-11-17"
        text: "AVOID defining operator overloads, except in types that should feel like primitive (built-in) types."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review: the reviewer agent checks the Framework Design Guidelines themes in docs/code-review.md and ranks a broken one Consider, or higher where it causes a defect; STY-009 gates the guidelines an analyzer checks"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-011
    statement: "Code awaits a task instead of blocking on it: no Task.Wait, Task.WaitAll, Task.WaitAny, Task<T>.Result or Thread.Sleep; where await can't reach, such as a synchronous interface the code must implement, it blocks with GetAwaiter().GetResult() and a comment saying why. No method or lambda is async void, except an event handler, which suppresses the rule where it lives with that reason: VSTHRD100 on a method, VSTHRD101 on a lambda (with #pragma warning disable, since a SuppressMessage attribute on a lambda compiles but doesn't suppress it). A returned Task is awaited or kept, never dropped unseen (fire-and-forget on purpose assigns it to a discard, _ = ..., with a comment saying why), and never disposed by a using in place of an await."
    why: "STY-017 holds what Microsoft's pages recommend; this rule turns it into bans and gates, which is the owner's choice. CA1849 flags a blocking call only inside an async method, so a ban covers the rest. Thread.Sleep is in the C# async page's table too: a pause is awaited, with Task.Delay. Event handlers are the one async void exception, and the threading analyzers flag them too, so each says why where it lives (ADR-0076). A dropped Task's exception is lost and nothing waits for it to finish, and a using over a Task<T> disposes the task, not the result it holds; the threading analyzers catch both where nothing else does, since CS4014 looks only inside async methods (owner, 2026-11-16: GAP-045)."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-11-16", "ADR-0076"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: BannedSymbols.txt bans every overload of Task.Wait, Task.WaitAll and Task.WaitAny, Task<T>.Result and Thread.Sleep (RS0030), and CA1849 flags a blocking call inside an async method; tools/tests/BuildConfig.Tests.ps1 has a failing fixture row for each banned call, a test that every public overload is listed, and a fixture that builds with GetAwaiter().GetResult(), the way out that needs no suppression; RS0030 is never suppressed without an ADR (CRF-010)"
      - kind: gate
        in: [kit, app]
        how: "build: Microsoft.VisualStudio.Threading.Analyzers, a global package reference, reports async void (VSTHRD100), an async lambda passed as a void delegate (VSTHRD101), a using statement over a Task (VSTHRD107) and a Task dropped in a method that isn't async (VSTHRD110), with its other rules off (ADR-0076), and the compiler reports a Task dropped in an async method (CS4014); tools/tests/BuildConfig.Tests.ps1 has a failing fixture for each"
      - kind: advisory
        in: [kit, app]
        how: "code review checks that each GetAwaiter().GetResult() is where await can't reach, with its reason, that a VSTHRD100 or VSTHRD101 suppression is on an event handler, that no using declaration holds a Task (using Task<Stream> stream = ...): VSTHRD107 checks only the using statement, and IDE0063 asks for the declaration; and that each discarded Task (_ = ...), which VSTHRD110 accepts, says why it isn't awaited"
    scope: core
    paths: ["**/*.cs", "BannedSymbols.txt", ".editorconfig", "Directory.Packages.props"]
  - id: STY-012
    statement: "Code follows Microsoft's .NET best-practices and C# guidance pages where no analyzer checks them; code review checks the themes docs/code-review.md lists."
    why: "The owner asked for Microsoft Learn's guidance as rules (owner O7, 2026-11-12). The .NET best-practices pass (21 pages) found 67 of its 157 recommendations, and the C# pass (8 pages) 30 of its 67, are judgment no analyzer checks; the owner accepted one advisory rule for them, like STY-010, with the themes worth a reviewer's eye listed for code review (owner, 2026-11-16: \"Yes, accept them\"). No one page says to follow the others, so this is the owner's decision to adopt them as a review checklist, and each recommendation stands at the strength of its own page. Where an analyzer, a ban or a kit rule checks a recommendation, that rule is its source (STY-003, STY-005, STY-007, STY-009, STY-011, ARC-008, OPS-003)."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-11-16", "owner, 2026-11-12", "https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/base-types/best-practices-strings, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/base-types/best-practices-display-data, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/base-types/best-practices-regex, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/core/extensions/best-practices-for-developing-world-ready-apps, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/implementing-the-task-based-asynchronous-pattern, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-dispose, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-disposeasync, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/datetime/choosing-between-datetime, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/core/extensions/options, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/fundamentals/exceptions/creating-and-throwing-exceptions, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/programming-guide/statements-expressions-operators/how-to-define-value-equality-for-a-type, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records, retrieved 2026-11-17"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review: the reviewer agent checks the .NET best-practices and C# themes in docs/code-review.md and ranks a broken one as that list says"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-013
    statement: "Choose Nullable enable for new projects and active projects where you want to protect against null reference exceptions. A project that migrated to nullable reference types ends with <Nullable>enable</Nullable> and no #nullable directives. Use the null-forgiving operator sparingly: prefer a null check, restructuring the code, or annotating the relevant API so the compiler reaches the right conclusion on its own."
    why: "The compiler then catches null misuse; each ! is a place it can no longer protect you. STY-005 is the kit's stricter form (a labelled operator, no hand-marked generated files)."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    ratified: "owner, 2026-11-16"
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/nullable-reference-types, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/advanced-topics/update-applications/nullable-migration-strategies, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/fundamentals/null-safety/nullable-reference-types, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/nullable-reference-types"
        retrieved: "2026-11-17"
        text: "Choose enable for new projects and active projects where you want to protect against null reference exceptions."
      - source: "https://learn.microsoft.com/dotnet/csharp/advanced-topics/update-applications/nullable-migration-strategies"
        retrieved: "2026-11-17"
        text: "The end state is the same in every case: the project sets <Nullable>enable</Nullable> and contains no #nullable preprocessor directives."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/null-safety/nullable-reference-types"
        retrieved: "2026-11-17"
        text: "Use ! sparingly. Each occurrence is a place the compiler can no longer protect you. Prefer adding a null check, restructuring the code, or annotating the relevant API so the compiler reaches the right conclusion on its own."
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: Nullable enable; tools/tests/BuildConfig.Tests.ps1 (NullableViolation fixture); STY-005 adds the CI checks"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-014
    statement: "Where the kit departs from STY-007's pages: a static readonly field that isn't private takes PascalCase, not s_; a thread-static field takes s_, not t_ (a naming rule can't tell a field by its [ThreadStatic] attribute); a constructor that only assigns its parameters is a primary constructor (IDE0290); and an Async suffix isn't required on an event handler, a controller action (MVC trims the suffix, so nameof() in CreatedAtAction would name a missing action), middleware's Invoke or a test method (ADR-0076: a naming rule tripped these, so the owner's decision keeps the suffix advisory)."
    why: "The kit's choices where the pages leave room or the build can't follow them. Microsoft's field naming guidelines give a public static field PascalCase and no prefix, and the identifier names page gives an internal static field s_, which CA1707, checking internal APIs here, fails as an underscore: CA1707 fails an underscore in a static readonly field on an internal API (STY-009), so no name is built on one, and a static readonly field that isn't private takes the PascalCase the Framework Design Guidelines give a public one (owner, 2026-11-16). A primary constructor is the owner's addition from the IDE style rules (owner, 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-11-12", "owner, 2026-11-16", "ADR-0076", "https://learn.microsoft.com/dotnet/standard/design-guidelines/names-of-type-members#names-of-fields, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1707, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: .editorconfig's naming rules with IDE1006 at warning, and IDE0290 at warning; tools/tests/BuildConfig.Tests.ps1 has a failing fixture for each, a static readonly field's s_ on each side of the private boundary among them, and a fixture that builds with a PascalCase static readonly field at every accessibility but private"
      - kind: advisory
        in: [kit, app]
        how: "code review checks the Async suffix and its exceptions"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-015
    statement: "Test projects (names ending in Tests) and the project BenchmarkDotNet generates for a run are left out of STY-008's XML documentation requirement."
    why: "A test class's name already says what it checks (ADR-0069); a comment on the public surface is what IntelliSense and a reviewer read, and a test project has none."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["ADR-0069", "owner, 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: Directory.Build.props sets GenerateDocumentationFile only in a project whose name doesn't end in Tests, and not in the project BenchmarkDotNet generates for a run; tools/tests/BuildConfig.Tests.ps1 (the UndocumentedTestProject and BenchmarkDotNetGenerated fixtures build)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-016
    statement: "Code review applies STY-010's Framework Design Guidelines themes to internal APIs too."
    why: "The guidelines are written for public APIs; like STY-009, the kit applies the themes to internal ones, since CA1515 makes an app's types internal (owner, 2026-11-13)."
    layer: owner
    basis: preference
    status: accepted
    strength: must
    ratified: ADR-0090
    sources: ["owner, 2026-11-13"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review: the reviewer agent applies docs/code-review.md's Framework Design Guidelines themes to internal types and members as well"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-017
    statement: "If a program needs the result of a task, write code that implements the await expression in a nonblocking manner: await instead of Task.Wait or Task.Result, await Task.WhenAny instead of Task.WaitAny, await Task.WhenAll instead of Task.WaitAll and await Task.Delay instead of Thread.Sleep. Synchronous blocking on asynchronous operations should be avoided whenever possible; where you must block synchronously, GetAwaiter().GetResult() is generally the preferred approach, and blocking with Wait() and Result is discouraged. Return async void only from event handlers; other methods that don't return a value should return a Task. Tasks returned from async methods should be awaited, or assigned to a variable for observation later; where a using expression holds a Task, add the await operator within it."
    why: "Blocking can deadlock under a synchronization context and ties up a thread the pool needs; Wait and Result also wrap the exception in an AggregateException, which GetAwaiter().GetResult() doesn't. An async void method can't be awaited, so its caller can't catch its exception, which is likely to bring the app down. STY-011 turns this into the kit's bans and gates."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    ratified: "owner, 2026-11-16"
    sources: ["https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-return-types, retrieved 2026-11-17", "https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD107.md, retrieved 2026-11-25", "https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD110.md, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "If your program needs the result of a task, write code that implements the await expression in a nonblocking manner. Blocking the current thread as a means to wait synchronously for a Task item to complete can result in deadlocks and blocked context threads."
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Task scenario Current code Replace with 'await'"
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Retrieve the result of a background task Task.Wait or Task.Result await"
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Continue when any task completes Task.WaitAny await Task.WhenAny"
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Continue when all tasks complete Task.WaitAll await Task.WhenAll"
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Continue after some amount of time Thread.Sleep await Task.Delay"
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Synchronous blocking on asynchronous operations can lead to deadlocks and should be avoided whenever possible. The preferred solution is to use async/await throughout your call stack."
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "The GetAwaiter().GetResult() pattern is generally the preferred approach when you must block synchronously:"
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "You can use a blocking approach by calling Wait() and Result. However, this approach is discouraged because it wraps exceptions in AggregateException."
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios"
        retrieved: "2026-11-17"
        text: "Return 'async void' only from event handlers"
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-return-types"
        retrieved: "2026-11-17"
        text: "For methods other than event handlers that don't return a value, you should return a Task instead, because an async method that returns void can't be awaited."
      - source: "https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-return-types"
        retrieved: "2026-11-17"
        text: "The caller of a void-returning async method can't catch exceptions thrown from the method. Such unhandled exceptions are likely to cause your application to fail."
      - source: "https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD110.md"
        retrieved: "2026-11-17"
        text: "Tasks returned from async methods should be awaited, or assigned to a variable for observation later."
      - source: "https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD107.md"
        retrieved: "2026-11-25"
        text: "Add the await operator within the using expression or variable initializer."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks it where STY-011's bans and analyzers don't reach"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-018
    statement: "For describing methods, classes, fields and all public members, use XML comments."
    why: "Microsoft's coding conventions page sets this among its comment styles: it says which kind of comment a description is, not which members need one. STY-008 is the kit's requirement that every publicly visible type and member has an XML documentation comment, which the build gates."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions"
        retrieved: "2026-11-17"
        text: "For describing methods, classes, fields, and all public members use XML comments."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that a comment describing a method, class, field or public member is an XML comment, not a // or /* */ one; STY-008's CS1591 gate requires one on every publicly visible type and member outside test projects"
    scope: core
    paths: ["**/*.cs"]
---

# Code style

Microsoft's own conventions, enforced by the build (ADR-0009). The root `.editorconfig` records its sources by commit SHA and retrieval date, and marks every deviation from them with `(kit)`.
