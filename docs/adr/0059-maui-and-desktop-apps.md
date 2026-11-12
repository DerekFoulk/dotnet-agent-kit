# ADR-0059: MAUI and desktop apps: thin UI projects, built on Windows and macOS

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

ARC-001 covers web apps only, so nothing said how a MAUI or desktop app is shaped, built or tested (scorecard GAP-001). ADR-0008 already chose native .NET MAUI with CommunityToolkit.Mvvm and Shell for mobile, with Blazor Hybrid only by ADR (ARC-004), and ARC-003 keeps UI-independent presentation logic in shared libraries.

The shared .NET CI (`dotnet-ci.reusable.yml`) runs on Linux, and Linux can't build these apps:

- The .NET 10 `dotnet new maui` template targets Android everywhere, iOS and Mac Catalyst on every OS but Linux, and Windows only on Windows (tried 2026-11-11). Native iOS builds need Apple's tools, which run only on a Mac (Microsoft Learn, Pair to Mac). WPF, Windows Forms and WinUI 3 build and run only on Windows.
- The kit's integration tests use Testcontainers with Linux containers, which GitHub's Windows runners can't run. So the tests must stay on Linux.
- The kit restores in locked mode (SUP-001). NuGet refuses a locked restore when the project's target frameworks differ from the lock file's (NU1004, tried 2026-11-11), and a MAUI project's frameworks depend on the OS that builds it.
- A workload set can be pinned with `sdk.workloadVersion` in `global.json`, but then every build fails (MSB4242) on a machine without that set, including the kit's and every web app's (tried 2026-11-11). `dotnet workload restore --version` pins it without that.

The coverage gate (TST-004) fails any production project no test loads. A UI project (views, platform code, startup wiring) can't be loaded by a plain `net10.0` test project, so an app with one could never pass.

## Options

### Option 1: Thin UI projects; Linux builds and tests the rest, Windows and macOS build the UI

UI projects (those that set `UseMaui`, `UseWPF`, `UseWindowsForms` or `UseWinUI`) hold only views, platform code and startup wiring. View models and all other logic live in UI-independent libraries, tested like any library (CommunityToolkit.Mvvm doesn't depend on a UI). `tools/Get-UiProject.ps1` finds the UI projects, and fails if any other project references one. In the shared CI, the Linux job builds, formats and tests a solution filter of every other project and runs the coverage gate, which exempts UI projects. A new job builds, with zero warnings, a filter of the projects each runner can build: the whole solution on Windows (every UI kind), and on macOS everything but the Windows-only UI projects (WPF, Windows Forms and WinUI fail off Windows, NETSDK1100). It restores the workloads of the UI projects it builds at the workload set that matches the SDK in use. The Windows job also checks formatting and deprecated packages for the whole solution. The macOS job restores without locked mode, because its frameworks are a subset of the lock file's, then `tools/Test-LockFileSubset.ps1` fails unless each lock file it wrote matches the committed one for every framework it lists. The required check ("Build, test and package checks") waits for the UI builds and fails if one failed. Desktop apps use MAUI too (Windows and Mac Catalyst); WPF, Windows Forms or WinUI 3 need an ADR.

- **Trade-offs:** Every gate still runs on every project, and logic gets the same coverage minimums as in a web app. Integration tests keep their Linux containers. Two scripts and two jobs to maintain. The required check now waits for the macOS queue in an app with a MAUI project. Windows and macOS minutes are free on public repos; a private repo pays for them, macOS at ten times the Linux rate.
- **Reversibility:** Easy: the jobs, scripts and exemption can be removed without touching any app's code.
- **Risk:** Medium until a real MAUI app runs it: the Windows job's iOS compile without a Mac, the macOS runner's default Xcode, Android SDK discovery on the runners, and the checks that move to Windows (code shape, duplicate code with PMD's `pmd.bat`, the SBOM) are untested (GAP-028).

### Option 2: Run the whole gate on Windows for an app with UI projects

- **Trade-offs:** One job, no solution filter. But integration tests with Linux containers can't run, iOS still needs a Mac, and the UI projects still can't be covered by tests.
- **Reversibility:** Easy.
- **Risk:** High: an app with an API and a MAUI client, the owner's likely shape, couldn't run its integration tests.

### Option 3: Pin the workload set in `global.json` and give each OS its own lock file

- **Trade-offs:** `global.json` breaks every build on a machine without the set, and the kit ships one `global.json` to every app. A second lock file per OS (`NuGetLockFilePath`) must be made on a Mac, which the owner doesn't have.
- **Reversibility:** Moderate.
- **Risk:** High: every non-MAUI app would fail to build.

### Option 4: Blazor Hybrid for MAUI

- **Trade-offs:** Reuses web Razor components, but ADR-0008 chose native MAUI, the owner's stated preference (owner, 2026-11-01). ARC-004 still allows it by ADR.
- **Reversibility:** Hard once an app's UI is written.
- **Risk:** Not a CI question; kept as the ADR-0008 exception it already is.

## Recommendation

Option 1: every gate keeps running on every project, and nothing changes for a web app.

## Decision

Pending the owner's yes: the coverage exemption and the required check's new shape change a CI check (AGENTS.md, "Working modes").

## Consequences

- New rules, proposed: ARC-010 (thin UI projects, no references to them, exempt from the coverage gate), ARC-011 (desktop apps use MAUI; others by ADR), SUP-011 (workloads at the SDK's own workload set). ADR-0008 points here for desktop.
- New scripts: `tools/Get-UiProject.ps1` (exported to apps, since the coverage gate calls it) and `tools/Test-LockFileSubset.ps1` (CI only).
- `dotnet-ci.reusable.yml` gains the `ui-projects` and `ui` jobs; the required job waits for them.
- **A better design, deferred (CRF-002):** the required job waits for the UI builds, so in an app with MAUI, Linux's build and tests start only after the macOS build. Running them side by side needs the required check to become a small job that waits for both, which changes the ruleset's required checks in every app: the owner's call (AGENTS.md, "Always ask"). It's worth doing once a MAUI app's CI time shows the wait matters.
- **Limits of `Get-UiProject`:** it reads each project file as written. It doesn't see `UseMaui` or the other properties when they're set in `Directory.Build.props`, an import or through another property, or a project reference whose path uses `$(...)`. Set them in the project file, as the templates do.
- The code shape check (CRF-011, ADR-0050) evaluates every project with MSBuild, which a MAUI project can't do on Linux. In an app with UI projects it runs in the Windows `ui` job, over the whole solution; otherwise on Linux, as before. It reads a multi-target project through its first framework, which for a MAUI project from the template is Android. So `Platforms/` code for the other platforms, and code under `#if WINDOWS` or `#if IOS`, isn't checked yet; GAP-028's first MAUI project is where to measure and fix that. The duplicate code check (CRF-003, ADR-0051) lists files the same way, so it moves with code shape, with the same limit; on Windows it runs PMD's `pmd.bat` with the runner's Java. So does the SBOM (SUP-009, ADR-0055), which asks MSBuild which projects are tests: with UI projects the Windows leg writes it, with the Linux job's steps word for word, from its restore of the whole solution, so the shipped UI app is in it.
- ARC-009 and ADR-0052 left MAUI and desktop structure to GAP-001; ARC-010 settles it, and ARC-009 now points there.
- GAP-001 closes. New gaps: GAP-026 (nightly mutation and the Dependabot lock-file refresh run on Linux and can't build a solution with UI projects), GAP-028 (no MAUI sample or fixture proves the Windows and macOS jobs).

## Pillars affected

Reliability: UI builds can't fail unnoticed, and integration tests keep working. Security: the new jobs keep `contents: read`, no persisted credentials, and values passed through the environment; locked restore's guarantee holds on macOS through the subset check. Cost Optimization: Windows and macOS runners only for apps with UI projects; free on public repos. Operational Excellence: each step prints which projects it filtered or exempted. Performance Efficiency: one short extra job on every run; apps with MAUI wait for the macOS build.

## Sources

- ADR-0008, ADR-0020, ADR-0025
- owner, 2026-11-01
- https://learn.microsoft.com/dotnet/core/tools/dotnet-workload-sets, retrieved 2026-11-11
- https://learn.microsoft.com/dotnet/core/tools/dotnet-workload-restore, retrieved 2026-11-11
- https://learn.microsoft.com/dotnet/maui/ios/pair-to-mac?view=net-maui-10.0, retrieved 2026-11-11
- https://learn.microsoft.com/dotnet/maui/get-started/first-app?view=net-maui-10.0, retrieved 2026-11-11
