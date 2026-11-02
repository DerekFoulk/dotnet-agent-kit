#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a project references a deprecated NuGet package (SUP-007, ADR-0016).
#>
[CmdletBinding()]
param(
    [string] $Path = '.',
    [string] $JsonFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DeprecatedPackage {
    param([Parameter(Mandatory)] [string] $Json)
    [pscustomobject]@{ Id = 'stub' }
}

function Invoke-DeprecatedPackageCheck {
    param([Parameter(Mandatory)] [string] $Json)
    -1
}
