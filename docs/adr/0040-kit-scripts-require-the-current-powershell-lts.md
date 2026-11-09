# ADR-0040: Kit scripts require the current PowerShell LTS, 7.6

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

ADR-0011 has kit scripts start with `#Requires -Version 7.0`, and `tools/Initialize-DevMachine.ps1` only checked that a `pwsh` command exists. Nothing tested the kit on anything older than the PowerShell that CI and the owner run: 7.6.9 on CI's `ubuntu-latest` runner (the ubuntu-24.04 image, version 20261101.360.1) and 7.6.9 on the owner's Windows machine. A shared test helper for git repos (`tools/tests/TestGit.psm1`, from PR 24) calls `[IO.Directory]::CreateTempSubdirectory`, a .NET 7 API, which PowerShell has had since 7.3. The helper declared `#Requires -Version 7.4`. A machine on 7.2, or on 7.3 under that line, would pass the toolchain check and then fail the tests at `Import-Module`.

Microsoft's lifecycle page lists 7.6 as the current LTS, supported until 2028-11-14. 7.4 (the previous LTS) and 7.5 both reach end of support on 2026-11-10, two days after this decision. 7.0 to 7.3 are already out of support. After end of support, a version gets no further updates, security ones included.

## Options

### Option 1: Require 7.6, the current LTS, everywhere

Every kit script starts with `#Requires -Version 7.6`, and `Initialize-DevMachine.ps1` passes only for a `pwsh` at 7.6 or later.

- **Trade-offs:** The minimum is a version Microsoft supports, and the same one CI and the owner run, so it's tested. A machine on 7.4 or 7.5 is told to upgrade now rather than in two days. It's stricter than the code itself needs (7.3, for the .NET 7 API).
- **Reversibility:** Easy. One function (`Get-MinimumPwshVersion`) and one line per script.
- **Risk:** Low. If the runner image ever ships an older pwsh, every script fails at once, loudly, on its `#Requires` line.

### Option 2: Require 7.4, the previous LTS and the version the git helper declares

- **Trade-offs:** Accepts more machines, and it's the oldest version Microsoft still supports today. But 7.4 is out of support in two days, and no CI run uses it, so the minimum would claim support the kit never tests. (7.3, the oldest version the code itself runs on, is already out of support.)
- **Reversibility:** Easy.
- **Risk:** Medium. It points people at an unsupported runtime, and a 7.4-only break would go unnoticed.

### Option 3: Raise only the toolchain check, leaving scripts at `#Requires -Version 7.0`

- **Trade-offs:** The smallest change. But the scripts and the check would disagree about the minimum, and a script run directly on 7.3 would start and fail partway through instead of saying why.
- **Reversibility:** Easy.
- **Risk:** Medium. Two minimums drift apart.

## Recommendation

Option 1. The kit should require a supported runtime it actually tests, and 7.6 is the only LTS that will still be supported next week.

## Decision

Accepted as recommended (owner, 2026-11-09: "Keep 7.6"). The task that started this asked for 7.4 as "the current LTS". Microsoft's lifecycle page shows 7.6 is, and 7.4 retires on 2026-11-10.

## Consequences

- Every kit script (`tools/`, `tools/tests/`, `.githooks/`) starts with `#Requires -Version 7.6`. The exception is `tools/Initialize-DevMachine.ps1`, which still runs in Windows PowerShell 5.1 so a new machine can install PowerShell with it (ADR-0011).
- `Initialize-DevMachine.ps1` asks `pwsh` for its version as a child process and reports the check as `PowerShell 7.6+`. Its install command, `winget install --id Microsoft.PowerShell --exact`, also upgrades an older pwsh, since `winget install` upgrades unless given `--no-upgrade`.
- A Pester test (`Initialize-DevMachine.Tests.ps1`, "the minimum PowerShell") fails when any script's `#Requires -Version` differs from `Get-MinimumPwshVersion`. A new script must start with `#Requires -Version 7.6`. PRs 23 and 24 merged scripts at 7.0 and 7.4 while this change was in review; it raises them too. The ruleset doesn't require a PR to be up to date with `main`, so a PR opened before this one merges must merge `main` and raise its new scripts' lines before it merges, or `main`'s Pester suite fails.
- The commit-msg hook's wrapper (`.githooks/commit-msg`) only checks that `pwsh` is on PATH. On an older pwsh, `commit-msg.ps1` stops at its `#Requires` line and the commit is rejected, with PowerShell's own message naming 7.6.
- When 7.6 nears its end of support (2028-11-14), raise the minimum to the next LTS the same way: one function, every `#Requires` line, and the docs.
- Supersedes the `#Requires -Version 7.0` part of ADR-0011's consequences.

## Pillars affected

- **Security:** the kit runs only on a PowerShell that gets security updates.
- **Reliability:** a machine with an older pwsh fails the toolchain check with an upgrade command, not the tests with an import error.
- **Operational Excellence:** one minimum, named in the check, the scripts and the docs, and tested in one place.

## Sources

- owner, 2026-11-09
- https://learn.microsoft.com/powershell/scripting/install/powershell-support-lifecycle, retrieved 2026-11-08
- https://learn.microsoft.com/windows/package-manager/winget/install, retrieved 2026-11-08
- https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md, retrieved 2026-11-08
- https://learn.microsoft.com/dotnet/api/system.io.directory.createtempsubdirectory, retrieved 2026-11-08
