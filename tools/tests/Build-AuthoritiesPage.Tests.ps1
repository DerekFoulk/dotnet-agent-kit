#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

Describe 'Build-AuthoritiesPage.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Build-AuthoritiesPage.ps1')

        function New-Entry {
            param([string] $Name, [string[]] $Match, [string] $Class = 'authority', [string] $Publisher = 'Someone')
            [ordered]@{ name = $Name; publisher = $Publisher; class = $Class; covers = "What $Name covers"; match = $Match }
        }

        function New-Rule {
            param([string] $Id, [string[]] $Sources, [string] $Status = 'accepted', [string] $Basis = 'authority')
            [ordered]@{ id = $Id; statement = 'A rule.'; layer = 'outside'; basis = $Basis; status = $Status; sources = $Sources }
        }

        function New-StandardsFile {
            param([string] $Topic, [object[]] $Rules, [string] $Body = 'People text.')
            $frontMatter = ConvertTo-Yaml ([ordered]@{ topic = $Topic; rules = $Rules })
            Set-Content -Path (Join-Path $script:standards "$Topic.md") -Value "---`n$frontMatter---`n`n# $Topic`n`n$Body`n"
        }

        # The name of the entry a URL goes to, or $null, so a missing entry fails the assertion, not the test.
        function Get-EntryName([string] $Url, [object[]] $Entries) {
            $entry = Find-SourceEntry -Url $Url -Entries $Entries
            if ($entry) { $entry['name'] }
        }
    }

    BeforeEach {
        $script:standards = Join-Path $TestDrive "standards-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:standards | Out-Null
    }

    Context 'Reading the cited URLs' {
        It 'reads each rule''s URL sources from the front matter only, skipping owner and ADR sources and retired rules' {
            New-StandardsFile -Topic 'api' -Body 'See https://example.com/in-the-body for more.' -Rules @(
                (New-Rule -Id 'API-001' -Sources 'https://www.rfc-editor.org/rfc/rfc9457, retrieved 2026-11-01', 'ADR-0038', 'owner, 2026-11-01')
                (New-Rule -Id 'API-002' -Status 'proposed' -Sources 'https://learn.microsoft.com/aspnet/core/web-api, retrieved 2026-11-01')
                (New-Rule -Id 'API-003' -Status 'retired' -Sources 'https://retired.example.com/, retrieved 2026-11-01')
            )

            $cited = @(Get-CitedUrl -StandardsPath $script:standards)

            @($cited | ForEach-Object { "$($_.RuleId) $($_.Status) $($_.Url)" }) | Should -Be @(
                'API-001 accepted https://www.rfc-editor.org/rfc/rfc9457'
                'API-002 proposed https://learn.microsoft.com/aspnet/core/web-api'
            )
        }

        It 'reads one page cited with a Learn locale or a fragment as the same page' {
            New-StandardsFile -Topic 'arc' -Rules @(
                (New-Rule -Id 'ARC-001' -Sources 'https://learn.microsoft.com/en-us/dotnet/architecture/x, retrieved 2026-11-01')
                (New-Rule -Id 'ARC-009' -Sources 'https://learn.microsoft.com/dotnet/architecture/x#layers, retrieved 2026-11-01')
            )

            @(Get-CitedUrl -StandardsPath $script:standards | ForEach-Object Url | Sort-Object -Unique) |
                Should -Be @('https://learn.microsoft.com/dotnet/architecture/x')
        }
    }

    Context 'Problems' {
        BeforeAll {
            function New-Cited([string] $Url, [string] $RuleId = 'API-001', [string] $Basis = 'authority') {
                [pscustomobject]@{ Url = $Url; RuleId = $RuleId; Status = 'accepted'; Basis = $Basis; File = 'api.md' }
            }
        }

        It 'reports a cited URL that no entry matches, with the rule that cites it' {
            $entries = @(New-Entry -Name 'IETF' -Match 'https://www.rfc-editor.org/')
            $cited = @((New-Cited 'https://www.rfc-editor.org/rfc/rfc9457'), (New-Cited 'https://example.com/page' -RuleId 'API-004'))

            @(Get-AuthoritiesProblem -Cited $cited -Entries $entries) |
                Should -Be @("https://example.com/page (API-004) matches no entry in docs/authorities.yml; add its publisher there (ADR-0070)")
        }

        It 'reports an entry that matches no cited URL' {
            $entries = @((New-Entry -Name 'IETF' -Match 'https://www.rfc-editor.org/'), (New-Entry -Name 'Gone' -Match 'https://gone.example.com/'))

            @(Get-AuthoritiesProblem -Cited @(New-Cited 'https://www.rfc-editor.org/rfc/rfc9457') -Entries $entries) |
                Should -Be @("entry 'Gone' matches no URL the rules cite; remove it")
        }

        It 'reports an entry with <Case>' -ForEach @(
            @{ Case = 'no covers'; Change = { param($e) $e.Remove('covers') }; Message = "entry 'IETF' is missing 'covers'" }
            @{ Case = 'an unknown class'; Change = { param($e) $e['class'] = 'blog' }; Message = "entry 'IETF' class 'blog' must be one of: authority, practitioner, project" }
            @{ Case = 'a prefix that isn''t a folder URL'; Change = { param($e) $e['match'] = @('https://www.rfc-editor.org/rfc', 'https://www.rfc-editor.org/') }
                Message = "entry 'IETF' match 'https://www.rfc-editor.org/rfc' must be an http or https URL ending in '/'" }
        ) {
            $entry = New-Entry -Name 'IETF' -Match 'https://www.rfc-editor.org/'
            & $Change $entry

            @(Get-AuthoritiesProblem -Cited @(New-Cited 'https://www.rfc-editor.org/rfc/rfc9457') -Entries @($entry)) | Should -Be @($Message)
        }
    }

    Context 'Classing a cited URL' {
        It 'gives a URL to the entry with the longest matching prefix, whatever the order' {
            $entries = @(
                (New-Entry -Name 'Tool repos' -Class 'project' -Match 'https://github.com/')
                (New-Entry -Name 'OWASP' -Match 'https://cheatsheetseries.owasp.org/', 'https://github.com/OWASP/')
            )

            Get-EntryName 'https://github.com/OWASP/ASVS/blob/v5.0.0/x.md' $entries | Should -Be 'OWASP'
            Get-EntryName 'https://github.com/OWASP/ASVS/blob/v5.0.0/x.md' ($entries[1], $entries[0]) | Should -Be 'OWASP'
            Get-EntryName 'https://github.com/dequelabs/axe-core' $entries | Should -Be 'Tool repos'
            Find-SourceEntry -Url 'https://example.com/page' -Entries $entries | Should -BeNullOrEmpty
        }

        It 'classes an archived copy by its original URL, http or https' {
            $entries = @(
                (New-Entry -Name 'Archive' -Class 'practitioner' -Match 'https://web.archive.org/')
                (New-Entry -Name 'Robert C. Martin' -Class 'practitioner' -Match 'http://butunclebob.com/')
            )

            Get-EntryName 'https://web.archive.org/web/20220121055640/http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod' $entries |
                Should -Be 'Robert C. Martin'
            Get-EntryName 'https://web.archive.org/web/2022/https://example.com/x' $entries | Should -BeNullOrEmpty
        }
    }
}
