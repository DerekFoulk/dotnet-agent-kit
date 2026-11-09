#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# TestGit.psm1 gives every git repo a test makes the same settings, through git's GIT_CONFIG_COUNT environment
# variables, which reach the scripts under test and any process they start. Without them, a fixture commit could
# start git's background maintenance, whose repack raced New-KitApp.Tests' lookups of the fixture commit on Windows:
# 11 tests failed, but only for some file contents, since git's "enough loose objects?" estimate depends on hashes.

Describe 'TestGit.psm1' {
    BeforeAll {
        $module = Join-Path $PSScriptRoot 'TestGit.psm1'
        if (Test-Path $module) { Import-Module $module -Force }

        function Get-GitConfigEnvironment {
            $names = @('GIT_CONFIG_COUNT') + (0..15 | ForEach-Object { "GIT_CONFIG_KEY_$_"; "GIT_CONFIG_VALUE_$_" })
            $values = [ordered]@{}
            foreach ($name in $names) { $values[$name] = [Environment]::GetEnvironmentVariable($name) }
            $values
        }

        function New-TestRepo {
            $repo = Join-Path $TestDrive "repo-$(New-Guid)"
            git init -q -b main $repo
            $repo
        }
    }

    AfterAll {
        Remove-Module TestGit -ErrorAction SilentlyContinue
    }

    It 'turns off git''s background maintenance in every repo a test makes, so a repack can''t race the test' {
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $saved = Set-TestGitEnvironment
        try {
            $repo = New-TestRepo
            git -C $repo config --get maintenance.auto | Should -Be 'false'
            git -C $repo config --get gc.auto | Should -Be '0'
        }
        finally { Restore-TestGitEnvironment -Saved $saved }
    }

    It 'makes a bare "remote" that a test can push into without starting background maintenance' {
        # git strips GIT_CONFIG_COUNT from the receive-pack a local push starts, so the remote needs its own config.
        # git's trace shows every git process a push starts, receive-pack's own included.
        Get-Command New-TestGitRemote -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $saved = Set-TestGitEnvironment
        $trace = Join-Path $TestDrive "push-trace-$(New-Guid).jsonl"
        $outerTrace = $env:GIT_TRACE2_EVENT
        try {
            $remote = New-TestGitRemote -Path (Join-Path $TestDrive "remote-$(New-Guid).git")
            $repo = New-TestRepo
            git -C $repo commit -q --allow-empty -m 'chore: fixture'
            $env:GIT_TRACE2_EVENT = $trace
            git -C $repo push -q $remote main 2>&1 | Out-Null
            $pushExit = $LASTEXITCODE
            $env:GIT_TRACE2_EVENT = $outerTrace

            $pushExit | Should -Be 0
            git -C $remote rev-parse --verify --quiet refs/heads/main | Should -Not -BeNullOrEmpty -Because 'the push landed'
            $started = @(Get-Content -LiteralPath $trace | ConvertFrom-Json | Where-Object event -EQ 'start' | ForEach-Object { $_.argv -join ' ' })
            $started | Should -Not -BeNullOrEmpty -Because 'the trace recorded the push'
            $started | Where-Object { $_ -match ' (maintenance|gc|repack)( |$)' } | Should -BeNullOrEmpty
        }
        finally { $env:GIT_TRACE2_EVENT = $outerTrace; Restore-TestGitEnvironment -Saved $saved }
    }

    It 'is how every test file makes a bare remote' {
        $byHand = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' |
            Where-Object { $_.Name -ne 'TestGit.Tests.ps1' -and (Get-Content -Raw -LiteralPath $_.FullName) -cmatch '\bgit\b[^\r\n]*\binit\b[^\r\n]*--bare\b' }

        @($byHand.Name) | Should -BeNullOrEmpty -Because 'New-TestGitRemote gives a remote the settings a push needs'
    }

    It 'commits as the fixture, unsigned, whatever this machine''s own git identity and signing are' {
        # Review of PR 24: author.* and committer.* config, and the GIT_AUTHOR_* and GIT_COMMITTER_* variables, all
        # rank above user.name, so a machine that sets any of them changed every fixture commit.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $machine = @{ GIT_AUTHOR_NAME = 'Env Author'; GIT_AUTHOR_EMAIL = 'env@example.invalid'; GIT_COMMITTER_NAME = 'Env Committer'; GIT_COMMITTER_EMAIL = 'env@example.invalid' }
        $outer = @{}
        foreach ($name in $machine.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name); Set-Item -LiteralPath "env:$name" -Value $machine[$name] }
        try {
            $saved = Set-TestGitEnvironment
            try {
                $repo = New-TestRepo
                git -C $repo config user.name 'someone else'
                git -C $repo config author.name 'Config Author'
                git -C $repo config committer.email 'config@example.invalid'
                git -C $repo config commit.gpgsign true
                git -C $repo commit -q --allow-empty -m 'chore: fixture'

                $LASTEXITCODE | Should -Be 0 -Because 'no signing key is needed'
                git -C $repo log -1 --format='%an <%ae> %cn <%ce>' | Should -Be 'fixture <fixture@example.invalid> fixture <fixture@example.invalid>'
            }
            finally { Restore-TestGitEnvironment -Saved $saved }

            foreach ($name in $machine.Keys) { [Environment]::GetEnvironmentVariable($name) | Should -Be $machine[$name] -Because "$name comes back" }
        }
        finally {
            foreach ($name in $machine.Keys) {
                if ($null -eq $outer[$name]) { Remove-Item -LiteralPath "env:$name" -ErrorAction SilentlyContinue }
                else { Set-Item -LiteralPath "env:$name" -Value $outer[$name] }
            }
        }
    }

    It 'puts back exactly the environment it found, including settings someone else set the same way' {
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $before = @{ GIT_CONFIG_COUNT = '1'; GIT_CONFIG_KEY_0 = 'core.example'; GIT_CONFIG_VALUE_0 = 'kept' }
        foreach ($name in $before.Keys) { [Environment]::SetEnvironmentVariable($name, $before[$name]) }
        try {
            $expected = Get-GitConfigEnvironment

            Restore-TestGitEnvironment -Saved (Set-TestGitEnvironment)

            (Get-GitConfigEnvironment).GetEnumerator() | ForEach-Object { $_.Value | Should -Be $expected[$_.Key] -Because $_.Key }
        }
        finally { foreach ($name in $before.Keys) { Remove-Item -LiteralPath "env:$name" -ErrorAction SilentlyContinue } }
    }

    It 'is used by every test file that makes a git repo' {
        # A repo is made by git init or git clone, directly or through a file's own Invoke-Git wrapper; its commits
        # then run with the settings.
        $makesRepos = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' |
            Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -cmatch '\b(git|Invoke-Git)\b(?:\s+-[Cc]\s+\S+)*\s+(init|clone)\b' }

        @($makesRepos).Count | Should -BeGreaterThan 5
        foreach ($file in $makesRepos) {
            Get-Content -Raw -LiteralPath $file.FullName | Should -Match 'Set-TestGitEnvironment' -Because "$($file.Name) makes git repos"
        }
    }
}
