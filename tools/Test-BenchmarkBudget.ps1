#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when a BenchmarkDotNet benchmark is over its performance budget (GAP-012, ADR-0062).

.DESCRIPTION
    Reads every JSON report BenchmarkDotNet wrote under -Path (run it with --exporters json) and checks each benchmark
    against -Budget, a JSON object keyed by the benchmark's full name (namespace, class and method, as the report
    names it), each with a maxMeanNanoseconds and a maxAllocatedBytes. Allocations per operation are the same on
    every machine, so their budget is exact; time on a shared runner varies, so the time budget is a ceiling with room
    for that (ADR-0062). Exit code: 0 when every benchmark is within its budget, otherwise 1.

.EXAMPLE
    ./tools/Test-BenchmarkBudget.ps1 -Path BenchmarkDotNet.Artifacts/results -Budget tests/App.Benchmarks/benchmark-budget.json
#>
[CmdletBinding()]
param(
    [string] $Path,
    [string] $Budget
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BenchmarkBudgetProblem {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Budget
    )

    $budgets = Get-Content -Raw -LiteralPath $Budget | ConvertFrom-Json -AsHashtable
    $reports = @(Get-ChildItem -LiteralPath $Path -Filter '*-report-full-compressed.json' -File -Recurse)
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($report in $reports) {
        foreach ($benchmark in (Get-Content -Raw -LiteralPath $report.FullName | ConvertFrom-Json -AsHashtable)['Benchmarks']) {
            $name = [string] $benchmark['FullName']
            $null = $seen.Add($name)
            $limit = $budgets[$name]
            if ($null -eq $limit) {
                "${name}: no budget in $(Split-Path -Leaf $Budget). Add one, with maxMeanNanoseconds and maxAllocatedBytes."
                continue
            }
            if ($null -eq $benchmark['Statistics']) {
                "${name}: no result; the benchmark failed to run. BenchmarkDotNet's log says why."
                continue
            }
            $mean = [double] $benchmark['Statistics']['Mean']
            if ($mean -gt [double] $limit['maxMeanNanoseconds']) {
                "${name}: mean $(Format-Number $mean) ns is over its budget of $(Format-Number $limit['maxMeanNanoseconds']) ns."
            }
            $allocated = [double] $benchmark['Memory']['BytesAllocatedPerOperation']
            if ($allocated -gt [double] $limit['maxAllocatedBytes']) {
                "${name}: allocates $(Format-Number $allocated) bytes per operation, over its budget of $(Format-Number $limit['maxAllocatedBytes'])."
            }
        }
    }

    foreach ($name in ($budgets.Keys | Sort-Object -CaseSensitive)) {
        if (-not $seen.Contains($name)) {
            "${name}: has a budget, but no report has it. Was it renamed or removed? Keep $(Split-Path -Leaf $Budget) in step."
        }
    }
}

# The same text on every machine, whatever its culture: 1,000.4.
function Format-Number([double] $Value) {
    $Value.ToString('#,0.###', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Invoke-BenchmarkBudgetCheck {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Budget
    )

    $problems = @(Get-BenchmarkBudgetProblem -Path $Path -Budget $Budget)
    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) benchmark budget problem(s); see $Budget." -ForegroundColor Red
        return 1
    }

    Write-Host "Every benchmark is within its budget ($Budget)." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Path -or -not $Budget) { throw 'Give the BenchmarkDotNet results folder with -Path and the budget file with -Budget.' }
    exit (Invoke-BenchmarkBudgetCheck -Path $Path -Budget $Budget)
}
