#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when any kit rule lacks a traceable source or an enforcement entry (brief §7, checkpoint §2).

.DESCRIPTION
    Reads the YAML front matter of every docs/standards/*.md file. Each rule needs id, statement, layer,
    status, sources and enforcement. Each source is "owner, YYYY-MM-DD", "ADR-NNNN" (an existing file in
    docs/adr) or "<URL>, retrieved YYYY-MM-DD". Enforcement "advisory" needs a reason. Ids are unique.
    Exit code: 0 when every rule is traceable, otherwise 1.

.EXAMPLE
    ./tools/Test-RuleSources.ps1
#>
[CmdletBinding()]
param(
    [string] $StandardsPath,
    [string] $AdrPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Not '#Requires -Modules': in PowerShell 7.6.9, a module loaded that way turns the script's 'exit 1' into 0
# when run with -File, which would make this check pass in CI no matter what it finds.
Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'
Import-Module -Name (Join-Path $PSScriptRoot 'KitFrontMatter.psm1') -Force

$script:RequiredFields = 'id', 'statement', 'layer', 'status', 'sources', 'enforcement'
$script:AllowedValues = [ordered]@{
    layer  = 'floor', 'owner', 'outside'
    status = 'proposed', 'accepted', 'retired'
}

function New-Problem {
    param([string] $File, [string] $RuleId, [string] $Message)
    [pscustomobject]@{ File = $File; RuleId = $RuleId; Message = $Message }
}

function Get-RuleSourceProblem {
    param(
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    $seen = @{}
    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File | Sort-Object Name) {
        $frontMatter = Read-FrontMatter -Path $file.FullName
        if ($null -eq $frontMatter) {
            New-Problem -File $file.Name -Message 'has no YAML front matter'
            continue
        }
        if (-not $frontMatter.Contains('rules') -or -not (Test-Present $frontMatter['rules'])) {
            New-Problem -File $file.Name -Message 'front matter has no rules'
            continue
        }

        foreach ($rule in $frontMatter['rules']) {
            $ruleId = if ($rule.Contains('id')) { "$($rule['id'])" } else { $null }
            foreach ($field in $script:RequiredFields) {
                if (-not $rule.Contains($field) -or -not (Test-Present $rule[$field])) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message "is missing '$field'"
                }
            }
            if ($ruleId) {
                if ($seen.ContainsKey($ruleId)) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message "id '$ruleId' is already used in $($seen[$ruleId])"
                }
                else {
                    $seen[$ruleId] = $file.Name
                }
            }
            foreach ($field in $script:AllowedValues.Keys) {
                if ($rule.Contains($field) -and (Test-Present $rule[$field]) -and "$($rule[$field])" -notin $script:AllowedValues[$field]) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message "$field '$($rule[$field])' must be one of: $($script:AllowedValues[$field] -join ', ')"
                }
            }
            if ($rule.Contains('enforcement') -and "$($rule['enforcement'])" -match '^advisory\b' -and "$($rule['enforcement'])" -notmatch '^advisory:\s*\S') {
                New-Problem -File $file.Name -RuleId $ruleId -Message "advisory enforcement needs a reason: 'advisory: <reason>'"
            }
            if ($rule.Contains('sources')) {
                foreach ($source in @($rule['sources'])) {
                    $message = Get-SourceProblem -Source "$source" -AdrPath $AdrPath
                    if ($message) {
                        New-Problem -File $file.Name -RuleId $ruleId -Message $message
                    }
                }
            }
        }
    }
}

# Prints every problem and returns 0 when every rule is traceable, otherwise 1.
function Invoke-RuleSourceCheck {
    param(
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    $problems = @(Get-RuleSourceProblem -StandardsPath $StandardsPath -AdrPath $AdrPath)
    foreach ($problem in $problems) {
        $where = if ($problem.RuleId) { "$($problem.File) $($problem.RuleId)" } else { $problem.File }
        Write-Host "  $where`: $($problem.Message)" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) rule problem(s) in $StandardsPath." -ForegroundColor Red
        return 1
    }

    $ruleCount = 0
    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File) {
        $ruleCount += @((Read-FrontMatter -Path $file.FullName)['rules']).Count
    }
    $noun = if ($ruleCount -eq 1) { 'rule' } else { 'rules' }
    Write-Host "$ruleCount $noun, all traceable to a source and an enforcement." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    if (-not $StandardsPath) { $StandardsPath = Join-Path $repoRoot 'docs' 'standards' }
    if (-not $AdrPath) { $AdrPath = Join-Path $repoRoot 'docs' 'adr' }
    exit (Invoke-RuleSourceCheck -StandardsPath $StandardsPath -AdrPath $AdrPath)
}
