#Requires -Version 7.0
<#
.SYNOPSIS
    Creates an app repo on GitHub with the kit's files, settings and "main protection" ruleset (PR D2b, ADR-0033).

.DESCRIPTION
    Exports the app's files with Export-KitApp, commits them, creates the repo on your own GitHub account
    with the kit's merge settings, pushes main, then adds the ruleset. The settings and the ruleset come from
    templates/github at the same kit commit as the files.

.EXAMPLE
    ./tools/New-KitApp.ps1 -Name Contoso.Orders -KitRef v0.1.0 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Name,
    [string] $KitRef,
    [string] $Destination,
    [switch] $Public,
    [string] $KitRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The body of POST /user/repos: the app's name and visibility, plus the kit's settings (templates/github/repo.json).
function Get-KitAppRepoRequest {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $SettingsText,
        [switch] $Public
    )

    $request = [ordered]@{ name = $Name; private = -not $Public }
    foreach ($setting in ($SettingsText | ConvertFrom-Json -AsHashtable).GetEnumerator()) {
        $request[$setting.Key] = $setting.Value
    }
    $request
}
