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
        @{ Item = 'guardrails' }, @{ Item = 'unmerged work|work that isn''t merged' }
    ) {
        # README says guardrails in "Working modes", and "deleting or rewriting anything" covers unmerged work.
        foreach ($name in 'AGENTS.md "Always ask"', 'SEC-003') {
            $askCopies[$name] | Should -Match $Item -Because "$name should name '$Item'"
        }
    }

    # Releases are the owner's: agents never merge a release PR or publish a release, in either mode (owner,
    # 2026-11-07). The ask lists used to say "ask first", which contradicted GIT-003 (rules audit, C1).
    It 'no copy of the "always ask" list offers to ask before a release' {
        foreach ($copy in $askCopies.GetEnumerator()) {
            $copy.Value | Should -Not -Match 'release' -Because "$($copy.Key) shouldn't offer to ask: agents never do it"
        }
    }

    It '<Name> says agents never merge a release PR' -ForEach @(
        @{ Name = 'AGENTS.md "Always ask"'; Path = 'AGENTS.md'; Start = '## Always ask'; End = '\r?\n## ' }
        @{ Name = 'SEC-003'; Path = 'docs/standards/security.md'; Start = 'id: SEC-003\s+statement:'; End = '\r?\n' }
        @{ Name = 'GIT-003'; Path = 'docs/standards/git.md'; Start = 'id: GIT-003\s+statement:'; End = '\r?\n' }
    ) {
        Get-Between (Read-Text $Path) $Start $End | Should -Match 'never (merge\w* )?a release PR' -Because "$Name should say never"
    }

    # GIT-003 is about merging only; the two lists that used to ask before a release also ban publishing one
    # (Copilot's review of PR 66: without this, dropping "or publish a release" passed).
    It '<Name> says agents never publish a release either' -ForEach @(
        @{ Name = 'AGENTS.md "Always ask"'; Path = 'AGENTS.md'; Start = '## Always ask'; End = '\r?\n## ' }
        @{ Name = 'SEC-003'; Path = 'docs/standards/security.md'; Start = 'id: SEC-003\s+statement:'; End = '\r?\n' }
    ) {
        Get-Between (Read-Text $Path) $Start $End | Should -Match 'never merge\w* a release PR or publish\w* a release' -Because "$Name should ban publishing too"
    }

    # SEC-003 is one sentence, so this list is checked against it rather than generated (ADR-0065).
    It 'AGENTS.md "Also ask in review mode" and SEC-003''s review part both name <Item>' -ForEach @(
        @{ Item = 'dependenc' }, @{ Item = '\bCI\b' }, @{ Item = 'repo settings' }, @{ Item = 'outside (this|the) repo' }
    ) {
        $agentsReview = Get-Between $agents 'In review mode, also ask the owner first before you:' '\r?\n\r?\n'
        $secReview = Get-Between (Read-Text 'docs/standards/security.md') 'in review mode, also before' ';'
        $agentsReview | Should -Match $Item -Because "AGENTS.md's review-mode list should name '$Item'"
        $secReview | Should -Match $Item -Because "SEC-003's review part should name '$Item'"
    }

    It 'every copy of the guardrail list names <Item>' -ForEach @(
        @{ Item = '"Working modes"' }, @{ Item = '"Always ask"' }, @{ Item = 'SEC-003' }, @{ Item = '\.claude/settings\.json' }
        @{ Item = 'Set-AgentMode\.ps1' }, @{ Item = 'code-review\.instructions\.md' }, @{ Item = 'ruleset' }, @{ Item = 'branch protection' }
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

    It 'the plan checklist''s Accessibility heading points at UI-001 in its standard' {
        # The checklist points at the rule instead of restating WCAG's criteria, so the two can't disagree (CRF-003).
        $checklist = Get-Between (Read-Text '.claude/skills/plan-checklist/SKILL.md') '## Accessibility' '\r?\n## '
        $checklist | Should -Match 'UI-001' -Because 'the Accessibility heading should name the rule'
        $checklist | Should -Match '`docs/standards/ui\.md`' -Because 'the Accessibility heading should name where the rule lives'
        # \r? because a Windows checkout has CRLF line endings (.gitattributes: text=auto).
        Read-Text 'docs/standards/ui.md' | Should -Match '(?m)^\s+- id: UI-001\r?$'
    }
}
