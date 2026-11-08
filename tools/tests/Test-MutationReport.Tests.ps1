#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Test-MutationReport.ps1 (ADR-0039) reads Stryker.NET's JSON report and refuses a score it can't trust: a test may
# only kill a mutant it ran against. Stryker records which tests reach each mutant (coveredBy); a kill by any other
# test means that test fails whatever is mutated. On PR 23 the API tests failed to start under Stryker, coverage
# capture failed, and every mutant counted as killed: a false 100%.

Describe 'Test-MutationReport.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Test-MutationReport.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        # One mutant in Stryker's JSON shape. KilledBy and CoveredBy are test ids; $null leaves the field out.
        function New-Mutant([string] $Status = 'Killed', [object] $KilledBy, [object] $CoveredBy, [bool] $Static = $false) {
            $mutant = [ordered]@{ id = [guid]::NewGuid().ToString('N'); mutatorName = 'Statement mutation'; status = $Status; static = $Static }
            if ($null -ne $KilledBy) { $mutant['killedBy'] = @($KilledBy) }
            if ($null -ne $CoveredBy) { $mutant['coveredBy'] = @($CoveredBy) }
            $mutant
        }

        function New-Report([object[]] $Mutants, [string[]] $TestIds = @('t1', 't2', 'tAlways')) {
            [ordered]@{
                schemaVersion = '2'
                files         = [ordered]@{ 'src/App/Thing.cs' = [ordered]@{ language = 'cs'; mutants = @($Mutants) } }
                testFiles     = [ordered]@{ 'tests/App.Tests/ThingTests.cs' = [ordered]@{ tests = @($TestIds | ForEach-Object { [ordered]@{ id = $_; name = "App.Tests.ThingTests.$_" } }) } }
            }
        }

        function Write-Report($Report) {
            $path = Join-Path $TestDrive 'mutation-report.json'
            $Report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
            $path
        }
    }

    It 'finds nothing wrong when every kill came from a test that reached the mutant' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $report = New-Report @(
            (New-Mutant -KilledBy 't1' -CoveredBy 't1', 't2')
            (New-Mutant -KilledBy 't2' -CoveredBy 't2')
            (New-Mutant -Status 'Survived' -CoveredBy 't1'))

        @(Get-MutationReportProblem -Path (Write-Report $report)) | Should -BeNullOrEmpty
    }

    It 'flags a test that killed mutants it never reached, by name and count' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $report = New-Report @(
            (New-Mutant -KilledBy 't1', 'tAlways' -CoveredBy 't1')
            (New-Mutant -KilledBy 't2', 'tAlways' -CoveredBy 't2')
            (New-Mutant -KilledBy 't1' -CoveredBy 't1'))

        $problems = @(Get-MutationReportProblem -Path (Write-Report $report))

        $problems.Count | Should -Be 1
        $problems[0] | Should -Match '^App\.Tests\.ThingTests\.tAlways killed 2 mutant\(s\) it never reached'
    }

    It 'flags kills when Stryker captured no coverage at all, as on PR 23' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $report = New-Report @(
            (New-Mutant -KilledBy 't1', 'tAlways' -CoveredBy @())
            (New-Mutant -KilledBy 'tAlways' -CoveredBy @()))

        $problems = @(Get-MutationReportProblem -Path (Write-Report $report))

        # With no coverage, every killer is outside it: both tests are named, each with its own count.
        $problems.Count | Should -Be 2
        $problems[0] | Should -Match '^App\.Tests\.ThingTests\.t1 killed 1 mutant\(s\) it never reached'
        $problems[1] | Should -Match '^App\.Tests\.ThingTests\.tAlways killed 2 mutant\(s\) it never reached'
    }

    It 'leaves static mutants alone: Stryker runs them against every test' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $report = New-Report @((New-Mutant -KilledBy 'tAlways' -CoveredBy @() -Static $true))

        @(Get-MutationReportProblem -Path (Write-Report $report)) | Should -BeNullOrEmpty
    }

    It 'reads killed mutants with no killedBy list as having no known killer' {
        # Review of PR 23: an absent killedBy became "" and was reported as a test.
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $report = New-Report @((New-Mutant -CoveredBy 't1'), (New-Mutant -CoveredBy 't2'))

        @(Get-MutationReportProblem -Path (Write-Report $report)) | Should -BeNullOrEmpty
    }

    It 'names a test by its id when the report has no test files' {
        # Review of PR 23: a report without testFiles threw under strict mode.
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $report = New-Report @((New-Mutant -KilledBy 'tAlways' -CoveredBy 't1'))
        $report.Remove('testFiles')
        $path = Write-Report $report

        { Get-MutationReportProblem -Path $path } | Should -Not -Throw
        @(Get-MutationReportProblem -Path $path) | Should -Match '^tAlways killed 1 mutant\(s\) it never reached'
    }

    It 'says plainly when there is no report to check' {
        # Review of PR 23: when Stryker died before writing one, the check failed with a bare Get-Content error.
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        { Get-MutationReportProblem -Path (Join-Path $TestDrive 'missing.json') } | Should -Throw '*No mutation report at*'
    }

    It 'returns exit code 1 with the problem, and 0 for a sound report' {
        Get-Command Invoke-MutationReportCheck -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $bad = Write-Report (New-Report @((New-Mutant -KilledBy 'tAlways' -CoveredBy 't1')))
        Invoke-MutationReportCheck -Path $bad 6> $null | Should -Be 1

        $good = Write-Report (New-Report @((New-Mutant -KilledBy 't1' -CoveredBy 't1')))
        Invoke-MutationReportCheck -Path $good 6> $null | Should -Be 0
    }
}
