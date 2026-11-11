#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when an app's runbook is missing a required section (OPS-004, ADR-0046).
#>
[CmdletBinding()]
param(
    [string] $Path = 'docs/runbook.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredSections = @(
    'Where it runs', 'How to deploy a release', 'How to roll back a release', 'How to check its health',
    'How to read its telemetry', 'How to restore its data', 'How to respond to an incident'
)

function New-Problem {
    param([string] $Message)
    [pscustomobject]@{ Message = $Message }
}

# Splits a runbook into its "## " sections: an ordered map of heading to body text. A "## " line inside a
# fenced code block is code, such as a shell comment, not a heading.
function Get-RunbookSection {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $sections = [ordered]@{}
    $current = $null
    $fence = $null
    foreach ($line in $Lines) {
        if ($line -match '^ {0,3}(?<marker>`{3,}|~{3,})') {
            $marker = $Matches['marker']
            if ($null -eq $fence) { $fence = $marker }
            elseif ($marker[0] -eq $fence[0] -and $marker.Length -ge $fence.Length) { $fence = $null }
        }
        elseif ($null -eq $fence -and $line -match '^## (.+?)\s*$') {
            $current = $Matches[1]
            $sections[$current] = [System.Collections.Generic.List[string]]::new()
            continue
        }
        if ($null -ne $current) { $sections[$current].Add($line) }
    }
    $result = [ordered]@{}
    foreach ($name in $sections.Keys) {
        $result[$name] = ($sections[$name] -join "`n").Trim()
    }
    $result
}

function Get-RunbookProblem {
    param([Parameter(Mandatory)] [string] $Path)

    $lines = @(Get-Content -LiteralPath $Path)
    $sections = Get-RunbookSection -Lines $lines

    foreach ($name in $script:RequiredSections) {
        if (-not $sections.Contains($name)) {
            New-Problem -Message "section '$name' is missing"
        }
        elseif (-not $sections[$name]) {
            New-Problem -Message "section '$name' is empty"
        }
    }
}
