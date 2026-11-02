#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

# Guards the repo's agent configuration: a silently dropped deny rule or a broken skill is a real gap.

Describe 'Agent configuration' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        Import-Module -Name (Join-Path $repoRoot 'tools' 'KitFrontMatter.psm1') -Force

        function Get-Json([string] $RelativePath) {
            $path = Join-Path $repoRoot $RelativePath
            if (-not (Test-Path $path)) { return $null }
            Get-Content -Path $path -Raw | ConvertFrom-Json -AsHashtable
        }

        $settings = Get-Json '.claude/settings.json'
        $permissions = if ($settings -and $settings.ContainsKey('permissions')) { $settings['permissions'] } else { @{} }
        function Get-RuleList([string] $Kind) {
            if ($permissions.ContainsKey($Kind)) { @($permissions[$Kind]) } else { @() }
        }
    }

    Context '.claude/settings.json permissions' {
        It 'denies <Rule>' -ForEach @(
            @{ Rule = 'Read(./.env)' }
            @{ Rule = 'Read(./.env.*)' }
            @{ Rule = 'Read(~/.ssh/**)' }
            @{ Rule = 'Bash(git push --force *)' }
            @{ Rule = 'PowerShell(git push --force *)' }
            @{ Rule = 'Bash(git push * main)' }
            @{ Rule = 'PowerShell(git push * main)' }
            @{ Rule = 'Bash(git * --no-verify*)' }
            @{ Rule = 'PowerShell(git * --no-verify*)' }
        ) {
            Get-RuleList 'deny' | Should -Contain $Rule
        }

        It 'asks before <Rule>' -ForEach @(
            @{ Rule = 'Bash(gh pr merge *)' }
            @{ Rule = 'PowerShell(gh pr merge *)' }
            @{ Rule = 'Edit(./Directory.Packages.props)' }
            @{ Rule = 'Edit(./.github/workflows/**)' }
            @{ Rule = 'Edit(./.claude/settings.json)' }
            @{ Rule = 'PowerShell(Install-PSResource *)' }
            @{ Rule = 'PowerShell(winget install *)' }
            # Initialize-DevMachine -Install installs software; the ./tools/* allow rule must not cover it.
            @{ Rule = 'Bash(*Initialize-DevMachine*-Install*)' }
            @{ Rule = 'PowerShell(*Initialize-DevMachine*-Install*)' }
            # Commands that can destroy work.
            @{ Rule = 'Bash(git reset --hard *)' }
            @{ Rule = 'PowerShell(git reset --hard *)' }
            @{ Rule = 'Bash(git clean *)' }
            @{ Rule = 'PowerShell(git clean *)' }
            @{ Rule = 'Bash(git branch -D *)' }
            @{ Rule = 'PowerShell(git branch -D *)' }
            @{ Rule = 'Bash(git push * --delete *)' }
            @{ Rule = 'PowerShell(git push * --delete *)' }
            @{ Rule = 'Bash(git push * :*)' }
            @{ Rule = 'PowerShell(git push * :*)' }
        ) {
            Get-RuleList 'ask' | Should -Contain $Rule
        }
    }

    Context 'MCP servers' {
        It 'configures the Microsoft Learn server in <File> under "<Key>"' -ForEach @(
            @{ File = '.mcp.json'; Key = 'mcpServers' }          # Claude Code and Visual Studio
            @{ File = '.vscode/mcp.json'; Key = 'servers' }      # VS Code
        ) {
            $json = Get-Json $File
            $server = if ($json -and $json.ContainsKey($Key) -and $json[$Key].ContainsKey('microsoft-learn')) { $json[$Key]['microsoft-learn'] } else { @{} }

            $server['type'] | Should -Be 'http'
            $server['url'] | Should -Be 'https://learn.microsoft.com/api/mcp'
        }
    }

    Context 'reviewer agent' {
        # It keeps Bash and PowerShell to run the gates, so it's read-only by instruction for the shell.
        It 'has no Edit or Write tool' {
            $path = Join-Path $repoRoot '.claude' 'agents' 'reviewer.md'
            $frontMatter = Read-FrontMatter -Path $path
            $tools = @("$($frontMatter['tools'])" -split '\s*,\s*')

            $tools | Should -Not -Contain 'Edit'
            $tools | Should -Not -Contain 'Write'
            "$($frontMatter['disallowedTools'])" | Should -Match 'Edit'
            "$($frontMatter['disallowedTools'])" | Should -Match 'Write'
        }
    }

    Context 'skills' {
        # Claude Code truncates description + when_to_use at 1,536 characters. The reviewer recalled a
        # 1,024 cap in the Agent Skills spec that Visual Studio and VS Code follow (not verified), so the
        # test uses the stricter number.
        It 'has the <Skill> skill, named after its folder, with a description under 1,024 characters' -ForEach @(
            @{ Skill = 'start-work' }, @{ Skill = 'plan-checklist' }, @{ Skill = 'tdd-cycle' },
            @{ Skill = 'write-adr' }, @{ Skill = 'finish-work' }
        ) {
            $path = Join-Path $repoRoot '.claude' 'skills' $Skill 'SKILL.md'
            $path | Should -Exist
            $frontMatter = Read-FrontMatter -Path $path

            $frontMatter['name'] | Should -Be $Skill
            "$($frontMatter['description'])".Length | Should -BeGreaterThan 0
            "$($frontMatter['description'])".Length | Should -BeLessThan 1024
        }
    }
}
