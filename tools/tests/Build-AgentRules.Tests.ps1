#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

Describe 'Build-AgentRules.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Build-AgentRules.ps1')

        function New-Rule {
            param([string] $Id, [string] $Statement, [string] $Status = 'accepted', [string[]] $Paths = @('**'))
            [ordered]@{
                id = $Id; statement = $Statement; why = 'Because.'; layer = 'owner'; status = $Status
                sources = @('owner, 2026-11-01'); enforcement = 'advisory: test'; scope = 'core'; paths = $Paths
            }
        }

        function New-StandardsFile {
            param([string] $Topic, [string] $Title, [object[]] $Rules)
            $frontMatter = ConvertTo-Yaml ([ordered]@{ topic = $Topic; rules = $Rules })
            Set-Content -Path (Join-Path $script:standards "$Topic.md") -Value "---`n$frontMatter---`n`n# $Title`n`nPeople text.`n"
        }

        function Get-File([string] $Path) {
            $file = Get-AgentRuleFile -StandardsPath $script:standards | Where-Object Path -EQ $Path
            if ($file) { $file } else { [pscustomobject]@{ Path = $Path; Content = '' } }
        }
    }

    BeforeEach {
        $script:standards = Join-Path $TestDrive "standards-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:standards | Out-Null
    }

    Context 'Claude Code rules' {
        It 'writes always-on rules to .claude/rules/TOPIC.md with no paths front matter' {
            New-StandardsFile -Topic 'git' -Title 'Git' -Rules @(
                (New-Rule -Id 'GIT-001' -Statement 'Merge with a merge commit.')
                (New-Rule -Id 'GIT-002' -Statement 'Use GitHub Flow.')
            )

            $content = (Get-File '.claude/rules/git.md').Content

            $content | Should -Not -Match '^---'
            $content | Should -Match '(?m)^# Git$'
            $content | Should -Match '(?m)^- GIT-001: Merge with a merge commit\.$'
            $content | Should -Match '(?m)^- GIT-002: Use GitHub Flow\.$'
        }

        It 'writes each path-scoped rule to .claude/rules/TOPIC-ID.md with only its own paths' {
            New-StandardsFile -Topic 'code-style' -Title 'Code style' -Rules @(
                (New-Rule -Id 'STY-001' -Statement 'Follow the baseline.' -Paths @('**/*.cs', '.editorconfig'))
                (New-Rule -Id 'STY-002' -Statement 'Never use var.' -Paths @('**/*.cs'))
            )

            $first = (Get-File '.claude/rules/code-style-sty-001.md').Content
            $second = (Get-File '.claude/rules/code-style-sty-002.md').Content

            $first | Should -Match "(?s)^---`npaths:`n  - '\*\*/\*\.cs'`n  - '\.editorconfig'`n---`n"
            $first | Should -Match '(?m)^- STY-001: Follow the baseline\.$'
            $first | Should -Not -Match 'STY-002'
            $second | Should -Match "(?s)^---`npaths:`n  - '\*\*/\*\.cs'`n---`n"
            $second | Should -Match '(?m)^- STY-002: Never use var\.$'
            Get-AgentRuleFile -StandardsPath $script:standards | Where-Object Path -EQ '.claude/rules/code-style.md' | Should -BeNullOrEmpty
        }

        It 'groups path-scoped rules with the same paths into one file, named after the first' {
            New-StandardsFile -Topic 'testing' -Title 'Testing' -Rules @(
                (New-Rule -Id 'TST-003' -Statement 'Every kind.' -Paths @('**/*.csproj', 'tests/**'))
                (New-Rule -Id 'TST-007' -Statement 'Same paths.' -Paths @('tests/**', '**/*.csproj'))
            )

            $content = (Get-File '.claude/rules/testing-tst-003.md').Content

            $content | Should -Match '(?m)^- TST-003: Every kind\.$'
            $content | Should -Match '(?m)^- TST-007: Same paths\.$'
            Get-AgentRuleFile -StandardsPath $script:standards | Where-Object Path -EQ '.claude/rules/testing-tst-007.md' | Should -BeNullOrEmpty
        }

        It 'escapes a single quote in a path' {
            New-StandardsFile -Topic 'git' -Title 'Git' -Rules @((New-Rule -Id 'GIT-009' -Statement 'Odd path.' -Paths @("docs/it's/**")))

            (Get-File '.claude/rules/git-git-009.md').Content | Should -Match "(?m)^  - 'docs/it''s/\*\*'$"
            (Get-File '.github/instructions/git-git-009.instructions.md').Content | Should -Match "(?m)^applyTo: 'docs/it''s/\*\*'$"
        }

        It 'leaves out rules that are <Status>, because only accepted rules are in force' -ForEach @(
            @{ Status = 'proposed' }, @{ Status = 'retired' }
        ) {
            New-StandardsFile -Topic 'git' -Title 'Git' -Rules @(
                (New-Rule -Id 'GIT-001' -Statement 'In force.')
                (New-Rule -Id 'GIT-003' -Statement 'Not in force.' -Status $Status)
            )

            (Get-File '.claude/rules/git.md').Content | Should -Not -Match 'GIT-003'
        }

        It 'writes no file for a topic with no accepted rules' {
            New-StandardsFile -Topic 'git' -Title 'Git' -Rules @((New-Rule -Id 'GIT-003' -Statement 'Proposed.' -Status 'proposed'))

            @(Get-AgentRuleFile -StandardsPath $script:standards).Count | Should -Be 0
        }

        It 'marks each file as generated from its standard' {
            New-StandardsFile -Topic 'git' -Title 'Git' -Rules @((New-Rule -Id 'GIT-001' -Statement 'Merge.'))

            (Get-File '.claude/rules/git.md').Content | Should -Match '<!-- Generated by tools/Build-AgentRules\.ps1 from docs/standards/git\.md\. Do not edit'
        }
    }

    Context 'Copilot repository instructions' {
        It 'copies AGENTS.md into .github/copilot-instructions.md under a generated marker' {
            $agents = Join-Path $TestDrive "AGENTS-$(New-Guid).md"
            Set-Content -Path $agents -Value "# Agent instructions`n`nRun the tests first.`n"

            $file = Get-CopilotInstructionsFile -AgentsPath $agents

            $file.Path | Should -Be '.github/copilot-instructions.md'
            $file.Content | Should -Match '^<!-- Generated by tools/Build-AgentRules\.ps1 from AGENTS\.md\. Do not edit'
            $file.Content | Should -Match "(?s)# Agent instructions`n`nRun the tests first\.`n$"
        }
    }

    Context 'runner' {
        BeforeAll {
            function New-Repo {
                $root = Join-Path $TestDrive "repo-$(New-Guid)"
                $script:standards = Join-Path $root 'docs' 'standards'
                New-Item -ItemType Directory -Path $script:standards | Out-Null
                Set-Content -Path (Join-Path $root 'AGENTS.md') -Value "# Agent instructions`n"
                New-StandardsFile -Topic 'git' -Title 'Git' -Rules @((New-Rule -Id 'GIT-001' -Statement 'Merge.'))
                $root
            }
        }

        BeforeEach {
            Mock Write-Host {}
        }

        It 'writes every generated file and returns 0' {
            $root = New-Repo

            Invoke-AgentRuleBuild -RepoRoot $root | Should -Be 0

            Join-Path $root '.claude' 'rules' 'git.md' | Should -Exist
            Join-Path $root '.github' 'instructions' 'git.instructions.md' | Should -Exist
            Join-Path $root '.github' 'copilot-instructions.md' | Should -Exist
        }

        It 'with -Check, returns 0 when every generated file is current, even with CRLF line endings' {
            $root = New-Repo
            Invoke-AgentRuleBuild -RepoRoot $root | Out-Null
            $rule = Join-Path $root '.claude' 'rules' 'git.md'
            Set-Content -Path $rule -Value ((Get-Content -Path $rule -Raw) -replace "`n", "`r`n") -NoNewline

            Invoke-AgentRuleBuild -RepoRoot $root -Check | Should -Be 0
        }

        It 'with -Check, returns 1 and names a <Case> file, without writing anything' -ForEach @(
            @{ Case = 'hand-edited'; Change = { param($p) Add-Content -Path $p -Value '- GIT-999: Sneaked in.' } }
            @{ Case = 'missing'; Change = { param($p) Remove-Item -Path $p } }
        ) {
            $root = New-Repo
            Invoke-AgentRuleBuild -RepoRoot $root | Out-Null
            $rule = Join-Path $root '.claude' 'rules' 'git.md'
            & $Change $rule
            $before = if (Test-Path $rule) { Get-Content -Path $rule -Raw } else { $null }

            Invoke-AgentRuleBuild -RepoRoot $root -Check | Should -Be 1

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*.claude/rules/git.md*' }
            $after = if (Test-Path $rule) { Get-Content -Path $rule -Raw } else { $null }
            $after | Should -Be $before
        }

        It 'removes a stale generated file but keeps a hand-written one' {
            $root = New-Repo
            Invoke-AgentRuleBuild -RepoRoot $root | Out-Null
            $stale = Join-Path $root '.claude' 'rules' 'old-topic.md'
            $handWritten = Join-Path $root '.claude' 'rules' 'project-notes.md'
            Set-Content -Path $stale -Value "<!-- Generated by tools/Build-AgentRules.ps1 from docs/standards/old-topic.md. Do not edit; edit the source and run ./tools/Build-AgentRules.ps1. -->"
            Set-Content -Path $handWritten -Value '# Project notes'

            Invoke-AgentRuleBuild -RepoRoot $root -Check | Should -Be 1
            Invoke-AgentRuleBuild -RepoRoot $root | Should -Be 0

            $stale | Should -Not -Exist
            $handWritten | Should -Exist
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*removed: .claude/rules/old-topic.md*' }
        }

        It 'with -Check, returns 1 for an edit that only changes letter case, and a build repairs it' {
            $root = New-Repo
            Invoke-AgentRuleBuild -RepoRoot $root | Out-Null
            $rule = Join-Path $root '.claude' 'rules' 'git.md'
            Set-Content -Path $rule -Value ((Get-Content -Path $rule -Raw) -creplace 'GIT-', 'git-') -NoNewline

            Invoke-AgentRuleBuild -RepoRoot $root -Check | Should -Be 1
            Invoke-AgentRuleBuild -RepoRoot $root | Out-Null

            Get-Content -Path $rule -Raw | Should -MatchExactly 'GIT-001'
        }

        It 'resolves a relative -RepoRoot against the PowerShell location, not the process directory' {
            $root = New-Repo
            Invoke-AgentRuleBuild -RepoRoot $root | Out-Null
            $processDirectory = [Environment]::CurrentDirectory
            try {
                [Environment]::CurrentDirectory = $env:TEMP
                Push-Location -Path (Split-Path -Path $root -Parent)

                Invoke-AgentRuleBuild -RepoRoot (Split-Path -Path $root -Leaf) -Check | Should -Be 0
                Invoke-AgentRuleBuild -RepoRoot (Split-Path -Path $root -Leaf) | Should -Be 0
            }
            finally {
                Pop-Location
                [Environment]::CurrentDirectory = $processDirectory
            }

            Join-Path $root '.claude' 'rules' 'git.md' | Should -Exist
        }

        It 'exits 1 when run as a script with -Check and a file has drifted' {
            $root = New-Repo
            Invoke-AgentRuleBuild -RepoRoot $root | Out-Null
            Add-Content -Path (Join-Path $root '.claude' 'rules' 'git.md') -Value 'drift'
            $script = Join-Path $PSScriptRoot '..' 'Build-AgentRules.ps1'

            $output = pwsh -NoProfile -File $script -RepoRoot $root -Check 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'git\.md'
        }
    }

    Context 'Copilot instructions' {
        It 'writes always-on rules with applyTo **' {
            New-StandardsFile -Topic 'git' -Title 'Git' -Rules @((New-Rule -Id 'GIT-001' -Statement 'Merge.'))

            $content = (Get-File '.github/instructions/git.instructions.md').Content

            $content | Should -Match "(?s)^---`napplyTo: '\*\*'`n---`n"
            $content | Should -Match '(?m)^- GIT-001: Merge\.$'
        }

        It 'writes path-scoped rules with comma-separated applyTo globs' {
            New-StandardsFile -Topic 'code-style' -Title 'Code style' -Rules @(
                (New-Rule -Id 'STY-001' -Statement 'Baseline.' -Paths @('**/*.cs', '.editorconfig'))
            )

            (Get-File '.github/instructions/code-style-sty-001.instructions.md').Content | Should -Match "(?s)^---`napplyTo: '\*\*/\*\.cs,\.editorconfig'`n---`n"
        }
    }
}
