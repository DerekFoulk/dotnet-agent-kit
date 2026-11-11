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

function Get-RunbookSection {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)
    [ordered]@{}
}

function Get-RunbookProblem {
    param([Parameter(Mandatory)] [string] $Path)
}
