#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when the quality scorecard (docs/quality/scorecard.md) doesn't match the kit's rules (ADR-0034).

.DESCRIPTION
    The scorecard maps each quality area of a .NET app to the kit's rules and lists what's missing. Its YAML
    front matter holds the areas. This check fails when an area names a rule that doesn't exist, when a rule
    in force has no area, or when the table of counts in the file is out of date.
    Exit code: 0 when the scorecard is consistent, otherwise 1.

.EXAMPLE
    ./tools/Test-Scorecard.ps1
#>
[CmdletBinding()]
param(
    [string] $ScorecardPath,
    [string] $StandardsPath,
    [string] $AdrPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Not '#Requires -Modules': a module loaded that way turns the script's 'exit 1' into 0 when run with -File
# (see Test-RuleSources.ps1).
Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'
Import-Module -Name (Join-Path $PSScriptRoot 'KitFrontMatter.psm1') -Force

# What every area needs: what "perfect" means for it, and where that comes from.
$script:RequiredAreaFields = 'id', 'name', 'perfect', 'sources'

function New-Problem {
    param([string] $Area, [string] $Message)
    [pscustomobject]@{ Area = $Area; Message = $Message }
}

# Every rule in docs/standards, keyed by id: its status and whether a tool enforces it.
function Get-KitRule {
    param([Parameter(Mandatory)] [string] $StandardsPath)

    $rules = [ordered]@{}
    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File | Sort-Object Name) {
        $frontMatter = Read-FrontMatter -Path $file.FullName
        if ($null -eq $frontMatter -or -not $frontMatter.Contains('rules')) { continue }
        foreach ($rule in @($frontMatter['rules'])) {
            $rules["$($rule['id'])"] = [pscustomobject]@{
                Id       = "$($rule['id'])"
                Status   = "$($rule['status'])"
                Advisory = "$($rule['enforcement'])" -match '^advisory\b'
            }
        }
    }
    $rules
}

function Get-ScorecardProblem {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    $rules = Get-KitRule -StandardsPath $StandardsPath
    $scorecard = Read-FrontMatter -Path $ScorecardPath
    $named = @{}
    foreach ($area in @($scorecard['areas'])) {
        $areaId = "$($area['id'])"
        foreach ($field in $script:RequiredAreaFields) {
            if (-not $area.Contains($field) -or -not (Test-Present $area[$field])) {
                New-Problem -Area $areaId -Message "is missing '$field'"
            }
        }
        foreach ($source in @(if ($area.Contains('sources')) { $area['sources'] })) {
            $message = Get-SourceProblem -Source "$source" -AdrPath $AdrPath
            if ($message) { New-Problem -Area $areaId -Message $message }
        }
        foreach ($ruleId in @($area['rules'])) {
            $named["$ruleId"] = $true
            if (-not $rules.Contains("$ruleId")) {
                New-Problem -Area $areaId -Message "names rule $ruleId, which no standard in $StandardsPath has"
            }
            elseif ($rules["$ruleId"].Status -eq 'retired') {
                New-Problem -Area $areaId -Message "names rule $ruleId, which is retired"
            }
        }
    }
    foreach ($rule in $rules.Values) {
        if ($rule.Status -eq 'accepted' -and -not $named.ContainsKey($rule.Id)) {
            New-Problem -Message "rule $($rule.Id) is in force but no area names it"
        }
    }
}
