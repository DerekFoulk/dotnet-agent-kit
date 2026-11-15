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

        It 'reports an authority rule that cites no authority''s or project''s page, but not one that cites practitioners too' {
            $entries = @(
                (New-Entry -Name 'Fowler' -Class 'practitioner' -Match 'https://martinfowler.com/')
                (New-Entry -Name 'Microsoft Learn' -Match 'https://learn.microsoft.com/')
                (New-Entry -Name 'axe-core' -Class 'project' -Match 'https://github.com/dequelabs/')
            )
            $cited = @(
                (New-Cited 'https://martinfowler.com/bliki/Yagni.html' -RuleId 'CRF-004')
                (New-Cited 'https://martinfowler.com/bliki/Yagni.html' -RuleId 'CRF-003')
                (New-Cited 'https://learn.microsoft.com/dotnet/architecture/x' -RuleId 'CRF-003')
                (New-Cited 'https://github.com/dequelabs/axe-core' -RuleId 'UI-002')
                (New-Cited 'https://martinfowler.com/articles/designDead.html' -RuleId 'CRF-009' -Basis 'preference')
            )

            @(Get-AuthoritiesProblem -Cited $cited -Entries $entries) |
                Should -Be @("CRF-004 has basis 'authority' but cites no page classed authority or project; cite one, or make it a preference (ADR-0063)")
        }
    }

    Context 'The generated block' {
        BeforeAll {
            $entries = @(
                (New-Entry -Name 'Fowler' -Publisher 'Martin Fowler' -Class 'practitioner' -Match 'https://martinfowler.com/')
                (New-Entry -Name 'Microsoft Learn' -Publisher 'Microsoft' -Match 'https://learn.microsoft.com/')
                (New-Entry -Name 'axe-core' -Publisher 'Deque Systems' -Class 'project' -Match 'https://github.com/dequelabs/')
            )
            $cited = @(
                [pscustomobject]@{ Url = 'https://learn.microsoft.com/b'; RuleId = 'SEC-002'; Status = 'accepted'; Basis = 'authority'; File = 'security.md' }
                [pscustomobject]@{ Url = 'https://learn.microsoft.com/a'; RuleId = 'API-002'; Status = 'accepted'; Basis = 'authority'; File = 'api-design.md' }
                [pscustomobject]@{ Url = 'https://learn.microsoft.com/a'; RuleId = 'API-001'; Status = 'proposed'; Basis = 'authority'; File = 'api-design.md' }
                [pscustomobject]@{ Url = 'https://learn.microsoft.com/b'; RuleId = 'API-002'; Status = 'accepted'; Basis = 'authority'; File = 'api-design.md' }
                [pscustomobject]@{ Url = 'https://github.com/dequelabs/axe-core'; RuleId = 'UI-002'; Status = 'proposed'; Basis = 'authority'; File = 'ui.md' }
                [pscustomobject]@{ Url = 'https://martinfowler.com/bliki/Yagni.html'; RuleId = 'CRF-004'; Status = 'accepted'; Basis = 'preference'; File = 'craft.md' }
            )
            $block = ConvertTo-AuthoritiesBlock -Cited $cited -Entries $entries
        }

        It 'lists the classes in order: authorities, then tool and project pages, then practitioners' {
            $block | Should -Match '(?s)### Authorities\n.*### Tool and project pages\n.*### Practitioners and references\n'
        }

        It 'gives each source a row in its class, with its publisher, what it covers and the rules citing it, each once and sorted' {
            $block | Should -Match '(?s)### Authorities\n.*\| \[Microsoft Learn\]\(#microsoft-learn\) \| Microsoft \| What Microsoft Learn covers \| \[API-001\]\(standards/api-design\.md\) \(proposed\), \[API-002\]\(standards/api-design\.md\), \[SEC-002\]\(standards/security\.md\) \|\n.*### Tool and project pages'
            $block | Should -Match '(?s)### Tool and project pages\n.*\| \[axe-core\]\(#axe-core\) \| Deque Systems \|.*### Practitioners'
            $block | Should -Match '(?s)### Practitioners and references\n.*\| \[Fowler\]\(#fowler\) \| Martin Fowler \|'
        }

        It 'lists each source''s pages, sorted, with the rules citing each' {
            $block | Should -Match '(?s)#### Microsoft Learn\n\n\| Page \| Cited by \|\n\|---\|---\|\n\| <https://learn\.microsoft\.com/a> \| \[API-001\]\(standards/api-design\.md\) \(proposed\), \[API-002\]\(standards/api-design\.md\) \|\n\| <https://learn\.microsoft\.com/b> \| \[API-002\]\(standards/api-design\.md\), \[SEC-002\]\(standards/security\.md\) \|\n'
        }

        It 'counts the pages, sources and rules' {
            $block | Should -Match 'The rules cite 4 pages from 3 sources; 5 rules cite them\.'
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
