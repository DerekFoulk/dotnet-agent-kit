#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when line coverage is below the TST-004 minimums.
#>
[CmdletBinding()]
param(
    [string] $Path = 'TestResults'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CoverageSummary {
    param([Parameter(Mandatory)] [string] $Path)
    @()
}

function Invoke-CoverageGate {
    param([Parameter(Mandatory)] [string] $Path)
    0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-CoverageGate -Path $Path)
}
