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

# A value for a single-quoted PowerShell string.
function ConvertTo-Literal([string] $Value) { "'" + ($Value -replace "'", "''") + "'" }

if (-not $Path) {
    [pscustomobject]@{ ExitCode = 1; Returned = $false; Total = 0; Passed = 0; Failed = 0; Skipped = 0; NotRun = 0; Broken = 0 }
    exit 1
}

$marker = 'Invoke-KitTests result: '
$paths = @($Path | ForEach-Object { ConvertTo-Literal (Resolve-Path -LiteralPath $_).Path }) -join ', '
$filters = @($FullNameFilter | Where-Object { $_ } | ForEach-Object { ConvertTo-Literal $_ }) -join ', '
$filterLine = if ($filters) { "`$c.Filter.FullName = @($filters)" }
$command = @"
`$ErrorActionPreference = 'Stop'
Import-Module -Name Pester -MinimumVersion 6.0.0
`$c = New-PesterConfiguration
`$c.Run.Path = @($paths)
`$c.Run.PassThru = `$true
`$c.Output.Verbosity = $(ConvertTo-Literal $Output)
$filterLine
`$r = Invoke-Pester -Configuration `$c
'$marker' + (ConvertTo-Json -Compress -InputObject @{
    Total = `$r.TotalCount; Passed = `$r.PassedCount; Failed = `$r.FailedCount; Skipped = `$r.SkippedCount
    NotRun = `$r.NotRunCount; Broken = `$r.FailedContainersCount + `$r.FailedBlocksCount
})
exit `$(if (`$r.Result -eq 'Passed' -and `$r.PassedCount + `$r.FailedCount -gt 0) { 0 } else { 1 })
"@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

$resultLine = $null
& pwsh -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | ForEach-Object {
    $line = "$_"
    if ($line.StartsWith($marker)) { $resultLine = $line.Substring($marker.Length) } else { Write-Host $line }
}
$exitCode = $LASTEXITCODE

$run = if ($resultLine) { $resultLine | ConvertFrom-Json }
$returned = $null -ne $run -and $null -ne $run.Total
if (-not $returned -and $exitCode -eq 0) { $exitCode = 1 }
[pscustomobject]@{
    ExitCode = $exitCode
    Returned = $returned
    Total    = if ($returned) { $run.Total } else { 0 }
    Passed   = if ($returned) { $run.Passed } else { 0 }
    Failed   = if ($returned) { $run.Failed } else { 0 }
    Skipped  = if ($returned) { $run.Skipped } else { 0 }
    NotRun   = if ($returned) { $run.NotRun } else { 0 }
    Broken   = if ($returned) { $run.Broken } else { 0 }
}
exit $exitCode
