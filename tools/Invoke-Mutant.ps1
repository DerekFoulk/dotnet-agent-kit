#Requires -Version 7.6
<#
.SYNOPSIS
    Breaks a file on purpose, one mutant at a time, and reports whether the tests notice (owner, 2026-11-10).

.DESCRIPTION
    Each mutant replaces one exact piece of text in -Path. The tests in -TestPath then run in a fresh pwsh
    -NoProfile process, and the file is restored byte for byte before the next mutant. A mutant the tests fail on,
    or that breaks a test file's discovery or setup, is "Killed"; one they pass with "Survived" shows behavior no
    test pins. Text found zero times or more than once is "NotFound" or "Ambiguous", and nothing runs.

    The tests run once on the unchanged file first. If they fail there, run no tests, or return no result, every
    mutant is an "Error", whose Message says why and adds what Pester wrote to stderr.

    Run it in a fresh clone, never in your working copy: the file is changed in place. A Ctrl+C or an error still
    restores it, but a killed pwsh leaves the mutant on disk; `git checkout -- <file>` puts it back.

    -Find is matched exactly, line endings included, so a multi-line -Find must use the file's own: .ps1 files
    are checked out with CRLF everywhere, and .md files with the platform's own. The file is read as UTF-8 (a
    byte order mark is kept); a file in another encoding reports NotFound or changes the wrong bytes.

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

# Runs the Pester tests at $TestPath in a fresh process, so no state from this session leaks in. Returns whether
# Pester returned a result, how many tests ran and failed, whether a test file or block broke outside a test (a
# failed discovery, BeforeAll or AfterAll), and what Pester wrote to stderr, for the message of an error.
function Invoke-TestRun([string] $TestPath) {
    # Pester reads Run.Path as a wildcard pattern, so a folder named "x [1]" needs escaping.
    $literal = [WildcardPattern]::Escape($TestPath) -replace "'", "''"
    $command = @"
`$c = New-PesterConfiguration
`$c.Run.Path = '$literal'
`$c.Run.PassThru = `$true
`$c.Output.Verbosity = 'None'
`$r = Invoke-Pester -Configuration `$c
@{ Total = `$r.TotalCount; Failed = `$r.FailedCount; Broken = `$r.FailedContainersCount + `$r.FailedBlocksCount } | ConvertTo-Json -Compress
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $output = @(& pwsh -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1)
    $stderr = @($output | Where-Object { $_ -is [Management.Automation.ErrorRecord] }) -join [Environment]::NewLine
    $last = $output | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] } | Select-Object -Last 1
    try { $run = $last | ConvertFrom-Json } catch { $run = $null }
    if ($null -eq $run) {
        return [pscustomobject]@{ Returned = $false; Total = 0; Failed = 0; Broken = 0; Stderr = $stderr }
    }
    [pscustomobject]@{ Returned = $true; Total = $run.Total; Failed = $run.Failed; Broken = $run.Broken; Stderr = $stderr }
}

# An error's reason, followed by Pester's own words when it wrote any.
function Format-Problem([string] $Reason, $Run) { "$Reason $($Run.Stderr)".Trim() }

function New-Result([string] $Name, [string] $Result, $Run, [string] $Message) {
    [pscustomobject]@{
        Name    = $Name
        Result  = $Result
        Failed  = if ($Run) { $Run.Failed } else { 0 }
        Total   = if ($Run) { $Run.Total } else { 0 }
        Message = $Message
    }
}

$file = (Resolve-Path -LiteralPath $Path).Path
$tests = (Resolve-Path -LiteralPath $TestPath).Path
$original = [IO.File]::ReadAllBytes($file)
$text = [Text.UTF8Encoding]::new($false).GetString($original)

# Why the tests can't judge a mutant, found by running them once on the unchanged file. "Survived" claims a test is
# missing, and "Killed" claims one noticed; neither holds when the tests already fail or run nothing.
$baselineProblem = $null
$baselineDone = $false

foreach ($m in $Mutant) {
    # Exactly one match, or nothing runs: a typo would otherwise "survive", and several matches would change
    # more than one place.
    $occurrences = [regex]::Matches($text, [regex]::Escape($m.Find)).Count
    if ($occurrences -ne 1) {
        New-Result $m.Name $(if ($occurrences -eq 0) { 'NotFound' } else { 'Ambiguous' }) $null $null
        continue
    }

    if (-not $baselineDone) {
        $baseline = Invoke-TestRun -TestPath $tests
        $baselineProblem =
            if (-not $baseline.Returned) { Format-Problem 'Pester returned no result on the unchanged file.' $baseline }
            elseif ($baseline.Total -eq 0) { Format-Problem 'The tests ran no tests on the unchanged file.' $baseline }
            elseif ($baseline.Failed -gt 0 -or $baseline.Broken -gt 0) { 'The tests already fail on the unchanged file.' }
        $baselineDone = $true
    }
    if ($baselineProblem) {
        New-Result $m.Name 'Error' $null $baselineProblem
        continue
    }

    try {
        [IO.File]::WriteAllText($file, $text.Replace($m.Find, $m.Replace), [Text.UTF8Encoding]::new($false))
        $run = Invoke-TestRun -TestPath $tests
        if (-not $run.Returned) {
            New-Result $m.Name 'Error' $run (Format-Problem 'Pester returned no result with the mutant in place.' $run)
        }
        elseif ($run.Failed -gt 0 -or $run.Broken -gt 0) {
            # A mutant that breaks a test file's discovery or setup is caught as surely as one that fails a test.
            New-Result $m.Name 'Killed' $run $null
        }
        elseif ($run.Total -eq 0) {
            New-Result $m.Name 'Error' $run (Format-Problem 'No tests ran with the mutant in place.' $run)
        }
        else {
            New-Result $m.Name 'Survived' $run $null
        }
    }
    finally {
        [IO.File]::WriteAllBytes($file, $original)
    }
}
