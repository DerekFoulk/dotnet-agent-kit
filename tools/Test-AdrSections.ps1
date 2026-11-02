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

function Get-AdrSectionProblem {
    param([Parameter(Mandatory)] [string] $AdrPath)
    [pscustomobject]@{ File = $null; Message = 'not implemented' }
}
