#Requires -Version 7.6
<#
.SYNOPSIS
    Breaks a file on purpose, one mutant at a time, and reports whether the tests notice (owner, 2026-11-10).

.DESCRIPTION
    Each mutant replaces one exact piece of text in -Path. The tests in -TestPath then run in a fresh pwsh
    -NoProfile process, and the file is restored byte for byte before the next mutant. A mutant the tests fail on
    is "Killed"; one they pass with "Survived" shows behavior no test pins.

.EXAMPLE
    ./tools/Invoke-Mutant.ps1 -Path tools/Export-KitApp.ps1 -TestPath tools/tests/Export-KitApp.Tests.ps1 `
        -Mutant @{ Name = 'case-sensitive'; Find = 'OrdinalIgnoreCase'; Replace = 'Ordinal' }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $TestPath,
    [Parameter(Mandatory)] [hashtable[]] $Mutant
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Runs the Pester tests at $TestPath in a fresh process, so no state from this session leaks in, and returns
# how many ran and how many failed.
function Invoke-TestRun([string] $TestPath) {
    $command = @"
`$c = New-PesterConfiguration
`$c.Run.Path = '$($TestPath -replace "'", "''")'
`$c.Run.PassThru = `$true
`$c.Output.Verbosity = 'None'
`$r = Invoke-Pester -Configuration `$c
@{ Total = `$r.TotalCount; Failed = `$r.FailedCount } | ConvertTo-Json -Compress
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $output = & pwsh -NoProfile -NonInteractive -EncodedCommand $encoded 2>$null
    ($output | Select-Object -Last 1) | ConvertFrom-Json
}

$file = (Resolve-Path -LiteralPath $Path).Path
$tests = (Resolve-Path -LiteralPath $TestPath).Path
$original = [IO.File]::ReadAllBytes($file)
$text = [Text.UTF8Encoding]::new($false).GetString($original)

foreach ($m in $Mutant) {
    try {
        [IO.File]::WriteAllText($file, $text.Replace($m.Find, $m.Replace), [Text.UTF8Encoding]::new($false))
        $run = Invoke-TestRun -TestPath $tests
        [pscustomobject]@{
            Name   = $m.Name
            Result = if ($run.Failed -gt 0) { 'Killed' } else { 'Survived' }
            Failed = $run.Failed
            Total  = $run.Total
        }
    }
    finally {
        [IO.File]::WriteAllBytes($file, $original)
    }
}
