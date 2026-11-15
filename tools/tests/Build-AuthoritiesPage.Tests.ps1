#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

Describe 'Build-AuthoritiesPage.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Build-AuthoritiesPage.ps1')

        function New-Entry {
            param([string] $Name, [string[]] $Match, [string] $Class = 'authority', [string] $Publisher = 'Someone')
            [ordered]@{ name = $Name; publisher = $Publisher; class = $Class; covers = "What $Name covers"; match = $Match }
        }

        # The name of the entry a URL goes to, or $null, so a missing entry fails the assertion, not the test.
        function Get-EntryName([string] $Url, [object[]] $Entries) {
            $entry = Find-SourceEntry -Url $Url -Entries $Entries
            if ($entry) { $entry['name'] }
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
