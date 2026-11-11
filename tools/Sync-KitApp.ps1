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

# Export-KitApp's text hash, loaded in a child scope so its parameters don't replace this script's. The manifest's
# hashes must be computed exactly as the export computes them (ADR-0032).
$script:TextHash = & { . (Join-Path $PSScriptRoot 'Export-KitApp.ps1'); ${function:Get-KitTextHash} }

# Exports the app at one kit commit with that commit's own Export-KitApp, so every file comes out as that version
# makes it: templates rendered, .claude/settings.json made with that version's tools, rule files generated.
function Export-KitAppAt {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Destination
    )

    $checkout = Join-Path ([IO.Path]::GetTempPath()) "kit-sync-$([guid]::NewGuid().ToString('N'))"
    git -C $KitRoot worktree add --quiet --detach $checkout "$KitRef^{commit}" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Couldn't check out $KitRef from $KitRoot." }
    try {
        $exporter = Join-Path $checkout 'tools/Export-KitApp.ps1'
        $output = & pwsh -NoProfile -File $exporter -Name $Name -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Exporting the app at $KitRef failed:`n$output" }
    }
    finally {
        git -C $KitRoot worktree remove --force $checkout
    }
    Get-Content -Raw -LiteralPath (Join-Path $Destination '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
}

# The text the manifest hashes for one entry: the whole file, or its kit block. $null when there's none.
function Get-KitEntryText {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [Collections.IDictionary] $Entry
    )

    $path = Join-Path $Root $Entry['path']
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    [IO.File]::ReadAllText($path)
}

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

    $result = [pscustomobject]@{
        FromVersion = $manifest['kitVersion']
        FromCommit  = $fromCommit
        ToVersion   = $KitRef
        ToCommit    = $toCommit
        Changed     = $false
        Files       = @()
    }
    if ($fromCommit -eq $toCommit) { return $result }

    $work = Join-Path ([IO.Path]::GetTempPath()) "kit-sync-$([guid]::NewGuid().ToString('N'))"
    try {
        $newRoot = Join-Path $work 'new'
        $new = Export-KitAppAt -KitRoot $KitRoot -KitRef $KitRef -Name $manifest['appName'] -Destination $newRoot
        $oldEntries = @{}
        foreach ($entry in $manifest['files']) { $oldEntries[$entry['path']] = $entry }
        $newEntries = @{}
        foreach ($entry in $new['files']) { $newEntries[$entry['path']] = $entry }

        $paths = @($oldEntries.Keys) + @($newEntries.Keys) | Sort-Object -Unique
        $files = foreach ($path in $paths) {
            $old = $oldEntries[$path]
            $theirs = $newEntries[$path]
            $ours = Get-KitEntryText -Root $AppRoot -Entry ($theirs ?? $old)
            $target = Join-Path $AppRoot $path
            $unedited = $old -and $null -ne $ours -and (& $script:TextHash -Text $ours) -eq $old['sha256']
            if (-not $old -and $null -eq $ours) {
                New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
                Copy-Item -LiteralPath (Join-Path $newRoot $path) -Destination $target
                [pscustomobject]@{ Path = $path; Action = 'Added' }
            }
            elseif ($unedited -and -not $theirs) {
                Remove-Item -LiteralPath $target
                [pscustomobject]@{ Path = $path; Action = 'Removed' }
            }
            elseif ($unedited -and $old['sha256'] -ne $theirs['sha256']) {
                Copy-Item -LiteralPath (Join-Path $newRoot $path) -Destination $target -Force
                [pscustomobject]@{ Path = $path; Action = 'Updated' }
            }
        }
        $result.Files = @($files)
        $result.Changed = $result.Files.Count -gt 0
    }
    finally {
        if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    }
    $result
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
