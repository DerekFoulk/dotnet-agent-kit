#Requires -Version 7.6
<#
.SYNOPSIS
    Breaks a file on purpose, one mutant at a time, and reports whether the tests notice (owner, 2026-11-10).

.DESCRIPTION
    Each mutant replaces one exact piece of text in -Path. The tests in -TestPath then run through
    Invoke-KitTests.ps1, in a fresh pwsh -NoProfile process with $ErrorActionPreference 'Stop', from the root of
    the repo this script is in (ADR-0092), and the file is restored byte for byte before the next mutant. A mutant
    the tests fail on, or that breaks a test file's discovery or setup, is "Killed"; one they pass with "Survived"
    shows behavior no test pins. Text found zero times or more than once is "NotFound" or "Ambiguous", and nothing
    runs.

    The tests run once on the unchanged file first. If they fail there, run no tests (none passed or failed), or
    return no result, every mutant is an "Error". So is a mutant whose own run returns no result or runs no tests.
    An error's Message says why and adds what the test process printed.

    Run it in a fresh clone, never in your working copy: the file is changed in place. Run that clone's own copy
    of this script, since its tests run from the root of the repo the script is in. A Ctrl+C or an error still
    restores the file, but a killed pwsh leaves the mutant on disk; `git restore -- <path>` puts it back. Never
    put a file back by writing saved text to a path held in a session variable: the restore here reads only this
    script's own variables, and nothing runs between the save and the restore but its own functions and a child
    process.

    Run it with ./ or &, never dot-sourced: dot-sourced, it refuses, though PowerShell has already set its
    parameters ($Path, $TestPath, $Mutant) in your session.

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

# First, before strict mode or a preference changes the caller's session: dot-sourced, $file, $original and the rest
# would land there, the kind of generic variable a later hand-made "restore" can write through (ADR-0092).
if ($MyInvocation.InvocationName -eq '.') {
    throw 'Run Invoke-Mutant.ps1 with ./ or &, not dot-sourced: dot-sourced, it would leave its variables in your session.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Runs the Pester tests at $TestPath through Invoke-KitTests.ps1, the kit's one launcher (ADR-0092): a fresh pwsh
# process, so no state from this session leaks in either way. Returns whether Pester returned a result, how many
# tests there were, how many ran (passed or failed: a skipped or filtered-out test proves nothing), how many
# failed, whether a test file or block broke outside a test (a failed discovery, BeforeAll or AfterAll), and
# everything else the process printed, on stdout or stderr, which the launcher shows on the information stream,
# for the message of an error.
function Invoke-TestRun([string] $TestPath) {
    $streams = @(& (Join-Path $PSScriptRoot 'Invoke-KitTests.ps1') -Path $TestPath -Output None 6>&1)
    $run = $streams | Where-Object { $_ -isnot [Management.Automation.InformationRecord] } | Select-Object -Last 1
    $printed = @($streams | Where-Object { $_ -is [Management.Automation.InformationRecord] } |
            ForEach-Object { "$($_.MessageData)".Trim() } | Where-Object { $_ }) -join ' '
    [pscustomobject]@{
        Returned = $run.Returned; Total = $run.Total; Ran = $run.Passed + $run.Failed; Failed = $run.Failed
        Broken = $run.Broken; Printed = $printed
    }
}

# An error's reason, followed by what the test process printed, if anything.
function Format-Problem([string] $Reason, $Run) { "$Reason $($Run.Printed)".Trim() }

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
            elseif ($baseline.Failed -gt 0 -or $baseline.Broken -gt 0) { 'The tests already fail on the unchanged file.' }
            elseif ($baseline.Ran -eq 0) { Format-Problem 'The tests ran no tests on the unchanged file.' $baseline }
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
        elseif ($run.Ran -eq 0) {
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

# Every mutant has its result, whatever it is. The launcher exits 1 when a mutant fails the tests, which would
# otherwise be the caller's $LASTEXITCODE.
exit 0
