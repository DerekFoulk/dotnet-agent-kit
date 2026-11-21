#Requires -Version 7.6
<#
.SYNOPSIS
    Runs the kit's Pester tests in a child pwsh process (ADR-0092).
#>
[CmdletBinding()]
param(
    [string[]] $Path,
    [string[]] $FullNameFilter,
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')] [string] $Output = 'Normal'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[pscustomobject]@{ ExitCode = 1; Returned = $false; Total = 0; Passed = 0; Failed = 0; Skipped = 0; NotRun = 0; Broken = 0 }
exit 1
