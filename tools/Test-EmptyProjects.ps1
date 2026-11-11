#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when a project in the solution holds no code of its own (ARC-009, ADR-0049).

.EXAMPLE
    ./tools/Test-EmptyProjects.ps1 -Solution dotnet-agent-kit.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EmptyProjectProblem {
    param([Parameter(Mandatory)] [string] $Solution)
}
