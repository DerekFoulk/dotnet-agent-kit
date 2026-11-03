#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a project references a deprecated NuGet package (SUP-007, ADR-0016).

.DESCRIPTION
    `dotnet list package --deprecated` exits 0 even when it lists deprecated packages, so this script reads
    its JSON output and fails instead. Restore first: a project that was never restored produces the same
    output as a clean one, so this script fails when a listed project has no obj/project.assets.json.

.EXAMPLE
    ./tools/Test-DeprecatedPackages.ps1 -Path dotnet-agent-kit.slnx

.EXAMPLE
    ./tools/Test-DeprecatedPackages.ps1 -JsonFile deprecated.json
    Checks output saved by an earlier step.
#>
[CmdletBinding()]
param(
    [string] $Path = '.',
    [string] $JsonFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Reads `dotnet list package --deprecated --format json` output. A project with nothing deprecated has
# no "frameworks" key; a solution with no projects has an empty "projects" list. Top-level packages
# only: those are the ones a project chose and can replace.
function Get-DeprecatedPackage {
    param([Parameter(Mandatory)] [string] $Json)

    $report = $Json | ConvertFrom-Json -AsHashtable
    foreach ($project in @($report['projects'])) {
        if ($null -eq $project -or -not $project.ContainsKey('frameworks')) { continue }
        foreach ($framework in @($project['frameworks'])) {
            if (-not $framework.ContainsKey('topLevelPackages')) { continue }
            foreach ($package in @($framework['topLevelPackages'])) {
                $alternative = if ($package.ContainsKey('alternativePackage') -and $package['alternativePackage']) { $package['alternativePackage']['id'] } else { $null }
                [pscustomobject]@{
                    Project     = $project['path']
                    Framework   = $framework['framework']
                    Id          = $package['id']
                    Version     = $package['resolvedVersion']
                    Reasons     = (@($package['deprecationReasons']) -join ', ')
                    Alternative = $alternative
                }
            }
        }
    }
}

# Prints each deprecated package and returns 0 when there are none, otherwise 1. A listed project with
# no restore output also fails: `dotnet list package` reports it exactly like a clean project.
function Invoke-DeprecatedPackageCheck {
    param([Parameter(Mandatory)] [string] $Json, [int] $ExitCode = 0)

    $report = $Json | ConvertFrom-Json -AsHashtable
    $projects = @($report['projects'] | Where-Object { $null -ne $_ })
    if ($projects.Count -eq 0) {
        Write-Host 'No deprecated packages: the solution has no projects yet.' -ForegroundColor Green
        return 0
    }

    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($project in $projects) {
        $assets = Join-Path (Split-Path -Path $project['path'] -Parent) 'obj' 'project.assets.json'
        if (-not (Test-Path -Path $assets)) {
            $problems.Add("$($project['path']) is not restored, so its packages weren't checked. Run dotnet restore first.")
        }
    }
    foreach ($package in @(Get-DeprecatedPackage -Json $Json)) {
        $instead = if ($package.Alternative) { "; use $($package.Alternative) instead" } else { '' }
        $problems.Add("$($package.Id) $($package.Version) is deprecated ($($package.Reasons))$instead. In $($package.Project) ($($package.Framework)).")
    }

    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }
    if ($problems.Count -gt 0) {
        Write-Host "`n$($problems.Count) deprecated-package problem(s). A preview or deprecated package needs an ADR (SUP-007)." -ForegroundColor Red
        return 1
    }
    Write-Host "$($projects.Count) project(s), no deprecated packages." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    $json = if ($JsonFile) {
        Get-Content -Path $JsonFile -Raw
    }
    else {
        # This command never fails on deprecated packages by itself, which is why this script exists.
        (dotnet list $Path package --deprecated --format json) -join "`n"
    }
    exit (Invoke-DeprecatedPackageCheck -Json $json)
}
