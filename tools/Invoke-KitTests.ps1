#Requires -Version 7.6
<#
.SYNOPSIS
    Runs the kit's Pester tests in a child pwsh process, so nothing Pester does reaches your session (ADR-0092).

.DESCRIPTION
    The one way to run the kit's script tests locally. Never run Invoke-Pester in Claude Code's PowerShell tool
    session, which keeps its variables between calls: twice, a run there left a path variable pointing into
    Pester's own module folder, and a later "restore" of a script through it overwrote a Pester file.

    Each -Path is resolved where you stand and passed to Pester literally (escaped, since Pester reads paths as
    wildcard patterns). The tests run in a new `pwsh -NoProfile -NonInteractive` process, with
    $ErrorActionPreference set to 'Stop' as in CI, from the root of the repo this script is in. Pester's own
    output is shown as it runs.

    Returns ExitCode, Returned (whether Pester returned a result), Total, Passed, Failed, Skipped, NotRun and
    Broken (blocks and files that failed outside a test), and exits with ExitCode: 0 only when Pester returned
    a result with no failed test or block and at least one test passed or failed. A run that only skipped
    tests, or whose filter matched none, proves nothing, so it exits 1.

    Run it with ./ or &, never dot-sourced: dot-sourced, it refuses, though PowerShell has already set its
    parameters ($Path, $FullNameFilter, $Output) in your session.

.PARAMETER Path
    Test files or folders. Defaults to tools/tests in this script's repo.

.PARAMETER FullNameFilter
    Pester's Filter.FullName: run only the tests whose full name (Describe, Context and It, joined by dots)
    matches one of these wildcard patterns.

.PARAMETER Output
    Pester's Output.Verbosity: None, Normal (the default), Detailed or Diagnostic.

.EXAMPLE
    ./tools/Invoke-KitTests.ps1
    Every script test.

.EXAMPLE
    ./tools/Invoke-KitTests.ps1 -Path ./tools/tests/Set-AgentMode.Tests.ps1 -Output Detailed
#>
[CmdletBinding()]
param(
    [string[]] $Path,
    [string[]] $FullNameFilter,
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')] [string] $Output = 'Normal'
)

# First, before strict mode or a preference changes the caller's session: dot-sourced, every variable below would
# land there too (ADR-0092).
if ($MyInvocation.InvocationName -eq '.') {
    throw 'Run Invoke-KitTests.ps1 with ./ or &, not dot-sourced: dot-sourced, it would leave its variables in your session.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A value for a single-quoted PowerShell string.
function ConvertTo-Literal([string] $Value) { "'" + ($Value -replace "'", "''") + "'" }

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
if (-not $Path) { $Path = @(Join-Path $repoRoot 'tools' 'tests') }

$marker = 'Invoke-KitTests result: '
# Pester reads Run.Path as a wildcard pattern, so each path is escaped: "a [1]" would otherwise run "a 1".
$paths = @($Path | ForEach-Object { ConvertTo-Literal ([WildcardPattern]::Escape((Resolve-Path -LiteralPath $_).Path)) }) -join ', '
$filters = @($FullNameFilter | Where-Object { $_ } | ForEach-Object { ConvertTo-Literal $_ }) -join ', '
$filterLine = if ($filters) { "`$c.Filter.FullName = @($filters)" }
$command = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $(ConvertTo-Literal $repoRoot)
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
