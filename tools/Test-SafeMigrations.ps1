#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when an EF Core migration's Up method makes a change the version of the app still running can't work
    with (DAT-003, ADR-0050).

.EXAMPLE
    ./.kit/tools/Test-SafeMigrations.ps1 -Path .
#>
[CmdletBinding()]
param(
    [string] $Path = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-MigrationProblem {
    param([Parameter(Mandatory)] [string] $Path)
}
