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
}
