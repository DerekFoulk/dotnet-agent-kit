#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# TestGit.psm1 gives every git repo a test makes the same settings, through environment variables that reach the
# scripts under test and the processes they start. The one exception: git strips the GIT_CONFIG_COUNT settings (and
# only those) from the receive-pack or upload-pack a push or fetch through a local path starts.
# Without them, a fixture commit could start git's background maintenance, whose repack raced New-KitApp.Tests'
# lookups of the fixture commit on Windows: 11 tests failed, but only for some file contents, since git's "enough
# loose objects?" estimate depends on hashes.

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

        # Review 2 of PR 24: the checks below read a file through PowerShell's own parser, so a comment or a string
        # is never taken for a command, and an option's position doesn't matter.
        function Get-FileAst([System.IO.FileInfo] $File) {
            [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref] $null, [ref] $null)
        }

        # The arguments of every git command (or a file's own Invoke-Git* wrapper) the file runs, one array each.
        # Command names are matched as PowerShell resolves them: in any case, with or without .exe.
        function Get-GitCall([System.IO.FileInfo] $File) {
            $commands = (Get-FileAst $File).FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -match '^(git|Invoke-Git\w*)(\.exe)?$'
                }, $true)
            foreach ($command in $commands) { , @($command.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text.Trim('''', '"') }) }
        }

        # The names of the commands the file's own BeforeAll or AfterAll (the one outside every Describe) runs
        # itself; a call inside a function it only defines doesn't count.
        function Get-FileLevelSetup([System.IO.FileInfo] $File, [string] $Block) {
            $root = Get-FileAst $File
            $blocks = $root.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq $Block }, $true)
            foreach ($call in $blocks) {
                $scope = $call.Parent
                while ($scope -isnot [System.Management.Automation.Language.ScriptBlockAst]) { $scope = $scope.Parent }
                if ($scope -ne $root) { continue }
                foreach ($body in $call.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }) {
                    $direct = $body.ScriptBlock.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | Where-Object {
                        $node = $_.Parent
                        while ($node -ne $body.ScriptBlock -and $node -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { $node = $node.Parent }
                        $node -eq $body.ScriptBlock
                    }
                    $direct | ForEach-Object { $_.GetCommandName() }
                }
            }
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

    It 'keeps this machine''s global and system git config out of every test repo, and puts it back after' {
        # Review 2 of PR 24: the settings above cover a handful of keys; any other global setting, such as a
        # core.hooksPath whose commit-msg hook rejects every commit, still reached every test repo.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $hooks = Join-Path $TestDrive "machine-hooks-$(New-Guid)"
        New-Item -ItemType Directory -Path $hooks | Out-Null
        $hook = Join-Path $hooks 'commit-msg'
        [IO.File]::WriteAllText($hook, "#!/bin/sh`necho 'machine hook rejected the commit' >&2`nexit 1`n")
        # Review 3 of PR 24: git skips a hook that isn't executable, so off Windows this half couldn't fail.
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($hook, 'UserRead, UserWrite, UserExecute') }
        $global = Join-Path $TestDrive "machine-global-$(New-Guid).gitconfig"
        $system = Join-Path $TestDrive "machine-system-$(New-Guid).gitconfig"
        [IO.File]::WriteAllText($global, "[core]`n`thooksPath = $($hooks -replace '\\', '/')`n[probe]`n`tglobal = machine`n")
        [IO.File]::WriteAllText($system, "[probe]`n`tsystem = machine`n")
        $machine = @{ GIT_CONFIG_GLOBAL = $global; GIT_CONFIG_SYSTEM = $system; GIT_CONFIG_NOSYSTEM = $null }
        $outer = @{}
        foreach ($name in $machine.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name) }
        Restore-TestGitEnvironment -Saved $machine
        try {
            $saved = Set-TestGitEnvironment
            try {
                $repo = New-TestRepo
                git -C $repo config --get probe.global | Should -BeNullOrEmpty -Because 'the machine''s global config is left out'
                git -C $repo config --get probe.system | Should -BeNullOrEmpty -Because 'the machine''s system config is left out'
                git -C $repo commit -q --allow-empty -m 'chore: fixture' 2>&1 | Out-Null
                $LASTEXITCODE | Should -Be 0 -Because 'the machine''s global hook doesn''t run'
            }
            finally { Restore-TestGitEnvironment -Saved $saved }

            foreach ($name in $machine.Keys) { [Environment]::GetEnvironmentVariable($name) | Should -Be $machine[$name] -Because "$name comes back" }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'starts no file-system monitor daemon for a test repo, even where this machine turns it on' {
        # Review of PR 24: with core.fsmonitor=true, every test repo got a daemon holding handles in TestDrive.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $saved = Set-TestGitEnvironment
        try {
            $repo = New-TestRepo
            git -C $repo config core.fsmonitor true
            git -C $repo config --get core.fsmonitor | Should -Be 'false'
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

    It 'stops with git''s reason when it can''t make the remote, rather than handing back a path to nothing' {
        # Review of PR 24: git's exit codes were ignored, so a later push failed far from the cause.
        Get-Command New-TestGitRemote -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $taken = Join-Path $TestDrive "taken-$(New-Guid).git"
        Set-Content -LiteralPath $taken -Value 'a file, not a folder'

        { New-TestGitRemote -Path $taken } | Should -Throw "*Couldn't make the test remote at*"
    }

    It 'is how every test file makes a bare remote' {
        # init or clone with --bare or --mirror, anywhere in the call (git --bare init too).
        $byHand = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' | Where-Object {
            $_.Name -ne 'TestGit.Tests.ps1' -and
            @(Get-GitCall $_ | Where-Object { ($_ -ccontains 'init' -or $_ -ccontains 'clone') -and ($_ -ccontains '--bare' -or $_ -ccontains '--mirror') }).Count -gt 0
        }

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
        # Review of PR 24: put back whatever the person running the tests had, rather than deleting it.
        $outer = @{}
        foreach ($name in $before.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name); Set-Item -LiteralPath "env:$name" -Value $before[$name] }
        try {
            $expected = Get-GitConfigEnvironment

            Restore-TestGitEnvironment -Saved (Set-TestGitEnvironment)

            (Get-GitConfigEnvironment).GetEnumerator() | ForEach-Object { $_.Value | Should -Be $expected[$_.Key] -Because $_.Key }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'is used by every test file that makes a git repo' {
        # A repo is made by git init or git clone, directly or through a file's own Invoke-Git wrapper; its commits
        # then run with the settings.
        # The setup runs in the file's own BeforeAll and AfterAll, so it wraps every Describe. TestGit.Tests.ps1 is
        # the exception: it tests the helper, setting and restoring it in each test.
        $makesRepos = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' | Where-Object {
            $_.Name -ne 'TestGit.Tests.ps1' -and @(Get-GitCall $_ | Where-Object { $_ -ccontains 'init' -or $_ -ccontains 'clone' }).Count -gt 0
        }

        @($makesRepos).Count | Should -BeGreaterThan 5
        foreach ($file in $makesRepos) {
            @(Get-FileLevelSetup $file 'BeforeAll') | Should -Contain 'Set-TestGitEnvironment' -Because "$($file.Name) makes git repos"
            @(Get-FileLevelSetup $file 'AfterAll') | Should -Contain 'Restore-TestGitEnvironment' -Because "$($file.Name) must put the environment back"
        }
    }
}
