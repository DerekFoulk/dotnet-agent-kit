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
