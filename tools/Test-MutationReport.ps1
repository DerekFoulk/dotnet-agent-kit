#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when Stryker.NET's mutation score can't be trusted (ADR-0039).

.DESCRIPTION
    Reads the JSON report Stryker.NET writes (mutation-report.json) and checks one rule: a test may only kill a mutant
    it ran against. Stryker records the tests that reach each mutant (coveredBy) and the tests that killed it
    (killedBy). A kill by a test outside coveredBy means that test fails whatever is mutated, so the mutant was never
    really tested and the score is falsely high. On PR 23 the API tests failed to start under Stryker, coverage capture
    failed, and the run reported 100%. Static mutants (code that runs once, such as a static constructor) run against
    every test, so they're exempt. Exit code: 0 when the report passes, otherwise 1.

.EXAMPLE
    ./tools/Test-MutationReport.ps1 -Path StrykerOutput/reports/mutation-report.json
#>
[CmdletBinding()]
param(
    [string] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The items of a report field, written to the pipeline; nothing when the report leaves the field out. Callers
# collect them with @().
function Get-ReportList {
    param([System.Collections.IDictionary] $Object, [Parameter(Mandatory)] [string] $Key)

    if ($null -eq $Object -or -not $Object.Contains($Key) -or $null -eq $Object[$Key]) { return }
    $value = $Object[$Key]
    if ($value -is [System.Collections.IDictionary]) { $value.Values } else { $value }
}

function Get-MutationReportProblem {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No mutation report at '$Path': Stryker.NET stopped before writing one. Its log above says why."
    }
    $report = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable

    $names = @{}
    foreach ($testFile in (Get-ReportList $report 'testFiles')) {
        foreach ($test in (Get-ReportList $testFile 'tests')) { $names[[string] $test['id']] = [string] $test['name'] }
    }

    # For each test, the number of killed mutants it never reached.
    $unreached = [ordered]@{}
    foreach ($file in (Get-ReportList $report 'files')) {
        foreach ($mutant in (Get-ReportList $file 'mutants')) {
            if ($mutant['status'] -ne 'Killed' -or $mutant['static'] -eq $true) { continue }
            $covered = [System.Collections.Generic.HashSet[string]]::new([string[]] @(Get-ReportList $mutant 'coveredBy'))
            foreach ($killer in (Get-ReportList $mutant 'killedBy')) {
                $id = [string] $killer
                if (-not $covered.Contains($id)) { $unreached[$id] = 1 + $(if ($unreached.Contains($id)) { $unreached[$id] } else { 0 }) }
            }
        }
    }

    foreach ($id in ($unreached.Keys | Sort-Object)) {
        $name = if ($names.ContainsKey($id)) { $names[$id] } else { $id }
        "$name killed $($unreached[$id]) mutant(s) it never reached, so it fails whatever is mutated and the score " +
        'can''t be trusted. Run that test under Stryker and fix why it fails there.'
    }
}

function Invoke-MutationReportCheck {
    param([Parameter(Mandatory)] [string] $Path)

    $problems = @(Get-MutationReportProblem -Path $Path)
    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) test(s) killed mutants they never reached; the mutation score is not trustworthy." -ForegroundColor Red
        return 1
    }

    Write-Host 'The mutation report checks out: every kill came from a test that reached the mutant.' -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Path) { throw 'Give the path of the mutation-report.json Stryker.NET wrote, with -Path.' }
    exit (Invoke-MutationReportCheck -Path $Path)
}
