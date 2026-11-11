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

# Export-KitApp's text hash and kit block, loaded in a child scope so its parameters don't replace this script's.
# The manifest's hashes must be computed exactly as the export computes them (ADR-0032).
$script:TextHash, $script:BlockPattern, $script:GeneratedFolders = & {
    . (Join-Path $PSScriptRoot 'Export-KitApp.ps1')
    ${function:Get-KitTextHash}
    $script:KitBlockPattern
    , $script:GeneratedFolders
}

# Whether a kit-managed path is a rule file Build-AgentRules generates.
function Test-KitGeneratedPath {
    param([Parameter(Mandatory)] [string] $Path)

    [bool] ($script:GeneratedFolders | Where-Object { $Path.StartsWith("$_/", [StringComparison]::Ordinal) })
}

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
    $text = [IO.File]::ReadAllText($path)
    if (-not $Entry.Contains('block')) { return $text }
    $block = [regex]::Match($text, $script:BlockPattern)
    if ($block.Success) { $block.Value } else { $null }
}

# Gives the app an entry as the release's export has it: the file byte for byte, or, in a file the app already
# has, only the kit block.
function Copy-KitEntry {
    param(
        [Parameter(Mandatory)] [string] $From,
        [Parameter(Mandatory)] [string] $To,
        [Parameter(Mandatory)] [Collections.IDictionary] $Entry
    )

    $target = Join-Path $To $Entry['path']
    if ($Entry.Contains('block') -and (Test-Path -LiteralPath $target -PathType Leaf)) {
        Set-KitEntryText -Root $To -Entry $Entry -Text (Get-KitEntryText -Root $From -Entry $Entry)
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $From $Entry['path']) -Destination $target -Force
}

# Writes an entry's new text: the whole file, or only its kit block, in the line endings the file already has.
function Set-KitEntryText {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [Collections.IDictionary] $Entry,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text
    )

    $path = Join-Path $Root $Entry['path']
    $file = [IO.File]::ReadAllText($path)
    $lf = $Text -replace "`r`n", "`n"
    $Text = $file.Contains("`r`n") ? ($lf -replace "`n", "`r`n") : $lf
    if ($Entry.Contains('block')) {
        $block = [regex]::Match($file, $script:BlockPattern)
        $Text = $file.Substring(0, $block.Index) + $Text + $file.Substring($block.Index + $block.Length)
    }
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
}

# Three-way merge of the app's text with the kit's change from Base to Theirs (git merge-file). Returns the merged
# text, or $null when the two changes overlap.
function Merge-KitText {
    param(
        [Parameter(Mandatory)] [string] $Work,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Ours,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Base,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Theirs
    )

    $folder = Join-Path $Work "merge-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $folder | Out-Null
    $files = foreach ($side in @{ Name = 'ours'; Text = $Ours }, @{ Name = 'base'; Text = $Base }, @{ Name = 'theirs'; Text = $Theirs }) {
        $path = Join-Path $folder $side.Name
        [IO.File]::WriteAllText($path, ($side.Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
        $path
    }
    # Writes the result into the first file; the exit code is the number of conflicts, or negative on an error.
    git merge-file --quiet $files[0] $files[1] $files[2] 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { return $null }
    [IO.File]::ReadAllText($files[0])
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
        # The kit's text at the app's version: the base of a three-way merge with an app's edit.
        $baseRoot = Join-Path $work 'base'
        $null = Export-KitAppAt -KitRoot $KitRoot -KitRef $fromCommit -Name $manifest['appName'] -Destination $baseRoot
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
            if ($old -and $theirs -and $null -ne $ours -and -not $unedited -and (Test-KitGeneratedPath -Path $path)) {
                # Generated from the standards: an edit there is lost at the next build anyway, so it's replaced.
                Copy-KitEntry -From $newRoot -To $AppRoot -Entry $theirs
                [pscustomobject]@{ Path = $path; Action = 'Regenerated' }
            }
            elseif (-not $old -and $null -eq $ours) {
                Copy-KitEntry -From $newRoot -To $AppRoot -Entry $theirs
                [pscustomobject]@{ Path = $path; Action = 'Added' }
            }
            elseif (-not $old) {
                # The kit now has a file where the app made its own: the app's stays.
                [pscustomobject]@{ Path = $path; Action = 'AppFileKept' }
            }
            elseif ($null -eq $ours) {
                # The app deleted a kit file (or its kit block): it isn't brought back.
                if ($theirs) { [pscustomobject]@{ Path = $path; Action = 'KeptDeleted' } }
            }
            elseif (-not $theirs -and -not $unedited) {
                # The kit dropped a file the app edited: the app's copy stays, and is the app's from now on.
                [pscustomobject]@{ Path = $path; Action = 'NowAppOwned' }
            }
            elseif ($unedited -and -not $theirs) {
                Remove-Item -LiteralPath $target
                [pscustomobject]@{ Path = $path; Action = 'Removed' }
            }
            elseif ($unedited -and $old['sha256'] -ne $theirs['sha256']) {
                Copy-KitEntry -From $newRoot -To $AppRoot -Entry $theirs
                [pscustomobject]@{ Path = $path; Action = 'Updated' }
            }
            elseif ($old -and $theirs -and $null -ne $ours -and -not $unedited -and (& $script:TextHash -Text $ours) -ne $theirs['sha256']) {
                # The base must be exactly the text the manifest recorded; anything else could merge in changes
                # nobody made.
                $base = Get-KitEntryText -Root $baseRoot -Entry $old
                $merged = if ($null -ne $base -and (& $script:TextHash -Text $base) -eq $old['sha256']) {
                    Merge-KitText -Work $work -Ours $ours -Base $base -Theirs (Get-KitEntryText -Root $newRoot -Entry $theirs)
                }
                if ($null -eq $merged) {
                    # Overlapping changes: the app's text stays, and the PR says so. Conflict markers in a file
                    # would only break the build or hide in a doc.
                    [pscustomobject]@{ Path = $path; Action = 'Conflict' }
                }
                else {
                    Set-KitEntryText -Root $AppRoot -Entry $theirs -Text $merged
                    [pscustomobject]@{ Path = $path; Action = 'Merged' }
                }
            }
        }
        # The app's own Build-AgentRules, now at the release, rebuilds every generated file: the rule files, and
        # copilot-instructions.md, which copies the app's AGENTS.md with its new kit block.
        $builder = Join-Path $AppRoot '.kit/tools/Build-AgentRules.ps1'
        $output = & pwsh -NoProfile -File $builder -RepoRoot $AppRoot 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Rebuilding the app's agent rule files failed:`n$output" }

        # The release's manifest: its version and the kit's hash of every file it manages. A file whose edit was
        # kept keeps the kit's hash here, so the next sync sees the edit again and merges with this release's text.
        Copy-Item -LiteralPath (Join-Path $newRoot '.kit/manifest.json') -Destination (Join-Path $AppRoot '.kit/manifest.json') -Force

        $result.Files = @($files)
        $result.Changed = $true
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
