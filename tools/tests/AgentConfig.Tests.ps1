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
        # Rules match command text, so they're best effort; GitHub rulesets on main are the real guard.
        It 'denies reading <Path>' -ForEach @(
            @{ Path = './.env' }, @{ Path = './.env.*' }, @{ Path = './**/*.pfx' }, @{ Path = './**/*.pem' },
            @{ Path = './**/*.key' }, @{ Path = './**/*.snk' }, @{ Path = '~/.ssh/**' },
            @{ Path = '~/AppData/Roaming/Microsoft/UserSecrets/**' }
        ) {
            (Get-RuleList 'deny') -ccontains "Read($Path)" | Should -BeTrue -Because 'rules are case-sensitive: -f and -F are different flags'
        }

        It 'denies <Command> in both Bash and PowerShell' -ForEach @(
            # Force-push, including --force-with-lease, short flags and +refspecs.
            @{ Command = 'git push --force*' }, @{ Command = 'git push -f *' }, @{ Command = 'git push * --force*' },
            @{ Command = 'git push * -f' }, @{ Command = 'git push * -f *' }, @{ Command = 'git push * +*' }
            # Push to main.
            @{ Command = 'git push * main' }, @{ Command = 'git push * HEAD:main' }, @{ Command = 'git push * *:main' },
            @{ Command = 'git push * refs/heads/main' }, @{ Command = 'git push * *:refs/heads/main' }
            # Skipping hooks.
            @{ Command = 'git * --no-verify*' }, @{ Command = 'git commit -n*' }, @{ Command = 'git commit * -n*' }
            # Merging past branch protection.
            @{ Command = 'gh pr merge * --admin*' }
        ) {
            (Get-RuleList 'deny') -ccontains "Bash($Command)" | Should -BeTrue -Because 'rules are case-sensitive: -f and -F are different flags'
            (Get-RuleList 'deny') -ccontains "PowerShell($Command)" | Should -BeTrue -Because 'rules are case-sensitive: -f and -F are different flags'
        }

        It 'asks before <Command> in both Bash and PowerShell' -ForEach @(
            # Merging, repo settings and other GitHub writes.
            @{ Command = 'gh pr merge *' }, @{ Command = 'gh repo edit *' }, @{ Command = 'gh api * -X *' },
            @{ Command = 'gh api * --method *' }, @{ Command = 'gh api * -f *' }, @{ Command = 'gh api * -F *' },
            @{ Command = 'gh api * --field *' }, @{ Command = 'gh api * --raw-field *' }, @{ Command = 'gh api * --input *' }
            # Dependencies and installs. -I* catches -Install and its prefixes (-Ins), which PowerShell accepts.
            @{ Command = 'dotnet add * package *' }, @{ Command = 'winget install *' }, @{ Command = '*Initialize-DevMachine*-I*' }
            # Commands that can destroy work.
            @{ Command = 'git reset --hard *' }, @{ Command = 'git clean *' }, @{ Command = 'git branch -D *' },
            @{ Command = 'git push * --delete *' }, @{ Command = 'git push * -d *' }, @{ Command = 'git push * :*' },
            @{ Command = 'git push --mirror*' }, @{ Command = 'git push * --mirror*' },
            @{ Command = 'git push --prune*' }, @{ Command = 'git push * --prune*' },
            @{ Command = 'git switch -f*' }, @{ Command = 'git switch * -f*' }, @{ Command = 'git switch --discard-changes*' },
            @{ Command = 'git switch * --discard-changes*' }, @{ Command = 'git switch -C *' },
            @{ Command = 'git checkout -- *' }, @{ Command = 'git checkout -f*' }, @{ Command = 'git restore *' }
        ) {
            (Get-RuleList 'ask') -ccontains "Bash($Command)" | Should -BeTrue -Because 'rules are case-sensitive: -f and -F are different flags'
            (Get-RuleList 'ask') -ccontains "PowerShell($Command)" | Should -BeTrue -Because 'rules are case-sensitive: -f and -F are different flags'
        }

        It 'asks before PowerShell module installs (<Command>)' -ForEach @(
            @{ Command = 'Install-PSResource *' }, @{ Command = 'Install-Module *' }
        ) {
            (Get-RuleList 'ask') -ccontains "PowerShell($Command)" | Should -BeTrue -Because 'rules are case-sensitive: -f and -F are different flags'
        }

        It 'asks before editing <Path>' -ForEach @(
            @{ Path = './**/Directory.Packages.props' }, @{ Path = './**/Directory.Build.props' },
            @{ Path = './nuget.config' }, @{ Path = './global.json' }, @{ Path = './.config/dotnet-tools.json' },
            @{ Path = './.github/workflows/**' }, @{ Path = './.github/dependabot.yml' },
            @{ Path = './.claude/settings.json' }, @{ Path = './.mcp.json' }, @{ Path = './.vscode/mcp.json' }
        ) {
            (Get-RuleList 'ask') -ccontains "Edit($Path)" | Should -BeTrue -Because 'rules are case-sensitive: -f and -F are different flags'
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
