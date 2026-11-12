#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when a Locust load test is over its budget (GAP-012, ADR-0062).

.DESCRIPTION
    Reads the CSV files a headless Locust run writes with --csv <prefix> (<prefix>_stats.csv and
    <prefix>_exceptions.csv) and checks them against -Budget, a JSON object keyed by "Aggregated" (the whole run) and
    by any request as Locust names it, "<Type> <Name>" (such as "GET /bookmarks"). Each entry sets maxFailureRatio (the
    share of requests that failed, 0 to 1) and maxMilliseconds (response-time percentiles, keyed as Locust's columns
    are, such as "95%"). Exit code: 0 when the run is within its budget, otherwise 1.

.EXAMPLE
    ./tools/Test-LoadBudget.ps1 -Path results/load -Budget tests/load/load-budget.json
#>
[CmdletBinding()]
param(
    [string] $Path,
    [string] $Budget
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LoadBudgetProblem {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Budget
    )

    $budgets = Get-Content -Raw -LiteralPath $Budget | ConvertFrom-Json -AsHashtable
    # A broken budget checks the wrong thing, so it's reported alone.
    $budgetProblems = @(Get-BudgetFileProblem $budgets)
    if ($budgetProblems) { return $budgetProblems }

    $statsFile = "${Path}_stats.csv"
    if (-not (Test-Path -LiteralPath $statsFile -PathType Leaf)) {
        return "No Locust stats at ${statsFile}: Locust stopped before the run. Its output above says why."
    }
    $rows = @{}
    foreach ($row in (Import-Csv -LiteralPath $statsFile)) { $rows[(Get-RequestKey $row)] = $row }

    # The whole run first, then each request, so the output reads the same every time.
    $keys = @('Aggregated') + @($budgets.Keys | Where-Object { $_ -cne 'Aggregated' } | Sort-Object -CaseSensitive)
    foreach ($key in $keys) {
        $limit = $budgets[$key]
        $row = $rows[$key]
        if ($null -eq $row) {
            "${key}: has a budget, but the stats have no such request. Locust names a request '<Type> <Name>'; was it renamed?"
            continue
        }
        $requests = [long] $row.'Request Count'
        if ($requests -eq 0) {
            "${key}: no requests were made, so there is nothing to check. Is the app up, and does the locustfile run?"
            continue
        }
        if ($limit.Contains('maxFailureRatio')) {
            $failures = [long] $row.'Failure Count'
            $max = [double] $limit['maxFailureRatio']
            if ($failures -gt $requests * $max) {
                "${key}: $failures of $requests requests failed ($(Format-Number (100.0 * $failures / $requests))%), over its budget of $(Format-Number (100 * $max))%."
            }
        }
        if (-not $limit.Contains('maxMilliseconds')) { continue }
        foreach ($percentile in $limit['maxMilliseconds'].Keys) {
            $time = [double] $row.$percentile
            $max = [double] $limit['maxMilliseconds'][$percentile]
            if ($time -gt $max) {
                "${key}: $percentile of requests took up to $(Format-Number $time) ms, over its budget of $(Format-Number $max) ms."
            }
        }
    }

    $exceptions = "${Path}_exceptions.csv"
    if (Test-Path -LiteralPath $exceptions -PathType Leaf) {
        foreach ($exception in (Import-Csv -LiteralPath $exceptions)) {
            "The locustfile raised $($exception.Message) $($exception.Count) time(s); see the exceptions CSV for its traceback."
        }
    }
}

# Locust's percentile columns (locust/stats.py, PERCENTILES_TO_REPORT, as of 2.47.0).
$script:Percentiles = @('50%', '66%', '75%', '80%', '90%', '95%', '98%', '99%', '99.9%', '99.99%', '100%')

function Test-Number([object] $Value) {
    $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]
}

# What's wrong with the budget file itself: keys it doesn't know, limits out of range, no failure budget for the run.
function Get-BudgetFileProblem([System.Collections.IDictionary] $Budgets) {
    $aggregated = $Budgets['Aggregated']
    if ($aggregated -isnot [System.Collections.IDictionary] -or -not $aggregated.Contains('maxFailureRatio')) {
        'The budget has no "Aggregated" entry with a maxFailureRatio: the whole run''s failures are always budgeted.'
    }
    foreach ($key in ($Budgets.Keys | Sort-Object -CaseSensitive)) {
        $limit = $Budgets[$key]
        if ($limit -isnot [System.Collections.IDictionary] -or $limit.Count -eq 0) {
            "${key}: give it a maxFailureRatio, a maxMilliseconds, or both."
            continue
        }
        foreach ($name in ($limit.Keys | Where-Object { $_ -cnotin 'maxFailureRatio', 'maxMilliseconds' })) {
            "${key}: unknown budget key ""$name""; use maxFailureRatio and maxMilliseconds."
        }
        if ($limit.Contains('maxFailureRatio')) {
            $ratio = $limit['maxFailureRatio']
            if (-not (Test-Number $ratio) -or $ratio -lt 0 -or $ratio -gt 1) {
                "${key}: maxFailureRatio must be a number from 0 to 1, such as 0.01 for 1%."
            }
        }
        if ($limit.Contains('maxMilliseconds')) {
            $times = $limit['maxMilliseconds']
            if ($times -isnot [System.Collections.IDictionary] -or $times.Count -eq 0) {
                "${key}: maxMilliseconds maps percentiles to milliseconds, such as { ""95%"": 300 }."
                continue
            }
            foreach ($percentile in $times.Keys) {
                if ($percentile -cnotin $script:Percentiles) {
                    "${key}: Locust reports no ""$percentile"" percentile; use one of $($script:Percentiles -join ', ')."
                }
                elseif (-not (Test-Number $times[$percentile]) -or $times[$percentile] -lt 0) {
                    "${key}: the $percentile budget must be a number of milliseconds, 0 or more."
                }
            }
        }
    }
}

# The name a budget gives a stats row: "Aggregated" for the whole run, "<Type> <Name>" for a request.
function Get-RequestKey([object] $Row) {
    if ($Row.Name -ceq 'Aggregated' -and -not $Row.Type) { 'Aggregated' } else { "$($Row.Type) $($Row.Name)" }
}

# The same text on every machine, whatever its culture: 1,000.4.
function Format-Number([double] $Value) {
    $Value.ToString('#,0.###', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Invoke-LoadBudgetCheck {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Budget
    )

    $problems = @(Get-LoadBudgetProblem -Path $Path -Budget $Budget)
    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) load budget problem(s); see $Budget." -ForegroundColor Red
        return 1
    }

    Write-Host "The load test is within its budget ($Budget)." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Path -or -not $Budget) { throw 'Give the --csv prefix Locust wrote with -Path and the budget file with -Budget.' }
    exit (Invoke-LoadBudgetCheck -Path $Path -Budget $Budget)
}
