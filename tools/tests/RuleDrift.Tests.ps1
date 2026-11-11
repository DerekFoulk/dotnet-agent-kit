#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The same rule is stated in several places, and reviewers kept finding one copy left behind (PRs 33, 35 and
# 37: a list missing "branch protection", Dependabot alerts, or a guardrail). These tests check that each copy
# names every item, so CI catches the drift instead of a review round (owner, 2026-11-10).

Describe 'Rules stated in several places agree' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Read-Text([string] $RelativePath) { [IO.File]::ReadAllText((Join-Path $root $RelativePath)) }

        # Only the list itself: the text after $Start, up to the first later match of $End. Neither the words that
        # open the list nor anything around it can name an item for it.
        function Get-Between([string] $Text, [string] $Start, [string] $End) {
            $match = [regex]::Match($Text, "(?s)$Start(.*?)(?=$End)")
            $match.Success | Should -BeTrue -Because "'$Start' should open a list that '$End' ends"
            $match.Groups[1].Value
        }

        $agents = Read-Text 'AGENTS.md'
        $askCopies = [ordered]@{
            'AGENTS.md "Always ask"' = Get-Between $agents 'In both modes, ask the owner first before you:' '\r?\n\r?\n'
            'SEC-003'                = Get-Between (Read-Text 'docs/standards/security.md') 'id: SEC-003\s+statement:' '; in review mode'
            'README "both modes"'    = Get-Between (Read-Text 'README.md') 'In both modes, the agent asks before:' '\r?\n\r?\n'
        }
        $guardrailCopies = [ordered]@{
            'AGENTS.md "Working modes"' = Get-Between $agents 'That means:' '- \*\*Review\.\*\*'
            'finish-work step 5'        = Get-Between (Read-Text '.claude/skills/finish-work/SKILL.md') 'The guardrails are:' 'A PR that changes any of them'
        }
    }

    # Items are regular expressions, so one item can match each copy's own wording.
    It 'every copy of the "always ask" list names <Item>' -ForEach @(
        @{ Item = 'money' }, @{ Item = 'cloud' }, @{ Item = 'delet' }, @{ Item = 'rewrit' }, @{ Item = 'app repo' }
        @{ Item = 'public' }, @{ Item = 'connector' }, @{ Item = 'install' }, @{ Item = 'ruleset' }
        @{ Item = 'branch protection' }, @{ Item = 'merge settings' }, @{ Item = 'Dependabot alerts' }
        @{ Item = 'security updates' }, @{ Item = 'CI check' }, @{ Item = 'switch\w* the (working )?mode' }
        @{ Item = 'undone' }
    ) {
        foreach ($copy in $askCopies.GetEnumerator()) {
            $copy.Value | Should -Match $Item -Because "$($copy.Key) should name '$Item'"
        }
    }

    It 'AGENTS.md and SEC-003 both ask before <Item>' -ForEach @(
        @{ Item = 'merg\w* a release PR' }, @{ Item = 'publish\w* a release' }, @{ Item = 'guardrails' }
        @{ Item = 'unmerged work|work that isn''t merged' }
    ) {
        # README says these in its own lines (releases are the owner's; guardrails in "Working modes"), and
        # "deleting or rewriting anything" covers unmerged work.
        foreach ($name in 'AGENTS.md "Always ask"', 'SEC-003') {
            $askCopies[$name] | Should -Match $Item -Because "$name should name '$Item'"
        }
    }

    It 'every copy of the guardrail list names <Item>' -ForEach @(
        @{ Item = '"Working modes"' }, @{ Item = '"Always ask"' }, @{ Item = 'SEC-003' }, @{ Item = '\.claude/settings\.json' }
        @{ Item = 'Set-AgentMode\.ps1' }, @{ Item = 'reviewer(` agent|\.md)' }, @{ Item = 'ruleset' }, @{ Item = 'branch protection' }
        @{ Item = 'merge settings' }, @{ Item = 'CI check' }, @{ Item = 'cooldown' }, @{ Item = 'New-KitApp' }
        @{ Item = 'Dependabot alerts and security updates' }
    ) {
        foreach ($copy in $guardrailCopies.GetEnumerator()) {
            $copy.Value | Should -Match $Item -Because "$($copy.Key) should name '$Item'"
        }
    }

    It 'AGENTS.md''s guardrail list names the finish-work skill' {
        # finish-work calls itself "this skill".
        $guardrailCopies['AGENTS.md "Working modes"'] | Should -Match '`finish-work` skill'
    }
}
