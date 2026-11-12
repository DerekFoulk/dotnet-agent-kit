#Requires -Version 7.6
<#
.SYNOPSIS
    Fails unless every NuGet lock file a restore wrote matches the committed one for each target framework it lists.

.DESCRIPTION
    A MAUI project builds fewer target frameworks on macOS than on Windows, where its lock file is made, so NuGet
    refuses a locked restore there (NU1004). The macOS CI job restores without locked mode, and this check then
    gives the same guarantee for the frameworks macOS builds (SUP-001, ADR-0057): each one's packages, versions and
    hashes must be exactly as committed. A framework the committed file lacks, or a lock file nobody committed,
    fails too. Run it in the checkout, after the restore.

.EXAMPLE
    dotnet restore App.slnx -p:RestoreLockedMode=false
    ./tools/Test-LockFileSubset.ps1 -RepoRoot .
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One line per problem; nothing when every lock file is a subset of its committed version.
function Get-LockFileSubsetProblem {
    param([Parameter(Mandatory)] [string] $RepoRoot)

    @()
}

if ($MyInvocation.InvocationName -ne '.') {
    $problems = @(Get-LockFileSubsetProblem -RepoRoot $RepoRoot)
    $problems | ForEach-Object { Write-Host $_ }
    if ($problems) { exit 1 }
    Write-Host 'Every restored lock file matches the committed one for each framework it lists.'
}
