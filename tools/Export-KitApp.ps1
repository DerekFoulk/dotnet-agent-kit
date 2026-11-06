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
    [string] $KitRoot
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

# Lists what goes where: Source is a path in the kit, Target a path in the app.
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
                [pscustomobject]@{ Kind = 'Copy'; Source = $file; Target = $file }
            }
        }
        else {
            [pscustomobject]@{ Kind = 'Copy'; Source = $path; Target = $path }
        }
    }
    foreach ($source in $script:KitMoves.Keys) {
        [pscustomobject]@{ Kind = 'Copy'; Source = $source; Target = $script:KitMoves[$source] }
    }
    foreach ($tool in $script:KitTools) {
        [pscustomobject]@{ Kind = 'Copy'; Source = "tools/$tool"; Target = ".kit/tools/$tool" }
    }
}

function Export-KitApp {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $KitRoot
    )

    $commit = (git -C $KitRoot rev-parse --verify --quiet "$KitRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "'$KitRef' isn't a commit or tag in $KitRoot." }

    $checkout = Join-Path ([IO.Path]::GetTempPath()) "kit-export-$([guid]::NewGuid().ToString('N'))"
    git -C $KitRoot worktree add --quiet --detach $checkout $commit
    if ($LASTEXITCODE -ne 0) { throw "Couldn't check out $commit from $KitRoot." }
    try {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        foreach ($entry in Get-KitAppFileMap -KitRoot $KitRoot -Commit $commit -Name $Name) {
            $target = Join-Path $Destination $entry.Target
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath (Join-Path $checkout $entry.Source) -Destination $target
        }
    }
    finally {
        git -C $KitRoot worktree remove --force $checkout
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $KitRoot) { $KitRoot = Split-Path -Path $PSScriptRoot -Parent }
    try {
        Export-KitApp -Name $Name -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
