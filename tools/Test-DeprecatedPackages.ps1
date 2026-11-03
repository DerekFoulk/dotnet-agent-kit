#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a project references a deprecated NuGet package (SUP-007, ADR-0016).

.DESCRIPTION
    `dotnet list package --deprecated` exits 0 even when it lists deprecated packages, so this script reads
    its JSON output and fails instead. The command restores each project itself; when that restore fails it
    exits 1 and reports "problems" with no "projects" list, and this script fails on that too, so a broken
    restore can't pass as "nothing deprecated".

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
    if (-not $report.ContainsKey('projects')) { return }
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

# Prints each problem and returns 0 only when dotnet list succeeded, reported no problems, and listed no
# deprecated package; otherwise 1.
function Invoke-DeprecatedPackageCheck {
    param([Parameter(Mandatory)] [string] $Json, [int] $ExitCode = 0)

    $report = $Json | ConvertFrom-Json -AsHashtable
    $problems = [System.Collections.Generic.List[string]]::new()

    if ($report.ContainsKey('problems')) {
        foreach ($problem in @($report['problems'])) {
            $problems.Add("dotnet list package reported ($($problem['level'])): $($problem['text'])")
        }
    }
    if ($ExitCode -ne 0) {
        $problems.Add("dotnet list package exited with code $ExitCode, so the packages weren't checked.")
    }
    if (-not $report.ContainsKey('projects')) {
        $problems.Add('dotnet list package returned no project list, so the packages weren''t checked.')
    }
    foreach ($package in @(Get-DeprecatedPackage -Json $Json)) {
        $instead = if ($package.Alternative) { "; use $($package.Alternative) instead" } else { '' }
        $problems.Add("$($package.Id) $($package.Version) is deprecated ($($package.Reasons))$instead. In $($package.Project) ($($package.Framework)).")
    }

    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }
    if ($problems.Count -gt 0) {
        Write-Host "`n$($problems.Count) deprecated-package problem(s). A deprecated package needs replacing, or an ADR (SUP-007)." -ForegroundColor Red
        return 1
    }

    $projects = @($report['projects'] | Where-Object { $null -ne $_ })
    if ($projects.Count -eq 0) {
        Write-Host 'No deprecated packages: the solution has no projects yet.' -ForegroundColor Green
        return 0
    }
    Write-Host "$($projects.Count) project(s), no deprecated packages." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = 0
    $json = if ($JsonFile) {
        Get-Content -Path $JsonFile -Raw
    }
    else {
        $output = (dotnet list $Path package --deprecated --format json) -join "`n"
        $exitCode = $LASTEXITCODE
        $output
    }
    exit (Invoke-DeprecatedPackageCheck -Json $json -ExitCode $exitCode)
}
