#Requires -Version 7.6
<#
.SYNOPSIS
    Lists the UI projects in a .slnx solution: its MAUI and desktop projects (ARC-010, ADR-0057).

.DESCRIPTION
    The coverage gate exempts UI projects, and the shared .NET CI builds them on Windows and macOS. This is the one
    place they're found, so both agree.

.EXAMPLE
    ./tools/Get-UiProject.ps1 -Solution Contoso.Orders.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-UiProject {
    param([Parameter(Mandatory)] [string] $Solution)

    @()
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution file to read, with -Solution.' }
    Get-UiProject -Solution $Solution
}
