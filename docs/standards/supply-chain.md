---
topic: supply-chain
rules:
  - id: SUP-001
    statement: "Every project restores with a package lock file, and CI restores in locked mode; the one exception is a project that pulls in SDK-implicit packages (trimming, AOT, Blazor WebAssembly), which may set RestorePackagesWithLockFile to false with a comment citing ADR-0020 until the SDK fixes dotnet/sdk#38200."
    why: "CI restores exactly what was tested, and a tampered package fails its hash check; SDK-implicit packages change with every SDK patch, so their lock files churn (ADR-0020). Central package management still pins those projects' versions."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0020"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: RestorePackagesWithLockFile, RestoreLockedMode when CI=true; tools/tests/BuildConfig.Tests.ps1"
      - kind: gate
        in: [app]
        how: "ci: on macOS, where a MAUI project builds a subset of its frameworks, dotnet-ci.reusable.yml restores unlocked and tools/Test-LockFileSubset.ps1 holds each lock file to the committed one (ADR-0059)"
      - kind: advisory
        in: [kit]
        how: "not a gate, a helper: dependabot-lockfiles.yml refreshes the lock files Dependabot misses on its NuGet PRs (tools/tests/DependabotLockfiles.Tests.ps1); a stale lock file still fails the locked restore above"
    paths: ["**/*.csproj", "**/packages.lock.json", "Directory.Build.props"]
  - id: SUP-002
    statement: "Package versions live only in Directory.Packages.props (central package management), with transitive pinning on."
    why: "One reviewed file controls every version, including transitive ones."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0020", "owner, 2026-11-09"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: ManagePackageVersionsCentrally makes a version in a project file a restore error (NU1008)"
    paths: ["Directory.Packages.props", "**/*.csproj"]
  - id: SUP-003
    statement: "Packages come only from nuget.org, enforced by package source mapping in nuget.config."
    why: "Stops a package with the same name resolving from another feed (dependency confusion); SUP-013 has what Microsoft says about trusted sources."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "restore: nuget.config clears other sources and maps every package to nuget.org"
    paths: ["nuget.config"]
  - id: SUP-004
    statement: "NuGet audits direct and transitive packages, and any known vulnerability fails the build."
    why: "A vulnerable package is caught on the PR that adds it; SUP-014 has what Microsoft says to do about a warning."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: NuGetAudit with NuGetAuditMode all and TreatWarningsAsErrors"
    paths: ["Directory.Build.props"]
  - id: SUP-005
    statement: "global.json pins the SDK with rollForward latestPatch and no prereleases."
    why: "Every machine and CI use the same SDK feature band, which also stops lock-file churn."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0025"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: global.json's version makes every dotnet command fail on an SDK that doesn't satisfy it; this gates the pin, not its rollForward or prerelease settings"
      - kind: advisory
        in: [kit, app]
        how: "rollForward latestPatch and no prereleases: no check reads global.json's settings, so code review does; tools/Initialize-DevMachine.ps1 reports an SDK that doesn't satisfy the pin, with the fix"
    paths: ["global.json"]
  - id: SUP-006
    statement: "Builds take their version only from git tags through MinVer; the only version records outside tags are the ones release-please writes, .release-please-manifest.json and CHANGELOG.md, and no build reads them."
    why: "Release tags are the single source of version numbers (ADR-0019); release-please needs its manifest to propose the next version, and writes each release's notes to CHANGELOG.md (ADR-0022)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0019", "ADR-0022", "owner, 2026-11-04"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: MinVer global package reference with tag prefix v; tools/tests/BuildConfig.Tests.ps1 (version from the tag) and tools/tests/ReleaseConfig.Tests.ps1 (release-please config)"
    paths: ["Directory.Build.props", "Directory.Packages.props", "release-please-config.json", ".release-please-manifest.json"]
  - id: SUP-007
    statement: "Deprecated packages fail CI; a preview package needs an ADR."
    why: "The kit turns the Well-Architected Framework's advice not to use deprecated components, and to assess the risks of preview features (SUP-015), into a CI failure and an ADR."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0016"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: dotnet-ci.reusable.yml runs tools/Test-DeprecatedPackages.ps1"
      - kind: advisory
        in: [kit, app]
        how: "preview packages: code review checks for the ADR"
    paths: ["Directory.Packages.props"]
  - id: SUP-008
    statement: "GitHub Actions are pinned to a full commit SHA, and Dependabot keeps actions and packages current, waiting 7 days before proposing a version and 14 for a NuGet or SDK major."
    why: "A tag can be moved to malicious code; a SHA can't. A release that's pulled or found compromised in its first days never reaches a PR."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09", "owner, 2026-11-11", "ADR-0041", "ADR-0060"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit]
        how: "settings: the kit repo requires actions pinned to a full-length commit SHA (GitHub's Actions setting, on since 2026-11-09), and .github/dependabot.yml updates the pins; Pester tests also check the pins in the release, Dependabot lock-file and shared app workflows, and Dependabot.Tests.ps1 checks the waits in the kit's and the app template's dependabot.yml, and that it watches the manifests pinning the two tools the shared .NET CI downloads, PMD and the gitleaks image (SharedCi.Tests.ps1 checks the CI reads only those pins), and the Playwright image pin in .config/playwright, in the kit and the app template (GAP-033: Invoke-WithPlaywrightImage.Tests.ps1 checks the kit's pin matches its Microsoft.Playwright version); PMD's pin is the SHA-256 of a zip whose signature verified against PMD's release key, pinned by fingerprint in .config/pmd (KitPmd.Tests.ps1, ADR-0060)"
      - kind: gate
        in: [app]
        how: "settings: New-KitApp turns the same setting on for every app (templates/github/actions.json)"
    paths: [".github/**"]
  - id: SUP-009
    statement: "Every build of a solution with projects writes a CycloneDX SBOM of its shipped projects, leaving out every project MSBuild marks as a test project and every benchmarks project (ADR-0062), and keeps it as the run's 'sbom' artifact."
    why: "When a package is found vulnerable, the SBOM answers which builds ship it; the kit's way of keeping the SBOM the Microsoft cloud security benchmark guidance asks for (SUP-016) (GAP-013)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0055"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: dotnet-ci.reusable.yml runs the CycloneDX .NET tool at the version .config/dotnet-tools.json pins, on the solution filter tools/New-ShippedSolutionFilter.ps1 writes of the projects MSBuild doesn't mark IsTestProject and whose names don't end in .Benchmarks, and uploads the SBOM, failing when it's missing; tools/tests/SharedCi.Tests.ps1 and New-ShippedSolutionFilter.Tests.ps1 check them"
    paths: [".github/workflows/**", ".config/dotnet-tools.json"]
  - id: SUP-010
    statement: "Every public repo runs OpenSSF Scorecard through the kit's scorecard.reusable.yml on each push to main and weekly, publishing its score and uploading its findings to code scanning, with only the security-events and id-token write permissions the action documents; a private repo skips it."
    why: "Scorecard checks the supply-chain practices from outside, with a public score that shows drift (GAP-014); publishing needs the action's workflow restrictions (SUP-017)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0056"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: scorecard.yml in the kit and in the app template call scorecard.reusable.yml, which reads the repo's visibility from the API and skips a private repo; tools/tests/SharedCi.Tests.ps1 checks the triggers, the permissions, the pins, the skip and each publishing restriction"
      - kind: advisory
        in: [app]
        how: "an app made before it adds the template's scorecard.yml by hand (WorkflowByHand)"
    paths: [".github/workflows/**"]
  - id: SUP-011
    statement: "Workloads such as MAUI install at the workload set whose version is the SDK's own (dotnet workload restore --version with the version dotnet --version prints), never the latest."
    why: "Unpinned workloads change under a build without any commit; a workload set ships with each SDK release and moves with the SDK pin. sdk.workloadVersion in global.json would pin it too, but every build then fails on a machine without that set (ADR-0059)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0059"]
    scope: [maui]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: dotnet-ci.reusable.yml's ui job restores workloads with --version (dotnet --version), and tools/tests/SharedCi.Tests.ps1 fails on an unpinned workload install or update"
    paths: [".github/workflows/**", "global.json"]
  - id: SUP-012
    statement: "Every package a restore extracts carries a signature from a trusted signer: nuget.config sets signatureValidationMode to require and trusts only nuget.org's repository certificates, the ones its service index announces, clearing any signer a config above the repo adds. The one exception is a restore on macOS, where .NET doesn't verify signatures and Microsoft advises leaving it off; there, the lock files' hashes hold a restore to the packages verified on Windows and Linux."
    why: "A package altered after nuget.org published it, or one from anywhere else, fails its restore instead of reaching the build; nuget.org adds a repository signature to every package it serves. .NET verifies during a restore on Windows always and on Linux by default from the .NET 8 SDK; on macOS it doesn't, and Microsoft recommends leaving it disabled (SUP-018)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-12", "ADR-0066"]
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "restore, on Windows and Linux: nuget.config's signatureValidationMode require and its nuget.org trusted signer fail a restore on an unsigned or untrusted package (NU3004); tools/tests/BuildConfig.Tests.ps1 restores an unsigned package and expects that failure, restores nuget.org's packages with a cold cache, and checks that a signer trusted in a config above the repo isn't trusted in it, and that no workflow sets DOTNET_NUGET_SIGNATURE_VERIFICATION to false"
      - kind: gate
        in: [kit, app]
        how: "ci, on macOS: dotnet-ci.reusable.yml's macOS restore isn't verified, but tools/Test-LockFileSubset.ps1 holds its lock files to the committed ones, hashes included, and those packages were verified by the Windows and Linux restores of the same commit (SUP-001, ADR-0059)"
      - kind: gate
        in: [kit]
        how: "schedule: nuget-trust.yml runs tools/Test-NuGetTrustedSigners.ps1 daily, which compares nuget.config's nuget.org certificates with the ones nuget.org's service index announces, and opens an issue when they differ, so the kit syncs (dotnet nuget trust sync nuget.org) before a restore fails; an app gets the synced nuget.config with the next kit release (ADR-0066); tools/tests/Test-NuGetTrustedSigners.Tests.ps1 checks the script and the workflow"
    paths: ["nuget.config"]
  - id: SUP-013
    statement: "Use package sources that you trust; knowing which feed each package comes from is a best practice against known attacks such as dependency confusion. Add a nuget.config at the root of the repo; adding clear elements to it, so no user or machine specific configuration applies, is recommended."
    why: "When a package can come from any of several feeds, a malicious package of the same name can win (dependency confusion)."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-09"
    sources: ["https://learn.microsoft.com/nuget/concepts/security-best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/nuget/concepts/security-best-practices"
        retrieved: "2026-11-17"
        text: "Use package sources that you trust."
      - source: "https://learn.microsoft.com/nuget/concepts/security-best-practices"
        retrieved: "2026-11-17"
        text: "To ensure your build is predictable and secure from known attacks such as Dependency Confusion, knowing what specific feed(s) your packages are coming from is a best practice."
      - source: "https://learn.microsoft.com/nuget/concepts/security-best-practices"
        retrieved: "2026-11-17"
        text: "Add a nuget.config file in the root of your project repository. This is considered a best practice as it promotes repeatability and ensures that different users have the same NuGet configuration. We recommend adding clear elements to ensure no user or machine specific configuration is applied."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the sources nuget.config names; SUP-003's restore gate checks that only nuget.org is mapped"
    paths: ["nuget.config"]
  - id: SUP-014
    statement: "When NuGet warns that a package your project uses has a known vulnerability, you should quickly take action; when a new security vulnerability is discovered, you must determine whether you are impacted and, if so, update to the latest version and security patch available."
    why: "By the time NuGet warns, the vulnerability is publicly known, so attackers can already build on it."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-09"
    sources: ["https://learn.microsoft.com/nuget/concepts/security-best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/nuget/concepts/security-best-practices"
        retrieved: "2026-11-17"
        text: "Therefore, when you get a warning that a package your project is using has a known vulnerability, you should quickly take action."
      - source: "https://learn.microsoft.com/nuget/concepts/security-best-practices"
        retrieved: "2026-11-17"
        text: "When a new security vulnerability is discovered, you must determine whether you are impacted, and if so, update to the latest version and security patch available."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that a NuGet audit warning is answered; SUP-004's build gate fails the build on one"
    paths: ["Directory.Build.props", "Directory.Packages.props"]
  - id: SUP-015
    statement: "Don't use deprecated components, and carefully assess the risks of using preview features."
    why: "A deprecated component won't get fixes, and a preview feature can change or go away."
    layer: outside
    basis: authority
    status: accepted
    ratified: "ADR-0016"
    sources: ["https://learn.microsoft.com/azure/well-architected/architect-role/fundamentals, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/well-architected/architect-role/fundamentals"
        retrieved: "2026-11-17"
        text: "Don't use deprecated components and carefully assess the risks of using preview features."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for deprecated components and for a preview package without an ADR; SUP-007's CI check fails a deprecated package"
    paths: ["Directory.Packages.props"]
  - id: SUP-016
    statement: "Maintain a Software Bill of Materials (SBOM) in an industry-standard format (SPDX or CycloneDX) for regulatory compliance and incident response readiness."
    why: "When a package is found vulnerable, the SBOM answers which builds ship it (GAP-013)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-devops-security, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-devops-security"
        retrieved: "2026-11-17"
        text: "Maintain Software Bill of Materials (SBOM) in industry-standard formats (SPDX, CycloneDX) for regulatory compliance and incident response readiness."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the SBOM format; SUP-009's CI gate writes and uploads the SBOM"
    paths: [".github/workflows/**", ".config/dotnet-tools.json"]
  - id: SUP-017
    statement: "When a Scorecard workflow publishes its results, give it no workflow-level write permissions and only the job with ossf/scorecard-action the id-token: write permission; that job should run on one of the Ubuntu hosted runners."
    why: "Scorecard's API checks the producing workflow against these rules and may reject the results otherwise."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://github.com/ossf/scorecard-action, retrieved 2026-11-17"]
    quotes:
      - source: "https://github.com/ossf/scorecard-action"
        retrieved: "2026-11-17"
        text: "If publishing results, our API enforces certain rules on the producing workflow, which may reject the results."
      - source: "https://github.com/ossf/scorecard-action"
        retrieved: "2026-11-17"
        text: "No workflow level write permissions."
      - source: "https://github.com/ossf/scorecard-action"
        retrieved: "2026-11-17"
        text: "Only the job with ossf/scorecard-action can use id-token: write permissions."
      - source: "https://github.com/ossf/scorecard-action"
        retrieved: "2026-11-17"
        text: "The job should run on one of the Ubuntu hosted runners."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the Scorecard workflow's permissions; SUP-010's SharedCi tests check them in the kit's shared workflow"
    paths: [".github/workflows/**"]
  - id: SUP-018
    statement: "On macOS, where it isn't currently supported, NuGet signed-package verification should not be enabled: leave it disabled by default. Don't use signed-package verification with .NET SDK versions earlier than 6.0.400."
    why: "Signed-package verification isn't supported on macOS, so SUP-012's trusted-signer rule can't apply to a macOS restore."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification"
        retrieved: "2026-11-17"
        text: "However, we recommend that you don't enable verification."
      - source: "https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification"
        retrieved: "2026-11-17"
        text: "Although signed-package verification functionality was added in .NET 5 SDK's, the functionality isn't currently supported on macOS. Don't use signed-package verification with .NET SDK versions earlier than 6.0.400. Leave it disabled by default."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that no workflow or config enables DOTNET_NUGET_SIGNATURE_VERIFICATION for a macOS restore; SUP-012's gates cover Windows and Linux"
    paths: ["nuget.config", ".github/workflows/**"]
---

# Supply chain

Dependencies and build tools can be trusted (brief §7, backed by OpenSSF guidance). The owner agreed to this checklist in one project and accepted its items for all repos on 2026-11-09. SUP-009 and SUP-010 came later, and stay proposed until he accepts them. SUP-013 to SUP-018 each say only what the cited pages say, with the quotes, beside the kit's own rule they came from (SUP-003, SUP-004, SUP-007, SUP-009, SUP-010, SUP-012); SUP-016 and SUP-017 are proposed.
