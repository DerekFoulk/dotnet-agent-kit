#Requires -Version 7.6
<#
.SYNOPSIS
    Lists the UI projects in a .slnx solution: its MAUI and desktop projects (ARC-010, ADR-0059).

.DESCRIPTION
    A UI project is one whose project file sets UseMaui, UseWPF, UseWindowsForms or UseWinUI to true. The coverage
    gate exempts UI projects, and the shared .NET CI builds them on Windows and macOS. This is the one place they're
    found, so both agree. It fails if any other project references a UI project (ARC-010). With -FilterPath, it also
    writes a solution filter of every other project, which the Linux CI job builds and tests. With -Runner too (a
    GitHub runner label, such as macos-latest), the filter also holds the UI projects that runner builds.

    It reads each project file as written: a property set in Directory.Build.props, an import or through another
    property, and a reference path that uses $(...), aren't seen. Set them in the project file (ADR-0059).

.EXAMPLE
    ./tools/Get-UiProject.ps1 -Solution Contoso.Orders.slnx -FilterPath $env:RUNNER_TEMP/without-ui.slnf
#>
[CmdletBinding()]
param(
    [string] $Solution,
    [string] $FilterPath,
    [string] $Runner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'KitSolution.psm1') -Force

# The MSBuild property that makes a project a UI project, its kind, and the GitHub runners that build it.
$script:UiKinds = @(
    [pscustomobject]@{ Property = 'UseMaui'; Kind = 'Maui'; Os = @('windows-latest', 'macos-latest') }
    [pscustomobject]@{ Property = 'UseWPF'; Kind = 'Wpf'; Os = @('windows-latest') }
    [pscustomobject]@{ Property = 'UseWindowsForms'; Kind = 'WindowsForms'; Os = @('windows-latest') }
    [pscustomobject]@{ Property = 'UseWinUI'; Kind = 'WinUI'; Os = @('windows-latest') }
)

function Get-UiProject {
    param([Parameter(Mandatory)] [string] $Solution, [string] $FilterPath, [string] $Runner)

    $projects = foreach ($listed in Get-SolutionProject -Solution $Solution) {
        $path = $listed.Path
        $file = $listed.FullPath
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "The solution $Solution lists $path, which doesn't exist." }
        [xml] $xml = Get-Content -LiteralPath $file -Raw
        $kind = $script:UiKinds | Where-Object {
            @($xml.SelectNodes("//PropertyGroup/$($_.Property)") | ForEach-Object { $_.InnerText.Trim() }) -contains 'true'
        } | Select-Object -First 1
        [pscustomobject]@{ Path = $path; File = $file; Xml = $xml; Kind = $kind }
    }

    $ui = @($projects | Where-Object Kind)
    # ARC-010: nothing references a UI project. MSBuild paths are relative to the project and may use either slash.
    foreach ($project in $projects) {
        foreach ($reference in $project.Xml.SelectNodes('//ItemGroup/ProjectReference')) {
            $target = [IO.Path]::GetFullPath((Join-Path (Split-Path $project.File) ($reference.GetAttribute('Include') -replace '\\', '/')))
            $hit = $ui | Where-Object File -EQ $target | Select-Object -First 1
            if ($hit) {
                throw "$($project.Path) references the UI project $($hit.Path). Put the code it needs in a UI-independent library instead (ARC-010)."
            }
        }
    }

    # A solution filter (.slnf) names its solution and the projects, relative to the solution's folder, to load.
    if ($FilterPath) {
        $filter = @{ solution = @{ path = (Resolve-Path -LiteralPath $Solution).Path; projects = @($projects | Where-Object { -not $_.Kind -or ($Runner -and $_.Kind.Os -contains $Runner) } | ForEach-Object Path) } }
        Set-Content -LiteralPath $FilterPath -Value (ConvertTo-Json -InputObject $filter -Depth 3)
    }

    foreach ($project in $ui) {
        [pscustomobject]@{
            Name     = [IO.Path]::GetFileNameWithoutExtension($project.File)
            Path     = $project.Path
            FullPath = $project.File
            Kind     = $project.Kind.Kind
            Os       = $project.Kind.Os
        }
    }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to read, with -Solution.' }
    Get-UiProject -Solution $Solution -FilterPath $FilterPath -Runner $Runner
}
