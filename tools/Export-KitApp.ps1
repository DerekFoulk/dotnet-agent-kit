#Requires -Version 7.0
<#
.SYNOPSIS
    Writes a new app repo's files, taken from the kit at one version, into an empty folder (PR D2a, ADR-0032).

.DESCRIPTION
    Not implemented yet.
#>
[CmdletBinding()]
param(
    [string] $Name,
    [string] $Destination,
    [string] $KitRef,
    [string] $KitRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-KitAppFileMap {
    @()
}

if ($MyInvocation.InvocationName -ne '.') {
    exit 0
}
