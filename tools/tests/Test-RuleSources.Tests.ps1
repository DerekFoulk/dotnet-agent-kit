#Requires -Version 7.0
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
                status      = 'accepted'
                sources     = @('owner, 2026-10-26', 'ADR-0007')
                enforcement = 'ruleset: merge-method rule (merge commit only)'
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
            @{ Field = 'id' }, @{ Field = 'statement' }, @{ Field = 'layer' },
            @{ Field = 'status' }, @{ Field = 'sources' }, @{ Field = 'enforcement' }
        ) {
            New-StandardsFile -Rules @(New-Rule -Remove $Field)

            $problems = Get-Problem

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike "*$Field*"
            $problems[0].File | Should -Be 'git.md'
        }

        It 'reports an empty sources list' {
            New-StandardsFile -Rules @(New-Rule -Override @{ sources = @() })

            (Get-Problem).Message | Should -BeLike '*sources*'
        }

        It 'reports a standards file with no front matter' {
            Set-Content -Path (Join-Path $script:standards 'loose.md') -Value '# No front matter'

            (Get-Problem).Message | Should -BeLike '*front matter*'
        }

        It 'reports a standards file whose front matter has no rules' {
            Set-Content -Path (Join-Path $script:standards 'empty.md') -Value "---`ntopic: empty`n---`n"

            (Get-Problem).Message | Should -BeLike '*no rules*'
        }
    }
}
