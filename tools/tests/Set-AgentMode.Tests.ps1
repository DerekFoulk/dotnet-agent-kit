#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Two working modes (ADR-0035). Auto, the default: the agent plans, builds and merges its own PRs, asking only
# for the hard limits. Review: the owner approves plans and merges, as before. Set-AgentMode.ps1 switches: review
# mode writes .agent-mode and adds the ask rules to the owner's own .claude/settings.local.json, which Claude Code
# merges with the project's settings (an ask rule from any file beats an allow rule).

Describe 'Set-AgentMode.ps1' {
    BeforeAll {
        $script = Join-Path $PSScriptRoot '..' 'Set-AgentMode.ps1'
        if (Test-Path -LiteralPath $script) { . $script }

        function New-Repo {
            $root = Join-Path $TestDrive "repo-$(New-Guid)"
            New-Item -ItemType Directory -Path (Join-Path $root '.claude') -Force | Out-Null
            $root
        }

        function Read-LocalSettings([string] $Root) {
            $path = Join-Path $Root '.claude' 'settings.local.json'
            if (Test-Path -LiteralPath $path) { Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable }
        }
    }

    It 'review mode adds the review ask rules to the local settings and keeps what was there' {
        Get-Command Set-AgentMode -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because 'Set-AgentMode.ps1 switches modes'
        $root = New-Repo
        $existing = [ordered]@{ permissions = [ordered]@{ allow = @('Bash(npm test)'); ask = @('Bash(rm *)') }; spinnerTipsEnabled = $false }
        Set-Content -LiteralPath (Join-Path $root '.claude' 'settings.local.json') -Value ($existing | ConvertTo-Json -Depth 5)

        Set-AgentMode -Mode Review -RepoRoot $root

        $settings = Read-LocalSettings $root
        $settings['spinnerTipsEnabled'] | Should -BeFalse
        $settings['permissions']['allow'] | Should -Be @('Bash(npm test)')
        $settings['permissions']['ask'] | Should -Contain 'Bash(rm *)'
        foreach ($rule in $script:ReviewAskRules) { $settings['permissions']['ask'] | Should -Contain $rule }
        $script:ReviewAskRules | Should -Contain 'Bash(gh pr merge *)'
    }

    It 'review mode writes the mode to .agent-mode, which every agent reads' {
        $root = New-Repo

        Set-AgentMode -Mode Review -RepoRoot $root

        Join-Path $root '.agent-mode' | Should -Exist
        (Get-Content -Raw -LiteralPath (Join-Path $root '.agent-mode')).Trim() | Should -Be 'review'
    }

    It 'auto mode removes only the review rules and the mode file, and running review twice adds nothing twice' {
        $root = New-Repo
        $existing = [ordered]@{ permissions = [ordered]@{ allow = @('Bash(npm test)'); ask = @('Bash(rm *)') } }
        Set-Content -LiteralPath (Join-Path $root '.claude' 'settings.local.json') -Value ($existing | ConvertTo-Json -Depth 5)

        Set-AgentMode -Mode Review -RepoRoot $root
        Set-AgentMode -Mode Review -RepoRoot $root
        @((Read-LocalSettings $root)['permissions']['ask'] | Where-Object { $_ -eq 'Bash(gh pr merge *)' }) | Should -HaveCount 1
        # Hidden, as it is on Linux and macOS, so a missing -Force fails here on Windows too (review 4 of PR 19).
        if ($IsWindows) { (Get-Item -LiteralPath (Join-Path $root '.agent-mode') -Force).Attributes = 'Hidden' }

        Set-AgentMode -Mode Auto -RepoRoot $root

        $settings = Read-LocalSettings $root
        @($settings['permissions']['ask']) | Should -Be @('Bash(rm *)')
        $settings['permissions']['allow'] | Should -Be @('Bash(npm test)')
        Join-Path $root '.agent-mode' | Should -Not -Exist
    }

    It 'keeps ask a JSON list, as Claude Code''s settings schema requires, with <Case>' -ForEach @(
        @{ Case = 'one rule of the owner''s'; Own = @('Bash(rm *)') }
        @{ Case = 'no rules of the owner''s'; Own = @() }
    ) {
        # Review 1 of the modes PR: auto mode wrote "ask": null or "ask": "Bash(rm *)", which the schema rejects,
        # so every session would start with a settings error.
        $root = New-Repo
        $existing = [ordered]@{ permissions = [ordered]@{ ask = $Own } }
        Set-Content -LiteralPath (Join-Path $root '.claude' 'settings.local.json') -Value (ConvertTo-Json -InputObject $existing -Depth 5)

        Set-AgentMode -Mode Review -RepoRoot $root
        Set-AgentMode -Mode Auto -RepoRoot $root

        $raw = Get-Content -Raw -LiteralPath (Join-Path $root '.claude' 'settings.local.json')
        $raw | Should -Match '"ask":\s*\[' -Because 'ask must stay a list'
        ($raw | ConvertFrom-Json).permissions.ask | Should -Be $Own
    }

    It 'takes no positional mode as a function either' {
        # Review 2 of the modes PR: ". ./tools/Set-AgentMode.ps1; Set-AgentMode Review ." matched no ask rule.
        $root = New-Repo

        { Set-AgentMode Review $root } | Should -Throw
        Join-Path $root '.agent-mode' | Should -Not -Exist
    }

    It 'removes the hidden .agent-mode on every system when switching to auto with no local settings' {
        # Review 2 of the modes PR: on Linux and macOS a dotfile is hidden, and Remove-Item refuses it without
        # -Force, so CI failed and a switch could stop halfway. This path had no test.
        $root = New-Repo
        Set-Content -LiteralPath (Join-Path $root '.agent-mode') -Value 'review'
        # Hidden on Windows too, so the test catches a missing -Force here as well as on Linux CI (review 3).
        if ($IsWindows) { (Get-Item -LiteralPath (Join-Path $root '.agent-mode') -Force).Attributes = 'Hidden' }

        Set-AgentMode -Mode Auto -RepoRoot $root

        Join-Path $root '.agent-mode' | Should -Not -Exist
    }

    It 'removes the mode file before rewriting the prompts, so a failed switch to auto leaves them on' {
        # Review 3 of PR 19: nothing tested the order. A read-only local file makes the rewrite fail.
        $root = New-Repo
        Set-AgentMode -Mode Review -RepoRoot $root
        $local = Get-Item -LiteralPath (Join-Path $root '.claude' 'settings.local.json')
        $local.IsReadOnly = $true
        try {
            { Set-AgentMode -Mode Auto -RepoRoot $root } | Should -Throw
            Join-Path $root '.agent-mode' | Should -Not -Exist -Because 'the mode file goes first'
            (Read-LocalSettings $root)['permissions']['ask'] | Should -Contain 'Bash(gh pr merge *)' -Because 'the prompts stay on'
        }
        finally { $local.IsReadOnly = $false }
    }

    It 'leaves no local settings behind when switching to auto, the default, if there were none' {
        $root = New-Repo

        Set-AgentMode -Mode Auto -RepoRoot $root

        Join-Path $root '.claude' 'settings.local.json' | Should -Not -Exist
    }

    It 'reads the mode: auto when there is no .agent-mode, review after switching' {
        Get-Command Get-AgentMode -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because 'agents and the owner check the mode'
        $root = New-Repo

        Get-AgentMode -RepoRoot $root | Should -Be 'auto'
        Set-AgentMode -Mode Review -RepoRoot $root
        Get-AgentMode -RepoRoot $root | Should -Be 'review'
    }

    It 'refuses local settings it can''t read, and leaves them and the mode as they were' {
        # Overwriting a file Claude Code can't parse would lose the owner's own rules.
        $root = New-Repo
        $path = Join-Path $root '.claude' 'settings.local.json'
        Set-Content -LiteralPath $path -Value '{ "permissions": { "allow": [ "Bash(npm test)", ] }' -NoNewline

        $message = $null
        try { Set-AgentMode -Mode Review -RepoRoot $root } catch { $message = "$_" }

        $message | Should -BeLike '*settings.local.json*'
        Get-Content -Raw -LiteralPath $path | Should -Be '{ "permissions": { "allow": [ "Bash(npm test)", ] }'
        Join-Path $root '.agent-mode' | Should -Not -Exist
    }

    It 'is kept out of commits: git ignores <Path>, here and in every app (which copies .gitignore)' -ForEach @(
        @{ Path = '.agent-mode' }, @{ Path = '.claude/settings.local.json' }
    ) {
        # Each person's mode is their own; a committed review mode would switch everyone.
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        # Only the repo's own .gitignore counts: Claude Code may also add the local settings to this machine's
        # global excludes, which CI and an app's other clones don't have.
        $noGlobal = Join-Path $TestDrive 'no-global-excludes'
        git -C $repoRoot -c "core.excludesFile=$noGlobal" check-ignore --no-index -q $Path
        $LASTEXITCODE | Should -Be 0 -Because "$Path must be in .gitignore"
    }

    Context 'run as a command' {
        It 'takes no positional mode, so a switch always shows -Mode for the ask rule to catch' {
            # Review 1 of the modes PR: "Set-AgentMode.ps1 Auto" would switch without matching '*-M*'.
            $root = New-Repo

            pwsh -NoProfile -File $script Review -RepoRoot $root 2>&1 | Out-Null

            $LASTEXITCODE | Should -Not -Be 0
            Join-Path $root '.agent-mode' | Should -Not -Exist
        }

        It 'exits 1 with the reason when it refuses' {
            $root = New-Repo
            Set-Content -LiteralPath (Join-Path $root '.claude' 'settings.local.json') -Value '[1, 2]'

            $output = pwsh -NoProfile -File $script -Mode Review -RepoRoot $root 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1
            $output | Should -Match "shape of Claude Code settings"
        }

        It 'switches with -Mode and says which mode is on; without -Mode it only reports' {
            $root = New-Repo

            $report = pwsh -NoProfile -File $script -RepoRoot $root 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $report | Should -Match 'auto'
            Join-Path $root '.agent-mode' | Should -Not -Exist -Because 'reporting changes nothing'

            $switched = pwsh -NoProfile -File $script -Mode Review -RepoRoot $root 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $switched | Should -Match 'review'
            Get-AgentMode -RepoRoot $root | Should -Be 'review'
        }
    }
}
