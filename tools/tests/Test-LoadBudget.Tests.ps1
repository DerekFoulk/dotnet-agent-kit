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

    # A run that sent nothing has no times and no failures, so every budget would pass.
    It 'says when the run, or a budgeted request, sent no requests' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/bookmarks' -Requests 0)
            (New-Row '' 'Aggregated' -Requests 0))

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget (New-StandardBudget))) } | Should -Not -Throw

        $script:problems | Should -Be @(
            'Aggregated: no requests were made, so there is nothing to check. Is the app up, and does the locustfile run?'
            'POST /bookmarks: no requests were made, so there is nothing to check. Is the app up, and does the locustfile run?')
    }

    # A renamed request would otherwise leave its budget checking nothing.
    It 'names a budgeted request that the stats don''t have' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/bookmarks/' -Requests 400 -P95 150)
            (New-Row '' 'Aggregated' -Requests 400 -P95 150))

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget (New-StandardBudget))) } | Should -Not -Throw

        $script:problems | Should -Be @("POST /bookmarks: has a budget, but the stats have no such request. Locust names a request '<Type> <Name>'; was it renamed?")
    }

    # Locust's whole-run row has no Type; a request that happens to be named Aggregated is just a request.
    It 'takes only the row with no Type as the whole run' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'GET' 'Aggregated' -Requests 400 -P95 150)
            (New-Row 'POST' '/bookmarks' -Requests 400 -P95 150)
            (New-Row '' 'Aggregated' -Requests 800 -P95 150 -P99 700))

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget (New-StandardBudget))) } | Should -Not -Throw

        $script:problems | Should -Be @('Aggregated: 99% of requests took up to 700 ms, over its budget of 600 ms.')
    }

    # Review 1 of PR 57: Locust's names are case-sensitive URLs, so a budget matches a request only as Locust spells it.
    It 'matches a budgeted request to the stats only in the same case' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/Bookmarks' -Requests 400 -P95 150)
            (New-Row '' 'Aggregated' -Requests 400 -P95 150))

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget (New-StandardBudget))) } | Should -Not -Throw

        $script:problems | Should -Be @("POST /bookmarks: has a budget, but the stats have no such request. Locust names a request '<Type> <Name>'; was it renamed?")
    }

    # An error in the locustfile's own code isn't a failed request, so no failure budget sees it: the user just stops
    # doing that task. The workflow runs Locust with --exit-code-on-error 0, so this check is what catches it.
    It 'names each exception the locustfile raised' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats -Rows @(
            (New-Row 'POST' '/bookmarks' -Requests 400 -P95 150)
            (New-Row '' 'Aggregated' -Requests 400 -P95 150)) -Exceptions @("KeyError('id')", 'ValueError: bad, "quoted" value')

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget (New-StandardBudget))) } | Should -Not -Throw

        $script:problems | Should -Be @(
            "The locustfile raised KeyError('id') 3 time(s); see the exceptions CSV for its traceback."
            'The locustfile raised ValueError: bad, "quoted" value 3 time(s); see the exceptions CSV for its traceback.')
    }

    # A misspelled limit would otherwise check nothing; the whole run's failure budget is always stated.
    It 'rejects a budget that <Case>' -ForEach @(
        @{ Case = 'has no Aggregated entry'; Budget = [ordered]@{ 'POST /bookmarks' = [ordered]@{ maxFailureRatio = 0 } }
            Problem = 'The budget has no "Aggregated" entry with a maxFailureRatio: the whole run''s failures are always budgeted.' }
        @{ Case = 'gives Aggregated no failure ratio'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxMilliseconds = [ordered]@{ '95%' = 300 } } }
            Problem = 'The budget has no "Aggregated" entry with a maxFailureRatio: the whole run''s failures are always budgeted.' }
        @{ Case = 'has an unknown key'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxFailureRatio = 0; maxMs = [ordered]@{ '95%' = 300 } } }
            Problem = 'Aggregated: unknown budget key "maxMs"; use maxFailureRatio and maxMilliseconds.' }
        @{ Case = 'names a percentile Locust doesn''t report'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxFailureRatio = 0; maxMilliseconds = [ordered]@{ '97%' = 300 } } }
            Problem = 'Aggregated: Locust reports no "97%" percentile; use one of 50%, 66%, 75%, 80%, 90%, 95%, 98%, 99%, 99.9%, 99.99%, 100%.' }
        @{ Case = 'has a failure ratio above 1'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxFailureRatio = 5 } }
            Problem = 'Aggregated: maxFailureRatio must be a number from 0 to 1, such as 0.01 for 1%.' }
        @{ Case = 'has a negative time'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxFailureRatio = 0; maxMilliseconds = [ordered]@{ '95%' = -1 } } }
            Problem = 'Aggregated: the 95% budget must be a number of milliseconds, 0 or more.' }
        # Review 1 of PR 57: each remaining check on the file, so none can be dropped unnoticed.
        @{ Case = 'has a negative failure ratio'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxFailureRatio = -0.1 } }
            Problem = 'Aggregated: maxFailureRatio must be a number from 0 to 1, such as 0.01 for 1%.' }
        @{ Case = 'gives a request an empty entry'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxFailureRatio = 0 }; 'POST /bookmarks' = [ordered]@{} }
            Problem = 'POST /bookmarks: give it a maxFailureRatio, a maxMilliseconds, or both.' }
        @{ Case = 'gives a request no percentiles'; Budget = [ordered]@{ 'Aggregated' = [ordered]@{ maxFailureRatio = 0 }; 'POST /bookmarks' = [ordered]@{ maxMilliseconds = [ordered]@{} } }
            Problem = 'POST /bookmarks: maxMilliseconds maps percentiles to milliseconds, such as { "95%": 300 }.' }
    ) {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/bookmarks' -Requests 400 -P95 150)
            (New-Row '' 'Aggregated' -Requests 400 -P95 150))

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget (Write-Budget $Budget)) } | Should -Not -Throw

        $script:problems | Should -Be @($Problem)
    }

    # Locust writes no stats when it stops before the run, such as on a locustfile it can't import.
    It 'says when Locust wrote no stats' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $prefix = Join-Path $TestDrive 'crashed'

        { $script:problems = @(Get-LoadBudgetProblem -Path $prefix -Budget (Write-Budget (New-StandardBudget))) } | Should -Not -Throw

        $script:problems | Should -Be @("No Locust stats at ${prefix}_stats.csv: Locust stopped before the run. Its output above says why.")
    }

    It 'says when there is no budget file' {
        Get-Command Get-LoadBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @((New-Row '' 'Aggregated' -Requests 400))
        $budget = Join-Path $TestDrive 'missing' 'load-budget.json'

        { $script:problems = @(Get-LoadBudgetProblem -Path $stats -Budget $budget) } | Should -Not -Throw

        $script:problems | Should -Be @("No budget file at $budget. A load test keeps its budget in load-budget.json, beside its locustfile.")
    }

    It 'returns exit code <Code> when the run is <State>' -ForEach @(
        @{ State = 'within budget'; P95 = 150; Code = 0 }
        @{ State = 'over budget'; P95 = 350; Code = 1 }
    ) {
        Get-Command Invoke-LoadBudgetCheck -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $stats = Write-Stats @(
            (New-Row 'POST' '/bookmarks' -Requests 400 -P95 150)
            (New-Row '' 'Aggregated' -Requests 400 -P95 $P95))

        Invoke-LoadBudgetCheck -Path $stats -Budget (Write-Budget (New-StandardBudget)) 6>$null | Should -Be $Code
    }
}
