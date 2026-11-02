#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a PR title or a commit subject isn't a Conventional Commit (GIT-004, ADR-0006, ADR-0022).
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TitleProblem {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Title)
    $null
}
