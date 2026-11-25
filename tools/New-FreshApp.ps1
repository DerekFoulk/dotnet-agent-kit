#Requires -Version 7.6
<#
.SYNOPSIS
    Writes a fresh app of one app type from the kit at one commit, with a probe project of that type, for the kit's
    CI to check (GAP-049, ADR-0095). It creates no GitHub repo.

.DESCRIPTION
    Exports the app with Export-KitApp.ps1, as New-KitApp does, with an app profile whose answers are the intake's
    defaults and whose app type is -Type. Kit only: an app never gets this script.

.EXAMPLE
    ./tools/New-FreshApp.ps1 -Type web-api -Destination ../fresh-web-api
#>
[CmdletBinding()]
param(
    [string] $Type,
    [string] $Destination,
    [string] $KitRef = 'HEAD',
    [string] $KitRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-FreshApp {
    param(
        [Parameter(Mandatory)] [string] $Type,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $KitRoot
    )
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $KitRoot) { $KitRoot = Split-Path -Path $PSScriptRoot -Parent }
    try {
        New-FreshApp -Type $Type -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
