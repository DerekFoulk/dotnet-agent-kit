#Requires -Version 7.6
<#
.SYNOPSIS
    Lists the UI projects in a .slnx solution: its MAUI and desktop projects (ARC-010, ADR-0057).

.DESCRIPTION
    The coverage gate exempts UI projects, and the shared .NET CI builds them on Windows and macOS. This is the one
    place they're found, so both agree.

.EXAMPLE
    ./tools/Get-UiProject.ps1 -Solution Contoso.Orders.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The MSBuild property that makes a project a UI project, its kind, and the GitHub runners that build it.
$script:UiKinds = @(
    [pscustomobject]@{ Property = 'UseMaui'; Kind = 'Maui'; Os = @('windows-latest', 'macos-latest') }
    [pscustomobject]@{ Property = 'UseWPF'; Kind = 'Wpf'; Os = @('windows-latest') }
    [pscustomobject]@{ Property = 'UseWindowsForms'; Kind = 'WindowsForms'; Os = @('windows-latest') }
    [pscustomobject]@{ Property = 'UseWinUI'; Kind = 'WinUI'; Os = @('windows-latest') }
)

function Get-UiProject {
    param([Parameter(Mandatory)] [string] $Solution)

    if (-not (Test-Path -LiteralPath $Solution -PathType Leaf)) { throw "No solution file at '$Solution'." }
    $folder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).Path
    $projects = foreach ($node in ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project')) {
        $path = $node.GetAttribute('Path')
        $file = [IO.Path]::GetFullPath((Join-Path $folder ($path -replace '\\', '/')))
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

    foreach ($project in $ui) {
        [pscustomobject]@{
            Name = [IO.Path]::GetFileNameWithoutExtension($project.Path)
            Path = $project.Path
            Kind = $project.Kind.Kind
            Os   = $project.Kind.Os
        }
    }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to read, with -Solution.' }
    Get-UiProject -Solution $Solution
}
