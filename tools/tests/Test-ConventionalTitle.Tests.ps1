#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Test-ConventionalTitle.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-ConventionalTitle.ps1')
    }

    Context 'Get-TitleProblem' {
        It 'accepts <Title>' -ForEach @(
            @{ Title = 'feat: add the bookmark tag endpoint' }
            @{ Title = 'fix(api): keep one bookmark per URL' }
            @{ Title = 'feat!: drop the v1 routes' }
            @{ Title = 'chore(deps): bump MinVer to 8.0.1' }
            @{ Title = 'ci: run the kit checks on every PR' }
            @{ Title = 'refactor: share front-matter reading' }
        ) {
            Get-TitleProblem -Title $Title | Should -BeNullOrEmpty
        }

        It 'rejects <Title> (<Reason>)' -ForEach @(
            @{ Title = 'Add the bookmark tag endpoint'; Reason = 'no type' }
            @{ Title = 'feature: add tags'; Reason = 'unknown type' }
            @{ Title = 'Feat: add tags'; Reason = 'type not lower case' }
            @{ Title = 'feat:add tags'; Reason = 'no space after the colon' }
            @{ Title = 'feat: '; Reason = 'empty description' }
            @{ Title = 'feat(): add tags'; Reason = 'empty scope' }
        ) {
            Get-TitleProblem -Title $Title | Should -BeLike '*Conventional Commit*'
        }
    }
}
