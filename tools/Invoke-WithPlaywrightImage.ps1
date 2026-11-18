#Requires -Version 7.6
<#
.SYNOPSIS
    Runs a command inside the pinned Playwright .NET image when the solution has Playwright tests, and on the runner
    when it has none (GAP-033, ADR-0061).

.DESCRIPTION
    The shared CI runs its tests through this script, and the mutation run its Stryker. For each C# project in the
    solution, MSBuild gives the project's restore graph (ProjectAssetsFile). A project with Microsoft.Playwright in that
    graph, directly or through Deque.AxeCore.Playwright, uses Playwright.

    With none, the command runs on the runner.

    With some, the command runs in Microsoft's Playwright .NET image, which holds that Playwright version's browsers and
    their system libraries. The image is the one the repo's pin names (-Pin, .config/playwright/Dockerfile) by tag and
    digest, so Docker checks every layer against the digest. Its tag's version must be the projects' Microsoft.Playwright
    version, since Playwright finds only its own version's browsers.

    The image's own .NET SDK is its base image's 10.0.1xx band, which can't match a global.json pin such as 10.0.403.
    So the container runs the SDK actions/setup-dotnet installed on the runner (DOTNET_ROOT), shared read-only at the
    same path: the dotnet-install script Playwright's Docker page uses to put another SDK in the image, run once on the
    runner. The home folder, the working folder and every -Share folder are shared at the same paths, so the build's
    absolute paths, the NuGet package folder and the results folder mean the same inside.

.EXAMPLE
    ./tools/Invoke-WithPlaywrightImage.ps1 -Solution App.slnx -Pin .config/playwright/Dockerfile -- dotnet test --solution App.slnx --no-build
#>
# No positional parameters: every word after the named ones is the command's, even the first.
[CmdletBinding(PositionalBinding = $false)]
param(
    [string] $Solution,
    [string] $Pin,
    [string[]] $Share = @(),
    [Parameter(ValueFromRemainingArguments)] [string[]] $Command
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'KitSolution.psm1') -Force

# Puts the runner's SDK first on the image's own PATH, inside the container, then runs the command (its arguments
# follow, after the "sh" that becomes $0), so the kit keeps no copy of the image's PATH.
$script:SdkFirst = @('sh', '-c', 'PATH="$DOTNET_ROOT:$PATH" exec "$@"', 'sh')

# CI's own variables, passed on by name: the tests and the SDK read them (CI turns on locked restore, GITHUB_ACTIONS
# GitHub's test reporting).
$script:PassedVariables = @('CI', 'GITHUB_ACTIONS', 'DOTNET_NOLOGO', 'DOTNET_CLI_TELEMETRY_OPTOUT')

# MSBuild's evaluation of a project, without a build: where its restore graph is, and its frameworks.
function Read-ProjectProperty {
    param([Parameter(Mandatory)] [string] $Project, [string] $TargetFramework)

    # @() outside the if: an if hands back a one-item array as a string, which splatting would pass letter by letter.
    $framework = @(if ($TargetFramework) { "-p:TargetFramework=$TargetFramework" })
    $output = @(& dotnet msbuild $Project -nologo -getProperty:ProjectAssetsFile -getProperty:TargetFramework `
            -getProperty:TargetFrameworks @framework 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "MSBuild couldn't read $Project, so it's unknown whether it uses Playwright:`n$($output -join "`n")" }
    # MSBuild may print an evaluation warning before its answer; the answer is the JSON object that ends the output.
    $start = [array]::LastIndexOf([string[]] $output, '{')
    if ($start -lt 0) { throw "MSBuild gave no properties for $Project`:`n$($output -join "`n")" }
    ($output[$start..($output.Count - 1)] -join "`n" | ConvertFrom-Json).Properties
}

# The restore graph of a project, as MSBuild names it. With TargetFrameworks, the outer evaluation names none, so the
# project is read through its first framework, as Test-CodeShape.ps1 does.
function Get-ProjectAssetsFile {
    param([Parameter(Mandatory)] [string] $Project)

    $properties = Read-ProjectProperty -Project $Project
    $first = Get-FirstTargetFramework -Properties $properties
    if ($first) { $properties = Read-ProjectProperty -Project $Project -TargetFramework $first }
    $properties.ProjectAssetsFile
}

# Each project of the solution that uses Playwright, with its Microsoft.Playwright version.
function Get-PlaywrightProject {
    param([Parameter(Mandatory)] [string] $Solution)

    # UI projects (MAUI, desktop) don't evaluate without their workloads, as on Linux, and hold no browser tests (ADR-0059).
    $ui = @(& (Join-Path $PSScriptRoot 'Get-UiProject.ps1') -Solution $Solution | ForEach-Object FullPath)
    foreach ($listed in @(Get-SolutionProject -Solution $Solution)) {
        $project = $listed.FullPath
        # Both FullPaths come from KitSolution.psm1, so they compare equal on every OS.
        if ($ui -contains $project -or [IO.Path]::GetExtension($project) -notin '.csproj', '.fsproj', '.vbproj') { continue }
        $assetsFile = Get-ProjectAssetsFile -Project $project
        if (-not $assetsFile -or -not (Test-Path -LiteralPath $assetsFile -PathType Leaf)) {
            throw "$project has no restore graph (obj/project.assets.json), so it's unknown whether it uses Playwright. Restore it first."
        }
        $assets = Get-Content -Raw -LiteralPath $assetsFile | ConvertFrom-Json
        # A list on the left, so -like filters it even when the graph holds one library.
        $library = @(@($assets.libraries.PSObject.Properties.Name) -like 'Microsoft.Playwright/*')
        if ($library) { [pscustomobject]@{ Project = $project; Version = ($library[0] -split '/')[1] } }
    }
}

# The image the pin names, and the Playwright version its tag is for.
function Get-PlaywrightImagePin {
    param([Parameter(Mandatory)] [string] $Path)

    $pattern = '^FROM (?<image>mcr\.microsoft\.com/playwright/dotnet:v(?<version>\d+\.\d+\.\d+)-[a-z]+@sha256:[0-9a-f]{64})$'
    $from = @(Get-Content -LiteralPath $Path | Where-Object { $_ -match '^\s*FROM\s' })
    if ($from.Count -ne 1 -or $from[0] -cnotmatch $pattern) {
        throw "$Path must have one FROM line naming Microsoft's Playwright .NET image by tag and digest, such as FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@sha256:<64 hex digits>."
    }
    [pscustomobject]@{ Image = $Matches['image']; Version = $Matches['version'] }
}

# The runner's user and group, which the container runs as, so what it writes stays the runner's; and the group that
# owns Docker's socket, when there is one.
function Get-RunnerIdentity {
    if (-not $IsLinux) { throw 'The Playwright image runs on a Linux runner only.' }
    $socket = '/var/run/docker.sock'
    [pscustomobject]@{
        User              = "$(& id -u):$(& id -g)"
        DockerSocketGroup = if (Test-Path -LiteralPath $socket) { (& stat -c '%g' $socket) } else { $null }
    }
}

# Whether a path is a folder already in the list, or inside one.
function Test-SharedPath {
    param([Parameter(Mandatory)] [string] $Path, [AllowEmptyCollection()] [string[]] $Shared)

    [bool] @($Shared | Where-Object { $Path -eq $_ -or $Path.StartsWith("$($_.TrimEnd('/'))/", [StringComparison]::Ordinal) })
}

# docker's arguments: run the image with Playwright's recommended --init and --ipc=host (Chromium runs out of shared
# memory without it), the runner's network and user, the runner's SDK first on PATH, and the folders the command reads
# and writes shared at the same paths. Tests that start containers of their own (Testcontainers) reach the runner's
# Docker through its socket; on the runner's network, those containers' ports are on localhost, which
# TESTCONTAINERS_HOST_OVERRIDE tells Testcontainers, since inside a container it would look for them at a network
# gateway. With -KeepTestcontainersHost, the runner's own value is passed on instead. The web UI fixture's ContainerTests
# proves it in the kit's CI (GAP-047).
function Get-PlaywrightContainerArgument {
    param(
        [Parameter(Mandatory)] [string] $Image,
        [Parameter(Mandatory)] [string[]] $Command,
        [Parameter(Mandatory)] [string] $WorkingDirectory,
        [Parameter(Mandatory)] [string] $HomePath,
        [Parameter(Mandatory)] [string] $DotnetRoot,
        [Parameter(Mandatory)] [string] $User,
        [string[]] $Share = @(),
        [string] $DockerSocketGroup,
        [switch] $KeepTestcontainersHost
    )

    $shared = [Collections.Generic.List[string]]::new()
    foreach ($folder in @($HomePath, $WorkingDirectory) + $Share) {
        if (-not (Test-SharedPath -Path $folder -Shared $shared)) { $shared.Add($folder) }
    }
    'run', '--rm', '--init', '--ipc=host', '--network', 'host', '--user', $User
    if ($DockerSocketGroup) { '--group-add', $DockerSocketGroup, '-v', '/var/run/docker.sock:/var/run/docker.sock' }
    foreach ($folder in $shared) { '-v', "${folder}:${folder}" }
    if (-not (Test-SharedPath -Path $DotnetRoot -Shared $shared)) { '-v', "${DotnetRoot}:${DotnetRoot}:ro" }
    '-w', $WorkingDirectory
    '-e', "HOME=$HomePath", '-e', "DOTNET_ROOT=$DotnetRoot"
    '-e', $(if ($KeepTestcontainersHost) { 'TESTCONTAINERS_HOST_OVERRIDE' } else { 'TESTCONTAINERS_HOST_OVERRIDE=localhost' })
    foreach ($name in $script:PassedVariables) { '-e', $name }
    $Image
    $script:SdkFirst
    $Command
}

function Invoke-WithPlaywrightImage {
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [Parameter(Mandatory)] [string] $Pin,
        [Parameter(Mandatory)] [string[]] $Command,
        [string[]] $Share = @()
    )

    $projects = @(Get-PlaywrightProject -Solution $Solution)
    if (-not $projects) {
        'No project uses Playwright, so the command runs on the runner.'
        & $Command[0] @($Command | Select-Object -Skip 1)
        return
    }

    $versions = @($projects.Version | Sort-Object -Unique)
    if ($versions.Count -gt 1) {
        throw "The solution's projects use Microsoft.Playwright $($versions -join ' and '). One image holds one Playwright version's browsers, so use one version."
    }
    $version = $versions[0]
    if (-not (Test-Path -LiteralPath $Pin -PathType Leaf)) {
        throw "$(Split-Path $projects[0].Project -Leaf) uses Microsoft.Playwright $version, but there's no image pin at $Pin. Add one: FROM mcr.microsoft.com/playwright/dotnet:v$version-noble@sha256:<its digest> (docs/standards/testing.md, ""Browser and accessibility tests"")."
    }
    $image = Get-PlaywrightImagePin -Path $Pin
    if ($image.Version -ne $version) {
        throw "The projects use Microsoft.Playwright $version, but $Pin pins the image for Playwright $($image.Version), and Playwright finds only its own version's browsers. Move both in one PR (docs/standards/testing.md, ""Browser and accessibility tests"")."
    }
    if (-not $env:DOTNET_ROOT) {
        throw 'DOTNET_ROOT isn''t set. actions/setup-dotnet sets it when it installs the SDK global.json names, which the container runs.'
    }

    $identity = Get-RunnerIdentity
    "Running in $($image.Image), for Playwright $version, with the .NET SDK in $env:DOTNET_ROOT."
    $arguments = Get-PlaywrightContainerArgument -Image $image.Image -Command $Command -WorkingDirectory (Get-Location).Path `
        -HomePath $HOME -DotnetRoot $env:DOTNET_ROOT -User $identity.User -Share $Share -DockerSocketGroup $identity.DockerSocketGroup `
        -KeepTestcontainersHost:([bool] $env:TESTCONTAINERS_HOST_OVERRIDE)
    & docker @arguments
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to read, with -Solution.' }
    if (-not $Pin) { throw 'Give the image pin, with -Pin (.config/playwright/Dockerfile).' }
    if (-not $Command) { throw 'Give the command to run after --, such as -- dotnet test --no-build.' }
    Invoke-WithPlaywrightImage -Solution $Solution -Pin $Pin -Command $Command -Share $Share
    exit $LASTEXITCODE
}
