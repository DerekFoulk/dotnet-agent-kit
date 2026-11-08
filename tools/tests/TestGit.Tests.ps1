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

    It 'commits as the fixture, unsigned, whatever this machine''s own git identity and signing are' {
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $saved = Set-TestGitEnvironment
        try {
            $repo = New-TestRepo
            # A repo's own config is below the environment's, so it can't win either.
            git -C $repo config user.name 'someone else'
            git -C $repo config commit.gpgsign true
            git -C $repo commit -q --allow-empty -m 'chore: fixture'

            $LASTEXITCODE | Should -Be 0 -Because 'no signing key is needed'
            git -C $repo log -1 --format='%an <%ae> %cn <%ce>' | Should -Be 'fixture <fixture@example.invalid> fixture <fixture@example.invalid>'
        }
        finally { Restore-TestGitEnvironment -Saved $saved }
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
        finally { foreach ($name in $before.Keys) { [Environment]::SetEnvironmentVariable($name, $null) } }
    }

    It 'is used by every test file that makes a git repo or commit' {
        $makesRepos = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' |
            Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -match '\bgit\b[^\r\n]*\s(init|commit|commit-tree)\b' }

        @($makesRepos).Count | Should -BeGreaterThan 5
        foreach ($file in $makesRepos) {
            Get-Content -Raw -LiteralPath $file.FullName | Should -Match 'Set-TestGitEnvironment' -Because "$($file.Name) makes git repos"
        }
    }
}
