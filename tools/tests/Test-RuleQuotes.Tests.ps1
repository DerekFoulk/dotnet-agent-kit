#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

# ADR-0083: the scheduled re-read of every quoted page. These tests never reach the network: each one hands the check
# a page reader that returns fixture HTML or fails.
Describe 'Test-RuleQuotes.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-RuleQuotes.ps1')

        function New-StandardsFile {
            param([object[]] $Quotes)
            $sources = @($Quotes | ForEach-Object { "$($_.source), retrieved $($_.retrieved)" } | Select-Object -Unique)
            $rule = [ordered]@{ id = 'DAT-012'; statement = 's'; basis = 'authority'; status = 'proposed'; sources = $sources; quotes = $Quotes }
            $yaml = ConvertTo-Yaml ([ordered]@{ topic = 'data'; rules = @($rule, [ordered]@{ id = 'GIT-001'; basis = 'preference' }) })
            Set-Content -Path (Join-Path $script:standards 'data.md') -Value "---`n$yaml---`n`n# Data`n"
        }

        function New-Quote([string] $Source, [string] $Text) {
            [ordered]@{ source = $Source; retrieved = '2026-11-17'; text = $Text }
        }
    }

    BeforeEach {
        $script:standards = Join-Path $TestDrive "standards-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:standards | Out-Null
        $script:fetched = [System.Collections.Generic.List[string]]::new()
    }

    Context 'reading the quotes' {
        It 'reads each quote with its rule, page and text, and skips rules with none' {
            New-StandardsFile -Quotes @((New-Quote 'https://learn.microsoft.com/a' 'First.'), (New-Quote 'https://learn.microsoft.com/b' 'Second.'))

            $quotes = @(Get-RuleQuote -StandardsPath $script:standards)

            $quotes.Count | Should -Be 2
            $quotes[0].RuleId | Should -Be 'DAT-012'
            $quotes[0].File | Should -Be 'data.md'
            $quotes[1].Source | Should -Be 'https://learn.microsoft.com/b'
            $quotes[1].Text | Should -Be 'Second.'
        }
    }

    Context 'comparing with the page' {
        It 'finds a quote the page renders <Case>' -ForEach @(
            @{ Case = 'with inline markup and line breaks'; Html = "<p>Avoid the <strong>in-memory</strong>`n provider for <a href='x'>testing</a> purposes.</p>" }
            @{ Case = 'with curly quotes and a non-breaking space'; Html = "<p>Avoid the in&#8209;memory provider&nbsp;for testing purposes.</p>" -replace 'in&#8209;memory', 'in-memory' }
            @{ Case = 'with an HTML entity'; Html = '<p>Avoid the in-memory provider for testing purposes &amp; more.</p>' }
            @{ Case = 'with a check-mark emoji before it'; Html = '<p>✔️ Avoid the in-memory provider for testing purposes.</p>' }
        ) {
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Avoid the in-memory provider for testing purposes.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) $Html })

            $result[0].State | Should -Be 'Found'
        }

        It 'finds a quote written with straight quotes on a page with curly ones' {
            $quote = [pscustomobject]@{ RuleId = 'DAT-011'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = "If you're using Migrations, don't use EnsureCreatedAsync." }

            # PowerShell reads a curly quote as a string delimiter, so the page's apostrophe is written by its code point.
            $apostrophe = [char] 0x2019
            $html = "<p>If you${apostrophe}re using Migrations, don${apostrophe}t use <code>EnsureCreatedAsync</code>.</p>"

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) $html }.GetNewClosure())

            $result[0].State | Should -Be 'Found'
        }

        It 'reports a quote the page no longer has as Missing' {
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Avoid the in-memory provider.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) '<p>Consider the in-memory provider.</p>' })

            $result[0].State | Should -Be 'Missing'
        }

        It 'ignores text in scripts and styles' {
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Avoid the in-memory provider.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) '<script>var s = "Avoid the in-memory provider.";</script><p>Other text.</p>' })

            $result[0].State | Should -Be 'Missing'
        }

        It 'reports a page that fails to load as Unreachable, not Missing' {
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Avoid the in-memory provider.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) throw '503 Service Unavailable' })

            $result[0].State | Should -Be 'Unreachable'
            $result[0].Detail | Should -BeLike '*503*'
        }

        It 'reads each page once for all its quotes' {
            $quotes = @(
                [pscustomobject]@{ RuleId = 'A'; File = 'a.md'; Source = 'https://learn.microsoft.com/a'; Text = 'One.' }
                [pscustomobject]@{ RuleId = 'B'; File = 'a.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Two.' }
            )

            $result = @(Test-RuleQuote -Quote $quotes -GetPage { param($Url) $script:fetched.Add($Url); '<p>One. Two.</p>' })

            $script:fetched.Count | Should -Be 1
            @($result | Where-Object State -eq 'Found').Count | Should -Be 2
        }
    }

    Context 'runner' {
        BeforeEach { Mock Write-Host {} }

        It 'returns 0 when every quote is on its page' {
            New-StandardsFile -Quotes @(New-Quote 'https://learn.microsoft.com/a' 'Avoid the in-memory provider.')

            Invoke-RuleQuoteCheck -StandardsPath $script:standards -GetPage { param($Url) '<p>Avoid the in-memory provider.</p>' } | Should -Be 0
        }

        It 'returns 1 and names the rule and page when a quote is missing' {
            New-StandardsFile -Quotes @(New-Quote 'https://learn.microsoft.com/a' 'Avoid the in-memory provider.')

            Invoke-RuleQuoteCheck -StandardsPath $script:standards -GetPage { param($Url) '<p>Something else.</p>' } | Should -Be 1
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*DAT-012*https://learn.microsoft.com/a*' }
        }

        It 'returns 2 when a page is unreachable and no quote is missing, so a failed fetch is never a missing quote' {
            New-StandardsFile -Quotes @(New-Quote 'https://learn.microsoft.com/a' 'Avoid the in-memory provider.')

            Invoke-RuleQuoteCheck -StandardsPath $script:standards -GetPage { param($Url) throw 'timed out' } | Should -Be 2
        }
    }
}
