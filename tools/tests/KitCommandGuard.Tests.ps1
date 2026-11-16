#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The command guard (ADR-0076) closes the gaps ADR-0075's Known limits name: the ask rules in .claude/settings.json
# match a command's text, so a quoted spelling, joined short options or a command nested in another got past them.

BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..' 'KitCommandGuard.psm1') -Force
}

Describe 'Test-PermissionRuleMatch' {
    # Claude Code's rule syntax, from its permissions page: '*' matches any text, a trailing ' *' also matches the
    # bare command, and a trailing ':*' is the older prefix form.
    It 'matches <Command> against <Rule>' -ForEach @(
        @{ Rule = 'Bash(git push *)'; Command = 'git push origin main' }
        @{ Rule = 'Bash(git push *)'; Command = 'git push' }
        @{ Rule = 'Bash(*git *push*--force*)'; Command = 'cd x && git push --force' }
        @{ Rule = 'Bash(ls:*)'; Command = 'ls -la' }
        @{ Rule = 'Bash(ls:*)'; Command = 'ls' }
        @{ Rule = 'PowerShell(./tools/New-KitApp*)'; Command = './tools/New-KitApp.ps1 -Name X' }
        @{ Rule = 'Bash(git switch main)'; Command = 'git switch main' }
    ) {
        $tool = $Rule.Substring(0, $Rule.IndexOf('('))
        Test-PermissionRuleMatch -Rule $Rule -Tool $tool -Command $Command | Should -BeTrue
    }

    It 'doesn''t match <Command> against <Rule>' -ForEach @(
        @{ Rule = 'Bash(git push *)'; Command = 'git pushx' }
        @{ Rule = 'Bash(ls:*)'; Command = 'lsof' }
        # The ':*' form's prefix is literal: its '*' isn't a wildcard.
        @{ Rule = 'Bash(a*b:*)'; Command = 'axxb c' }
        # '[', ']', '?' and '`' are literal, not -like's wildcards or its escape.
        @{ Rule = 'Bash(echo [ab])'; Command = 'echo a' }
        @{ Rule = 'Bash(echo ?)'; Command = 'echo x' }
        @{ Rule = 'Bash(echo `*)'; Command = 'echo *' }
        @{ Rule = 'Bash(git switch main)'; Command = 'git switch mainx' }
    ) {
        $tool = $Rule.Substring(0, $Rule.IndexOf('('))
        Test-PermissionRuleMatch -Rule $Rule -Tool $tool -Command $Command | Should -BeFalse
    }

    It 'matches a literal [, ?, or backtick as itself' {
        Test-PermissionRuleMatch -Rule 'Bash(echo [ab]?`x)' -Tool 'Bash' -Command 'echo [ab]?`x' | Should -BeTrue
    }

    It 'matches a wildcard across lines, as a heredoc''s command text has them' {
        Test-PermissionRuleMatch -Rule 'Bash(*git *push*--force*)' -Tool 'Bash' -Command "git commit -m x`ngit push --force" | Should -BeTrue
    }

    It 'checks only the rules of the tool it''s given' {
        Test-PermissionRuleMatch -Rule 'Bash(git push *)' -Tool 'PowerShell' -Command 'git push x' | Should -BeFalse
        Test-PermissionRuleMatch -Rule 'PowerShell(git push *)' -Tool 'PowerShell' -Command 'git push x' | Should -BeTrue
    }

    It 'matches case-sensitively unless told to ignore case' {
        Test-PermissionRuleMatch -Rule 'Bash(*git *push* -f*)' -Tool 'Bash' -Command 'git push -F' | Should -BeFalse
        Test-PermissionRuleMatch -Rule 'PowerShell(*git *push* -f*)' -Tool 'PowerShell' -Command 'GIT push -F' -IgnoreCase | Should -BeTrue
        Test-PermissionRuleMatch -Rule 'PowerShell(git push *)' -Tool 'PowerShell' -Command 'GIT PUSH' -IgnoreCase | Should -BeTrue
    }
}
