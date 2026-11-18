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
            @{ Case = 'with a non-breaking hyphen and a non-breaking space'; Html = "<p>Avoid the in&#8209;memory provider&nbsp;for testing purposes.</p>" }
            @{ Case = 'with an HTML entity'; Html = '<p>Avoid the in&#45;memory provider for testing&#x20;purposes.</p>' }
            @{ Case = 'with a check-mark emoji before it'; Html = '<p>✔️ Avoid the in-memory provider for testing purposes.</p>' }
            @{ Case = 'with a link that leaves a space before the period'; Html = "<p>Avoid the in-memory provider for <a href='x'>testing purposes</a> .</p>" }
            @{ Case = 'with a comment inside a word'; Html = '<p>Avoid the in-memory pro<!-- note -->vider for testing purposes.</p>' }
        ) {
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Avoid the in-memory provider for testing purposes.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) $Html })

            $result[0].State | Should -Be 'Found'
        }

        # Fix round: dropping every space before a period joined a heading word to a quote that starts ".NET".
        It 'finds a quote that starts with ".NET" after a heading' {
            $quote = [pscustomobject]@{ RuleId = 'CS-025'; File = 'csharp.md'; Source = 'https://learn.microsoft.com/a'; Text = '.NET 8 and later use the new format.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) '<h2>Warning</h2><p>.NET 8 and later use the new format.</p>' })

            $result[0].State | Should -Be 'Found'
        }

        # A quote that ends in punctuation needs no word edge after it, since inline markup can join the next word on.
        It 'finds a quote that ends in a period when a word follows with no space' {
            $quote = [pscustomobject]@{ RuleId = 'CS-025'; File = 'csharp.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Call Dispose.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) '<p>Call Dispose.<a>Next</a></p>' })

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

        # Review of the branch: a page that turned the advice around still matched once case and word edges were dropped.
        It 'reports a quote as Missing when the page now says <Case>' -ForEach @(
            @{ Case = 'the opposite, with a negation before it'; Text = 'Use the in-memory provider for tests.'; Html = "<p>Don't use the in-memory provider for tests.</p>" }
            @{ Case = 'never, before it'; Text = 'Use the in-memory provider for tests.'; Html = '<p>Never use the in-memory provider for tests.</p>' }
            @{ Case = 'that it isn''t needed'; Text = 'Call Dispose.'; Html = "<p>You don't need to call Dispose.</p>" }
            @{ Case = 'the words run into another word'; Text = 'a cache'; Html = '<p>Use acache.</p>' }
            @{ Case = 'a longer word where the quote ends'; Text = 'Call Dispose'; Html = '<p>Call DisposeAsync when you are done.</p>' }
            @{ Case = 'a longer word where the quote starts'; Text = 'use the cache.'; Html = '<p>Reuse the cache.</p>' }
        ) {
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = $Text }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) $Html })

            $result[0].State | Should -Be 'Missing'
        }

        # Review of the branch: a removed page answered 404 and read as an outage, so the weekly run stayed green.
        It 'reports the quotes of a page that is gone as Missing, not Unreachable' {
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Avoid the in-memory provider.' }

            $result = @(Test-RuleQuote -Quote $quote -GetPage { param($Url) throw [System.IO.FileNotFoundException]::new('404 (Not Found)') })

            $result[0].State | Should -Be 'Missing'
            $result[0].Detail | Should -BeLike '*gone*404*'
        }

        # Review round 2: the 404 and 410 mapping lives in Get-PageHtml, which the other tests stub out.
        It 'reads a page that answers <Code> as <State>' -ForEach @(
            @{ Code = 404; State = 'Missing' }
            @{ Code = 410; State = 'Missing' }
            @{ Code = 503; State = 'Unreachable' }
        ) {
            Mock Invoke-WebRequest {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("$Code", [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode] $Code))
            }
            $quote = [pscustomobject]@{ RuleId = 'DAT-012'; File = 'data.md'; Source = 'https://learn.microsoft.com/a'; Text = 'Avoid the in-memory provider.' }

            $result = @(Test-RuleQuote -Quote $quote)

            $result[0].State | Should -Be $State
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

# ADR-0083: the scheduled re-read. Kit only: an app's standards come from the kit.
Describe 'rule-quotes.yml' {
    BeforeAll {
        Import-Module powershell-yaml
        $path = Join-Path $PSScriptRoot '..' '..' '.github' 'workflows' 'rule-quotes.yml'
        $script:text = if (Test-Path -LiteralPath $path) { Get-Content -Raw -LiteralPath $path } else { '' }
        $script:workflow = if ($text) { ConvertFrom-Yaml $text } else { @{} }
        $script:jobs = if ($workflow.ContainsKey('jobs')) { $workflow['jobs'] } else { @{} }
        $script:check = if ($jobs.ContainsKey('check')) { $jobs['check'] } else { @{} }
        $script:report = if ($jobs.ContainsKey('report')) { $jobs['report'] } else { @{} }
        # powershell-yaml reads YAML 1.1, where a bare "on" key can be the boolean true.
        $script:on = if ($workflow.ContainsKey('on')) { $workflow['on'] } elseif ($workflow.ContainsKey($true)) { $workflow[$true] } else { @{} }
    }

    It 'runs on a schedule, by hand, and on pull requests that change the rules or the check' {
        $on.ContainsKey('workflow_dispatch') | Should -BeTrue
        @($on['schedule']).Count | Should -Be 1
        @($on['pull_request']['paths']) | Should -Be @('docs/standards/**', 'tools/Test-RuleQuotes.ps1', '.github/workflows/rule-quotes.yml')
    }

    It 'gives the workflow no permissions, the check read access only, and the report only issue writes' {
        $workflow['permissions'].Count | Should -Be 0
        @($check['permissions'].Keys) | Should -Be @('contents')
        $check['permissions']['contents'] | Should -Be 'read'
        @($report['permissions'].Keys) | Should -Be @('issues')
        $report['permissions']['issues'] | Should -Be 'write'
    }

    It 'runs the kit script, and passes only its result word to the report, never page text' {
        $text | Should -Match '\./tools/Test-RuleQuotes\.ps1'
        $check['outputs']['result'] | Should -Be '${{ steps.quotes.outputs.result }}'
        $report['steps'][0]['env']['RESULT'] | Should -Be '${{ needs.check.outputs.result }}'
        # Every expression the workflow uses is one of these: a page's text never reaches a run step.
        $allowed = 'steps.quotes.outputs.result', 'needs.check.outputs.result', 'needs.check.result', 'github.event_name',
        'github.token', 'github.server_url', 'github.repository', 'github.run_id'
        $used = @([regex]::Matches($text, '\$\{\{\s*(.*?)\s*\}\}') | ForEach-Object { $_.Groups[1].Value } | ForEach-Object { $_ -split "\s*(?:&&|==|!=|\(|\))\s*" } |
                Where-Object { $_ -match '^[a-z_]+\.[\w.]+$' } | Select-Object -Unique)
        $used | Should -Not -BeNullOrEmpty
        foreach ($expression in $used) { $expression | Should -BeIn $allowed }
    }

    # Review of the branch: on a schedule, pages that don't load (a site that starts blocking runners) passed silently.
    It 'passes a pull request whose pages didn''t load, but fails a scheduled run, so an issue opens' {
        $run = ($check['steps'] | Where-Object { $_['id'] -eq 'quotes' })['run']
        $run | Should -Match "\`$code -eq 2 -and \`$env:GITHUB_EVENT_NAME -eq 'pull_request'"
        $text | Should -Match 'title="Pages a rule quotes didn''t load"'
    }

    It 'opens one issue for a missing quote or a failed check, never from a pull request, and not when one is open' {
        @($report['needs']) | Should -Be @('check')
        "$($report['if'])" | Should -Match "needs\.check\.result == 'failure'"
        "$($report['if'])" | Should -Match "github\.event_name != 'pull_request'"
        $text | Should -Match "title=""A rule's quoted source changed"""
        $text | Should -Match 'gh issue list'
        $text | Should -Match 'gh issue create'
    }

    It 'pins every action to a full commit SHA (SUP-008)' {
        $uses = @($jobs.Values | ForEach-Object { @($_['steps']) } | Where-Object { $_.ContainsKey('uses') } | ForEach-Object { $_['uses'] })
        $uses | Should -Not -BeNullOrEmpty
        $uses | Should -Match '@[0-9a-f]{40}$'
    }
}
