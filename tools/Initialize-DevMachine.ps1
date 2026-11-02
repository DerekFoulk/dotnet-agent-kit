<#
.SYNOPSIS
    Checks this machine for the dotnet-agent-kit toolchain and, with -Install, installs what's missing.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch] $Install,
    [string] $RepoRoot = (Split-Path -Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# True when an installed SDK satisfies the global.json pin. SDK patch numbers carry the feature band
# in their hundreds (10.0.403 is band 4, patch 3); latestPatch accepts a newer patch in the same band only.
function Test-SdkSatisfiesPin {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Installed,
        [Parameter(Mandatory)] [string] $Pinned,
        [Parameter(Mandatory)] [string] $RollForward
    )

    if ($RollForward -notin 'disable', 'patch', 'latestPatch') {
        throw "Unsupported rollForward '$RollForward'. The kit pins the SDK with latestPatch (D25)."
    }

    $pin = [version] $Pinned
    foreach ($candidate in $Installed) {
        $version = [version] $candidate
        if ($RollForward -eq 'disable') {
            if ($version -eq $pin) { return $true }
            continue
        }
        $sameBand = $version.Major -eq $pin.Major -and
            $version.Minor -eq $pin.Minor -and
            [math]::Floor($version.Build / 100) -eq [math]::Floor($pin.Build / 100)
        if ($sameBand -and $version.Build -ge $pin.Build) { return $true }
    }
    $false
}

function Get-PinnedSdk {
    param([Parameter(Mandatory)] [string] $GlobalJsonPath)

    $sdk = (Get-Content -Path $GlobalJsonPath -Raw | ConvertFrom-Json).sdk
    $rollForward = 'latestPatch'
    if ($sdk.PSObject.Properties['rollForward']) {
        $rollForward = $sdk.rollForward
    }
    [pscustomobject]@{ Version = $sdk.version; RollForward = $rollForward }
}

function Test-CommandAvailable {
    param([Parameter(Mandatory)] [string] $Name)
    [bool] (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [string[]] $Arguments = @()
    )
    $output = & $FilePath @Arguments 2>&1
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output | ForEach-Object { "$_" }) }
}

function Test-GitHubSignIn {
    (Test-CommandAvailable -Name 'gh') -and (Invoke-Native -FilePath 'gh' -Arguments 'auth', 'status').ExitCode -eq 0
}

function Test-DotNetSdk {
    param(
        [Parameter(Mandatory)] [string] $Pinned,
        [Parameter(Mandatory)] [string] $RollForward
    )
    if (-not (Test-CommandAvailable -Name 'dotnet')) {
        return $false
    }
    # Each line of `dotnet --list-sdks` reads "10.0.403 [C:\Program Files\dotnet\sdk]".
    $installed = @((Invoke-Native -FilePath 'dotnet' -Arguments '--list-sdks').Output | ForEach-Object { ($_ -split ' ')[0] })
    Test-SdkSatisfiesPin -Installed $installed -Pinned $Pinned -RollForward $RollForward
}

function Test-VsCodeExtension {
    param([Parameter(Mandatory)] [string] $Id)
    (Test-CommandAvailable -Name 'code') -and (Invoke-Native -FilePath 'code' -Arguments '--list-extensions').Output -contains $Id
}

function New-DevMachineCheck {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [bool] $Required,
        [Parameter(Mandatory)] [scriptblock] $Test,
        [string] $InstallCommand,
        [string] $ManualAction
    )
    [pscustomobject]@{
        Name           = $Name
        Required       = $Required
        Test           = $Test
        InstallCommand = $InstallCommand
        ManualAction   = $ManualAction
    }
}

# The toolchain, required tools first. Optional tools are needed later in the build (VS Code for scripts
# the owner runs himself, D11; Docker for Testcontainers).
function Get-DevMachineCheck {
    param([Parameter(Mandatory)] [string] $RepoRoot)

    $pin = Get-PinnedSdk -GlobalJsonPath (Join-Path -Path $RepoRoot -ChildPath 'global.json')
    $sdkVersion = [version] $pin.Version
    $sdkTest = [scriptblock]::Create("Test-DotNetSdk -Pinned '$sdkVersion' -RollForward '$($pin.RollForward)'")

    New-DevMachineCheck -Name 'PowerShell 7' -Required $true -Test { Test-CommandAvailable -Name 'pwsh' } `
        -InstallCommand 'winget install --id Microsoft.PowerShell --exact'
    New-DevMachineCheck -Name 'Git' -Required $true -Test { Test-CommandAvailable -Name 'git' } `
        -InstallCommand 'winget install --id Git.Git --exact'
    New-DevMachineCheck -Name 'GitHub CLI' -Required $true -Test { Test-CommandAvailable -Name 'gh' } `
        -InstallCommand 'winget install --id GitHub.cli --exact'
    New-DevMachineCheck -Name 'GitHub CLI signed in' -Required $true -Test { Test-GitHubSignIn } `
        -ManualAction 'Sign in yourself: run `gh auth login` in a separate PowerShell window, then run this script again.'
    New-DevMachineCheck -Name ".NET SDK $sdkVersion" -Required $true -Test $sdkTest `
        -InstallCommand "winget install --id Microsoft.DotNet.SDK.$($sdkVersion.Major) --exact --version $sdkVersion"
    New-DevMachineCheck -Name 'Claude Code' -Required $true -Test { Test-CommandAvailable -Name 'claude' } `
        -InstallCommand 'irm https://claude.ai/install.ps1 | iex'
    New-DevMachineCheck -Name 'VS Code' -Required $false -Test { Test-CommandAvailable -Name 'code' } `
        -InstallCommand 'winget install --id Microsoft.VisualStudioCode --exact'
    New-DevMachineCheck -Name 'VS Code PowerShell extension' -Required $false -Test { Test-VsCodeExtension -Id 'ms-vscode.powershell' } `
        -InstallCommand 'code --install-extension ms-vscode.powershell'
    New-DevMachineCheck -Name 'Docker' -Required $false -Test { Test-CommandAvailable -Name 'docker' } `
        -InstallCommand 'winget install --id Docker.DockerDesktop --exact'
}

function Invoke-DevMachineCheck {
    param([Parameter(Mandatory)] [pscustomobject] $Check)
    [pscustomobject]@{ Name = $null; Required = $Check.Required; Status = $null; InstallCommand = $Check.InstallCommand; ManualAction = $Check.ManualAction }
}
