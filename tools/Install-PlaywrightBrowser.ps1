#Requires -Version 7.6
<#
.SYNOPSIS
    Installs the browser an app's Playwright tests need, before they run (GAP-004, ADR-0061).

.DESCRIPTION
    The shared .NET CI runs this after the build and before the tests. For each C# project in the solution, MSBuild
    gives the project's restore graph (ProjectAssetsFile). A project with Microsoft.Playwright in that graph, directly
    or through Deque.AxeCore.Playwright, uses Playwright. With none, the script says so and does nothing, so an app
    without browser tests pays only the MSBuild evaluations.
#>
[CmdletBinding()]
param(
    [string] $Solution,
    [string] $Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-PlaywrightBrowser {
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [string] $Configuration = 'Release',
        [switch] $WithDependencies
    )

    $solutionPath = (Resolve-Path -LiteralPath $Solution).Path
    $folder = Split-Path -Parent $solutionPath
    $users = foreach ($node in ([xml] (Get-Content -LiteralPath $solutionPath -Raw)).SelectNodes('//Project')) {
        $project = Join-Path $folder $node.GetAttribute('Path')
        $json = (& dotnet msbuild $project -nologo -getProperty:ProjectAssetsFile -getProperty:TargetDir "-p:Configuration=$Configuration") -join "`n" | ConvertFrom-Json
        $assets = Get-Content -Raw -LiteralPath $json.Properties.ProjectAssetsFile | ConvertFrom-Json
        if ($assets.libraries.PSObject.Properties.Name -like 'Microsoft.Playwright/*') {
            Join-Path $json.Properties.TargetDir 'playwright.ps1'
        }
    }
    if (-not $users) { 'No project uses Playwright; no browser to install.'; return }
    foreach ($script in $users) {
        & pwsh -NoProfile -File $script install chromium
    }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to read, with -Solution.' }
    Install-PlaywrightBrowser -Solution $Solution -Configuration $Configuration
}
