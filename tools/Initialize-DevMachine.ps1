<#
.SYNOPSIS
    Checks this machine for the dotnet-agent-kit toolchain and, with -Install, installs what's missing.

.DESCRIPTION
    Required: PowerShell 7, Pester 6 (runs the kit's script tests), powershell-yaml (reads rule metadata), Git, GitHub CLI (signed in), the .NET SDK pinned in global.json, Claude Code.
    Later in the build: VS Code with the PowerShell extension, Docker.

    Nothing is installed unless you pass -Install; each install command is shown first, and -WhatIf
    shows them without running them. GitHub sign-in is always yours to do (gh auth login): this script
    never handles credentials.

    Runs on Windows PowerShell 5.1 too, so a new machine can find out that it needs PowerShell 7.
    Exit code: 0 when every required tool is ready, otherwise 1.

.PARAMETER Install
    Install each missing tool with winget (Claude Code with its official installer), one at a time.

.PARAMETER RepoRoot
    The repo whose global.json names the SDK to check. Defaults to this script's repo.

.EXAMPLE
    ./tools/Initialize-DevMachine.ps1
    Check only.

.EXAMPLE
    ./tools/Initialize-DevMachine.ps1 -Install -WhatIf
    Show what would be installed, without installing.

.EXAMPLE
    ./tools/Initialize-DevMachine.ps1 -Install
    Install what's missing, then open a new PowerShell window and run the check again.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch] $Install,
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 doesn't set $PSScriptRoot inside parameter defaults, so default it here.
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
}

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
        # Preview and RC SDKs (10.0.100-rc.2...) never satisfy the pin: global.json sets allowPrerelease false.
        $version = $null
        if (-not [version]::TryParse($candidate, [ref] $version)) {
            continue
        }
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
    # In Windows PowerShell 5.1, captured native stderr is an error record that 'Stop' would make terminating.
    # Probes write to stderr when they fail (gh auth status), so keep it as output and judge by the exit code.
    $ErrorActionPreference = 'Continue'
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

# Asks PowerShell 7 itself: Windows PowerShell 5.1 reads a different module folder, and the kit's scripts run in 7.
function Test-PwshModule {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $MinimumVersion
    )
    if (-not (Test-CommandAvailable -Name 'pwsh')) {
        return $false
    }
    $moduleQuery = "if (Get-Module -ListAvailable -Name $Name | Where-Object Version -GE ([version] '$MinimumVersion')) { exit 0 } else { exit 1 }"
    (Invoke-Native -FilePath 'pwsh' -Arguments '-NoProfile', '-Command', $moduleQuery).ExitCode -eq 0
}

function Get-PwshModuleInstallCommand {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version
    )
    "pwsh -NoProfile -Command `"Install-PSResource -Name $Name -Version $Version -Scope CurrentUser -Repository PSGallery -TrustRepository`""
}

function Test-VsCodeExtension {
    param([Parameter(Mandatory)] [string] $Id)
    (Test-CommandAvailable -Name 'code') -and (Invoke-Native -FilePath 'code' -Arguments '--list-extensions').Output -contains $Id
}

# The commit-msg hook (.githooks/, ADR-0027) runs only when this clone's core.hooksPath points at it.
function Test-GitHooksPath {
    param([Parameter(Mandatory)] [string] $RepoRoot)
    if (-not (Test-CommandAvailable -Name 'git')) {
        return $false
    }
    $result = Invoke-Native -FilePath 'git' -Arguments '-C', $RepoRoot, 'config', '--get', 'core.hooksPath'
    $result.ExitCode -eq 0 -and ("$($result.Output)".Trim() -eq '.githooks')
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
    New-DevMachineCheck -Name 'Pester 6' -Required $true -Test { Test-PwshModule -Name 'Pester' -MinimumVersion '6.0.0' } `
        -InstallCommand (Get-PwshModuleInstallCommand -Name 'Pester' -Version '6.2.0')
    New-DevMachineCheck -Name 'powershell-yaml' -Required $true -Test { Test-PwshModule -Name 'powershell-yaml' -MinimumVersion '0.4.12' } `
        -InstallCommand (Get-PwshModuleInstallCommand -Name 'powershell-yaml' -Version '0.4.12')
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
    $hookTest = [scriptblock]::Create("Test-GitHooksPath -RepoRoot '$($RepoRoot -replace "'", "''")'")
    New-DevMachineCheck -Name 'Git commit-msg hook' -Required $true -Test $hookTest `
        -InstallCommand "git -C '$($RepoRoot -replace "'", "''")' config core.hooksPath .githooks"
    New-DevMachineCheck -Name 'VS Code' -Required $false -Test { Test-CommandAvailable -Name 'code' } `
        -InstallCommand 'winget install --id Microsoft.VisualStudioCode --exact'
    New-DevMachineCheck -Name 'VS Code PowerShell extension' -Required $false -Test { Test-VsCodeExtension -Id 'ms-vscode.powershell' } `
        -InstallCommand 'code --install-extension ms-vscode.powershell'
    New-DevMachineCheck -Name 'Docker' -Required $false -Test { Test-CommandAvailable -Name 'docker' } `
        -InstallCommand 'winget install --id Docker.DockerDesktop --exact'
}

function Invoke-DevMachineCheck {
    param([Parameter(Mandatory)] [pscustomobject] $Check)

    # ok: present. action: only the owner can fix it. missing: required now. later: needed in a later build step.
    $status = 'later'
    if (& $Check.Test) {
        $status = 'ok'
    }
    elseif (-not $Check.InstallCommand) {
        $status = 'action'
    }
    elseif ($Check.Required) {
        $status = 'missing'
    }

    [pscustomobject]@{
        Name           = $Check.Name
        Required       = $Check.Required
        Status         = $status
        InstallCommand = $Check.InstallCommand
        ManualAction   = $Check.ManualAction
    }
}

function Invoke-InstallCommand {
    param([Parameter(Mandatory)] [string] $Command)

    # Installers report failure by exit code, not by throwing. Reset it first, so a leftover code from an
    # earlier command can't fail an install that runs no native command (irm ... | iex).
    # Their output goes to the host, so callers get only what they return themselves.
    $global:LASTEXITCODE = 0
    Invoke-Expression -Command $Command | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "'$Command' failed with exit code $LASTEXITCODE."
    }
}

# Runs every check, prints the results and, with -Install, installs what's missing one tool at a time.
# Returns 0 when every required tool is ready, otherwise 1.
function Initialize-DevMachine {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $RepoRoot,
        [switch] $Install
    )

    $labels = @{ ok = '[ok]     '; missing = '[missing]'; later = '[later]  '; action = '[action] ' }
    $colors = @{ ok = 'Green'; missing = 'Red'; later = 'Yellow'; action = 'Red' }

    Write-Host "`nChecking the dotnet-agent-kit toolchain on $env:COMPUTERNAME..." -ForegroundColor Cyan
    $results = @(Get-DevMachineCheck -RepoRoot $RepoRoot | ForEach-Object { Invoke-DevMachineCheck -Check $_ })
    foreach ($result in $results) {
        $line = "  $($labels[$result.Status]) $($result.Name)"
        if ($result.Status -in 'missing', 'later') {
            $line += "  ->  $($result.InstallCommand)"
        }
        elseif ($result.Status -eq 'action') {
            $line += "  ->  $($result.ManualAction)"
        }
        Write-Host $line -ForegroundColor $colors[$result.Status]
    }

    $notReady = @($results | Where-Object { $_.Required -and $_.Status -ne 'ok' })

    if ($Install) {
        $installable = @($results | Where-Object { $_.Status -in 'missing', 'later' })
        foreach ($result in $installable) {
            if ($PSCmdlet.ShouldProcess($result.Name, $result.InstallCommand)) {
                Write-Host "`nInstalling $($result.Name): $($result.InstallCommand)" -ForegroundColor Cyan
                try {
                    Invoke-InstallCommand -Command $result.InstallCommand
                }
                catch {
                    # Typically a tool installed earlier in this run that isn't on PATH until a new window.
                    Write-Host "  $($result.Name) install failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        if ($installable) {
            Write-Host "`nOpen a new PowerShell window so new tools are on PATH, then run this script again to confirm." -ForegroundColor Yellow
        }
    }
    elseif ($notReady) {
        Write-Host "`nFix the items above, or run again with -Install to install the missing tools." -ForegroundColor Red
    }
    else {
        Write-Host "`nAll required tools are ready." -ForegroundColor Green
    }

    if ($notReady) { 1 } else { 0 }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    exit (Initialize-DevMachine -RepoRoot $RepoRoot -Install:$Install)
}
