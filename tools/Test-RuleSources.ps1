#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when any kit rule lacks a traceable source or an enforcement entry (brief §7, checkpoint §2).

.DESCRIPTION
    Reads the YAML front matter of every docs/standards/*.md file. Each rule needs id, statement, layer,
    basis, status, sources and enforcement. Each source is "owner, YYYY-MM-DD", "ADR-NNNN" (an existing file
    in docs/adr) or "<URL>, retrieved YYYY-MM-DD". Basis 'authority' needs a URL source and 'preference' an
    owner or ADR source. Enforcement is a list of parts, each with kind (gate or advisory), in (kit, app or
    both) and how (ADR-0063). Ids are unique.
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

$script:RequiredFields = 'id', 'statement', 'layer', 'basis', 'status', 'sources', 'enforcement'
$script:AllowedValues = [ordered]@{
    layer  = 'floor', 'owner', 'outside'
    basis  = 'authority', 'preference'
    status = 'proposed', 'accepted', 'retired'
}
# ADR-0063: each enforcement part is a gate (a tool fails the change) or advisory (a person or code review
# checks it), and says where it applies: in the kit, in apps, or both.
$script:PartKinds = 'gate', 'advisory'
$script:PartPlaces = 'kit', 'app'

# The problems with a rule's enforcement: it must be a list of parts, each with a known kind, at least one known
# place, and a non-empty 'how' (for an advisory part, the reason no tool checks it).
function Get-EnforcementProblem {
    param([Parameter(Mandatory)] [AllowNull()] [object] $Enforcement)

    # A dictionary is enumerable too, so a single part written without its list must be caught first.
    if ($Enforcement -is [string] -or $Enforcement -is [System.Collections.IDictionary] -or
        $Enforcement -isnot [System.Collections.IEnumerable]) {
        return "enforcement must be a list of parts, each with kind, in and how (ADR-0063)"
    }
    foreach ($part in @($Enforcement)) {
        if ($part -isnot [System.Collections.IDictionary]) {
            "enforcement part '$part' must have kind, in and how"
            continue
        }
        if (-not $part.Contains('kind') -or -not (Test-Present $part['kind'])) {
            "an enforcement part has no kind"
        }
        elseif ("$($part['kind'])" -notin $script:PartKinds) {
            "enforcement part kind '$($part['kind'])' must be one of: $($script:PartKinds -join ', ')"
        }
        $places = @()
        if ($part.Contains('in') -and $part['in'] -is [string]) {
            "enforcement part in '$($part['in'])' must be a list, such as [kit] or [kit, app]"
        }
        else {
            if ($part.Contains('in')) { $places = @($part['in'] | Where-Object { Test-Present $_ }) }
            if (-not $places) { "an enforcement part has no 'in' (kit, app or both)" }
        }
        foreach ($place in $places) {
            if ("$place" -notin $script:PartPlaces) {
                "enforcement part in '$place' must be one of: $($script:PartPlaces -join ', ')"
            }
        }
        if (-not $part.Contains('how') -or "$($part['how'])" -notmatch '\S') {
            "an enforcement part has no 'how'"
        }
    }
}

# ADR-0063: an authority's rule cites the authority by URL; a preference cites the owner or the ADR he accepted.
function Get-BasisProblem {
    param([string] $Basis, [object[]] $Sources)

    $sources = @($Sources | ForEach-Object { "$_" })
    if ($Basis -eq 'authority' -and -not ($sources -match '^https?://')) {
        return "basis 'authority' needs a URL source for the authority"
    }
    if ($Basis -eq 'preference' -and -not ($sources -match '^(owner, |ADR-\d{4}$)')) {
        return "basis 'preference' needs an 'owner, YYYY-MM-DD' or ADR source"
    }
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
            if ($rule.Contains('enforcement') -and (Test-Present $rule['enforcement'])) {
                foreach ($message in @(Get-EnforcementProblem -Enforcement $rule['enforcement'])) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message $message
                }
            }
            # Only sources that are valid count toward the basis; a rule with none already has a problem above.
            $validSources = @(@($(if ($rule.Contains('sources')) { $rule['sources'] })) | Where-Object {
                    (Test-Present $_) -and -not (Get-SourceProblem -Source "$_" -AdrPath $AdrPath)
                })
            if ($rule.Contains('basis') -and $validSources -and "$($rule['basis'])" -in $script:AllowedValues['basis']) {
                $message = Get-BasisProblem -Basis "$($rule['basis'])" -Sources $validSources
                if ($message) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message $message
                }
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
