#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Test-Duplication.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-Duplication.ps1')
        $script:fixtures = Join-Path $PSScriptRoot 'fixtures' 'Duplication'
    }

    Context 'reading the report' {
        It 'reads each duplication with every place it occurs' {
            $found = @(Get-Duplication -Report (Join-Path $script:fixtures 'cpd-report.xml'))

            $found.Count | Should -Be 1
            $found[0].Lines | Should -Be 33
            $found[0].Tokens | Should -Be 239
            $found[0].Places.Path | Should -Be '/repo/src/Orders.cs', '/repo/src/Invoices.cs'
            $found[0].Places.Line | Should -Be 32, 68
            $found[0].Places.EndLine | Should -Be 64, 100
        }

        It 'reads a report with no duplication as none' {
            @(Get-Duplication -Report (Join-Path $script:fixtures 'cpd-empty.xml')).Count | Should -Be 0
        }
    }

    Context 'printing the findings' {
        It 'prints each place in MSBuild error format, naming where the same code is' {
            $lines = @(Get-Duplication -Report (Join-Path $script:fixtures 'cpd-report.xml') | Format-Duplication -Solution 'App.slnx')

            $lines | Should -Be @(
                '/repo/src/Orders.cs(32,29): error CRF003: 33 lines (239 tokens) repeat /repo/src/Invoices.cs lines 68-100; keep the knowledge in one place (CRF-003). [App.slnx]'
                '/repo/src/Invoices.cs(68,37): error CRF003: 33 lines (239 tokens) repeat /repo/src/Orders.cs lines 32-64; keep the knowledge in one place (CRF-003). [App.slnx]'
            )
        }
    }

    # CI on PR 49: CPD 7.29.0's C# tokenizer can't read a raw string literal ("""..."""), and stops the run. A file it
    # can't read is skipped, and named as a warning so a reader knows it wasn't checked.
    Context 'a file CPD cannot read' {
        It 'reads each skipped file with where CPD stopped' {
            $skipped = @(Get-SkippedFile -Report (Join-Path $script:fixtures 'cpd-report.xml'))

            $skipped.Count | Should -Be 1
            $skipped[0].Path | Should -Be '/repo/tests/RawTests.cs'
            $skipped[0].Line | Should -Be 44
            $skipped[0].Column | Should -Be 40
        }

        It 'prints it as an MSBuild warning that it was not checked' {
            $lines = @(Get-SkippedFile -Report (Join-Path $script:fixtures 'cpd-report.xml') | Format-SkippedFile -Solution 'App.slnx')

            $lines | Should -Be "/repo/tests/RawTests.cs(44,40): warning CRF003: CPD can't read this C# (token recognition error at: '`$`$'), so the file isn't checked for duplicate code. [App.slnx]"
        }
    }

    Context 'running CPD' {
        It 'asks for C# with the tuning ADR-0051 records' {
            $arguments = Get-CpdArgument -FileList 'files.txt' -Report 'cpd.xml'

            $arguments[0] | Should -Be 'cpd'
            $arguments | Should -Contain '--ignore-usings'
            $arguments | Should -Contain '--ignore-literal-sequences'
            $arguments | Should -Contain '--ignore-annotations'
            ($arguments -join ' ') | Should -Match '--language cs --minimum-tokens 100 '
            ($arguments -join ' ') | Should -Match '--file-list files\.txt --format xml --report-file cpd\.xml'
            $arguments | Should -Contain '--no-fail-on-violation'
            $arguments | Should -Contain '--no-fail-on-error'
        }
    }

    # Review 1 of GAP-020: what decides pass or fail, run with a stand-in for PMD's launcher, so it needs no Java.
    Context 'checking a solution' {
        BeforeAll {
            $script:codeShape = Join-Path $PSScriptRoot 'fixtures' 'CodeShape'
            $script:kitRoot = Join-Path $PSScriptRoot '..' '..'
            $script:fakePmd = Join-Path $script:fixtures 'FakePmd.ps1'
        }

        AfterEach {
            Remove-Item Env:KIT_FAKE_CPD_REPORT, Env:KIT_FAKE_CPD_EXIT -ErrorAction Ignore
        }

        It 'fails when code repeats, naming each repeat and each file CPD skipped' {
            $env:KIT_FAKE_CPD_REPORT = Join-Path $script:fixtures 'cpd-report.xml'
            $env:KIT_FAKE_CPD_EXIT = '0'

            $result = Invoke-DuplicationCheck -Solution (Join-Path $script:codeShape 'Tidy.slnx') -KitRoot $script:kitRoot -Pmd $script:fakePmd

            $result.ExitCode | Should -Be 1
            @($result.Output -split "`n" | ForEach-Object { ($_ -split ': ')[1] }) | Should -Be 'warning CRF003', 'error CRF003', 'error CRF003'
        }

        It 'passes when nothing repeats, counting the files it checked' {
            $env:KIT_FAKE_CPD_REPORT = Join-Path $script:fixtures 'cpd-empty.xml'
            $env:KIT_FAKE_CPD_EXIT = '0'

            $result = Invoke-DuplicationCheck -Solution (Join-Path $script:codeShape 'Tidy.slnx') -KitRoot $script:kitRoot -Pmd $script:fakePmd

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Be 'Duplicate code (CRF-003): 1 file checked, nothing repeats in 100 tokens or more; 0 skipped.'
        }

        It 'stops when CPD itself fails' {
            $env:KIT_FAKE_CPD_EXIT = '1'

            { Invoke-DuplicationCheck -Solution (Join-Path $script:codeShape 'Tidy.slnx') -KitRoot $script:kitRoot -Pmd $script:fakePmd } |
                Should -Throw '*CPD failed with exit code 1*'
        }

        It 'checks nothing, and runs no CPD, when there is no C# file' {
            $env:KIT_FAKE_CPD_EXIT = '1' # CPD would fail if it ran

            { $script:result = Invoke-DuplicationCheck -Solution (Join-Path $script:codeShape 'NoCSharp.slnx') -KitRoot $script:kitRoot -Pmd $script:fakePmd } |
                Should -Not -Throw
            $result = $script:result

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Be 'Duplicate code (CRF-003): no C# files to check.'
        }
    }
}
