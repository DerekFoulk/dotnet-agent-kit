#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when Stryker.NET's mutation score can't be trusted (ADR-0039).

.DESCRIPTION
    Reads the JSON report Stryker.NET writes (mutation-report.json). When at least 10 mutants were killed and one
    test is among the killers of every one of them, that test almost certainly fails whatever is mutated: a broken
    test setup, not a strong test. Every mutant then counts as killed, and the score is falsely high. On PR 23 the API
    tests couldn't find the API under Stryker, and the run reported 100%. Exit code: 0 when the report looks sound,
    otherwise 1.

.EXAMPLE
    ./tools/Test-MutationReport.ps1 -Path StrykerOutput/reports/mutation-report.json
#>
[CmdletBinding()]
param(
    [string] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Below this, one broad test killing every mutant is believable.
$script:MinimumKilled = 10

function Get-MutationReportProblem {
    param([Parameter(Mandatory)] [string] $Path)

    $report = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable
    $names = @{}
    foreach ($testFile in @($report['testFiles'].Values)) {
        foreach ($test in @($testFile['tests'])) { $names[[string] $test['id']] = [string] $test['name'] }
    }

    $killed = @(foreach ($file in @($report['files'].Values)) {
            foreach ($mutant in @($file['mutants'])) {
                if ($mutant['status'] -eq 'Killed') { , @($mutant['killedBy'] | ForEach-Object { [string] $_ }) }
            }
        })
    if ($killed.Count -lt $script:MinimumKilled) { return }

    # The tests that killed every killed mutant.
    $common = [System.Collections.Generic.HashSet[string]]::new([string[]] $killed[0])
    foreach ($killers in $killed) { $common.IntersectWith([string[]] $killers) }

    foreach ($id in ($common | Sort-Object)) {
        $name = if ($names.ContainsKey($id)) { $names[$id] } else { $id }
        "$name killed every one of the $($killed.Count) killed mutants, so it most likely fails whatever is mutated. " +
        'The score can''t be trusted: run that test under Stryker and fix why it fails.'
    }
}

function Invoke-MutationReportCheck {
    param([Parameter(Mandatory)] [string] $Path)

    $problems = @(Get-MutationReportProblem -Path $Path)
    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) test(s) killed every mutant; the mutation score is not trustworthy." -ForegroundColor Red
        return 1
    }

    Write-Host 'The mutation report looks sound: no test killed every mutant.' -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Path) { throw 'Give the path of the mutation-report.json Stryker.NET wrote, with -Path.' }
    exit (Invoke-MutationReportCheck -Path $Path)
}
