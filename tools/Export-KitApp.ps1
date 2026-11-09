#Requires -Version 7.6
<#
.SYNOPSIS
    Writes a new app repo's files, taken from the kit at one commit, into an empty folder (PR D2a, ADR-0032).

.DESCRIPTION
    The app gets the kit's build files, agent files, rules and checking scripts exactly as they are at the
    chosen commit, so an app pinned to a kit version has that version's files, except .claude/settings.json:
    its permission rules for kit scripts the app doesn't get (./tools/New-KitApp) are left out, since they could
    never fire there. The files come from a clean
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
    'CLAUDE.md', '.mcp.json', '.vscode/mcp.json', '.vscode/settings.json',
    '.claude/agents/reviewer.md', '.claude/skills/', 'docs/standards/', '.githooks/',
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
    'KitFrontMatter.psm1', 'Set-AgentMode.ps1'
)

# Templates the app owns from the start: the sync job never changes them.
$script:AppOwnedTemplates = @('README.md', 'App.slnx', 'docs/corrections-log.md', '.github/dependabot.yml')

# Templates the app owns except for the block between kit:begin and kit:end, which is the kit's.
$script:KitBlockTemplates = @('AGENTS.md', 'THIRD-PARTY-NOTICES.md')

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

    # Claude Code's permission rules, without those for kit scripts the app doesn't get.
    [pscustomobject]@{ Kind = 'Settings'; Owner = 'Kit'; Source = '.claude/settings.json'; Target = '.claude/settings.json' }

    # Central package versions: the kit's build and test toolset, without its sample app's packages. The
    # app adds its own packages, so the app owns the file.
    [pscustomobject]@{ Kind = 'Packages'; Owner = 'App'; Source = 'Directory.Packages.props'; Target = 'Directory.Packages.props' }

    # The app's own files, rendered from templates/app. App.slnx takes the app's name.
    $templates = @(git -C $KitRoot ls-tree -r --name-only $Commit -- templates/app)
    if ($LASTEXITCODE -ne 0) { throw "git ls-tree failed for templates/app at $Commit." }
    foreach ($file in $templates) {
        $relative = $file.Substring('templates/app/'.Length)
        $owner = if ($relative -in $script:KitBlockTemplates) { 'KitBlock' } elseif ($relative -in $script:AppOwnedTemplates) { 'App' } else { 'Kit' }
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

# SHA-256 of text with LF line endings. git stores text as LF, but a checkout may give CRLF (core.autocrlf,
# .gitattributes eol=crlf), so hashing the LF form gives the same value on every machine and checkout.
function Get-KitTextHash {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)

    $lf = $Text -replace "`r`n", "`n"
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lf))).ToLowerInvariant()
}

# .kit/manifest.json: the kit version an app was made from and every file the kit manages in it, with
# its SHA-256 (of the text with LF line endings), so the sync job (PR D3) knows what it may replace and
# can tell when someone edited one.
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
            [ordered]@{ path = $entry.Target; block = 'kit'; sha256 = (Get-KitTextHash -Text $block.Value) }
        }
        else {
            [ordered]@{ path = $entry.Target; sha256 = (Get-KitTextHash -Text ([IO.File]::ReadAllText($path))) }
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

# Whether a permission rule names a kit script under tools/ that the app doesn't get, such as
# "./tools/New-KitApp*": it could never fire in the app, whose kit scripts are the KitTools in .kit/tools.
function Test-KitOnlyRule {
    param([Parameter(Mandatory)] [string] $Rule, [Parameter(Mandatory)] [string[]] $AppTools)

    foreach ($match in [regex]::Matches($Rule, '(?<![\w.])tools[/\\]([A-Za-z][\w.-]*)')) {
        $named = $match.Groups[1].Value
        if (-not ($AppTools | Where-Object { $_.StartsWith($named, [StringComparison]::OrdinalIgnoreCase) })) { return $true }
    }
    $false
}

# The kit's .claude/settings.json for an app: every permission rule but the kit-only ones. Worked out from the
# tools an app gets, so a rule for a new kit-only script is dropped without being listed anywhere.
function Get-KitAppSettingsText {
    param([Parameter(Mandatory)] [string] $SettingsText, [Parameter(Mandatory)] [string[]] $AppTools)

    $settings = $SettingsText | ConvertFrom-Json -AsHashtable
    foreach ($list in @($settings['permissions'].Keys)) {
        $settings['permissions'][$list] = @($settings['permissions'][$list] | Where-Object { -not (Test-KitOnlyRule -Rule $_ -AppTools $AppTools) })
    }
    "$(($settings | ConvertTo-Json -Depth 10) -replace "`r`n", "`n")`n"
}

# Drops the ItemGroup labelled "Sample app", with the comment line above it, from Directory.Packages.props.
function Remove-KitSamplePackage {
    param([Parameter(Mandatory)] [string] $PropsText)

    $pattern = '(?ms)(^[ \t]*<!--[^\r\n]*-->\r?\n)?^[ \t]*<ItemGroup Label="Sample app">.*?</ItemGroup>\r?\n(\r?\n)?'
    if (-not [regex]::IsMatch($PropsText, $pattern)) { throw "The kit's Directory.Packages.props has no ItemGroup labelled 'Sample app'." }
    $text = [regex]::Replace($PropsText, $pattern, '')
    [xml] $text | Out-Null # still well-formed
    $text
}

# Runs the app's own copy of Build-AgentRules, so its .claude/rules, .github/instructions and
# copilot-instructions.md exist from the first commit and pass -Check. Returns the rule files as map
# entries: they come from the kit's standards, so the kit manages them. copilot-instructions.md copies the
# app's AGENTS.md, which the app edits, so it stays out of the manifest.
function New-KitAgentRuleFile {
    param([Parameter(Mandatory)] [string] $Destination)

    $builder = Join-Path $Destination '.kit/tools/Build-AgentRules.ps1'
    $output = & pwsh -NoProfile -File $builder -RepoRoot $Destination 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Generating the app's agent rule files failed:`n$output" }

    foreach ($folder in '.claude/rules', '.github/instructions') {
        $directory = Join-Path $Destination $folder
        if (-not (Test-Path -LiteralPath $directory)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $directory -File | Sort-Object Name) {
            $target = "$folder/$($file.Name)"
            [pscustomobject]@{ Kind = 'Generated'; Owner = 'Kit'; Source = $null; Target = $target }
        }
    }
}

# The release tag that points to the commit, or 'unreleased'. Only a tag counts: a ref that merely looks
# like a release (v0.1.0~3, a branch named v1.2.3-wip) would label the app with a release it isn't, and
# ADR-0031 trusts a pin only when a release tag points to it.
function Get-KitVersionLabel {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $Commit
    )

    # Release tags (vX.Y.Z) that point at the commit itself; prefer the one the caller named.
    $releases = @(git -C $KitRoot tag --points-at $Commit 2>$null | Where-Object { $_ -cmatch '^v\d+\.\d+\.\d+$' })
    if ($KitRef -cin $releases) { return $KitRef }
    if ($releases) { return ($releases | Sort-Object { [version] $_.Substring(1) } | Select-Object -Last 1) }
    'unreleased'
}

# Refuses a name that can't be an app's solution file, folder and root namespace.
function Assert-KitAppName {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Name)

    # A dotted .NET name (Contoso.Orders): it becomes the solution's file name and the root namespace.
    if ($Name -cnotmatch '^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$') {
        throw "The app name '$Name' isn't a dotted .NET name such as Contoso.Orders: letters and digits, each part starting with a letter."
    }
    # Windows reserves device names such as Con and Nul. Current Windows 11 accepts Con.Orders.slnx, but a
    # bare Con folder fails, and older Windows and some tools refuse the name with an extension too.
    $device = @($Name.Split('.') | Where-Object { $_ -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])$' })
    if ($device) {
        throw "The app name '$Name' contains '$($device[0])', a Windows device name, which Windows and some tools refuse as a file or folder name."
    }
}

function Export-KitApp {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $KitRoot
    )

    # .NET file calls resolve a relative path against the process's directory, not PowerShell's location.
    $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)

    Assert-KitAppName -Name $Name
    if ((Test-Path -LiteralPath $Destination) -and @(Get-ChildItem -LiteralPath $Destination -Force).Count -gt 0) {
        throw "$Destination isn't empty. Export into a new or empty folder, so no existing file is overwritten."
    }

    $commit = (git -C $KitRoot rev-parse --verify --quiet "$KitRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "'$KitRef' isn't a commit or tag in $KitRoot." }
    $KitVersion = Get-KitVersionLabel -KitRoot $KitRoot -KitRef $KitRef -Commit $commit

    $checkout = Join-Path ([IO.Path]::GetTempPath()) "kit-export-$([guid]::NewGuid().ToString('N'))"
    git -C $KitRoot worktree add --quiet --detach $checkout $commit
    if ($LASTEXITCODE -ne 0) { throw "Couldn't check out $commit from $KitRoot." }
    $created = $false
    try {
        $values = @{
            Name          = $Name
            KitCommit     = $commit
            KitVersion    = $KitVersion
            KitSections   = Get-KitAgentsSection -AgentsText ([IO.File]::ReadAllText((Join-Path $checkout 'AGENTS.md')))
            # The kit's notices without their title; the template has its own.
            KitNotices    = ([IO.File]::ReadAllText((Join-Path $checkout 'THIRD-PARTY-NOTICES.md')) -replace '(?s)^# [^\r\n]*\r?\n(\r?\n)?', '').TrimEnd()
        }

        $created = -not (Test-Path -LiteralPath $Destination)
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
            elseif ($entry.Kind -eq 'Packages') {
                [IO.File]::WriteAllText($target, (Remove-KitSamplePackage -PropsText ([IO.File]::ReadAllText($source))), [Text.UTF8Encoding]::new($false))
            }
            elseif ($entry.Kind -eq 'Settings') {
                [IO.File]::WriteAllText($target, (Get-KitAppSettingsText -SettingsText ([IO.File]::ReadAllText($source)) -AppTools $script:KitTools), [Text.UTF8Encoding]::new($false))
            }
            else {
                Copy-Item -LiteralPath $source -Destination $target
            }
        }
        $map += @(New-KitAgentRuleFile -Destination $Destination)
        Write-KitManifest -Destination $Destination -Map $map -Commit $commit -KitVersion $KitVersion
    }
    catch {
        # A half-written app would block the rerun ("isn't empty"); remove only what this run made.
        if ($created -and (Test-Path -LiteralPath $Destination)) { Remove-Item -LiteralPath $Destination -Recurse -Force }
        elseif (Test-Path -LiteralPath $Destination) { Get-ChildItem -LiteralPath $Destination -Force | Remove-Item -Recurse -Force }
        throw
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
