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
[CmdletBinding()]
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
    param(
        [Parameter(Mandatory)] [ValidateSet('Auto', 'Review')] [string] $Mode,
        [Parameter(Mandatory)] [string] $RepoRoot
    )

    $path = Join-Path $RepoRoot '.claude' 'settings.local.json'
    $settings = if (Test-Path -LiteralPath $path) { Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable } else { [ordered]@{} }
    if (-not $settings.Contains('permissions')) { $settings['permissions'] = [ordered]@{} }
    $ask = @(if ($settings['permissions'].Contains('ask')) { $settings['permissions']['ask'] })
    $settings['permissions']['ask'] = @($ask + $script:ReviewAskRules)
    New-Item -ItemType Directory -Path (Split-Path -Path $path -Parent) -Force | Out-Null
    Set-Content -LiteralPath $path -Value ($settings | ConvertTo-Json -Depth 10)
}
