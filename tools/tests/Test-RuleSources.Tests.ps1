#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

Describe 'Test-RuleSources.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-RuleSources.ps1')

        function New-Rule {
            param([hashtable] $Override = @{}, [string[]] $Remove = @())

            $rule = [ordered]@{
                id          = 'GIT-001'
                statement   = 'Pull requests merge into main with a merge commit.'
                why         = 'Keeps each red and green commit in history.'
                layer       = 'owner'
                basis       = 'preference'
                status      = 'accepted'
                sources     = @('owner, 2026-10-26', 'ADR-0007')
                enforcement = @(
                    [ordered]@{ kind = 'gate'; in = @('kit', 'app'); how = 'ruleset: merge-method rule (merge commit only)' }
                )
                scope       = 'core'
                paths       = @('**')
            }
            foreach ($key in $Override.Keys) { $rule[$key] = $Override[$key] }
            foreach ($key in $Remove) { $rule.Remove($key) }
            $rule
        }

        # A quote for each URL source, so a test about something else has a well-formed authority rule (ADR-0082).
        function New-QuotesFor {
            param([string[]] $Sources)
            , @(foreach ($source in $Sources) {
                    if ($source -match '^(https?://\S+), retrieved (\S+)$') {
                        [ordered]@{ source = $Matches[1]; retrieved = $Matches[2]; text = 'The page''s own words.' }
                    }
                })
        }

        function New-StandardsFile {
            param([string] $Name = 'git', [object[]] $Rules = @(New-Rule))

            $frontMatter = ConvertTo-Yaml ([ordered]@{ topic = $Name; rules = $Rules })
            Set-Content -Path (Join-Path $script:standards "$Name.md") -Value "---`n$frontMatter---`n`n# $Name`n"
        }

        function Get-Problem {
            @(Get-RuleSourceProblem -StandardsPath $script:standards -AdrPath $script:adr)
        }
    }

    BeforeEach {
        $script:standards = Join-Path $TestDrive "standards-$(New-Guid)"
        $script:adr = Join-Path $TestDrive "adr-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:standards, $script:adr | Out-Null
        Set-Content -Path (Join-Path $script:adr '0007-github-flow.md') -Value '# ADR-0007'
        # ADR-0084: the app types a rule's scope can name, kept beside the standards.
        Set-Content -Path (Join-Path $script:standards 'app-types.yml') -Value @'
types:
  - id: web-api
    name: ASP.NET Core Web API
    docs: https://learn.microsoft.com/aspnet/core/web-api/
  - id: maui
    name: .NET MAUI
    docs: https://learn.microsoft.com/dotnet/maui/
'@
    }

    Context 'structure' {
        It 'finds no problems in a complete rule' {
            New-StandardsFile

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports a rule missing <Field>' -ForEach @(
            @{ Field = 'id' }, @{ Field = 'statement' }, @{ Field = 'layer' }, @{ Field = 'basis' },
            @{ Field = 'status' }, @{ Field = 'sources' }, @{ Field = 'enforcement' }
        ) {
            New-StandardsFile -Rules @(New-Rule -Remove $Field)

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*$Field*"
            $problems[0].File | Should -Be 'git.md'
        }

        It 'reports an empty sources list' {
            New-StandardsFile -Rules @(New-Rule -Override @{ sources = @() })

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*sources*'
        }

        It 'reports a standards file with no front matter' {
            Set-Content -Path (Join-Path $script:standards 'loose.md') -Value '# No front matter'

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*front matter*'
        }

        It 'reports a standards file whose front matter has no rules' {
            Set-Content -Path (Join-Path $script:standards 'empty.md') -Value "---`ntopic: empty`n---`n"

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*no rules*'
        }
    }

    Context 'sources' {
        It 'accepts the source <Source>' -ForEach @(
            @{ Source = 'owner, 2026-10-26'; Basis = 'preference' }
            @{ Source = 'ADR-0007'; Basis = 'preference' }
            @{ Source = 'https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-01'; Basis = 'authority' }
        ) {
            $layer = if ($Basis -eq 'authority') { 'outside' } else { 'owner' }
            New-StandardsFile -Rules @(New-Rule -Override @{
                    sources = @($Source); basis = $Basis; layer = $layer; status = 'proposed'; quotes = New-QuotesFor $Source
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports the source <Source> (<Reason>)' -ForEach @(
            @{ Source = 'https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview'; Reason = 'outside source with no retrieval date'; Expected = '*retrieved*' }
            @{ Source = 'https://example.com/x, retrieved last week'; Reason = 'retrieval date not a date'; Expected = '*retrieved*' }
            @{ Source = 'https:///missing-host, retrieved 2026-11-01'; Reason = 'URL with no host'; Expected = '*not a valid http(s) URL*' }
            @{ Source = 'https://exa`mple.com/x, retrieved 2026-11-01'; Reason = 'URL with an invalid host'; Expected = '*not a valid http(s) URL*' }
            @{ Source = 'owner'; Reason = 'owner with no date'; Expected = '*owner, YYYY-MM-DD*' }
            @{ Source = 'owner, 2026-13-45'; Reason = 'owner with an impossible date'; Expected = '*owner, YYYY-MM-DD*' }
            @{ Source = 'ADR-0099'; Reason = 'ADR that does not exist'; Expected = '*ADR-0099*not found*' }
            @{ Source = 'a blog I read'; Reason = 'unrecognized form'; Expected = '*not a recognized source*' }
        ) {
            New-StandardsFile -Rules @(New-Rule -Override @{ sources = @($Source) })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].RuleId | Should -Be 'GIT-001'
            $problems[0].Message | Should -BeLike $Expected
        }
    }

    Context 'values' {
        It 'accepts layer <Layer> and status <Status>' -ForEach @(
            @{ Layer = 'floor'; Status = 'proposed'; Basis = 'preference' }
            @{ Layer = 'owner'; Status = 'accepted'; Basis = 'preference' }
            @{ Layer = 'outside'; Status = 'retired'; Basis = 'authority' }
        ) {
            # A retired rule isn't in force, so it needs no quote; an outside rule is an authority's.
            $sources = if ($Basis -eq 'authority') { @('https://example.com/guide, retrieved 2026-11-01') } else { @('owner, 2026-10-26') }
            New-StandardsFile -Rules @(New-Rule -Override @{ layer = $Layer; status = $Status; basis = $Basis; sources = $sources })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports <Field> <Value>' -ForEach @(
            @{ Field = 'layer'; Value = 'team' }
            @{ Field = 'basis'; Value = 'taste' }
            @{ Field = 'status'; Value = 'draft' }
        ) {
            New-StandardsFile -Rules @(New-Rule -Override @{ $Field = $Value })

            (Get-Problem | ForEach-Object Message) | Should -BeLike "*$Field*$Value*"
        }
    }

    # ADR-0063: basis says where a rule's substance comes from. An authority's rule cites the authority by URL;
    # the owner's preference cites him or the ADR he accepted.
    Context 'basis' {
        It 'accepts an authority rule that cites a URL' {
            New-StandardsFile -Rules @(New-Rule -Override @{
                    basis = 'authority'; layer = 'outside'; status = 'proposed'
                    sources = @('https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-01')
                    quotes = New-QuotesFor 'https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-01'
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'accepts an authority rule that cites an http URL' {
            New-StandardsFile -Rules @(New-Rule -Override @{
                    basis = 'authority'; layer = 'outside'; status = 'proposed'; sources = @('http://example.com/guide, retrieved 2026-11-01')
                    quotes = New-QuotesFor 'http://example.com/guide, retrieved 2026-11-01'
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        # ADR-0082: an authority rule says only what its pages say, so it cites pages only. An owner's decision or an
        # ADR in its sources would mean part of it is the kit's: that part is a preference rule of its own.
        It 'reports an authority rule that also cites <Source>' -ForEach @(
            @{ Source = 'owner, 2026-10-26' }
            @{ Source = 'ADR-0007' }
        ) {
            $url = 'https://example.com/guide, retrieved 2026-11-01'
            New-StandardsFile -Rules @(New-Rule -Override @{
                    basis = 'authority'; layer = 'outside'; status = 'proposed'; sources = @($url, $Source); quotes = New-QuotesFor $url
                })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*authority*cites pages only*$Source*preference*ratified*"
        }

        It 'reports basis <Basis> with layer <Layer>' -ForEach @(
            @{ Basis = 'authority'; Layer = 'owner' }
            @{ Basis = 'preference'; Layer = 'outside' }
        ) {
            $sources = if ($Basis -eq 'authority') { @('https://example.com/guide, retrieved 2026-11-01') } else { @('owner, 2026-10-26') }
            New-StandardsFile -Rules @(New-Rule -Override @{
                    basis = $Basis; layer = $Layer; status = 'proposed'; sources = $sources; quotes = New-QuotesFor $sources
                })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*basis '$Basis'*layer '$Layer'*"
        }

        It 'accepts layer floor with basis <Basis>' -ForEach @(
            @{ Basis = 'authority' }
            @{ Basis = 'preference' }
        ) {
            $sources = if ($Basis -eq 'authority') { @('https://example.com/guide, retrieved 2026-11-01') } else { @('owner, 2026-10-26') }
            New-StandardsFile -Rules @(New-Rule -Override @{
                    basis = $Basis; layer = 'floor'; status = 'proposed'; sources = $sources; quotes = New-QuotesFor $sources
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        # The owner's acceptance of an authority rule is recorded, not mixed into its sources.
        It 'accepts an accepted authority rule ratified by <Ratified>' -ForEach @(
            @{ Ratified = 'owner, 2026-11-12' }
            @{ Ratified = 'ADR-0007' }
        ) {
            $url = 'https://example.com/guide, retrieved 2026-11-01'
            New-StandardsFile -Rules @(New-Rule -Override @{
                    basis = 'authority'; layer = 'outside'; status = 'accepted'; ratified = $Ratified; sources = @($url); quotes = New-QuotesFor $url
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports an accepted authority rule with ratified <Case>' -ForEach @(
            @{ Case = 'missing'; Ratified = $null; Expected = "*accepted*authority*ratified*" }
            @{ Case = 'not an owner date or an ADR'; Ratified = 'the owner'; Expected = "*ratified 'the owner'*owner, YYYY-MM-DD*ADR*" }
            @{ Case = 'an owner with no real date'; Ratified = 'owner, 2026-13-45'; Expected = "*ratified*owner, YYYY-MM-DD*" }
            @{ Case = 'an ADR that doesn''t exist'; Ratified = 'ADR-9999'; Expected = "*ratified*ADR-9999*not found*" }
        ) {
            $url = 'https://example.com/guide, retrieved 2026-11-01'
            $rule = New-Rule -Override @{ basis = 'authority'; layer = 'outside'; status = 'accepted'; sources = @($url); quotes = New-QuotesFor $url }
            if ($Ratified) { $rule['ratified'] = $Ratified }
            New-StandardsFile -Rules @($rule)

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike $Expected
        }

        It 'reports ratified on a preference rule, whose sources already name the owner' {
            New-StandardsFile -Rules @(New-Rule -Override @{ ratified = 'owner, 2026-11-12' })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*ratified*authority*"
        }

        It 'reports an authority rule that cites no URL' {
            New-StandardsFile -Rules @(New-Rule -Override @{ basis = 'authority'; sources = @('owner, 2026-10-26', 'ADR-0007') })

            # It has no quote either, since it cites no page to quote; that's reported too.
            (Get-Problem | ForEach-Object Message) -join "`n" | Should -BeLike '*authority*URL*'
        }

        It 'reports a preference that cites neither the owner nor an ADR' {
            New-StandardsFile -Rules @(New-Rule -Override @{
                    sources = @('https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-01')
                })

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*preference*owner*ADR*'
        }
    }

    # ADR-0082: an authority rule stores the sentence on each cited page that says what the rule says, so a reader
    # and the reviewer can compare the two; a rule worded beyond its quote is the kit's, and says so (preference).
    Context 'quotes' {
        BeforeAll {
            function New-Quote {
                param([hashtable] $Override = @{}, [string[]] $Remove = @())
                $quote = [ordered]@{
                    source    = 'https://learn.microsoft.com/ef/core/testing/'
                    retrieved = '2026-11-17'
                    text      = 'We recommend testing against the same database system you use in production.'
                }
                foreach ($key in $Override.Keys) { $quote[$key] = $Override[$key] }
                foreach ($key in $Remove) { $quote.Remove($key) }
                $quote
            }
            function New-AuthorityRule {
                param([hashtable] $Override = @{}, [string[]] $Remove = @())
                $rule = New-Rule -Override @{
                    basis = 'authority'; layer = 'outside'; status = 'proposed'
                    sources = @('https://learn.microsoft.com/ef/core/testing/, retrieved 2026-11-17'); quotes = @(New-Quote)
                }
                foreach ($key in $Override.Keys) { $rule[$key] = $Override[$key] }
                foreach ($key in $Remove) { $rule.Remove($key) }
                $rule
            }
        }

        It 'accepts an authority rule whose cited page has a quote' {
            New-StandardsFile -Rules @(New-AuthorityRule)

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports an authority rule with quotes <Case>' -ForEach @(
            @{ Case = 'missing'; Value = $null }
            @{ Case = 'empty'; Value = @() }
        ) {
            $rule = if ($null -eq $Value) { New-AuthorityRule -Remove 'quotes' } else { New-AuthorityRule -Override @{ quotes = $Value } }
            New-StandardsFile -Rules @($rule)

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].RuleId | Should -Be 'GIT-001'
            $problems[0].Message | Should -BeLike "*authority*quote*"
        }

        It 'reports a quote whose <Field> is <Case>' -ForEach @(
            @{ Field = 'source'; Case = 'missing'; Value = $null; Expected = "*quote*source*" }
            @{ Field = 'retrieved'; Case = 'missing'; Value = $null; Expected = "*quote*retrieved*" }
            @{ Field = 'text'; Case = 'missing'; Value = $null; Expected = "*quote*text*" }
            @{ Field = 'text'; Case = 'blank'; Value = '   '; Expected = "*quote*text*" }
            @{ Field = 'retrieved'; Case = 'not a date'; Value = 'last week'; Expected = "*quote*retrieved*YYYY-MM-DD*" }
        ) {
            $quote = if ($null -eq $Value) { New-Quote -Remove $Field } else { New-Quote -Override @{ $Field = $Value } }
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{ quotes = @($quote) })

            # A quote with no source also leaves the cited page unquoted, which is reported as well.
            (Get-Problem | ForEach-Object Message) -join "`n" | Should -BeLike $Expected
        }

        It 'reports a quote written as a string, not a map' {
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{ quotes = @('We recommend testing against production.') })

            (Get-Problem | ForEach-Object Message) -join "`n" | Should -BeLike '*quote*source, retrieved and text*'
        }

        It 'reports a quote whose page the rule doesn''t cite' {
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{
                    quotes = @((New-Quote), (New-Quote -Override @{ source = 'https://learn.microsoft.com/ef/core/other' }))
                })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*quote*https://learn.microsoft.com/ef/core/other*not one of the rule's sources*"
        }

        It 'reports a quote read on another day than its source says' {
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{ quotes = @(New-Quote -Override @{ retrieved = '2026-11-16' }) })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*quote*2026-11-16*source*2026-11-17*"
        }

        It 'reports an authority rule that cites a page it doesn''t quote' {
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{
                    sources = @('https://learn.microsoft.com/ef/core/testing/, retrieved 2026-11-17', 'https://learn.microsoft.com/ef/core/other, retrieved 2026-11-17')
                })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*https://learn.microsoft.com/ef/core/other*no quote*"
        }

        It 'reports a quote that skips words with <Mark>' -ForEach @(
            @{ Mark = '...' }
            @{ Mark = '…' }
        ) {
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{ quotes = @(New-Quote -Override @{ text = "We recommend testing $Mark in production." }) })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike '*quote*ellipsis*one contiguous passage*'
        }

        It 'accepts dots that are part of the page''s code: <Text>' -ForEach @(
            @{ Text = "Don't use _ = Task.Run(...) to discard a task." }
            @{ Text = 'Prefer ForAll(...) to Parallel.ForEach(source, ...).' }
        ) {
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{ quotes = @(New-Quote -Override @{ text = $Text }) })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports a quote that skips words with <Mark> (<Case>)' -ForEach @(
            @{ Case = 'at the start'; Mark = '...'; Text = '... testing in production.' }
            @{ Case = 'in brackets'; Mark = '[...]'; Text = 'We recommend [...] testing in production.' }
        ) {
            New-StandardsFile -Rules @(New-AuthorityRule -Override @{ quotes = @(New-Quote -Override @{ text = $Text }) })

            (Get-Problem | ForEach-Object Message) -join "`n" | Should -BeLike '*quote*ellipsis*'
        }

        It 'accepts a preference rule that also stores a quote' {
            New-StandardsFile -Rules @(New-Rule -Override @{
                    sources = @('owner, 2026-10-26', 'https://learn.microsoft.com/ef/core/testing/, retrieved 2026-11-17'); quotes = @(New-Quote)
                })

            Get-Problem | Should -BeNullOrEmpty
        }
    }

    # ADR-0084: every rule names its scope, so an app gets only the rules that fit it: core, for every app type, or the
    # supported app types in app-types.yml it applies to.
    Context 'scope' {
        It 'accepts a rule for <Case>' -ForEach @(
            @{ Case = 'every app type'; Scope = 'core' }
            @{ Case = 'one app type'; Scope = @('maui') }
        ) {
            New-StandardsFile -Rules @(New-Rule -Override @{ scope = $Scope })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports scope <Case>' -ForEach @(
            @{ Case = 'missing'; Scope = $null; Expected = "*scope*" }
            @{ Case = 'empty'; Scope = @(); Expected = "*scope*" }
            @{ Case = 'a word other than core'; Scope = 'all'; Expected = "*scope 'all'*core*" }
            @{ Case = 'naming an unknown app type'; Scope = @('wpf'); Expected = "*app type 'wpf'*app-types.yml*" }
            @{ Case = 'naming core in a list'; Scope = @('core', 'maui'); Expected = "*core*alone*" }
            @{ Case = 'listing every app type'; Scope = @('web-api', 'maui'); Expected = "*every app type*core*" }
        ) {
            $rule = if ($null -eq $Scope) { New-Rule -Remove 'scope' } else { New-Rule -Override @{ scope = $Scope } }
            New-StandardsFile -Rules @($rule)

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike $Expected
        }

        It 'reports the field projectTypes, which scope replaced' {
            New-StandardsFile -Rules @(New-Rule -Override @{ projectTypes = @('maui') })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*projectTypes*scope*"
        }

        It 'needs no scope on a retired rule' {
            New-StandardsFile -Rules @(New-Rule -Override @{ status = 'retired' } -Remove 'scope')

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports an app types file that <Case>' -ForEach @(
            @{ Case = 'is missing'; Yaml = $null; Expected = '*app-types.yml*missing*' }
            @{ Case = 'repeats an id'; Yaml = "types:`n  - { id: maui, name: A, docs: 'https://learn.microsoft.com/a' }`n  - { id: maui, name: B, docs: 'https://learn.microsoft.com/b' }"; Expected = "*app-types.yml*'maui'*more than once*" }
            @{ Case = 'has a type with no name'; Yaml = "types:`n  - { id: maui, docs: 'https://learn.microsoft.com/a' }"; Expected = "*app-types.yml*'maui'*name*" }
            @{ Case = 'has a type with no docs URL'; Yaml = "types:`n  - { id: maui, name: A, docs: 'see the docs' }"; Expected = "*app-types.yml*'maui'*docs*URL*" }
            @{ Case = 'names a type core'; Yaml = "types:`n  - { id: core, name: A, docs: 'https://learn.microsoft.com/a' }"; Expected = "*app-types.yml*'core'*reserved*" }
        ) {
            $path = Join-Path $script:standards 'app-types.yml'
            if ($null -eq $Yaml) { Remove-Item -LiteralPath $path } else { Set-Content -LiteralPath $path -Value $Yaml }
            New-StandardsFile

            (Get-Problem | ForEach-Object Message) -join "`n" | Should -BeLike $Expected
        }
    }

    # ADR-0063: enforcement is a list of parts, each a gate (a tool fails the change) or advisory (a person or the
    # reviewer agent checks it), in the kit, in apps or both.
    Context 'enforcement parts' {
        It 'accepts a gate and an advisory part with a reason' {
            New-StandardsFile -Rules @(New-Rule -Override @{
                    enforcement = @(
                        [ordered]@{ kind = 'gate'; in = @('kit'); how = 'ci: the sample''s tests' }
                        [ordered]@{ kind = 'advisory'; in = @('app'); how = 'until the app copies the sample''s tests' }
                    )
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports enforcement written as one string' {
            New-StandardsFile -Rules @(New-Rule -Override @{ enforcement = 'ci: a check' })

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*enforcement*list of parts*'
        }

        # Review 1 of PR 1: a single part not in a list, and a list of strings, were the likeliest mistakes.
        It 'reports enforcement written as one part, not a list' {
            New-StandardsFile -Rules @(New-Rule -Override @{ enforcement = [ordered]@{ kind = 'gate'; in = @('kit'); how = 'ci: a check' } })

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*enforcement*list of parts*'
        }

        It 'reports a part written as a string' {
            New-StandardsFile -Rules @(New-Rule -Override @{ enforcement = @('ci: a check') })

            (Get-Problem | ForEach-Object Message) | Should -BeLike "*part 'ci: a check'*kind, in and how*"
        }

        It 'reports in written as <In> (<Reason>)' -ForEach @(
            @{ In = 'kit'; Reason = 'a word, not a list'; Expected = "*in*list*" }
            @{ In = $null; Reason = 'no in key'; Expected = "*part*no 'in'*" }
            @{ In = @('kit', 'cloud'); Reason = 'one known place, one not'; Expected = "*in 'cloud'*kit, app*" }
            @{ In = @(''); Reason = 'a list holding only an empty value'; Expected = "*part*no 'in'*" }
        ) {
            $part = [ordered]@{ kind = 'gate'; in = $In; how = 'ci: a check' }
            if ($null -eq $In) { $part.Remove('in') }
            New-StandardsFile -Rules @(New-Rule -Override @{ enforcement = @($part) })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike $Expected
        }

        It 'reports a part whose <Field> is <Value>' -ForEach @(
            @{ Field = 'kind'; Value = 'maybe'; Expected = '*kind*maybe*gate, advisory*' }
            @{ Field = 'kind'; Value = $null; Expected = '*part*kind*' }
            @{ Field = 'in'; Value = @('cloud'); Expected = '*in*cloud*kit, app*' }
            @{ Field = 'in'; Value = @(); Expected = '*part*in*' }
            @{ Field = 'how'; Value = '  '; Expected = '*part*how*' }
        ) {
            $part = [ordered]@{ kind = 'gate'; in = @('kit'); how = 'ci: a check' }
            if ($null -eq $Value) { $part.Remove($Field) } else { $part[$Field] = $Value }
            New-StandardsFile -Rules @(New-Rule -Override @{ enforcement = @($part) })

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].RuleId | Should -Be 'GIT-001'
            $problems[0].Message | Should -BeLike $Expected
        }

        It 'reports a rule id used twice, across files' {
            New-StandardsFile -Name 'git'
            New-StandardsFile -Name 'testing'

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].File | Should -Be 'testing.md'
            $problems[0].Message | Should -BeLike '*GIT-001*git.md*'
        }
    }

    Context 'runner' {
        BeforeEach {
            Mock Write-Host {}
        }

        It 'returns 0 and says so when every rule is traceable' {
            New-StandardsFile

            Invoke-RuleSourceCheck -StandardsPath $script:standards -AdrPath $script:adr | Should -Be 0
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*1 rule*traceable*' }
        }

        It 'returns 1 and prints each problem with its file and rule id' {
            New-StandardsFile -Rules @(New-Rule -Override @{ sources = @('owner') })

            Invoke-RuleSourceCheck -StandardsPath $script:standards -AdrPath $script:adr | Should -Be 1
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*git.md*GIT-001*owner, YYYY-MM-DD*' }
        }

        It 'exits 1 when run as a script against a broken rule' {
            New-StandardsFile -Rules @(New-Rule -Remove 'enforcement')
            $script = Join-Path $PSScriptRoot '..' 'Test-RuleSources.ps1'

            $output = pwsh -NoProfile -File $script -StandardsPath $script:standards -AdrPath $script:adr 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'enforcement'
        }
    }
}
