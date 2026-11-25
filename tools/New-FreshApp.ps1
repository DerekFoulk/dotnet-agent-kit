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

# The probe for each app type the job checks: the kit's own reference app of that type (ADR-0095). Name is the app's
# name; From is the kit folder whose src/ and tests/ become the app's.
$script:Probes = [ordered]@{
    'web-api' = @{ Name = 'Fresh.WebApi'; From = 'sample' }
    'blazor'  = @{ Name = 'Fresh.Blazor'; From = 'fixtures/WebUi' }
}

# App types in docs/standards/app-types.yml that have no probe yet, and why (GAP-049 stays open for them).
$script:Waiting = @{
    'maui' = "MAUI's leg needs the Windows and macOS jobs proven first (GAP-028), and the owner put MAUI after the practice run"
}

# Refuses a type with no probe, saying why.
function Assert-FreshAppType {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Type)

    if ($script:Probes.Contains($Type)) { return }
    $reason = if ($script:Waiting.ContainsKey($Type)) { ": $($script:Waiting[$Type])" } else { '' }
    throw "There's no fresh-app probe for the app type '$Type'$reason. Types with a probe: $($script:Probes.Keys -join ', ')."
}

function New-FreshApp {
    param(
        [Parameter(Mandatory)] [string] $Type,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $KitRoot
    )

    Assert-FreshAppType -Type $Type
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
