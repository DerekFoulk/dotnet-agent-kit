#Requires -Version 7.6
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
            # git revert's default subject, recognized by Conventional Commits parsers.
            @{ Title = 'Revert "feat: add the bookmark tag endpoint"' }
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
            @{ Title = 'Revert "add tags"'; Reason = 'revert of a non-Conventional subject' }
            @{ Title = 'Revert feat: add tags'; Reason = 'revert without quotes' }
        ) {
            Get-TitleProblem -Title $Title | Should -BeLike '*Conventional Commit*'
        }
    }

    Context 'runner' {
        BeforeAll {
            # A small repo: main has one commit; the branch adds a good, a bad and a merge commit.
            $script:repo = Join-Path $TestDrive 'repo'
            New-Item -ItemType Directory -Path $script:repo | Out-Null
            function Invoke-Git { git -C $script:repo -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false @args 2>&1 | Out-Null }
            Invoke-Git init --quiet --initial-branch main
            Invoke-Git commit --quiet --allow-empty --message 'chore: initial'
            Invoke-Git switch --quiet -c work
            Invoke-Git commit --quiet --allow-empty --message 'feat: a good subject'
            Invoke-Git commit --quiet --allow-empty --message 'a bad subject'
            Invoke-Git switch --quiet main
            Invoke-Git switch --quiet -c side
            Invoke-Git commit --quiet --allow-empty --message 'fix: on the side'
            Invoke-Git switch --quiet work
            Invoke-Git merge --quiet --no-ff side --message "Merge branch 'side' into work"
        }

        BeforeEach {
            Mock Write-Host {}
        }

        It 'returns <Expected> for the title <Title>' -ForEach @(
            @{ Title = 'feat: add tags'; Expected = 0 }
            @{ Title = 'Add tags'; Expected = 1 }
        ) {
            Invoke-ConventionalTitleCheck -Title $Title | Should -Be $Expected
        }

        It 'checks every commit subject in a range, skipping merge commits' {
            Invoke-ConventionalTitleCheck -RepoPath $script:repo -Range 'main..work' | Should -Be 1

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like "*'a bad subject'*" } -Times 1 -Exactly
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like "*Merge branch*" } -Times 0 -Exactly
        }

        It 'exits 1 as a script given nothing to check, rather than passing on zero titles' {
            $script = Join-Path $PSScriptRoot '..' 'Test-ConventionalTitle.ps1'

            $output = pwsh -NoProfile -File $script 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match '-Title|-Range'
        }

        It 'exits 1 when run as a script with a bad title' {
            $script = Join-Path $PSScriptRoot '..' 'Test-ConventionalTitle.ps1'

            $output = pwsh -NoProfile -File $script -Title 'Add tags' 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'Conventional Commit'
        }
    }
}
