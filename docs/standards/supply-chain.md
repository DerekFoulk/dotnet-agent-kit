---
topic: supply-chain
rules:
  - id: SUP-001
    statement: "Every project restores with a package lock file, and CI restores in locked mode; the one exception is a project that pulls in SDK-implicit packages (trimming, AOT, Blazor WebAssembly), which may set RestorePackagesWithLockFile to false with a comment citing ADR-0020 until the SDK fixes dotnet/sdk#38200."
    why: "CI restores exactly what was tested, and a tampered package fails its hash check; SDK-implicit packages change with every SDK patch, so their lock files churn (ADR-0020). Central package management still pins those projects' versions."
    layer: owner
    status: accepted
    sources: ["ADR-0020"]
    enforcement: "build: RestorePackagesWithLockFile, RestoreLockedMode when CI=true; tools/tests/BuildConfig.Tests.ps1; ci: dependabot-lockfiles.yml refreshes the lock files Dependabot misses on its NuGet PRs (tools/tests/DependabotLockfiles.Tests.ps1); on macOS, where a MAUI project builds a subset of its frameworks, CI restores unlocked and tools/Test-LockFileSubset.ps1 holds each lock file to the committed one (ADR-0057)"
    scope: core
    paths: ["**/*.csproj", "**/packages.lock.json", "Directory.Build.props"]
  - id: SUP-002
    statement: "Package versions live only in Directory.Packages.props (central package management), with transitive pinning on."
    why: "One reviewed file controls every version, including transitive ones."
    layer: owner
    status: accepted
    sources: ["ADR-0020", "owner, 2026-11-09"]
    enforcement: "build: ManagePackageVersionsCentrally makes a version in a project file a restore error (NU1008)"
    scope: core
    paths: ["Directory.Packages.props", "**/*.csproj"]
  - id: SUP-003
    statement: "Packages come only from nuget.org, enforced by package source mapping in nuget.config."
    why: "Stops a package with the same name resolving from another feed (dependency confusion)."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    enforcement: "restore: nuget.config clears other sources and maps every package to nuget.org"
    scope: core
    paths: ["nuget.config"]
  - id: SUP-004
    statement: "NuGet audits direct and transitive packages, and any known vulnerability fails the build."
    why: "A vulnerable package is caught on the PR that adds it."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    enforcement: "build: NuGetAudit with NuGetAuditMode all and TreatWarningsAsErrors"
    scope: core
    paths: ["Directory.Build.props"]
  - id: SUP-005
    statement: "global.json pins the SDK with rollForward latestPatch and no prereleases."
    why: "Every machine and CI use the same SDK feature band, which also stops lock-file churn."
    layer: owner
    status: accepted
    sources: ["ADR-0025"]
    enforcement: "check: tools/Initialize-DevMachine.ps1 reports an SDK that doesn't satisfy the pin"
    scope: core
    paths: ["global.json"]
  - id: SUP-006
    statement: "Builds take their version only from git tags through MinVer; the only version records outside tags are the ones release-please writes, .release-please-manifest.json and CHANGELOG.md, and no build reads them."
    why: "Release tags are the single source of version numbers (ADR-0019); release-please needs its manifest to propose the next version, and writes each release's notes to CHANGELOG.md (ADR-0022)."
    layer: owner
    status: accepted
    sources: ["ADR-0019", "ADR-0022", "owner, 2026-11-04"]
    enforcement: "build: MinVer global package reference with tag prefix v; tools/tests/BuildConfig.Tests.ps1 (version from the tag) and tools/tests/ReleaseConfig.Tests.ps1 (release-please config)"
    scope: core
    paths: ["Directory.Build.props", "Directory.Packages.props", "release-please-config.json", ".release-please-manifest.json"]
  - id: SUP-007
    statement: "Deprecated packages fail CI; a preview package needs an ADR."
    why: "The Well-Architected Framework asks architects to avoid deprecated components and assess preview features."
    layer: owner
    status: accepted
    sources: ["ADR-0016"]
    enforcement: "ci: dotnet-ci.reusable.yml runs tools/Test-DeprecatedPackages.ps1; preview packages are advisory (the reviewer agent checks for the ADR)"
    scope: core
    paths: ["Directory.Packages.props"]
  - id: SUP-008
    statement: "GitHub Actions are pinned to a full commit SHA, and Dependabot keeps actions and packages current, waiting 7 days before proposing a version and 14 for a NuGet or SDK major."
    why: "A tag can be moved to malicious code; a SHA can't. A release that's pulled or found compromised in its first days never reaches a PR."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09", "ADR-0041"]
    enforcement: "settings: the kit repo requires actions pinned to a full-length commit SHA (GitHub's Actions setting, on since 2026-11-09), and .github/dependabot.yml updates the pins; Pester tests also check the pins in the release, Dependabot lock-file and shared app workflows, and Dependabot.Tests.ps1 checks the waits in the kit's and the app template's dependabot.yml; New-KitApp turns the same setting on for every app (templates/github/actions.json)"
    scope: core
    paths: [".github/**"]
  - id: SUP-011
    statement: "Workloads such as MAUI install at the workload set whose version is the SDK's own (dotnet workload restore --version with the version dotnet --version prints), never the latest."
    why: "Unpinned workloads change under a build without any commit; a workload set ships with each SDK release and moves with the SDK pin. sdk.workloadVersion in global.json would pin it too, but every build then fails on a machine without that set (ADR-0057)."
    layer: outside
    status: proposed
    sources: ["ADR-0057", "https://learn.microsoft.com/dotnet/core/tools/dotnet-workload-sets, retrieved 2026-11-11"]
    enforcement: "ci: dotnet-ci.reusable.yml's ui job restores workloads with --version (dotnet --version), and tools/tests/SharedCi.Tests.ps1 fails on an unpinned workload install or update"
    scope: core
    paths: [".github/workflows/**", "global.json"]
---

# Supply chain

Dependencies and build tools can be trusted (brief §7, backed by OpenSSF guidance). The owner agreed to this checklist in one project and accepted its items for all repos on 2026-11-09.
