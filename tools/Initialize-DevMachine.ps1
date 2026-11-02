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

function Test-SdkSatisfiesPin {
    param(
        [AllowEmptyCollection()] [string[]] $Installed,
        [string] $Pinned,
        [string] $RollForward
    )
    $false
}

function Get-PinnedSdk {
    param([string] $GlobalJsonPath)
    [pscustomobject]@{ Version = $null; RollForward = $null }
}
