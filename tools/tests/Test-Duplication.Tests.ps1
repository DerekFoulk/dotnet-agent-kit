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
            $arguments = Get-CpdArgument -FileList 'files.txt'

            $arguments[0] | Should -Be 'cpd'
            $arguments | Should -Contain '--ignore-usings'
            $arguments | Should -Contain '--ignore-literal-sequences'
            $arguments | Should -Contain '--ignore-annotations'
            ($arguments -join ' ') | Should -Match '--language cs --minimum-tokens 100 '
            ($arguments -join ' ') | Should -Match '--file-list files\.txt --format xml'
            $arguments | Should -Contain '--no-fail-on-violation'
            $arguments | Should -Contain '--no-fail-on-error'
        }
    }
}
