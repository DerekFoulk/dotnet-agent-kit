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
    $rows = @{}
    foreach ($row in (Import-Csv -LiteralPath "${Path}_stats.csv")) { $rows[(Get-RequestKey $row)] = $row }

    # The whole run first, then each request, so the output reads the same every time.
    $keys = @('Aggregated') + @($budgets.Keys | Where-Object { $_ -cne 'Aggregated' } | Sort-Object -CaseSensitive)
    foreach ($key in $keys) {
        $limit = $budgets[$key]
        $row = $rows[$key]
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
