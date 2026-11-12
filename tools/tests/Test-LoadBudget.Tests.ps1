#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Test-LoadBudget.ps1 (GAP-012, ADR-0062) reads the CSV files a headless Locust run writes (--csv <prefix>) and checks
# them against the load test's load-budget.json: response-time percentiles and the share of requests that failed, for
# the whole run ("Aggregated") and for any request the budget names ("<Type> <Name>", as Locust names it).

Describe 'Test-LoadBudget.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Test-LoadBudget.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        # Locust 2.47.0's columns (locust/stats.py: requests_csv_columns, PERCENTILES_TO_REPORT, exceptions_columns).
        $script:Percentiles = '50%', '66%', '75%', '80%', '90%', '95%', '98%', '99%', '99.9%', '99.99%', '100%'

        # One stats row. -P95 and -P99 set those percentiles; the others follow from them. Requests 0 gives N/A, as Locust does.
        function New-Row([string] $Type, [string] $Name, [int] $Requests = 1000, [int] $Failures = 0, [int] $P95 = 120, [int] $P99 = 250) {
            $row = [ordered]@{
                'Type' = $Type; 'Name' = $Name; 'Request Count' = $Requests; 'Failure Count' = $Failures
                'Median Response Time' = 40; 'Average Response Time' = 52.5; 'Min Response Time' = 3; 'Max Response Time' = 400
                'Average Content Size' = 180; 'Requests/s' = 33.3; 'Failures/s' = 0
            }
            foreach ($percentile in $script:Percentiles) {
                $value = switch ($percentile) { '95%' { $P95 } '99%' { $P99 } { $_ -in '98%' } { $P95 } { $_ -in '99.9%', '99.99%', '100%' } { $P99 } default { 40 } }
                $row[$percentile] = if ($Requests -eq 0) { 'N/A' } else { $value }
            }
            [pscustomobject] $row
        }

        # Writes <prefix>_stats.csv (and _exceptions.csv, with the given messages) as Locust does; returns the prefix.
        function Write-Stats([object[]] $Rows, [string[]] $Exceptions = @()) {
            $prefix = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $Rows | Export-Csv -LiteralPath "${prefix}_stats.csv" -UseQuotes AsNeeded
            $exceptionRows = @($Exceptions | ForEach-Object { [pscustomobject][ordered]@{ Count = 3; Message = $_; Traceback = 'Traceback (most recent call last): ...'; Nodes = 'local' } })
            if ($exceptionRows) { $exceptionRows | Export-Csv -LiteralPath "${prefix}_exceptions.csv" -UseQuotes AsNeeded }
            else { Set-Content -LiteralPath "${prefix}_exceptions.csv" -Value 'Count,Message,Traceback,Nodes' }
            $prefix
        }

        function Write-Budget([System.Collections.IDictionary] $Budget) {
            $path = Join-Path $TestDrive "$([guid]::NewGuid().ToString('N'))-load-budget.json"
            $Budget | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
            $path
        }

        function New-StandardBudget {
            [ordered]@{
                'Aggregated'     = [ordered]@{ maxFailureRatio = 0; maxMilliseconds = [ordered]@{ '95%' = 300; '99%' = 600 } }
                'POST /bookmarks' = [ordered]@{ maxMilliseconds = [ordered]@{ '95%' = 200 } }
            }
        }
    }

    It 'finds nothing wrong when the run is within its budget' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/bookmarks' -Requests 400 -P95 200 -P99 260)
            (New-Row 'GET' '/bookmarks/[id]' -Requests 400 -P95 80 -P99 150)
            (New-Row '' 'Aggregated' -Requests 800 -P95 190 -P99 250))

        @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget (New-StandardBudget))) | Should -BeNullOrEmpty
    }

    It 'names the request, the percentile, its time and its budget when a percentile is over budget' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/bookmarks' -Requests 400 -P95 210 -P99 260)
            (New-Row '' 'Aggregated' -Requests 400 -P95 210 -P99 610))

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget (New-StandardBudget))) } | Should -Not -Throw

        $script:problems | Should -Be @(
            'Aggregated: 99% of requests took up to 610 ms, over its budget of 600 ms.'
            'POST /bookmarks: 95% of requests took up to 210 ms, over its budget of 200 ms.')
    }

    It 'names the whole run, or a request, whose share of failed requests is over budget' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/bookmarks' -Requests 400 -Failures 6 -P95 150)
            (New-Row 'GET' '/bookmarks' -Requests 400 -Failures 0 -P95 150)
            (New-Row '' 'Aggregated' -Requests 800 -Failures 6 -P95 150))
        $budget = [ordered]@{
            'Aggregated'      = [ordered]@{ maxFailureRatio = 0.01; maxMilliseconds = [ordered]@{ '95%' = 300 } }
            'POST /bookmarks' = [ordered]@{ maxFailureRatio = 0.01 }
            'GET /bookmarks'  = [ordered]@{ maxFailureRatio = 0 }
        }

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget $budget)) } | Should -Not -Throw

        # 6 of 800 is 0.75%, within 1%; 6 of 400 is 1.5%, over it.
        $script:problems | Should -Be @('POST /bookmarks: 6 of 400 requests failed (1.5%), over its budget of 1%.')
    }
}
