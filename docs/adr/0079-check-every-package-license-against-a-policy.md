# ADR-0079: Check every package's license against a policy

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

SEC-005 (ADR-0004) says a repo marked commercial uses no package whose license isn't free for commercial use. Nothing checked it (GAP-040): the rule was advisory, and nothing marked a repo commercial. ADR-0004 decided how it should work. A repo declares itself commercial, and CI then fails on a package that isn't free for commercial use, naming its swap: AwesomeAssertions for FluentAssertions 8.

What the kit's packages look like, read on 2026-11-16 from the global packages folder for every package the kit's 16 lock files resolve (151 packages, transitive ones included):
- 142 give an SPDX license expression (`<license type="expression">`): MIT, Apache-2.0, BSD-3-Clause and MPL-2.0. MPL-2.0 is axe-core's, under Deque.AxeCore.Commons, which every app's browser tests use (ADR-0061).
- 4 give a license file (`<license type="file">`). CommandLineParser and Microsoft.DotNet.PlatformAbstractions, which BenchmarkDotNet brings, carry the MIT license. Microsoft.Testing.Extensions.CodeCoverage, the coverage gate's collector, carries the Microsoft .NET Library license, which allows any number of copies to design, develop and test your applications. FluentAssertions 8 carries Xceed's Community License, which is for non-commercial use only.
- None gives only the deprecated `licenseUrl`, though older packages do.

NuGet's `.nuspec` reference defines the `license` element: an SPDX expression, with `AND`, `OR`, `WITH`, parentheses and `+`, or a file in the package; `licenseUrl` is deprecated. The SPDX specification says operators are case-sensitive, license ids match in any case, `+` means "this version or any later", and `WITH` binds tighter than `AND`, which binds tighter than `OR`.

Every app's tests reference FluentAssertions 8 today (`tests/Directory.Build.props`, from the kit's sample). So a check that treats every repo as commercial would fail every app until it declared otherwise.

## Options

### Option 1: A kit script that reads each locked package's .nuspec, against a policy file the repo can extend

`tools/Test-PackageLicenses.ps1 -Solution <slnx>` reads the lock file beside each project the solution lists, and each resolved package's `.nuspec` in the global packages folder. The license is one of these:
- `expression <SPDX>`: allowed when the policy's licenses satisfy it.
- `file <name> sha256:<hash>`: allowed only by a package entry that pins that file's hash.
- `url <url>`: allowed only by a package entry that names the URL.

The policy is `tools/package-licenses.json` (in an app, `.kit/tools/`). It holds SPDX ids, plus package entries (`id`, `license`, `reason`, optionally `commercialUse: false` and a `swap`). A repo adds its own in `.config/package-licenses.json`, which is also where it sets `"commercial": true`. The shared .NET CI runs the script after restore, where the whole solution was restored.

- **Trade-offs:** No new tool or dependency, and it reads the same files NuGet does. Because an entry pins the license, not just the package, a package that changes its license fails until someone reads the new one (FluentAssertions did this in version 8). Pinning a license file's hash means a reworded file fails too, which is the point. The cost is a short list to keep, and a Dependabot bump of a file-licensed package can fail until its entry is re-pinned.
- **Reversibility:** easy. Remove the CI step.
- **Risk:** low. A package whose `.nuspec` misstates its license would pass, as it would under any tool that reads metadata.

### Option 2: A third-party license tool (nuget-license, or a dotnet-project-licenses fork)

- **Trade-offs:** ready-made. But it's one more .NET tool for apps to restore and keep current, and each tool's allowlist and exception format differs. Most also fetch license URLs over the network to guess a license, which is slow and not reproducible.
- **Reversibility:** easy.
- **Risk:** medium. Network lookups make CI flaky, and the tool's maintenance is outside the kit's control.

### Option 3: Read the licenses from the SBOM CI already writes (ADR-0055)

- **Trade-offs:** reuses an artifact. But the SBOM leaves out test and benchmarks projects, which are exactly where FluentAssertions 8 lives, and its license fields come from the same `.nuspec` anyway.
- **Reversibility:** easy.
- **Risk:** medium. It would miss test-only packages, whose licenses still bind a commercial repo.

## Recommendation

Option 1. It reads what NuGet reads, offline, with a policy an app extends in one file, and it catches a license that changes between versions.

## Decision

Option 1, decided in auto mode (ADR-0035) on 2026-11-16, to close GAP-040 (owner, 2026-11-16: "Finish the free gaps").

- **Every repo is checked; only a commercial one is restricted to licenses free for commercial use.** As ADR-0004 decided, a repo declares itself commercial, here with `"commercial": true` in `.config/package-licenses.json`. Until it does, a package entry marked `commercialUse: false` (FluentAssertions 8) is allowed. Any package whose license the policy doesn't know fails in every repo, so a new license is read before it's used.
- **The kit's licenses** are permissive SPDX licenses, approved by the OSI, that are free for commercial use and put no obligation on the app's own code: 0BSD, Apache-2.0, BSD-2-Clause, BSD-3-Clause, BSL-1.0, ISC, MIT, MIT-0, MPL-2.0, MS-PL, PostgreSQL, Unlicense and Zlib. MPL-2.0 is file-level copyleft: it covers changes to the MPL files themselves, which a NuGet consumer doesn't make, and axe-core, under Deque.AxeCore.Commons, uses it. The GPL, LGPL, AGPL, EPL and similar licenses are left out. They are free for commercial use, but their obligations can reach the app or its distribution, which is a call for the app's owner, so an app adds one with its reason.
- **The kit's package entries** pin the four license files above, each with its reason. FluentAssertions 8 is marked non-commercial, with AwesomeAssertions as its swap.

## Consequences

- SEC-005's enforcement becomes a gate in the kit and in apps: `dotnet-ci.reusable.yml` runs the check in the Linux job when there are no UI projects, and in the Windows ui job when there are, as it does the code shape check. Export-KitApp gives an app the script and the kit's policy in `.kit/tools`, and the app's AGENTS.md lists the command. The repo's own `.config/package-licenses.json` stays the app's: the kit sync never writes it.
- A commercial app sets `"commercial": true`; its CI then fails on FluentAssertions 8, naming AwesomeAssertions. No tool can tell whether an app is sold, so setting it is the app owner's step (SEC-005's advisory part).
- When Dependabot bumps a package that carries a license file, and the file's text changed, the check fails and names both hashes. Someone reads the new license and re-pins the entry, in the kit's policy for the kit's toolset or in the app's file for the app's own packages. A bump that leaves the file alone passes.
- The check needs a restore first: it reads `.nuspec` files from the global packages folder, which `dotnet nuget locals global-packages --list` names.
- Not checked: a package's own dependencies' licenses beyond what NuGet resolves, which are all in the lock files anyway, and licenses of tools CI downloads outside NuGet (PMD, gitleaks), which ADR-0051 and ADR-0024 chose by their licenses.

## Pillars affected

- **Security (compliance):** a license breach fails CI instead of shipping, as the floor requires (ADR-0004).
- **Cost:** a paid license is caught before it's owed.
- **Operational excellence:** a message that names the package, its license, and the line to add or the swap to use.
- **Reliability, performance:** no network calls; the check reads local files after restore, in seconds.

## Sources

- owner, 2026-11-01 (ADR-0004)
- owner, 2026-11-16 ("Finish the free gaps")
- https://learn.microsoft.com/en-us/nuget/reference/nuspec, retrieved 2026-11-16 (`license`: an SPDX expression or a file; `licenseUrl` deprecated; the expression grammar)
- https://spdx.github.io/spdx-spec/v2.3.1/SPDX-license-expressions/, retrieved 2026-11-16 (precedence, case, `+`)
- https://learn.microsoft.com/en-us/nuget/consume-packages/managing-the-global-packages-and-cache-folders, retrieved 2026-11-16
- ADR-0003, ADR-0004, ADR-0051, ADR-0055, ADR-0061
