#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Test-MutationReport.ps1 (ADR-0039) reads Stryker.NET's JSON report and refuses a score it can't trust: when one test
# "killed" every mutant, it almost certainly fails whatever is mutated (PR 23: the API tests couldn't find the API
# under Stryker, every mutant counted as killed, and the run reported 100%).

Describe 'Test-MutationReport.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Test-MutationReport.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        # A report in Stryker's JSON shape: files with mutants, and test files naming each test id.
        function New-Report {
            param([object[]] $KilledBy, [string[]] $Statuses)
            $mutants = for ($i = 0; $i -lt $KilledBy.Count; $i++) {
                $status = if ($Statuses) { $Statuses[$i] } else { 'Killed' }
                [ordered]@{ id = "$i"; mutatorName = 'Statement mutation'; status = $status; killedBy = @($KilledBy[$i]) }
            }
            $ids = @($KilledBy | ForEach-Object { $_ } | Sort-Object -Unique)
            [ordered]@{
                schemaVersion = '2'
                files         = [ordered]@{ 'src/App/Thing.cs' = [ordered]@{ language = 'cs'; mutants = @($mutants) } }
                testFiles     = [ordered]@{ 'tests/App.Tests/ThingTests.cs' = [ordered]@{ tests = @($ids | ForEach-Object { [ordered]@{ id = $_; name = "App.Tests.ThingTests.Test$_" } }) } }
            }
        }

        function Write-Report($Report) {
            $path = Join-Path $TestDrive 'mutation-report.json'
            $Report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
            $path
        }
    }

    It 'finds nothing wrong when different tests kill different mutants' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $killedBy = 1..12 | ForEach-Object { , @("t$_", 'tShared') }
        $killedBy[0] = , @('t1')

        @(Get-MutationReportProblem -Path (Write-Report (New-Report -KilledBy $killedBy))) | Should -BeNullOrEmpty
    }

    It 'flags a test that killed every one of at least 10 mutants, by name' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $killedBy = 1..10 | ForEach-Object { , @("t$_", 'tAlways') }

        $problems = @(Get-MutationReportProblem -Path (Write-Report (New-Report -KilledBy $killedBy)))

        $problems.Count | Should -Be 1
        $problems[0] | Should -Match 'App\.Tests\.ThingTests\.TesttAlways'
        $problems[0] | Should -Match 'every one of the 10 killed mutants'
    }

    It 'leaves a small report alone: one test can rightly kill all of a few mutants' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $killedBy = 1..9 | ForEach-Object { , @('tAlways') }

        @(Get-MutationReportProblem -Path (Write-Report (New-Report -KilledBy $killedBy))) | Should -BeNullOrEmpty
    }

    It 'counts only killed mutants, not survivors or ignored ones' {
        Get-Command Get-MutationReportProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $killedBy = @(1..10 | ForEach-Object { , @('tAlways') }) + @(, @())
        $statuses = @(1..10 | ForEach-Object { 'Killed' }) + 'Survived'

        @(Get-MutationReportProblem -Path (Write-Report (New-Report -KilledBy $killedBy -Statuses $statuses))).Count | Should -Be 1
    }

    It 'reads killed mutants with no killedBy list as having no known killer, not as one blank test' {
        # Review of PR 23: an absent killedBy became "" and was reported as a test that killed everything.
        $report = New-Report -KilledBy (1..10 | ForEach-Object { , @("t$_") })
        foreach ($mutant in $report['files']['src/App/Thing.cs']['mutants']) { $mutant.Remove('killedBy') }

        @(Get-MutationReportProblem -Path (Write-Report $report)) | Should -BeNullOrEmpty
    }

    It 'names a test by its id when the report has no test files' {
        # Review of PR 23: a report without testFiles threw under strict mode.
        $report = New-Report -KilledBy (1..10 | ForEach-Object { , @('tAlways') })
        $report.Remove('testFiles')

        $path = Write-Report $report

        { Get-MutationReportProblem -Path $path } | Should -Not -Throw
        $problems = @(Get-MutationReportProblem -Path $path)
        $problems.Count | Should -Be 1
        $problems[0] | Should -Match '^tAlways killed every one'
    }

    It 'says plainly when there is no report to check' {
        # Review of PR 23: when Stryker died before writing one, the check failed with a bare Get-Content error.
        { Get-MutationReportProblem -Path (Join-Path $TestDrive 'missing.json') } | Should -Throw '*No mutation report at*'
    }

    It 'returns exit code 1 with the problem, and 0 for a sound report' {
        Get-Command Invoke-MutationReportCheck -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $bad = Write-Report (New-Report -KilledBy (1..10 | ForEach-Object { , @('tAlways') }))
        Invoke-MutationReportCheck -Path $bad 6> $null | Should -Be 1

        $good = Write-Report (New-Report -KilledBy (1..10 | ForEach-Object { , @("t$_") }))
        Invoke-MutationReportCheck -Path $good 6> $null | Should -Be 0
    }
}
