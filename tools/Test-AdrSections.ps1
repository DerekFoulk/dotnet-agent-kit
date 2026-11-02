#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when any ADR is missing a required section (brief §5, checkpoint §3).
#>
[CmdletBinding()]
param(
    [string] $AdrPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredSections = 'Context', 'Options', 'Recommendation', 'Decision', 'Consequences', 'Pillars affected', 'Sources'

function New-Problem {
    param([string] $File, [string] $Message)
    [pscustomobject]@{ File = $File; Message = $Message }
}

# Splits an ADR into its "## " sections: an ordered map of heading to body text.
function Get-AdrSection {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $sections = [ordered]@{}
    $current = $null
    foreach ($line in $Lines) {
        if ($line -match '^## (.+?)\s*$') {
            $current = $Matches[1]
            $sections[$current] = [System.Collections.Generic.List[string]]::new()
        }
        elseif ($null -ne $current) {
            $sections[$current].Add($line)
        }
    }
    $result = [ordered]@{}
    foreach ($name in $sections.Keys) {
        $result[$name] = ($sections[$name] -join "`n").Trim()
    }
    $result
}

function Get-AdrSectionProblem {
    param([Parameter(Mandatory)] [string] $AdrPath)

    # 0000-template.md holds placeholders by design.
    $files = Get-ChildItem -Path $AdrPath -Filter '*.md' -File | Where-Object Name -NotLike '0000-*' | Sort-Object Name
    foreach ($file in $files) {
        $lines = @(Get-Content -Path $file.FullName)
        $sections = Get-AdrSection -Lines $lines

        foreach ($name in $script:RequiredSections) {
            if (-not $sections.Contains($name)) {
                New-Problem -File $file.Name -Message "section '$name' is missing"
            }
            elseif (-not $sections[$name]) {
                New-Problem -File $file.Name -Message "section '$name' is empty"
            }
        }
    }
}
