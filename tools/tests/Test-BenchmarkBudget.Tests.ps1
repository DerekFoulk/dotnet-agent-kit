#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Test-BenchmarkBudget.ps1 (GAP-012, ADR-0062) reads the JSON reports BenchmarkDotNet writes (--exporters json) and
# checks each benchmark against the budget in its project's benchmark-budget.json: a mean time and the bytes it
# allocates per operation.

Describe 'Test-BenchmarkBudget.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Test-BenchmarkBudget.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        # One benchmark in BenchmarkDotNet's JSON shape. A $null Mean leaves Statistics out, as when a benchmark fails;
        # a $null Allocated leaves Memory out, as without [MemoryDiagnoser].
        function New-Benchmark([string] $FullName, [object] $Mean = 100.0, [object] $Allocated = 192) {
            $benchmark = [ordered]@{ FullName = $FullName; Method = ($FullName -split '\.')[-1] }
            $benchmark['Statistics'] = if ($null -ne $Mean) { [ordered]@{ N = 15; Mean = $Mean; Median = $Mean } } else { $null }
            if ($null -ne $Allocated) {
                $benchmark['Memory'] = [ordered]@{ Gen0Collections = 0; TotalOperations = 1024; BytesAllocatedPerOperation = $Allocated }
            }
            $benchmark
        }

        # A results folder with one report per class, named as BenchmarkDotNet names them.
        function Write-Result([object[]] $Benchmarks) {
            $folder = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $folder | Out-Null
            foreach ($group in ($Benchmarks | Group-Object { ($_.FullName -split '\.')[0..(($_.FullName -split '\.').Count - 2)] -join '.' })) {
                [ordered]@{ Title = "$($group.Name)-20261112"; Benchmarks = @($group.Group) } |
                    ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $folder "$($group.Name)-report-full-compressed.json")
            }
            $folder
        }

        function Write-Budget([System.Collections.IDictionary] $Budget) {
            $path = Join-Path $TestDrive "$([guid]::NewGuid().ToString('N'))-budget.json"
            $Budget | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
            $path
        }
    }

    It 'finds nothing wrong when every benchmark is within its time and allocation budget' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @(
            (New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Mean 950.5 -Allocated 192)
            (New-Benchmark 'App.Benchmarks.FormatBenchmarks.Format' -Mean 40 -Allocated 0))
        $budget = Write-Budget ([ordered]@{
                'App.Benchmarks.ParseBenchmarks.Parse'   = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 }
                'App.Benchmarks.FormatBenchmarks.Format' = [ordered]@{ maxMeanNanoseconds = 40; maxAllocatedBytes = 0 }
            })

        @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget) | Should -BeNullOrEmpty
    }

    It 'names the benchmark, its mean and its budget when the mean time is over budget' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Mean 1000.4 -Allocated 192))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems.Count | Should -Be 1
        $problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.Parse: mean 1,000.4 ns is over its budget of 1,000 ns*'
    }

    It 'names the benchmark, its allocations and its budget when it allocates more than its budget' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Mean 900 -Allocated 216))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems.Count | Should -Be 1
        $problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.Parse: allocates 216 bytes per operation, over its budget of 192*'
    }

    # Every benchmark states its budget, so a new one can't go unchecked.
    It 'names a benchmark that has no budget' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @(
            (New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse')
            (New-Benchmark 'App.Benchmarks.ParseBenchmarks.ParseLong'))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems.Count | Should -Be 1
        $problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.ParseLong: no budget in *-budget.json*'
    }

    # A renamed or deleted benchmark would otherwise leave its budget checking nothing.
    It 'names a budgeted benchmark that no report has' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse'))
        $budget = Write-Budget ([ordered]@{
                'App.Benchmarks.ParseBenchmarks.Parse'    = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 }
                'App.Benchmarks.ParseBenchmarks.Gone'     = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 }
            })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems.Count | Should -Be 1
        $problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.Gone: has a budget, but no report has it*'
    }

    # A benchmark that throws gets no statistics; BenchmarkDotNet's log says why.
    It 'names a benchmark that produced no result' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Mean $null))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        { $script:problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget) } | Should -Not -Throw

        $script:problems.Count | Should -Be 1
        $script:problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.Parse: no result*'
    }

    # Without [MemoryDiagnoser] the report has no allocations, so the allocation budget would check nothing.
    It 'names a benchmark whose report has no allocations to check' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Allocated $null))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        { $script:problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget) } | Should -Not -Throw

        $script:problems.Count | Should -Be 1
        $script:problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.Parse: no allocations in its report*MemoryDiagnoser*'
    }

    # Review 1 of PR 57: a missing figure would otherwise read as 0 bytes and pass any allocation budget.
    It 'names a benchmark whose report has memory data but no allocation figure' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $benchmark = New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse'
        $benchmark['Memory']['BytesAllocatedPerOperation'] = $null
        $results = Write-Result @($benchmark)
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 0 } })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems | Should -HaveCount 1
        $problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.Parse: no allocations in its report*'
    }

    # Without --exporters json BenchmarkDotNet writes no JSON report: say that, rather than list every budget as missing.
    It 'says there is no report, and nothing else, when the folder has no JSON report' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Join-Path $TestDrive 'empty-results'
        New-Item -ItemType Directory -Path $results | Out-Null
        Set-Content -LiteralPath (Join-Path $results 'App.Benchmarks.ParseBenchmarks-report.csv') -Value 'Method,Mean'
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems.Count | Should -Be 1
        $problems[0] | Should -BeLike 'No BenchmarkDotNet JSON report under *empty-results*--exporters json*'
    }

    # A misspelled limit would otherwise read as no limit, or as zero.
    It 'names a budget entry that lacks <Missing> or has an unknown key' -ForEach @(
        @{ Missing = 'maxMeanNanoseconds'; Entry = [ordered]@{ maxMeanNs = 1000; maxAllocatedBytes = 192 } }
        @{ Missing = 'maxAllocatedBytes'; Entry = [ordered]@{ maxMeanNanoseconds = 1000 } }
    ) {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse'))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = $Entry })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems.Count | Should -Be 1
        $problems[0] | Should -BeLike 'App.Benchmarks.ParseBenchmarks.Parse: its budget must have exactly maxMeanNanoseconds and maxAllocatedBytes, as numbers*'
    }

    # Results left from an earlier run in the same folder would otherwise be checked as well, or instead.
    It 'names a benchmark that more than one report has' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Mean 900))
        $older = Join-Path $results 'older'
        New-Item -ItemType Directory -Path $older | Out-Null
        Copy-Item -LiteralPath (Join-Path $results 'App.Benchmarks.ParseBenchmarks-report-full-compressed.json') -Destination $older
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems | Should -Be @("App.Benchmarks.ParseBenchmarks.Parse: in more than one report under $results. Run the benchmarks into an empty folder.")
    }

    It 'says when there is no budget file' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse'))
        $budget = Join-Path $TestDrive 'missing' 'benchmark-budget.json'

        { $script:problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget) } | Should -Not -Throw

        $script:problems | Should -Be @("No budget file at $budget. Each benchmarks project keeps its budgets in benchmark-budget.json.")
    }

    # BenchmarkDotNet puts a [Params] value in the full name, so each value has its own budget.
    It 'keeps a separate budget for each parameter value' {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @(
            (New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse(Length: 10)' -Mean 90)
            (New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse(Length: 1000)' -Mean 9000))
        $budget = Write-Budget ([ordered]@{
                'App.Benchmarks.ParseBenchmarks.Parse(Length: 10)'   = [ordered]@{ maxMeanNanoseconds = 100; maxAllocatedBytes = 192 }
                'App.Benchmarks.ParseBenchmarks.Parse(Length: 1000)' = [ordered]@{ maxMeanNanoseconds = 8000; maxAllocatedBytes = 192 }
            })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems | Should -Be @('App.Benchmarks.ParseBenchmarks.Parse(Length: 1000): mean 9,000 ns is over its budget of 8,000 ns.')
    }

    # Review 1 of PR 57: each check on a budget entry's values, so none can be dropped unnoticed.
    It 'names a budget entry that <Case>' -ForEach @(
        @{ Case = 'has a negative limit'; Entry = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = -1 } }
        @{ Case = 'has a limit that isn''t a number'; Entry = [ordered]@{ maxMeanNanoseconds = '1000'; maxAllocatedBytes = 192 } }
        @{ Case = 'isn''t an object'; Entry = 1000 }
    ) {
        Get-Command Get-BenchmarkBudgetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Mean 900 -Allocated 0))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = $Entry })

        $problems = @(Get-BenchmarkBudgetProblem -Path $results -Budget $budget)

        $problems | Should -Be @('App.Benchmarks.ParseBenchmarks.Parse: its budget must have exactly maxMeanNanoseconds and maxAllocatedBytes, as numbers of 0 or more.')
    }

    It 'returns exit code <Code> when the benchmarks are <State>' -ForEach @(
        @{ State = 'within budget'; Mean = 900; Code = 0 }
        @{ State = 'over budget'; Mean = 1100; Code = 1 }
    ) {
        Get-Command Invoke-BenchmarkBudgetCheck -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $results = Write-Result @((New-Benchmark 'App.Benchmarks.ParseBenchmarks.Parse' -Mean $Mean))
        $budget = Write-Budget ([ordered]@{ 'App.Benchmarks.ParseBenchmarks.Parse' = [ordered]@{ maxMeanNanoseconds = 1000; maxAllocatedBytes = 192 } })

        Invoke-BenchmarkBudgetCheck -Path $results -Budget $budget 6>$null | Should -Be $Code
    }
}
