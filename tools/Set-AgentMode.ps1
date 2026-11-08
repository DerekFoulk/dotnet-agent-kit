#Requires -Version 7.0
<#
.SYNOPSIS
    Switches how agents work in this repo: auto (the default) or review (ADR-0035).

.DESCRIPTION
    Auto: the agent plans, builds and merges its own pull requests, and asks only for the hard limits in
    AGENTS.md ("Working modes"). Review: the owner approves plans and merges each PR, as before ADR-0035.

    Review mode writes "review" to .agent-mode (gitignored), which every agent reads, and adds ask rules to the
    owner's own .claude/settings.local.json, so Claude Code asks before merging a PR, editing build or CI files,
    adding a package or editing repo settings. Claude Code merges that file's lists with .claude/settings.json,
    and an ask rule from any file wins over an allow rule. Auto mode removes both again, and leaves the rest of
    the local settings as they were.

.EXAMPLE
    ./tools/Set-AgentMode.ps1 -Mode Review
#>
# No positional arguments: a switch must say -Mode, which the ask rule in .claude/settings.json catches.
[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet('Auto', 'Review')] [string] $Mode,
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# What review mode asks before, on top of the ask rules in .claude/settings.json, which apply in both modes.
$script:ReviewAskRules = @(
    'Bash(gh pr merge *)', 'PowerShell(gh pr merge *)'
    'Bash(gh repo edit *)', 'PowerShell(gh repo edit *)'
    'Bash(dotnet add * package *)', 'PowerShell(dotnet add * package *)'
    'Edit(./**/Directory.Packages.props)', 'Edit(./**/Directory.Build.props)', 'Edit(./nuget.config)'
    'Edit(./global.json)', 'Edit(./.config/dotnet-tools.json)'
    'Edit(./.github/workflows/**)', 'Edit(./.github/dependabot.yml)'
)

function Set-AgentMode {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory)] [ValidateSet('Auto', 'Review')] [string] $Mode,
        [Parameter(Mandatory)] [string] $RepoRoot
    )

    $path = Join-Path $RepoRoot '.claude' 'settings.local.json'
    $modeFile = Join-Path $RepoRoot '.agent-mode'
    # Auto is the default and adds nothing, so with no local settings there's nothing to take away.
    # -Force: on Linux and macOS a dotfile is hidden, and Remove-Item refuses it otherwise (review 2 of PR 19).
    if ($Mode -eq 'Auto' -and -not (Test-Path -LiteralPath $path)) {
        if (Test-Path -LiteralPath $modeFile) { Remove-Item -LiteralPath $modeFile -Force }
        return
    }
    $settings = [ordered]@{}
    if (Test-Path -LiteralPath $path) {
        $text = Get-Content -Raw -LiteralPath $path
        if ($text -and $text.Trim()) {
            try { $settings = $text | ConvertFrom-Json -AsHashtable }
            catch { throw "$path isn't valid JSON, so it was left as it is and the mode wasn't changed: $($_.Exception.Message)" }
            if ($settings -isnot [Collections.IDictionary] -or
                ($settings.Contains('permissions') -and $settings['permissions'] -isnot [Collections.IDictionary])) {
                throw "$path doesn't have the shape of Claude Code settings, so it was left as it is and the mode wasn't changed."
            }
        }
    }
    if (-not $settings.Contains('permissions')) { $settings['permissions'] = [ordered]@{} }
    # The owner's own rules stay; only the review rules are added or taken away.
    $own = @(@(if ($settings['permissions'].Contains('ask')) { $settings['permissions']['ask'] }) | Where-Object { $_ -cnotin $script:ReviewAskRules })
    # A typed array, not an if-expression: PowerShell would unroll that to $null or one string, and Claude Code's
    # settings schema needs a list (review 1 of the modes PR).
    [object[]] $ask = @(if ($Mode -eq 'Review') { $own + $script:ReviewAskRules } else { $own })
    $settings['permissions']['ask'] = $ask
    # Switching to auto, the mode file goes before the prompts; switching to review, the prompts come before the
    # mode file. A failure halfway then leaves the prompts on, the safer side.
    if ($Mode -eq 'Auto' -and (Test-Path -LiteralPath $modeFile)) { Remove-Item -LiteralPath $modeFile -Force }
    New-Item -ItemType Directory -Path (Split-Path -Path $path -Parent) -Force | Out-Null
    Set-Content -LiteralPath $path -Value (ConvertTo-Json -InputObject $settings -Depth 10)
    if ($Mode -eq 'Review') { Set-Content -LiteralPath $modeFile -Value 'review' -Force }
}

# The mode agents follow: 'review' when .agent-mode says so, otherwise 'auto' (the default, ADR-0035).
function Get-AgentMode {
    param([Parameter(Mandatory)] [string] $RepoRoot)

    $modeFile = Join-Path $RepoRoot '.agent-mode'
    if ((Test-Path -LiteralPath $modeFile) -and (Get-Content -Raw -LiteralPath $modeFile).Trim() -eq 'review') { 'review' } else { 'auto' }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $RepoRoot) { $RepoRoot = (& git -C $PWD rev-parse --show-toplevel 2>$null) ?? $PWD.Path }
    try {
        if ($Mode) { Set-AgentMode -Mode $Mode -RepoRoot $RepoRoot }
        $current = Get-AgentMode -RepoRoot $RepoRoot
        $meaning = if ($current -eq 'review') { 'the owner approves plans and merges each PR' } else { 'the agent works and merges its own PRs, asking only for the hard limits' }
        Write-Host "Mode: $current ($meaning)."
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
