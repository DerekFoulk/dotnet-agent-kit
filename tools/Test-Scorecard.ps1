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

function Get-ScorecardProblem {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath
    )
}
