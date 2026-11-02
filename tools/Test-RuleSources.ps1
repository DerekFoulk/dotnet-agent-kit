#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }
<#
.SYNOPSIS
    Fails when any kit rule lacks a traceable source or an enforcement entry (brief §7, checkpoint §2).
#>
[CmdletBinding()]
param(
    [string] $StandardsPath,
    [string] $AdrPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredFields = 'id', 'statement', 'layer', 'status', 'sources', 'enforcement'
$script:AllowedValues = [ordered]@{
    layer  = 'floor', 'owner', 'outside'
    status = 'proposed', 'accepted', 'retired'
}

# Returns the YAML front matter of a Markdown file (between the opening and closing --- lines), or $null.
function Read-FrontMatter {
    param([Parameter(Mandatory)] [string] $Path)

    $lines = @(Get-Content -Path $Path)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        return $null
    }
    $end = [array]::IndexOf($lines, '---', 1)
    if ($end -lt 0) {
        return $null
    }
    ConvertFrom-Yaml -Yaml ($lines[1..($end - 1)] -join "`n")
}

function New-Problem {
    param([string] $File, [string] $RuleId, [string] $Message)
    [pscustomobject]@{ File = $File; RuleId = $RuleId; Message = $Message }
}

function Test-Present {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return -not [string]::IsNullOrWhiteSpace($Value) }
    if ($Value -is [System.Collections.ICollection]) { return $Value.Count -gt 0 }
    $true
}

function Test-IsoDate {
    param([string] $Text)
    $parsed = [datetime]::MinValue
    [datetime]::TryParseExact($Text, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, 'None', [ref] $parsed)
}

# A source is one of: "owner, YYYY-MM-DD", "ADR-NNNN" (an existing ADR file), or "<URL>, retrieved YYYY-MM-DD".
# Returns the problem message, or $null when the source is valid.
function Get-SourceProblem {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    if ($Source -match '^owner\b') {
        if ($Source -match '^owner, (\S+)$' -and (Test-IsoDate $Matches[1])) { return $null }
        return "source '$Source' must read 'owner, YYYY-MM-DD'"
    }
    if ($Source -match '^ADR-(\d{4})$') {
        if (Get-ChildItem -Path $AdrPath -Filter "$($Matches[1])-*.md" -File) { return $null }
        return "source '$Source' not found in $AdrPath"
    }
    if ($Source -match '^https?://') {
        if ($Source -match '^https?://\S+, retrieved (\S+)$' -and (Test-IsoDate $Matches[1])) { return $null }
        return "outside source '$Source' needs ', retrieved YYYY-MM-DD'"
    }
    "source '$Source' is not a recognized source (owner, ADR or URL)"
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
