#Requires -Version 7.6
<#
.SYNOPSIS
    Brings a newer kit release into an existing app's files (PR D3, ADR-0042).

.DESCRIPTION
    Reads the app's .kit/manifest.json and updates every kit-managed file, and the kit blocks of AGENTS.md and
    THIRD-PARTY-NOTICES.md, to the kit at -KitRef, a release tag. Files the app owns are never read or written.

.EXAMPLE
    ./tools/Sync-KitApp.ps1 -AppRoot ../Contoso.Orders -KitRoot . -KitRef v0.2.0 -ReportPath ../sync-report.md
#>
[CmdletBinding()]
param(
    [string] $AppRoot,
    [string] $KitRoot,
    [string] $KitRef,
    [string] $ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The commit a release tag (vX.Y.Z) in the kit repo points to. Only a tag counts: ADR-0031 trusts a kit pin only
# when a release tag in the kit's own repo points to it.
function Get-KitReleaseCommit {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $KitRef
    )

    $commit = if ($KitRef -cmatch '^v\d+\.\d+\.\d+$') {
        (git -C $KitRoot rev-parse --verify --quiet "refs/tags/$KitRef^{commit}" | Out-String).Trim()
    }
    if (-not $commit) { throw "'$KitRef' isn't a release tag (vX.Y.Z) in the kit at $KitRoot." }
    $commit
}

function Sync-KitApp {
    param(
        [Parameter(Mandatory)] [string] $AppRoot,
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $KitRef
    )

    $AppRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($AppRoot)
    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)
    $toCommit = Get-KitReleaseCommit -KitRoot $KitRoot -KitRef $KitRef
    $manifest = Read-KitManifest -AppRoot $AppRoot
    $fromCommit = $manifest['kitCommit']

    # Only forward: the release must contain the app's kit commit. An app's files at a later kit version than the
    # release would otherwise be taken back.
    git -C $KitRoot cat-file -e "$fromCommit^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "The app's kit commit $fromCommit isn't in the kit at $KitRoot." }
    git -C $KitRoot merge-base --is-ancestor $fromCommit $toCommit
    if ($LASTEXITCODE -ne 0) {
        throw "$KitRef doesn't come after the app's kit commit $fromCommit ($($manifest['kitVersion'])), so syncing to it would take the app back."
    }
}

# The app's .kit/manifest.json, checked for what the sync needs.
function Read-KitManifest {
    param([Parameter(Mandatory)] [string] $AppRoot)

    Get-Content -Raw -LiteralPath (Join-Path $AppRoot '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Sync-KitApp -AppRoot $AppRoot -KitRoot $KitRoot -KitRef $KitRef | Out-Null
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
