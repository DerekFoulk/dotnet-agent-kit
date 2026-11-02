#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a branch's TDD commits are out of order: every red must be made green, and every green
    must follow a red (TST-001, GIT-005, ADR-0006, ADR-0018).
#>
[CmdletBinding()]
param(
    [string] $RepoPath = '.',
    [string] $Range
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RedGreenProblem {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Commits)
    'not implemented'
}

function Get-TddCommit {
    param([Parameter(Mandatory)] [string] $RepoPath, [Parameter(Mandatory)] [string] $Range)
    @()
}

function Invoke-RedGreenCheck {
    param([object[]] $Commits, [string] $RepoPath, [string] $Range)
    -1
}
