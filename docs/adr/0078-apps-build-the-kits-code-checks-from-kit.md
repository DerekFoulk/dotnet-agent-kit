# ADR-0078: Apps build the kit's code checks from source in .kit

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

The code shape check (CRF-011, ADR-0050) and the duplicate code check (CRF-003, ADR-0051) run in an app's CI, from the kit's download (the `kit-tools` action). An app can't run either on its own machine (GAP-022):

- Both run the kit's `Kit.CodeShape` tool. `Test-CodeShape.ps1` builds it from `tools/CodeShape/src/Kit.CodeShape`. The duplicate code check uses it to list the files.
- An app's `.kit/tools` has neither script nor the tool's source (ADR-0032).
- The tool can't simply be copied into an app. MSBuild takes the nearest `Directory.Build.props` and `Directory.Packages.props` above a project, so a copy would build with the app's files. The app's `Directory.Packages.props` deliberately leaves out the "Kit tools" group, so `Microsoft.CodeAnalysis.CSharp` would have no version (NU1010).
- The duplicate code check also needs Java and PMD. Those are the developer's own install, and installing software is the owner's call ("Always ask").

ADR-0050 expected this to wait for the kit's move to a .NET tool (v0.2.0). The owner chose on 2026-11-16 to finish the free gaps before v0.1.0, and GAP-022 is one of them.

## Options

### Option 1: Export the tool's source, with a copy of the kit's build files, into .kit

The export adds three things to an app's files:

- `Test-CodeShape.ps1` and `Test-Duplication.ps1` in `.kit/tools`, as for the other checks.
- The tool's source: `tools/CodeShape/src/` at `.kit/tools/CodeShape/src/`, its lock file included and its tests left out.
- The kit's build files in `.kit`: `Directory.Build.props`, the whole `Directory.Packages.props` (not the app's trimmed copy), and the two files the props point to (`CodeMetricsConfig.txt`, `BannedSymbols.txt`).

MSBuild then finds `.kit/Directory.Build.props` and `.kit/Directory.Packages.props` before the app's own. The tool builds as it does in the kit and from the kit's download in CI: the same package versions, so the same lock file. The script's own path logic (`$PSScriptRoot/..` as the kit root) already points at `.kit`.

- **Trade-offs:** No package and no publish. One build, the same in CI and on a machine. The app gets about 30 more kit-managed files, and a second copy of the kit's two props files. The sync replaces all of them like any kit file (ADR-0044), and the manifest hashes them. The first local run builds the tool, which restores `Microsoft.CodeAnalysis.CSharp` (about a minute on a cold NuGet cache).
- **Reversibility:** Easy. Dropping the entries from the export lets the sync remove the files from every app at its next kit release.
- **Risk:** Low. An app's Dependabot could see the `.kit` copy of the package versions and propose an edit to a kit-managed file. The app template's NuGet entry now leaves out `.kit/**` (`exclude-paths`, which GitHub's Dependabot options reference documents).

### Option 2: Ship Kit.CodeShape as a .NET tool the app restores

Pack the tool as a NuGet package. The app's `.config/dotnet-tools.json` pins it, and `dotnet tool restore` installs it.

- **Trade-offs:** This is the usual way to share a .NET command-line tool, and there's nothing to build on the app's machine. But it needs a feed:
  - Publishing to nuget.org is a public release, which is the owner's call (SEC-003).
  - GitHub Packages' NuGet feed needs a token to restore, even a public package, so every app's CI and every developer would need one.
  - Each kit release would also need a package release step. That is the shape of the kit's planned v0.2.0 move to a .NET tool, which will carry the whole kit, not just this check.
- **Reversibility:** Medium. A published version stays on nuget.org; it can only be unlisted.
- **Risk:** Medium. The release pipeline and the publishing credentials are new, and this tool would come first, ahead of the kit-wide design.

### Option 3: Leave it to CI

- **Trade-offs:** Nothing to build. But a breach shows only on the pull request, after a push, which is what GAP-022 records.
- **Reversibility:** Easy.
- **Risk:** Low, but slow feedback stays.

## Recommendation

Option 1: it closes the gap with no publish and no token, and builds the tool exactly as CI does. The kit-wide .NET tool (v0.2.0) can replace it later.

## Decision

Accepted (auto mode, 2026-11-16): the owner asked for the free gaps to be finished, and Option 1 needs no publish, package or money.

## Consequences

- `Export-KitApp.ps1` exports the two scripts, the tool's source (`$KitToolSources`) and the kit's build files (`$KitBuildRoot`). The sync brings them to existing apps at their next kit release.
- An app's AGENTS.md lists both checks under Commands. The code shape check builds the tool first, from the repo root, so the app's `global.json` picks the SDK. The duplicate code check takes `-Pmd`, the developer's own PMD launcher. Java and PMD stay the developer's install, which is the owner's call. CI keeps downloading the PMD release the kit pins (ADR-0060).
- `tools/tests/Export-KitApp.Tests.ps1` shows both checks running in an exported app: a nesting breach fails the code shape check, and a stand-in PMD makes the duplicate code check report a repeat.
- The app template's Dependabot NuGet entry leaves out `.kit/**`, and `tools/tests/Dependabot.Tests.ps1` checks it. An app made before this has its own `dependabot.yml`, which the sync never changes. Such an app adds the line itself if Dependabot proposes an edit under `.kit`.
- `.kit/Directory.Build.props`, `CodeMetricsConfig.txt` and `BannedSymbols.txt` repeat the app root's own copies. They're kept so that lines an app adds to its root `Directory.Build.props` (ADR-0044) can't change how the kit's tool builds.
- **CodeQL scans the tool's source in every public app.** The shared CodeQL workflow adds C# once `git ls-files -- '*.cs'` finds a file, so an app's C# job now runs from its first commit, over `.kit`'s C# too. An alert there would show in the app's Security tab, but the fix is the kit's, and the kit's own CodeQL scans the same code first. Leaving `.kit` out (`':!.kit/**'` in the detection and CodeQL's `paths-ignore`) would keep an app's results to its own code. That narrows a CI check, which is the owner's call (AGENTS.md, "Working modes"), so it isn't done here. It's listed for him in the PR.
- ADR-0050's note that an app can't run the check on its own machine, and craft.md's "Apps run it only in CI for now", are updated. GAP-022 is closed.
- When the kit moves to a .NET tool (v0.2.0), Kit.CodeShape moves with it. The `.kit` copies then go, by the same sync.

## Pillars affected

- **Operational Excellence:** a developer or agent sees a code shape or duplicate code breach before pushing, with the same tool and limits as CI.
- **Security:** nothing is published, and no new feed or token is needed. The tool restores from nuget.org under the app's existing trust policy (SUP-012), with the kit's lock file.
- **Cost Optimization:** free; no runner time is added.
- **Reliability and Performance Efficiency:** not affected. The first local run takes about a minute longer, to restore and build the tool.

## Sources

- owner, 2026-11-16 ("Finish the free gaps")
- https://learn.microsoft.com/en-us/visualstudio/msbuild/customize-by-directory, retrieved 2026-11-16
- https://learn.microsoft.com/en-us/nuget/consume-packages/central-package-management, retrieved 2026-11-16
- https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference, retrieved 2026-11-16
- https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-nuget-registry, retrieved 2026-11-16
