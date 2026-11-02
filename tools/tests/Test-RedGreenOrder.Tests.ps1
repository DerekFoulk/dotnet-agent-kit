#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeDiscovery {
    # -ForEach data is built at discovery time, before BeforeAll runs.
    function New-TddCommit([string] $Hash, [string] $Marker) {
        [pscustomobject]@{ Hash = $Hash; Subject = "subject $Hash"; Marker = $Marker }
    }
}

Describe 'Test-RedGreenOrder.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-RedGreenOrder.ps1')

        function New-TddCommit([string] $Hash, [string] $Marker) {
            [pscustomobject]@{ Hash = $Hash; Subject = "subject $Hash"; Marker = $Marker }
        }
    }

    Context 'Get-RedGreenProblem' {
        It 'passes <Case>' -ForEach @(
            @{ Case = 'a red followed by a green'; Commits = @((New-TddCommit 'a1' 'red'), (New-TddCommit 'b2' 'green')) }
            @{ Case = 'several reds closed by one green'; Commits = @((New-TddCommit 'a1' 'red'), (New-TddCommit 'b2' 'red'), (New-TddCommit 'c3' 'green')) }
            @{ Case = 'commits with no marker in between'; Commits = @((New-TddCommit 'a1' 'red'), (New-TddCommit 'x0' $null), (New-TddCommit 'b2' 'green'), (New-TddCommit 'y0' $null)) }
            @{ Case = 'a range with no TDD commits'; Commits = @((New-TddCommit 'x0' $null), (New-TddCommit 'y0' $null)) }
            @{ Case = 'two cycles in a row'; Commits = @((New-TddCommit 'a1' 'red'), (New-TddCommit 'b2' 'green'), (New-TddCommit 'c3' 'red'), (New-TddCommit 'd4' 'green')) }
        ) {
            @(Get-RedGreenProblem -Commits $Commits) | Should -BeNullOrEmpty
        }

        It 'reports <Case>' -ForEach @(
            @{ Case = 'a green with no red before it'; Commits = @((New-TddCommit 'b2' 'green')); Expected = '*b2*green*no red*' }
            @{ Case = 'a red never made green'; Commits = @((New-TddCommit 'a1' 'red'), (New-TddCommit 'x0' $null)); Expected = '*a1*red*never*green*' }
            @{ Case = 'a second green after its red was closed'; Commits = @((New-TddCommit 'a1' 'red'), (New-TddCommit 'b2' 'green'), (New-TddCommit 'c3' 'green')); Expected = '*c3*green*no red*' }
            @{ Case = 'an unknown marker value'; Commits = @((New-TddCommit 'a1' 'blue')); Expected = "*a1*'blue'*" }
        ) {
            $problems = @(Get-RedGreenProblem -Commits $Commits)

            $problems.Count | Should -Be 1
            $problems[0] | Should -BeLike $Expected
        }
    }

    Context 'reading markers from git' {
        BeforeAll {
            $script:repo = Join-Path $TestDrive 'repo'
            New-Item -ItemType Directory -Path $script:repo | Out-Null
            function Invoke-Git { git -C $script:repo -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false @args 2>&1 | Out-Null }
            Invoke-Git init --quiet --initial-branch main
            Invoke-Git commit --quiet --allow-empty --message 'chore: initial'
            Invoke-Git switch --quiet -c work
            # A real trailer: TDD shares the final paragraph with Co-Authored-By.
            Invoke-Git commit --quiet --allow-empty --message 'test: trailer red' --message "TDD: red`nCo-Authored-By: A <a@example.invalid>"
            # The older form: TDD in its own paragraph, so git doesn't read it as a trailer.
            Invoke-Git commit --quiet --allow-empty --message 'feat: legacy green' --message 'TDD: green' --message 'Co-Authored-By: A <a@example.invalid>'
            Invoke-Git commit --quiet --allow-empty --message 'docs: no marker'
            Invoke-Git switch --quiet main
            Invoke-Git switch --quiet -c side
            Invoke-Git commit --quiet --allow-empty --message 'test: side red' --message 'TDD: red'
            Invoke-Git switch --quiet work
            Invoke-Git merge --quiet --no-ff side --message 'Merge side'
        }

        It 'reads the trailer, the older body line, and no marker, oldest first, skipping merge commits' {
            $commits = @(Get-TddCommit -RepoPath $script:repo -Range 'main..work')

            ($commits | ForEach-Object Subject) | Should -Be @('test: trailer red', 'feat: legacy green', 'docs: no marker', 'test: side red')
            ($commits | ForEach-Object { "$($_.Marker)" }) | Should -Be @('red', 'green', '', 'red')
        }
    }

    Context 'runner' {
        BeforeEach {
            Mock Write-Host {}
        }

        It 'exits 1 as a script when a red is never made green' {
            $repo = Join-Path $TestDrive "runner-$(New-Guid)"
            New-Item -ItemType Directory -Path $repo | Out-Null
            git -C $repo init --quiet --initial-branch main 2>&1 | Out-Null
            git -C $repo -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit --quiet --allow-empty --message 'chore: initial' 2>&1 | Out-Null
            git -C $repo -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit --quiet --allow-empty --message 'test: red' --message 'TDD: red' 2>&1 | Out-Null
            $script = Join-Path $PSScriptRoot '..' 'Test-RedGreenOrder.ps1'

            $output = pwsh -NoProfile -File $script -RepoPath $repo -Range 'HEAD~1..HEAD' 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'never'
        }

        It 'returns 0 and counts the cycles when every red is made green' {
            Invoke-RedGreenCheck -Commits @((New-TddCommit 'a1' 'red'), (New-TddCommit 'b2' 'green')) | Should -Be 0
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*1 red*1 green*' }
        }
    }
}
