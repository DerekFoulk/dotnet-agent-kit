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
            New-StandardsFile -Rules @(New-Rule -Override @{ sources = @($Source); basis = $Basis })

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
            @{ Layer = 'floor'; Status = 'proposed' }
            @{ Layer = 'owner'; Status = 'accepted' }
            @{ Layer = 'outside'; Status = 'retired' }
        ) {
            New-StandardsFile -Rules @(New-Rule -Override @{ layer = $Layer; status = $Status })

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
                    basis = 'authority'; sources = @('https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-01')
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'accepts an authority rule that cites an http URL' {
            New-StandardsFile -Rules @(New-Rule -Override @{
                    basis = 'authority'; sources = @('http://example.com/guide, retrieved 2026-11-01')
                })

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports an authority rule that cites no URL' {
            New-StandardsFile -Rules @(New-Rule -Override @{ basis = 'authority'; sources = @('owner, 2026-10-26', 'ADR-0007') })

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*authority*URL*'
        }

        It 'reports a preference that cites neither the owner nor an ADR' {
            New-StandardsFile -Rules @(New-Rule -Override @{
                    sources = @('https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-01')
                })

            (Get-Problem | ForEach-Object Message) | Should -BeLike '*preference*owner*ADR*'
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
