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

    $folder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).Path
    foreach ($node in ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project')) {
        $path = $node.GetAttribute('Path')
        [xml] $project = Get-Content -LiteralPath (Join-Path $folder $path) -Raw
        foreach ($kind in $script:UiKinds) {
            $values = @($project.SelectNodes("//PropertyGroup/$($kind.Property)") | ForEach-Object { $_.InnerText.Trim() })
            if ($values -contains 'true') {
                [pscustomobject]@{
                    Name = [IO.Path]::GetFileNameWithoutExtension($path)
                    Path = $path
                    Kind = $kind.Kind
                    Os   = $kind.Os
                }
                break
            }
        }
    }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to read, with -Solution.' }
    Get-UiProject -Solution $Solution
}
