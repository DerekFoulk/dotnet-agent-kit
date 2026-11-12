#Requires -Version 7.6
<#
.SYNOPSIS
    Writes the number of projects in a .slnx solution, read through KitSolution.psm1.

.DESCRIPTION
    The shared .NET CI and mutation workflows skip their .NET steps while a new app's solution is still empty: an empty
    solution only warns "no project to restore", which would fail the zero-warnings gate, and there's nothing to
    mutate. This is the one place that count is made, so both workflows agree on it.

.EXAMPLE
    ./tools/Get-SolutionProjectCount.ps1 -Solution Contoso.Orders.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'KitSolution.psm1') -Force

function Get-SolutionProjectCount {
    param([Parameter(Mandatory)] [string] $Solution)

    @(Get-SolutionProject -Solution $Solution).Count
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to count, with -Solution.' }
    Get-SolutionProjectCount -Solution $Solution
}
