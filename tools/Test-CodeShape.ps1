#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when C# code breaks a CRF-008 limit that no analyzer checks: nesting, statements per member, file length
    or LCOM4 (ADR-0050).
#>
[CmdletBinding()]
param(
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CodeShapeProject {
    param([Parameter(Mandatory)] [string] $Solution)
    @()
}

function Invoke-CodeShapeCheck {
    param([Parameter(Mandatory)] [string] $Solution, [Parameter(Mandatory)] [string] $KitRoot)
    [pscustomobject]@{ ExitCode = 2; Output = '' }
}
