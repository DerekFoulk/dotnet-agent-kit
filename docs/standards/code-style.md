---
topic: code-style
rules:
  - id: STY-001
    statement: "Follow the Microsoft .editorconfig baseline at the repo root; every rule it adopts is a warning, and warnings fail the build."
    why: "The owner follows Microsoft Learn guidance; when severities weren't enforced, about 185 violations were found late."
    layer: owner
    basis: authority
    status: accepted
    sources: ["owner, 2026-10-27", "ADR-0009", "https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig, retrieved 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: EnforceCodeStyleInBuild and TreatWarningsAsErrors; tools/tests/BuildConfig.Tests.ps1"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-002
    statement: "Never use var; write the type."
    why: "The owner corrected var usage as a Microsoft-convention violation."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-10-27", "ADR-0009"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: IDE0008 at warning; tools/tests/BuildConfig.Tests.ps1 (UsesVar fixture)"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-003
    statement: "Turn on every analyzer rule (AnalysisLevel latest-all, plus the root .globalconfig for the rules it leaves off); an opt-out needs an ADR."
    why: "Analyzer rules catch real defects; all of them on is the Microsoft baseline the owner asked for."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0009", "ADR-0043", "ADR-0049"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: AnalysisLevel latest-all, and the root .globalconfig for every rule latest-all leaves off, with Directory.Build.props declaring ComVisible(false) on every assembly for CA1017 (ADR-0043) and CLSCompliant(false) for CA1014 (ADR-0049); tools/tests/BuildConfig.Tests.ps1 (the CatchAll fixture, and fixtures that cover every rule .globalconfig turns on)"
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
---

# Code style

Microsoft's own conventions, enforced by the build (ADR-0009). The root `.editorconfig` records its sources by commit SHA and retrieval date, and marks every deviation from them with `(kit)`.
