---
topic: code-style
rules:
  - id: STY-001
    statement: "Follow the Microsoft .editorconfig baseline at the repo root; every rule it adopts is a warning (STY-004 makes warnings fail the build)."
    why: "The owner follows Microsoft Learn guidance; when severities weren't enforced, about 185 violations were found late."
    layer: owner
    basis: authority
    status: accepted
    sources: ["owner, 2026-10-27", "ADR-0009", "https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig, retrieved 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: EnforceCodeStyleInBuild runs the style rules in every build, and STY-004's TreatWarningsAsErrors fails it on any of them; tools/tests/BuildConfig.Tests.ps1"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-002
    statement: "Use var only where the type is named on the right side of the assignment (a new or a cast), as dotnet/runtime does, and never for a built-in type such as int or string; everywhere else, write the type."
    why: "The owner first ruled var out entirely as a Microsoft-convention violation (owner, 2026-10-27). The rules audit found that stricter than Microsoft's own repos: dotnet/runtime leaves var to the author when the type is apparent, and asks for the type elsewhere; the owner chose to follow it (owner, 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-10-27", "owner, 2026-11-12", "ADR-0009", "https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig, retrieved 2026-11-13"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: IDE0008 at warning wherever the type isn't apparent (csharp_style_var_for_built_in_types and csharp_style_var_elsewhere false:warning, csharp_style_var_when_type_is_apparent false:none); tools/tests/BuildConfig.Tests.ps1 (the UsesVar and VarForBuiltInType fixtures fail, the VarWhenApparent fixture builds)"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-003
    statement: "Turn on every analyzer rule (AnalysisLevel latest-all, plus the root .globalconfig for the rules it leaves off); an opt-out needs an ADR."
    why: "Analyzer rules catch real defects. Microsoft's default AnalysisLevel turns on only some of them; turning on all of them is the owner's choice of full rigor (brief §2), not Microsoft's default."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0009", "ADR-0043", "ADR-0049", "https://learn.microsoft.com/dotnet/core/project-sdk/msbuild-props#analysislevel, retrieved 2026-11-13"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: AnalysisLevel latest-all, and the root .globalconfig for every rule latest-all leaves off, with Directory.Build.props declaring ComVisible(false) on every assembly for CA1017 (ADR-0043) and CLSCompliant(false) for CA1014 (ADR-0049); tools/tests/BuildConfig.Tests.ps1 (the CatchAll fixture; one fixture per family of rules latest-all turns on that Microsoft's .NET best-practices pages rely on: strings and culture, CA1305, CA1307, CA1309, CA1310, CA1311; dispose, CA2000, CA1063, CA1816, CA1001; async, CA2008, CA2016, CA1849, CA2012, CS4014; logging, CA1848, CA2254, CA1727, CA1873; throwing, CA2200, CA2201, CA1510 to CA1513; and fixtures that cover every rule .globalconfig turns on)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props", ".globalconfig"]
  - id: STY-004
    statement: "Zero warnings: warnings are errors in every build."
    why: "A warning nobody must fix becomes noise that hides the next real one."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0009", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: TreatWarningsAsErrors (compiler and NuGet warnings) and MSBuildTreatWarningsAsErrors (MSBuild task warnings); tools/tests/BuildConfig.Tests.ps1"
    scope: core
    paths: ["Directory.Build.props"]
  - id: STY-005
    statement: "Nullable reference types are on in every project."
    why: "The compiler then catches null misuse; part of the platinum standard the owner asked for."
    layer: owner
    basis: authority
    status: accepted
    sources: ["owner, 2026-10-27", "owner, 2026-11-09", "https://learn.microsoft.com/dotnet/csharp/nullable-references, retrieved 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: Nullable enable; tools/tests/BuildConfig.Tests.ps1 (NullableViolation fixture)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-006
    statement: "Don't loosen a kit rule in a repo's own .editorconfig; an exception needs an ADR."
    why: "An .editorconfig entry overrides settings shipped in a package, so local edits could quietly turn rules off."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0009"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "until the sync step's check for local overrides (after v0.1)"
    scope: core
    paths: [".editorconfig"]
  - id: STY-007
    statement: "Code follows Microsoft's C# coding conventions and identifier names: PascalCase for types, namespaces, members, local functions and local constants, camelCase for parameters and locals; simple using declarations; collection expressions; a target-typed new() where the type is apparent; a primary constructor where a constructor only assigns its parameters; and parentheses wherever operators of different precedence meet."
    why: "The owner asked for the C# documentation's recommendations as rules (owner O7, 2026-11-12: \"adhere to all of the guidance provided by Microsoft Learn\"); the rules audit mapped both pages recommendation by recommendation and made every one an analyzer can check a gate."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions, retrieved 2026-11-12", "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names, retrieved 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: .editorconfig's naming rules with IDE1006 at warning (the build reports a naming rule only at IDE1006's own severity), and IDE0063, IDE0300 to IDE0305, IDE0090, IDE0290, IDE0047 and IDE0048 at warning; tools/tests/BuildConfig.Tests.ps1 has a failing fixture for each"
      - kind: advisory
        in: [kit, app]
        how: "the recommendations no analyzer checks, checked by code review: meaningful names without abbreviations or single letters, no double underscore, t_ for thread-static fields, int over unsigned types, string interpolation and StringBuilder in loops, raw string literals, required properties, Func and Action over custom delegates, && and || over & and |, lambdas for event handlers, static members through their declaring type, the LINQ guidance, one statement and one declaration per line, a blank line between members, and comments on their own line, starting with a capital letter and ending with a period"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-008
    statement: "Every publicly visible type and member has an XML documentation comment; test projects (names ending in Tests) are left out."
    why: "The owner asked for the C# documentation's recommendations as rules (owner O7, 2026-11-12); the coding conventions pass made XML documentation on public members a gate. A comment on the public surface is what IntelliSense and a reviewer read; a test class's name already says what it checks (ADR-0069)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "ADR-0069", "https://learn.microsoft.com/dotnet/csharp/language-reference/xmldoc/, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/csharp/language-reference/xmldoc/recommended-tags, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions, retrieved 2026-11-15"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: Directory.Build.props sets GenerateDocumentationFile in every project whose name doesn't end in Tests (and not in the project BenchmarkDotNet generates for a run, ADR-0069), so the compiler reports CS1591 for an undocumented public member and STY-004 fails the build on it; tools/tests/BuildConfig.Tests.ps1 (the UndocumentedPublicMember fixture fails; the UndocumentedTestProject and BenchmarkDotNetGenerated fixtures build)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-009
    statement: "Code follows the Framework Design Guidelines wherever an analyzer checks them: the Design, Naming and Usage rules, CA1815 and CA1819 check internal APIs as well as public and protected ones, and a struct whose members are all read-only is declared readonly."
    why: "The owner asked for Microsoft Learn's guidance as rules (owner O7, 2026-11-12); the Framework Design Guidelines pass found that 70 of the guidelines an analyzer gates rest on rules that check only public APIs by default, so they never reach an app, whose types CA1515 makes internal (owner, 2026-11-13: \"Yes, accept them\"; ADR-0070)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-13", "ADR-0070", "https://learn.microsoft.com/dotnet/standard/design-guidelines/, retrieved 2026-11-13", "https://learn.microsoft.com/dotnet/fundamentals/code-analysis/code-quality-rule-options#api_surface, retrieved 2026-11-15"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: .editorconfig sets api_surface to public, internal for the Design, Naming and Usage categories and for CA1815 and CA1819, keeps all for CA1068 and CA2208 (their own default), and csharp_style_prefer_readonly_struct to true:warning (IDE0250); tools/tests/BuildConfig.Tests.ps1 has a failing fixture for CA1051, CA1711, CA2225, CA1815, CA1819 and IDE0250 (on a struct and on a record struct), and for a private CA2208 and CA1068"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-010
    statement: "Code follows the Framework Design Guidelines where no analyzer checks them; code review checks the themes docs/code-review.md lists."
    why: "The owner asked for Microsoft Learn's guidance as rules (owner O7, 2026-11-12). The Framework Design Guidelines pass found 229 of their 369 guidelines are judgment no analyzer checks, and the owner accepted one advisory rule for them, with the themes worth a reviewer's eye in an app listed for code review (owner, 2026-11-13: \"Yes, accept them\"). The guidelines are written for public APIs; like STY-009, the kit applies the themes to internal ones too, since CA1515 makes an app's types internal. The themes for libraries a kit app ships (versioning, extensibility, virtual and protected members) wait for the .NET library guidance pass."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-13", "https://learn.microsoft.com/dotnet/standard/design-guidelines/, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/exception-throwing, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/exceptions-and-performance, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/guidelines-for-collections, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/parameter-design, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/general-naming-conventions, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/property, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/event, retrieved 2026-11-15", "https://learn.microsoft.com/dotnet/standard/design-guidelines/operator-overloads, retrieved 2026-11-15"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review: the reviewer agent checks the Framework Design Guidelines themes in docs/code-review.md and ranks a broken one Consider, or higher where it causes a defect; STY-009 gates the guidelines an analyzer checks"
    scope: core
    paths: ["**/*.cs"]
---

# Code style

Microsoft's own conventions, enforced by the build (ADR-0009). The root `.editorconfig` records its sources by commit SHA and retrieval date, and marks every deviation from them with `(kit)`.
