#Requires -Version 7.6
<#
.SYNOPSIS
    Brings a newer kit release into an existing app's files (PR D3, ADR-0044).

.DESCRIPTION
    Reads the app's .kit/manifest.json and updates every kit-managed file, and the kit blocks of AGENTS.md and
    THIRD-PARTY-NOTICES.md, to a kit release. Files the app owns are left alone, with one exception: a package
    the release adds is added to the app's Directory.Packages.props, if the app lacks it (Add-KitPackage).

    The release is -KitRef, a release tag, or, without it, the release the app's workflows pin the kit to:
    Dependabot moves that pin, and a release tag must point to it (ADR-0031). The app is exported at its kit
    version and at the release, each with that version's own Export-KitApp, so every file comes out as that
    version makes it (.claude/settings.json included, ADR-0032). A file the app edited is merged three ways with
    the kit's change; overlapping changes keep the app's text. Workflow files are never written: a workflow's
    own token can't push them. ADR-0044 has the full rule; -ReportPath gets the pull request's report of every
    file that needs a look. When the app is already at the release, nothing changes and no report is written.

    kit-sync.reusable.yml runs it on Dependabot's kit-pin PR in an app. -KitRoot is a clone of the kit with its
    release tags; the script itself must come from the release, as the workflow's does.

.EXAMPLE
    ./tools/Sync-KitApp.ps1 -AppRoot ../Contoso.Orders -KitRoot . -ReportPath ../sync-report.md

.EXAMPLE
    ./tools/Sync-KitApp.ps1 -AppRoot ../Contoso.Orders -KitRoot . -KitRef v0.2.0
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

# What the sync does with one kit-managed path (ADR-0044), from the manifest entries at the app's version (Old) and
# at the release (Theirs), and the hash of the app's text ($null when the app has no such file or block):
#   Added, Updated, Removed, Regenerated: the app gets the release's text, or loses the file.
#   Merge: the app edited it and the kit changed it, so the two are merged (Merged, or Conflict if they overlap).
#   AppFileKept, KeptDeleted, NowAppOwned: the app's choice stands, and the PR says so.
#   None: nothing to do or say.
function Get-KitSyncAction {
    param(
        [Collections.IDictionary] $Old,
        [Collections.IDictionary] $Theirs,
        [AllowNull()] [string] $OursHash,
        [bool] $Generated
    )

    if (-not $Old) {
        if (-not $OursHash) { return 'Added' }
        # The kit now has a file where the app made its own: the app's stays, unless it's the kit's already.
        return ($OursHash -eq $Theirs['sha256'] ? 'None' : 'AppFileKept')
    }
    # The app deleted a kit file (or its kit block): it isn't brought back. A generated file is, since the
    # rebuild writes every one.
    if (-not $OursHash) {
        if (-not $Theirs) { return 'None' }
        return ($Generated ? 'Added' : 'KeptDeleted')
    }
    $edited = $OursHash -ne $Old['sha256']
    if (-not $Theirs) {
        # A generated file the kit no longer makes goes, edited or not: the app's Build-AgentRules removes it anyway.
        if ($Generated) { return 'Removed' }
        # A kit block is part of an app's file, so the file stays. Otherwise an edited copy stays, as the app's.
        return ($edited -or $Old.Contains('block') ? 'NowAppOwned' : 'Removed')
    }
    if ($OursHash -eq $Theirs['sha256']) { return 'None' }
    if (-not $edited) { return 'Updated' }
    # Generated from the standards: an edit there is lost at the next build anyway, so it's replaced.
    if ($Generated) { return 'Regenerated' }
    # The kit didn't change it: the app's edit stays, with nothing to merge or report.
    if ($Old['sha256'] -eq $Theirs['sha256']) { return 'None' }
    'Merge'
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

# A workflow's text without its kit pins (the commit SHA and any comment after it: a version, or 'unreleased'),
# which Dependabot moves: what's left is what a person would have to change.
function Remove-KitPin {
    param(
        [AllowNull()] [string] $Text,
        [Parameter(Mandatory)] [string] $Repository
    )

    $Text -replace "(uses:\s*$([regex]::Escape($Repository))/\S*@)[0-9a-f]{40}(?:[ \t]*#[^\r\n]*)?", '${1}' -replace "`r`n", "`n"
}

# The PackageVersion and GlobalPackageReference items of a Directory.Packages.props, keyed by kind and package,
# in any XML namespace (an older file may declare MSBuild's).
function Get-KitPackageItem {
    param([Parameter(Mandatory)] [string] $Path)

    $items = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $items }
    $xml = [xml] [IO.File]::ReadAllText($Path)
    foreach ($node in $xml.SelectNodes("//*[local-name()='PackageVersion' or local-name()='GlobalPackageReference']")) {
        $items["$($node.LocalName)|$($node.GetAttribute('Include'))".ToLowerInvariant()] = $node
    }
    $items
}

# Directory.Packages.props is the app's, but a kit file can need a package (an analyzer for BannedSymbols.txt,
# say). Adds each item the release's export adds, compared with the base, that the app's file lacks, in an
# ItemGroup of its own. A package the app removed, or a version it changed, stays as the app has it. A package
# the app has in the other form (PackageVersion or GlobalPackageReference) isn't added, since NuGet rejects one
# listed both ways. Returns the items added and those left out, as the release writes them.
function Add-KitPackage {
    param(
        [Parameter(Mandatory)] [string] $AppRoot,
        [Parameter(Mandatory)] [string] $BaseRoot,
        [Parameter(Mandatory)] [string] $NewRoot
    )

    $path = Join-Path $AppRoot 'Directory.Packages.props'
    $result = [pscustomobject]@{ Added = @(); Skipped = @() }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $result }
    $base = Get-KitPackageItem -Path (Join-Path $BaseRoot 'Directory.Packages.props')
    $theirs = Get-KitPackageItem -Path (Join-Path $NewRoot 'Directory.Packages.props')
    # The app's packages by name alone: in either form, the app has it.
    $ours = @{}
    foreach ($node in (Get-KitPackageItem -Path $path).Values) { $ours[$node.GetAttribute('Include').ToLowerInvariant()] = $node.LocalName }
    # The base's packages by name alone: one the app lacks, in either form, is one the app removed.
    $baseNames = @{}
    foreach ($node in $base.Values) { $baseNames[$node.GetAttribute('Include').ToLowerInvariant()] = $true }
    foreach ($key in $theirs.Keys) {
        if ($base.Contains($key)) { continue }
        $node = $theirs[$key]
        $name = $node.GetAttribute('Include').ToLowerInvariant()
        $form = $ours[$name]
        if ($form) {
            if ($form -cne $node.LocalName) { $result.Skipped += $node.OuterXml }
        }
        elseif (-not $baseNames.Contains($name)) { $result.Added += $node.OuterXml }
    }
    $added = $result.Added
    if (-not $added) { return $result }

    $text = [IO.File]::ReadAllText($path)
    $eol = $text.Contains("`r`n") ? "`r`n" : "`n"
    $lines = ($added | ForEach-Object { "    $_" }) -join $eol
    # The app's group, however its start tag is written: another attribute, or single quotes.
    $group = [regex]::Match($text, '(?s)<ItemGroup\b[^>]*\bLabel\s*=\s*["'']dotnet-agent-kit["''][^>]*>.*?(?=[ \t]*</ItemGroup>)')
    $text = if ($group.Success) {
        $text.Insert($group.Index + $group.Length, "$lines$eol")
    }
    else {
        $end = $text.LastIndexOf('</Project>', [StringComparison]::Ordinal)
        if ($end -lt 0) { throw "The app's Directory.Packages.props has no </Project>." }
        $text.Insert($end, "  <!-- Added by the kit sync: packages the kit's files need (kit ADR-0044). -->$eol  <ItemGroup Label=""dotnet-agent-kit"">$eol$lines$eol  </ItemGroup>$eol$eol")
    }
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
    $result
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

# The release the app's workflows pin the kit to: Dependabot moves that pin (ADR-0044). Every kit pin must name
# the same commit, and a release tag must point to it, or it isn't trusted (ADR-0031).
function Get-KitPinnedRelease {
    param(
        [Parameter(Mandatory)] [string] $AppRoot,
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $Repository
    )

    $pattern = "(?m)^\s*(?:-\s*)?uses:\s*$([regex]::Escape($Repository))/\S*@(?<sha>[0-9a-f]{40})\b"
    $pins = @(Get-ChildItem -LiteralPath (Join-Path $AppRoot '.github/workflows') -File -Include '*.yml', '*.yaml' -ErrorAction SilentlyContinue |
            ForEach-Object { [regex]::Matches([IO.File]::ReadAllText($_.FullName), $pattern) } |
            ForEach-Object { $_.Groups['sha'].Value } | Sort-Object -Unique)
    if ($pins.Count -eq 0) { throw "The app's workflows pin $Repository to no full commit SHA." }
    if ($pins.Count -gt 1) { throw "The app's workflows pin $Repository to different commits, which disagree: $($pins -join ', ')." }
    $releases = @(git -C $KitRoot tag --points-at $pins[0] 2>$null | Where-Object { $_ -cmatch '^v\d+\.\d+\.\d+$' })
    if (-not $releases) { throw "The app's workflows pin $Repository to $($pins[0]), but no release tag points to it, so it isn't trusted (ADR-0031)." }
    $releases | Sort-Object { [version] $_.Substring(1) } | Select-Object -Last 1
}

function Sync-KitApp {
    param(
        [Parameter(Mandatory)] [string] $AppRoot,
        [Parameter(Mandatory)] [string] $KitRoot,
        # A release tag. Without it, the release the app's workflows pin the kit to.
        [string] $KitRef
    )

    $AppRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($AppRoot)
    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)
    $manifest = Read-KitManifest -AppRoot $AppRoot
    if (-not $KitRef) {
        $KitRef = Get-KitPinnedRelease -AppRoot $AppRoot -KitRoot $KitRoot -Repository ($manifest['kitRepository'] ?? 'DerekFoulk/dotnet-agent-kit')
    }
    $toCommit = Get-KitReleaseCommit -KitRoot $KitRoot -KitRef $KitRef
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
        Repository  = $manifest['kitRepository'] ?? 'DerekFoulk/dotnet-agent-kit'
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
            $oursHash = if ($null -ne $ours) { & $script:TextHash -Text $ours }
            $action = Get-KitSyncAction -Old $old -Theirs $theirs -OursHash $oursHash -Generated (Test-KitGeneratedPath -Path $path)
            # A workflow's own token can't push a change under .github/workflows, so the sync never makes one:
            # Dependabot moves the kit pin there, and anything else is listed for a person (ADR-0045).
            if ($path.StartsWith('.github/workflows/', [StringComparison]::Ordinal) -and $action -in 'Added', 'Updated', 'Removed', 'Regenerated', 'Merge') {
                $pinOnly = $old -and $theirs -and
                    (Remove-KitPin -Text (Get-KitEntryText -Root $baseRoot -Entry $old) -Repository $result.Repository) -ceq
                    (Remove-KitPin -Text (Get-KitEntryText -Root $newRoot -Entry $theirs) -Repository $result.Repository)
                $action = $pinOnly ? 'None' : 'WorkflowByHand'
            }
            switch ($action) {
                { $_ -in 'Added', 'Updated', 'Regenerated' } { Copy-KitEntry -From $newRoot -To $AppRoot -Entry $theirs }
                'Removed' { Remove-Item -LiteralPath (Join-Path $AppRoot $path) }
                'Merge' {
                    # The base must be exactly the text the manifest recorded; anything else could merge in changes
                    # nobody made.
                    $base = Get-KitEntryText -Root $baseRoot -Entry $old
                    $merged = if ($null -ne $base -and (& $script:TextHash -Text $base) -eq $old['sha256']) {
                        Merge-KitText -Work $work -Ours $ours -Base $base -Theirs (Get-KitEntryText -Root $newRoot -Entry $theirs)
                    }
                    # Overlapping changes leave the app's text, and the PR says so: conflict markers in a file would
                    # only break the build or hide in a doc.
                    $action = if ($null -eq $merged) { 'Conflict' } else { 'Merged' }
                    if ($null -ne $merged) { Set-KitEntryText -Root $AppRoot -Entry $theirs -Text $merged }
                }
            }
            if ($action -ne 'None') { [pscustomobject]@{ Path = $path; Action = $action; Detail = $null } }
        }
        $packages = Add-KitPackage -AppRoot $AppRoot -BaseRoot $baseRoot -NewRoot $newRoot
        if ($packages.Added) {
            $files = @($files) + [pscustomobject]@{ Path = 'Directory.Packages.props'; Action = 'PackagesAdded'; Detail = ($packages.Added | ForEach-Object { "``$_``" }) -join ', ' }
        }
        if ($packages.Skipped) {
            $files = @($files) + [pscustomobject]@{ Path = 'Directory.Packages.props'; Action = 'PackageNotAdded'; Detail = ($packages.Skipped | ForEach-Object { "``$_``" }) -join ', ' }
        }
        # Build-AgentRules rebuilds every generated file: the rule files, and copilot-instructions.md, which copies
        # the app's AGENTS.md with its new kit block. It's this script's own copy, from the same kit version as the
        # app's .kit/tools now has, so the sync runs no code from the app's repo.
        $builder = Join-Path $PSScriptRoot 'Build-AgentRules.ps1'
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

# What each reported file needs from the person reviewing the PR: what happened, then what to do.
$script:Explanations = [ordered]@{
    Merged      = "This app had edited it; the kit's change merged into the edit without overlapping it.", 'Check the merged text.'
    Conflict    = "This app had edited it, and the kit's change overlaps the edit (or the kit's earlier text couldn't be rebuilt to merge with), so the app's text is kept and the kit's change isn't in this PR.", "Bring the kit's change in by hand on this branch, keeping the app's edit, or move the edit out of the kit's file."
    KeptDeleted = 'This app had deleted it, so it stays deleted, though the kit changed it.', 'Restore it if the change matters here.'
    NowAppOwned = "The kit no longer manages it, but this app had edited it (or it's a kit block in this app's file), so it stays, as this app's own.", 'Keep it or delete it.'
    AppFileKept = 'The kit now has a file at this path, but this app already had its own, which stays.', "Rename the app's file and take the kit's, or keep the app's."
    WorkflowByHand = "The release adds, changes or removes this workflow beyond the kit pin Dependabot moves. A workflow's own token can't write workflow files, so this PR doesn't.", "Apply the kit's change on this branch: compare with templates/app/.github/workflows in the kit at this release, with this app's name for {{Name}}."
    PackagesAdded = "The release adds packages the kit's files need, which this app's file lacked, so the sync added them in an ItemGroup labelled ``dotnet-agent-kit``:", 'Run `dotnet restore --force-evaluate` on this branch and commit the lock files: the sync doesn''t restore.'
    PackageNotAdded = "The release adds packages the kit's files need, but this app has them in the other form (PackageVersion or GlobalPackageReference), and NuGet rejects one listed both ways, so they weren't added:", 'Keep one entry per package: a GlobalPackageReference if every project needs it, or a PackageVersion with a PackageReference in each project that does.'
    Regenerated = "This app had edited a generated rule file, which is rebuilt from docs/standards, so the edit is gone.", "Put the change in an app-owned file, or propose it to the kit."
}

# The pull request's description: the versions, the files that need a look, then everything else it changed.
function Format-KitSyncReport {
    param([Parameter(Mandatory)] [pscustomobject] $Result)

    $kit = "https://github.com/$($Result.Repository)"
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("Brings dotnet-agent-kit $($Result.ToVersion) (commit ``$($Result.ToCommit)``) into this app, from $($Result.FromVersion) (commit ``$($Result.FromCommit)``). The kit's sync job made it from ``.kit/manifest.json`` (kit ADR-0044): it updates the files the kit manages and the kit blocks of ``AGENTS.md`` and ``THIRD-PARTY-NOTICES.md``. Of this app's own files, it changes only ``Directory.Packages.props``, and only to add a package the kit's files need.")
    $lines.Add('')
    $lines.Add("Release notes: $kit/releases/tag/$($Result.ToVersion). The kit's files at this release: $kit/tree/$($Result.ToCommit).")

    $look = @($Result.Files | Where-Object { $script:Explanations.Contains($_.Action) })
    if ($look) {
        $lines.Add('')
        $lines.Add('## Needs a look')
        $lines.Add('')
        $lines.Add('| File | What happened | What to do |')
        $lines.Add('|---|---|---|')
        foreach ($file in $look) {
            $what, $todo = $script:Explanations[$file.Action]
            if ($file.Detail) { $what = "$what $($file.Detail)." }
            $lines.Add("| ``$($file.Path)`` | $what | $todo |")
        }
    }

    $lines.Add('')
    $lines.Add('## Updated')
    $lines.Add('')
    foreach ($action in 'Updated', 'Added', 'Removed') {
        $files = @($Result.Files | Where-Object Action -EQ $action)
        if (-not $files) { continue }
        $lines.Add("<details><summary>$action ($($files.Count))</summary>")
        $lines.Add('')
        foreach ($file in $files) { $lines.Add("- ``$($file.Path)``") }
        $lines.Add('')
        $lines.Add('</details>')
        $lines.Add('')
    }
    $lines.Add('`.kit/manifest.json` records the new version, and the generated agent files are rebuilt.')

    $lines.Add('')
    $lines.Add('## Before merging')
    $lines.Add('')
    $lines.Add("- The kit pin in this app's workflows moves to ``$($Result.ToCommit)``. Trust it only if the release tag points to it (kit ADR-0031): ``gh api repos/$($Result.Repository)/commits/$($Result.ToVersion) --jq .sha`` must print that SHA.")
    $lines.Add("- A change to this app's guardrails (AGENTS.md, ""Working modes"") is the owner's to merge.")
    ($lines -join "`n") + "`n"
}

# The app's .kit/manifest.json, checked for what the sync needs.
function Read-KitManifest {
    param([Parameter(Mandatory)] [string] $AppRoot)

    $path = Join-Path $AppRoot '.kit/manifest.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$AppRoot has no .kit/manifest.json, so it wasn't made from the kit." }
    $manifest = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable
    foreach ($key in 'kitVersion', 'kitCommit', 'appName', 'files') {
        if ($manifest -isnot [Collections.IDictionary] -or -not $manifest[$key]) {
            throw "The app's .kit/manifest.json has no ""$key"". An app made before the sync job (ADR-0044) needs ""appName"", its solution's name, added by hand."
        }
    }
    # A full SHA, never a branch or tag name, which could point somewhere else by now.
    if ($manifest['kitCommit'] -cnotmatch '^[0-9a-f]{40}$') { throw "The app's .kit/manifest.json names '$($manifest['kitCommit'])', not a full kit commit SHA." }
    # Its paths decide what the sync deletes, so each must stay inside the app: relative, with forward slashes,
    # and no '.', '..' or empty segment.
    foreach ($entry in $manifest['files']) {
        $path = "$($entry['path'])"
        if ($path -match '[\\:]' -or @($path -split '/' | Where-Object { $_ -in '', '.', '..' }).Count -gt 0) {
            throw "The app's .kit/manifest.json lists '$path', which is not a path inside the app."
        }
    }
    $manifest
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Sync-KitApp -AppRoot $AppRoot -KitRoot $KitRoot -KitRef $KitRef
        if ($result.Changed) {
            Write-Host "Synced the app to dotnet-agent-kit $($result.ToVersion); $(@($result.Files).Count) file(s) changed or need a look."
            if ($ReportPath) { [IO.File]::WriteAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath), (Format-KitSyncReport -Result $result), [Text.UTF8Encoding]::new($false)) }
        }
        else {
            Write-Host "The app is already at dotnet-agent-kit $($result.ToVersion)."
        }
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
