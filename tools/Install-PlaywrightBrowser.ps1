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

# MSBuild's evaluation of a project, without a build: where its restore graph and its build output are.
function Read-ProjectOutput {
    param([Parameter(Mandatory)] [string] $Project, [Parameter(Mandatory)] [string] $Configuration, [string] $TargetFramework)

    # @() outside the if: an if hands back a one-item array as a string, which splatting would pass letter by letter.
    $framework = @(if ($TargetFramework) { "-p:TargetFramework=$TargetFramework" })
    $output = @(& dotnet msbuild $Project -nologo -getProperty:ProjectAssetsFile -getProperty:TargetDir `
            -getProperty:TargetFramework -getProperty:TargetFrameworks "-p:Configuration=$Configuration" @framework 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "MSBuild couldn't read $Project, so it's unknown whether it uses Playwright:`n$($output -join "`n")" }
    $output -join "`n" | ConvertFrom-Json
}

function Install-PlaywrightBrowser {
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [string] $Configuration = 'Release',
        [switch] $WithDependencies
    )

    $solutionPath = (Resolve-Path -LiteralPath $Solution).Path
    $folder = Split-Path -Parent $solutionPath
    # UI projects (MAUI, desktop) don't evaluate without their workloads, as on Linux, and hold no browser tests (ADR-0059).
    $ui = @(& (Join-Path $PSScriptRoot 'Get-UiProject.ps1') -Solution $solutionPath | ForEach-Object FullPath)
    $users = foreach ($node in ([xml] (Get-Content -LiteralPath $solutionPath -Raw)).SelectNodes('//Project')) {
        $project = [IO.Path]::GetFullPath((Join-Path $folder $node.GetAttribute('Path')))
        if ($ui -contains $project) { continue }
        $json = Read-ProjectOutput -Project $project -Configuration $Configuration
        # With TargetFrameworks, the outer evaluation has no TargetDir: read the project through its first framework.
        if (-not $json.Properties.TargetFramework -and $json.Properties.TargetFrameworks) {
            $first = ($json.Properties.TargetFrameworks -split ';' | Where-Object { $_ })[0]
            $json = Read-ProjectOutput -Project $project -Configuration $Configuration -TargetFramework $first
        }
        $assets = Get-Content -Raw -LiteralPath $json.Properties.ProjectAssetsFile | ConvertFrom-Json
        # A list on the left, so -like filters it even when the graph holds one library.
        $library = @(@($assets.libraries.PSObject.Properties.Name) -like 'Microsoft.Playwright/*')
        if ($library) {
            $script = Join-Path $json.Properties.TargetDir 'playwright.ps1'
            if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
                throw "$project uses Playwright, but its $Configuration build has no playwright.ps1 at $script. Build it in $Configuration first."
            }
            [pscustomobject]@{ Version = ($library[0] -split '/')[1]; Script = $script }
        }
    }
    if (-not $users) { 'No project uses Playwright; no browser to install.'; return }
    $arguments = @('install') + @(if ($WithDependencies) { '--with-deps' }) + 'chromium'
    # Each Playwright version pins its own browser build, so one install per version.
    $installed = [Collections.Generic.HashSet[string]]::new()
    foreach ($user in $users | Where-Object { $installed.Add($_.Version) }) {
        & pwsh -NoProfile -File $user.Script @arguments
        if ($LASTEXITCODE -ne 0) { throw "Installing Playwright $($user.Version)'s browser failed with exit code $LASTEXITCODE ($($user.Script))." }
    }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to read, with -Solution.' }
    Install-PlaywrightBrowser -Solution $Solution -Configuration $Configuration
}
