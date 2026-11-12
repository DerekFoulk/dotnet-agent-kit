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
    [string] $Configuration = 'Release',
    [switch] $WithDependencies
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'KitSolution.psm1') -Force

# MSBuild's evaluation of a project, without a build: where its restore graph and its build output are.
function Read-ProjectOutput {
    param([Parameter(Mandatory)] [string] $Project, [Parameter(Mandatory)] [string] $Configuration, [string] $TargetFramework)

    # @() outside the if: an if hands back a one-item array as a string, which splatting would pass letter by letter.
    $framework = @(if ($TargetFramework) { "-p:TargetFramework=$TargetFramework" })
    $output = @(& dotnet msbuild $Project -nologo -getProperty:ProjectAssetsFile -getProperty:TargetDir `
            -getProperty:TargetFramework -getProperty:TargetFrameworks "-p:Configuration=$Configuration" @framework 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "MSBuild couldn't read $Project, so it's unknown whether it uses Playwright:`n$($output -join "`n")" }
    # MSBuild may print an evaluation warning before its answer; the answer is the JSON object that ends the output.
    $start = [array]::LastIndexOf([string[]] $output, '{')
    if ($start -lt 0) { throw "MSBuild gave no properties for $Project`:`n$($output -join "`n")" }
    $output[$start..($output.Count - 1)] -join "`n" | ConvertFrom-Json
}

function Install-PlaywrightBrowser {
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [string] $Configuration = 'Release',
        [switch] $WithDependencies
    )

    $projects = @(Get-SolutionProject -Solution $Solution)
    # UI projects (MAUI, desktop) don't evaluate without their workloads, as on Linux, and hold no browser tests (ADR-0059).
    $ui = @(& (Join-Path $PSScriptRoot 'Get-UiProject.ps1') -Solution $Solution | ForEach-Object FullPath)
    $users = foreach ($listed in $projects) {
        $project = $listed.FullPath
        # Both FullPaths come from KitSolution.psm1, so they compare equal on every OS.
        if ($ui -contains $project -or [IO.Path]::GetExtension($project) -notin '.csproj', '.fsproj', '.vbproj') { continue }
        $json = Read-ProjectOutput -Project $project -Configuration $Configuration
        # With TargetFrameworks, the outer evaluation has no TargetDir: read the project through its first framework.
        $first = Get-FirstTargetFramework -Properties $json.Properties
        if ($first) { $json = Read-ProjectOutput -Project $project -Configuration $Configuration -TargetFramework $first }
        $assetsFile = $json.Properties.ProjectAssetsFile
        if (-not $assetsFile -or -not (Test-Path -LiteralPath $assetsFile -PathType Leaf)) {
            throw "$project has no restore graph (obj/project.assets.json), so it's unknown whether it uses Playwright. Restore it first."
        }
        $assets = Get-Content -Raw -LiteralPath $assetsFile | ConvertFrom-Json
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
    Install-PlaywrightBrowser -Solution $Solution -Configuration $Configuration -WithDependencies:$WithDependencies
}
