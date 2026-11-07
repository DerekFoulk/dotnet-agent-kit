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
        # ADR-0026: only rules that match a path or a precise command. Pushes are guarded by the GitHub
        # ruleset on main, not by matching command text. Comparisons are case-sensitive, like flags.
        It 'denies reading <Path>' -ForEach @(
            @{ Path = './.env' }, @{ Path = './.env.*' }, @{ Path = './**/.env' }, @{ Path = './**/.env.*' },
            @{ Path = './**/*.pfx' }, @{ Path = './**/*.pem' },
            @{ Path = './**/*.key' }, @{ Path = './**/*.snk' }, @{ Path = '~/.ssh/**' },
            @{ Path = '~/AppData/Roaming/Microsoft/UserSecrets/**' }
        ) {
            (Get-RuleList 'deny') -ccontains "Read($Path)" | Should -BeTrue
        }

        It 'asks before <Command> in both Bash and PowerShell' -ForEach @(
            # The owner's decisions: merging and repo settings.
            @{ Command = 'gh pr merge *' }, @{ Command = 'gh repo edit *' }
            # Dependencies and installs. -I* catches -Install and its prefixes (-Ins), which PowerShell accepts.
            @{ Command = 'dotnet add * package *' }, @{ Command = 'winget install *' }, @{ Command = '*Initialize-DevMachine*-I*' }
            # The two commands that destroy local work and that an agent rarely needs.
            @{ Command = 'git reset --hard *' }, @{ Command = 'git clean *' }
        ) {
            (Get-RuleList 'ask') -ccontains "Bash($Command)" | Should -BeTrue
            (Get-RuleList 'ask') -ccontains "PowerShell($Command)" | Should -BeTrue
        }

        It 'asks before PowerShell module installs (<Command>)' -ForEach @(
            @{ Command = 'Install-PSResource *' }, @{ Command = 'Install-Module *' }
        ) {
            (Get-RuleList 'ask') -ccontains "PowerShell($Command)" | Should -BeTrue
        }

        It 'asks before editing <Path>' -ForEach @(
            @{ Path = './**/Directory.Packages.props' }, @{ Path = './**/Directory.Build.props' },
            @{ Path = './nuget.config' }, @{ Path = './global.json' }, @{ Path = './.config/dotnet-tools.json' },
            @{ Path = './.github/workflows/**' }, @{ Path = './.github/dependabot.yml' },
            @{ Path = './.claude/settings.json' }, @{ Path = './.mcp.json' }, @{ Path = './.vscode/mcp.json' },
            # An app's kit-managed scripts and manifest (ADR-0032): the sync job changes them, not a hand edit.
            @{ Path = './.kit/**' }
        ) {
            (Get-RuleList 'ask') -ccontains "Edit($Path)" | Should -BeTrue
        }

        # New-KitApp creates a GitHub repo and changes its settings (ADR-0033); './tools/*' would allow it unasked.
        # Each way of running it must match an ask rule. PowerShell runs a path-qualified script without its
        # .ps1, so the rules can't end in '.ps1*' (review 1 of PR 17).
        It 'asks before running New-KitApp as <Tool>(<Command>)' -ForEach @(
            @{ Tool = 'PowerShell'; Command = './tools/New-KitApp -Name Contoso.Orders' }
            @{ Tool = 'PowerShell'; Command = './tools/New-KitApp.ps1 -Name Contoso.Orders' }
            @{ Tool = 'PowerShell'; Command = '.\tools\New-KitApp -Name Contoso.Orders' }
            @{ Tool = 'PowerShell'; Command = '.\tools\New-KitApp.ps1 -Name Contoso.Orders' }
            @{ Tool = 'PowerShell'; Command = 'pwsh -NoProfile -File ./tools/New-KitApp.ps1 -Name Contoso.Orders' }
            @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools/New-KitApp.ps1 -Name Contoso.Orders' }
        ) {
            # A rule's '*' matches any text, as in Claude Code's patterns; [ and ] are taken literally.
            $matching = @(Get-RuleList 'ask' | Where-Object {
                    $_ -match "^$Tool\((.*)\)$" -and $Command -like ($Matches[1] -replace '[\[\]]', '`$0')
                })
            $matching | Should -Not -BeNullOrEmpty -Because "an ask rule should catch $Tool($Command)"
        }

        It 'leaves pushes to the GitHub ruleset: no deny or ask rule matches git push' {
            @((Get-RuleList 'deny') + (Get-RuleList 'ask')) -match 'git push' | Should -BeNullOrEmpty
        }

        It 'allows git switch only as the exact command <Rule>' -ForEach @(
            @{ Rule = 'Bash(git switch main)' }, @{ Rule = 'PowerShell(git switch main)' }
        ) {
            (Get-RuleList 'allow') -ccontains $Rule | Should -BeTrue
        }

        # An app repo has the kit's scripts in .kit/tools (ADR-0032); the kit has them in tools.
        It 'allows running the kit''s scripts with <Rule>' -ForEach @(
            @{ Rule = 'PowerShell(./tools/*)' }, @{ Rule = 'PowerShell(pwsh -NoProfile -File ./tools/*)' }
            @{ Rule = 'PowerShell(./.kit/tools/*)' }, @{ Rule = 'PowerShell(pwsh -NoProfile -File ./.kit/tools/*)' }
        ) {
            (Get-RuleList 'allow') -ccontains $Rule | Should -BeTrue
        }

        # Any wildcard also accepts --discard-changes or -f, which drop uncommitted work: those must prompt.
        It 'has no wildcard allow rule for git switch' {
            @(Get-RuleList 'allow') -match 'git switch .*\*' | Should -BeNullOrEmpty
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
            @{ Skill = 'write-adr' }, @{ Skill = 'finish-work' }, @{ Skill = 'address-review' }
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
