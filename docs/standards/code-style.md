---
topic: code-style
rules:
  - id: STY-001
    statement: "Follow the Microsoft .editorconfig baseline at the repo root; every rule it adopts is a warning, and warnings fail the build."
    why: "The owner follows Microsoft Learn guidance; when severities weren't enforced, about 185 violations were found late."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-27", "ADR-0009"]
    enforcement: "build: EnforceCodeStyleInBuild and TreatWarningsAsErrors; tools/tests/BuildConfig.Tests.ps1"
    scope: core
    paths: ["**/*.cs", ".editorconfig"]
  - id: STY-002
    statement: "Never use var; write the type."
    why: "The owner corrected var usage as a Microsoft-convention violation."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-27", "ADR-0009"]
    enforcement: "build: IDE0008 at warning; tools/tests/BuildConfig.Tests.ps1 (UsesVar fixture)"
    scope: core
    paths: ["**/*.cs"]
  - id: STY-003
    statement: "Turn on every analyzer rule (AnalysisLevel latest-all); an opt-out needs an ADR."
    why: "Analyzer rules catch real defects; all of them on is the Microsoft baseline the owner asked for."
    layer: owner
    status: accepted
    sources: ["ADR-0009"]
    enforcement: "build: AnalysisLevel latest-all; tools/tests/BuildConfig.Tests.ps1 (CatchAll fixture)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-004
    statement: "Zero warnings: warnings are errors in every build."
    why: "A warning nobody must fix becomes noise that hides the next real one."
    layer: owner
    status: proposed
    sources: ["ADR-0009"]
    enforcement: "build: TreatWarningsAsErrors (compiler and NuGet warnings) and MSBuildTreatWarningsAsErrors (MSBuild task warnings); tools/tests/BuildConfig.Tests.ps1"
    scope: core
    paths: ["Directory.Build.props"]
  - id: STY-005
    statement: "Nullable reference types are on in every project."
    why: "The compiler then catches null misuse; part of the platinum standard the owner asked for."
    layer: owner
    status: proposed
    sources: ["owner, 2026-10-27"]
    enforcement: "build: Nullable enable; tools/tests/BuildConfig.Tests.ps1 (NullableViolation fixture)"
    scope: core
    paths: ["**/*.cs", "Directory.Build.props"]
  - id: STY-006
    statement: "Don't loosen a kit rule in a repo's own .editorconfig; an exception needs an ADR."
    why: "An .editorconfig entry overrides settings shipped in a package, so local edits could quietly turn rules off."
    layer: owner
    status: accepted
    sources: ["ADR-0009"]
    enforcement: "advisory: until the sync step's check for local overrides (after v0.1)"
    scope: core
    paths: [".editorconfig"]
---

# Code style

Microsoft's own conventions, enforced by the build (ADR-0009). The root `.editorconfig` records its sources by commit SHA and retrieval date, and marks every deviation from them with `(kit)`.

## Pending ratification

- **STY-004 (zero warnings):** the brief lists it as proposed (brief §7).
- **STY-005 (nullable on):** an agent added it under your "platinum standard" request.

Both are already on in `Directory.Build.props`. Accepting them changes nothing in the build. Rejecting one means an ADR and a props change.
