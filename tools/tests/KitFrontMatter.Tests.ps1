#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

Describe 'KitFrontMatter.psm1' {
    BeforeAll {
        Import-Module -Name (Join-Path $PSScriptRoot '..' 'KitFrontMatter.psm1') -Force

        function New-MarkdownFile([string] $Text) {
            $path = Join-Path $TestDrive "file-$(New-Guid).md"
            Set-Content -Path $path -Value $Text -NoNewline
            $path
        }
    }

    Context 'Read-FrontMatter' {
        It 'reads the YAML between the delimiters' {
            $frontMatter = Read-FrontMatter -Path (New-MarkdownFile "---`ntopic: git`n---`n# Git`n")

            $frontMatter['topic'] | Should -Be 'git'
        }

        It 'returns $null for a file with no front matter' {
            Read-FrontMatter -Path (New-MarkdownFile "# Git`n") | Should -BeNullOrEmpty
        }

        It 'returns an empty map for an empty front matter block' {
            $frontMatter = Read-FrontMatter -Path (New-MarkdownFile "---`n---`n# Git`n")

            # A block that exists isn't "no front matter": callers can still report a missing key.
            $frontMatter -is [System.Collections.IDictionary] | Should -BeTrue
            $frontMatter.Count | Should -Be 0
        }
    }

    Context 'Read-MarkdownBody' {
        It 'returns the text after the front matter' {
            Read-MarkdownBody -Path (New-MarkdownFile "---`ntopic: git`n---`n# Git`n`nText.`n") | Should -Be "# Git`n`nText."
        }

        It 'returns an empty body when the file ends at the closing delimiter' {
            Read-MarkdownBody -Path (New-MarkdownFile "---`ntopic: git`n---`n") | Should -Be ''
        }

        It 'returns the whole text when there is no front matter' {
            Read-MarkdownBody -Path (New-MarkdownFile "# Git`n`nText.`n") | Should -Be "# Git`n`nText."
        }
    }
}
