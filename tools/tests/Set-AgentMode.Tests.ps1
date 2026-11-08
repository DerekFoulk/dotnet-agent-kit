#Requires -Version 7.0
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

        Set-AgentMode -Mode Auto -RepoRoot $root

        $settings = Read-LocalSettings $root
        @($settings['permissions']['ask']) | Should -Be @('Bash(rm *)')
        $settings['permissions']['allow'] | Should -Be @('Bash(npm test)')
        Join-Path $root '.agent-mode' | Should -Not -Exist
    }
}
