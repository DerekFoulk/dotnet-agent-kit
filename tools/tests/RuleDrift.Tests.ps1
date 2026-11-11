#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The same rule is stated in several places, and reviewers kept finding one copy left behind (PRs 33, 35 and
# 37: a list missing "branch protection", Dependabot alerts, or a guardrail). These tests check that each copy
# names every item, so CI catches the drift instead of a review round (owner, 2026-11-10).

Describe 'Rules stated in several places agree' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Read-Text([string] $RelativePath) { [IO.File]::ReadAllText((Join-Path $root $RelativePath)) }

        # The text from the line where $Start matches up to the first later match of $End. The start can't reach
        # back past that line, so text above the section never counts.
        function Get-Between([string] $Text, [string] $Start, [string] $End) {
            $match = [regex]::Match($Text, "(?ms)^[^\n]*?$Start.*?(?=$End)")
            $match.Success | Should -BeTrue -Because "'$Start' should open a section that '$End' ends"
            $match.Value
        }

        $agents = Read-Text 'AGENTS.md'
        $security = Read-Text 'docs/standards/security.md'
        $askCopies = [ordered]@{
            'AGENTS.md "Always ask"' = Get-Between $agents '^## Always ask' '^## '
            'SEC-003'                = Get-Between $security 'id: SEC-003' '\n    why:'
            'README "both modes"'    = Get-Between (Read-Text 'README.md') 'In both modes, the agent asks before' '\r?\n\r?\n'
        }
        $guardrailCopies = [ordered]@{
            'AGENTS.md "Working modes"' = Get-Between $agents 'That means:' '- \*\*Review\.\*\*'
            'finish-work step 5'        = Get-Between (Read-Text '.claude/skills/finish-work/SKILL.md') 'The guardrails are:' 'A PR that changes any of them'
        }
    }

    It 'every copy of the "always ask" list names <Item>' -ForEach @(
        @{ Item = 'money' }, @{ Item = 'cloud' }, @{ Item = 'delet' }, @{ Item = 'rewrit' }, @{ Item = 'app repo' }
        @{ Item = 'public' }, @{ Item = 'connector' }, @{ Item = 'install' }, @{ Item = 'ruleset' }
        @{ Item = 'branch protection' }, @{ Item = 'merge settings' }, @{ Item = 'Dependabot alerts' }
        @{ Item = 'CI check' }, @{ Item = 'mode' }, @{ Item = 'undone' }
    ) {
        foreach ($copy in $askCopies.GetEnumerator()) {
            $copy.Value | Should -Match ([regex]::Escape($Item)) -Because "$($copy.Key) should name '$Item'"
        }
    }

    It 'AGENTS.md and SEC-003 both ask before <Item>' -ForEach @(
        @{ Item = 'release' }, @{ Item = 'guardrails' }
    ) {
        # README says these in its own lines (releases are the owner's; guardrails in "Working modes").
        foreach ($name in 'AGENTS.md "Always ask"', 'SEC-003') {
            $askCopies[$name] | Should -Match ([regex]::Escape($Item)) -Because "$name should name '$Item'"
        }
    }

    It 'every copy of the guardrail list names <Item>' -ForEach @(
        @{ Item = 'Working modes' }, @{ Item = 'Always ask' }, @{ Item = 'SEC-003' }, @{ Item = '.claude/settings.json' }
        @{ Item = 'Set-AgentMode.ps1' }, @{ Item = 'reviewer' }, @{ Item = 'ruleset' }, @{ Item = 'branch protection' }
        @{ Item = 'merge settings' }, @{ Item = 'CI check' }, @{ Item = 'cooldown' }, @{ Item = 'New-KitApp' }
    ) {
        foreach ($copy in $guardrailCopies.GetEnumerator()) {
            $copy.Value | Should -Match ([regex]::Escape($Item)) -Because "$($copy.Key) should name '$Item'"
        }
    }
}
