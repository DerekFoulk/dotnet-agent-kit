#Requires -Version 7.0
<#
.SYNOPSIS
    Writes a new app repo's files, taken from the kit at one commit, into an empty folder (PR D2a, ADR-0032).

.DESCRIPTION
    The app gets the kit's build files, agent files, rules and checking scripts exactly as they are at the
    chosen commit, so an app pinned to a kit version has that version's files. The files come from a clean
    checkout of the commit (a temporary git worktree), never from the kit's working tree, so an unfinished
    local edit can't slip into an app.

    New-KitApp (PR D2b) calls this, then creates the GitHub repo.

.EXAMPLE
    ./tools/Export-KitApp.ps1 -Name Contoso.Orders -Destination ../Contoso.Orders -KitRef v0.1.0
#>
[CmdletBinding()]
param(
    [string] $Name,
    [string] $Destination,
    [string] $KitRef,
    [string] $KitRoot,
    [string] $KitVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Kit files an app gets unchanged. A trailing slash means every file under that folder.
$script:KitCopies = @(
    '.editorconfig', '.gitattributes', '.gitignore', 'global.json', 'nuget.config', 'Directory.Build.props',
    'THIRD-PARTY-NOTICES.md', 'CLAUDE.md', '.mcp.json', '.vscode/mcp.json', '.vscode/settings.json',
    '.claude/settings.json', '.claude/agents/reviewer.md', '.claude/skills/', 'docs/standards/', '.githooks/',
    '.github/pull_request_template.md', 'docs/adr/0000-template.md'
)

# Kit files an app gets at another path.
$script:KitMoves = [ordered]@{
    # The test-project settings the kit's sample uses (xUnit v3, coverage); an app's tests live in tests/.
    'sample/Directory.Build.props' = 'tests/Directory.Build.props'
}

# The checking scripts an app's agents and hook run locally, kept under .kit/tools.
$script:KitTools = @(
    'Test-ConventionalTitle.ps1', 'Test-RedGreenOrder.ps1', 'Test-AdrSections.ps1', 'Test-CoverageGate.ps1',
    'Test-DeprecatedPackages.ps1', 'KitReview.psm1', 'Initialize-DevMachine.ps1', 'Build-AgentRules.ps1',
    'KitFrontMatter.psm1'
)

# Templates the app owns from the start: the sync job never changes them.
$script:AppOwnedTemplates = @('README.md', 'App.slnx', 'docs/corrections-log.md')

# Lists what goes where: Source is a path in the kit, Target a path in the app. Owner says who changes
# the file later: Kit (the sync job replaces it), KitBlock (only the kit:begin..kit:end block is the
# kit's) or App.
function Get-KitAppFileMap {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $Commit,
        [Parameter(Mandatory)] [string] $Name
    )

    $folders = @($script:KitCopies | Where-Object { $_.EndsWith('/') })
    $inFolders = @(git -C $KitRoot ls-tree -r --name-only $Commit -- @($folders | ForEach-Object { $_.TrimEnd('/') }))
    if ($LASTEXITCODE -ne 0) { throw "git ls-tree failed for $Commit in $KitRoot." }

    foreach ($path in $script:KitCopies) {
        if ($path.EndsWith('/')) {
            foreach ($file in $inFolders | Where-Object { $_.StartsWith($path) }) {
                [pscustomobject]@{ Kind = 'Copy'; Owner = 'Kit'; Source = $file; Target = $file }
            }
        }
        else {
            [pscustomobject]@{ Kind = 'Copy'; Owner = 'Kit'; Source = $path; Target = $path }
        }
    }
    foreach ($source in $script:KitMoves.Keys) {
        [pscustomobject]@{ Kind = 'Copy'; Owner = 'Kit'; Source = $source; Target = $script:KitMoves[$source] }
    }
    foreach ($tool in $script:KitTools) {
        [pscustomobject]@{ Kind = 'Copy'; Owner = 'Kit'; Source = "tools/$tool"; Target = ".kit/tools/$tool" }
    }

    # The app's own files, rendered from templates/app. App.slnx takes the app's name.
    $templates = @(git -C $KitRoot ls-tree -r --name-only $Commit -- templates/app)
    if ($LASTEXITCODE -ne 0) { throw "git ls-tree failed for templates/app at $Commit." }
    foreach ($file in $templates) {
        $relative = $file.Substring('templates/app/'.Length)
        $owner = if ($relative -eq 'AGENTS.md') { 'KitBlock' } elseif ($relative -in $script:AppOwnedTemplates) { 'App' } else { 'Kit' }
        $target = if ($relative -eq 'App.slnx') { "$Name.slnx" } else { $relative }
        [pscustomobject]@{ Kind = 'Template'; Owner = $owner; Source = $file; Target = $target }
    }
}

# The kit AGENTS.md sections every repo shares, from "Whose rules win" up to the kit's own Commands.
function Get-KitAgentsSection {
    param([Parameter(Mandatory)] [string] $AgentsText)

    $match = [regex]::Match($AgentsText, '(?ms)^## Whose rules win\r?\n.*?(?=^## Commands\r?$)')
    if (-not $match.Success) { throw "The kit's AGENTS.md has no sections from '## Whose rules win' to '## Commands'." }
    $match.Value.TrimEnd()
}

# .kit/manifest.json: the kit version an app was made from and every file the kit manages in it, with
# its SHA-256, so the sync job (PR D3) knows what it may replace and can tell when someone edited one.
function Write-KitManifest {
    param(
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [object[]] $Map,
        [Parameter(Mandatory)] [string] $Commit,
        [Parameter(Mandatory)] [string] $KitVersion
    )

    $files = foreach ($entry in $Map | Where-Object { $_.Owner -ne 'App' } | Sort-Object Target) {
        $path = Join-Path $Destination $entry.Target
        if ($entry.Owner -eq 'KitBlock') {
            $block = [regex]::Match([IO.File]::ReadAllText($path), '(?s)<!-- kit:begin.*?<!-- kit:end -->')
            if (-not $block.Success) { throw "$($entry.Target) has no kit:begin..kit:end block." }
            $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($block.Value)))
            [ordered]@{ path = $entry.Target; block = 'kit'; sha256 = $hash.ToLowerInvariant() }
        }
        else {
            [ordered]@{ path = $entry.Target; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
        }
    }
    $manifest = [ordered]@{
        kitRepository = 'DerekFoulk/dotnet-agent-kit'
        kitVersion    = $KitVersion
        kitCommit     = $Commit
        files         = @($files)
    }
    $json = ($manifest | ConvertTo-Json -Depth 4) -replace "`r`n", "`n"
    New-Item -ItemType Directory -Force -Path (Join-Path $Destination '.kit') | Out-Null
    [IO.File]::WriteAllText((Join-Path $Destination '.kit/manifest.json'), "$json`n", [Text.UTF8Encoding]::new($false))
}

function Get-KitVersionLabel {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $Commit
    )

    if ($KitRef -match '^v\d+\.\d+\.\d+') { return $KitRef }
    $tag = (git -C $KitRoot describe --tags --exact-match $Commit 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $tag) { return $tag }
    'unreleased'
}

function Export-KitApp {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $KitRoot,
        [string] $KitVersion
    )

    $commit = (git -C $KitRoot rev-parse --verify --quiet "$KitRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "'$KitRef' isn't a commit or tag in $KitRoot." }
    if (-not $KitVersion) { $KitVersion = Get-KitVersionLabel -KitRoot $KitRoot -KitRef $KitRef -Commit $commit }

    $checkout = Join-Path ([IO.Path]::GetTempPath()) "kit-export-$([guid]::NewGuid().ToString('N'))"
    git -C $KitRoot worktree add --quiet --detach $checkout $commit
    if ($LASTEXITCODE -ne 0) { throw "Couldn't check out $commit from $KitRoot." }
    try {
        $values = @{
            Name          = $Name
            KitCommit     = $commit
            KitVersion    = $KitVersion
            KitSections   = Get-KitAgentsSection -AgentsText ([IO.File]::ReadAllText((Join-Path $checkout 'AGENTS.md')))
        }

        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        $map = @(Get-KitAppFileMap -KitRoot $KitRoot -Commit $commit -Name $Name)
        foreach ($entry in $map) {
            $source = Join-Path $checkout $entry.Source
            $target = Join-Path $Destination $entry.Target
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            if ($entry.Kind -eq 'Template') {
                $text = [regex]::Replace([IO.File]::ReadAllText($source), '\{\{([A-Za-z]+)\}\}', {
                        param($match)
                        $key = $match.Groups[1].Value
                        if (-not $values.ContainsKey($key)) { throw "Unknown placeholder {{$key}} in $($entry.Source)." }
                        $values[$key]
                    })
                [IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($false))
            }
            else {
                Copy-Item -LiteralPath $source -Destination $target
            }
        }
        Write-KitManifest -Destination $Destination -Map $map -Commit $commit -KitVersion $KitVersion
    }
    finally {
        git -C $KitRoot worktree remove --force $checkout
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $KitRoot) { $KitRoot = Split-Path -Path $PSScriptRoot -Parent }
    try {
        Export-KitApp -Name $Name -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot -KitVersion $KitVersion
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
