#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The command guard (ADR-0076) closes the gaps ADR-0075's Known limits name: the ask rules in .claude/settings.json
# match a command's text, so a quoted spelling, joined short options or a command nested in another got past them.

BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..' 'KitCommandGuard.psm1') -Force
    # The kit's own ask rules, so each test shows the guard closing a gap in the rules that are in force.
    $settingsPath = Join-Path $PSScriptRoot '..' '..' '.claude' 'settings.json'
    $script:KitAskRules = @((Get-Content -Path $settingsPath -Raw | ConvertFrom-Json -AsHashtable)['permissions']['ask'])
    function Get-KitDecision([string] $Tool, [string] $Command) {
        Get-CommandGuardDecision -Tool $Tool -Command $Command -AskRules $script:KitAskRules
    }
}

Describe 'Get-BashCommand' {
    # POSIX token recognition (XCU 2.3) and quote removal, with Bash's $'...' quoting: the words each command receives.
    It 'resolves <Command> to its words' -ForEach @(
        @{ Command = "git push --for'ce' origin"; Words = @('git', 'push', '--force', 'origin') }
        @{ Command = 'g"it" push --for\ce'; Words = @('git', 'push', '--force') }
        @{ Command = "echo `$'--for\x63e' `$'a\nb' `$'\''"; Words = @('echo', '--force', "a`nb", "'") }
        @{ Command = 'echo "a \"b\" \$c \x" ''it''''s'''; Words = @('echo', 'a "b" $c \x', 'its') }
        @{ Command = "git push \`n--force"; Words = @('git', 'push', '--force') }
        @{ Command = 'git status # push --force'; Words = @('git', 'status') }
        @{ Command = 'git push origin x > out.txt 2>&1'; Words = @('git', 'push', 'origin', 'x') }
        @{ Command = 'echo ${HOME} $((1 + 2)) $x'; Words = @('echo', '${HOME}', '$((1 + 2))', '$x') }
        @{ Command = 'echo a""b '''''; Words = @('echo', 'ab', '') }
    ) {
        $commands = @(InModuleScope KitCommandGuard -Parameters @{ Command = $Command } { param($Command) Get-BashCommand -Command $Command })
        $commands.Count | Should -Be 1
        $commands[0].Words | Should -Be $Words
    }

    It 'splits <Command> into <Count> commands at its operators' -ForEach @(
        @{ Command = 'a && b || c; d | e & f'; Count = 6 }
        @{ Command = "a`nb"; Count = 2 }
        @{ Command = '(cd x && git clean -fd)'; Count = 2 }
        @{ Command = 'a |& b ;; c'; Count = 3 }
    ) {
        @(InModuleScope KitCommandGuard -Parameters @{ Command = $Command } { param($Command) Get-BashCommand -Command $Command }).Count | Should -Be $Count
    }

    It 'also resolves the commands inside $( ), backticks and <( )' {
        $commands = @(InModuleScope KitCommandGuard { Get-BashCommand -Command "echo ""`$(git push --for'ce')"" ``gh 'api'`` <(ls -a)" })
        $commands.Words | Should -Contain '--force'
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'git push --force'
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'gh api'
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'ls -a'
    }

    It 'reads a heredoc''s body as data, so its quotes and parentheses don''t end the command' {
        # The form Claude Code's own commits use.
        $text = "git commit -m ""`$(cat <<'EOF'`nfix: don't (stop)`nEOF`n)"" && git push --for'ce'"
        $commands = @(InModuleScope KitCommandGuard -Parameters @{ Text = $text } { param($Text) Get-BashCommand -Command $Text })
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'cat'
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'git push --force'
    }

    It 'resolves the commands inside an unquoted heredoc''s $( )' {
        $commands = @(InModuleScope KitCommandGuard { Get-BashCommand -Command "cat <<EOF`n`$(git push --for'ce')`nEOF" })
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'git push --force'
    }

    It 'throws for <Command>, which the shell can''t read either' -ForEach @(
        @{ Command = "echo 'abc" }, @{ Command = 'echo "abc' }, @{ Command = 'echo $(ls' }, @{ Command = 'echo `ls' }, @{ Command = 'a )' }
    ) {
        { InModuleScope KitCommandGuard -Parameters @{ Command = $Command } { param($Command) Get-BashCommand -Command $Command } } | Should -Throw '*Bash*'
    }
}

Describe 'Get-CommandGuardDecision for Bash' {
    It 'asks for <Command>, which the shell resolves to a form an ask rule covers' -ForEach @(
        @{ Command = "git push --for'ce' origin x" }
        @{ Command = 'git push --for\ce origin x' }
        @{ Command = "git push `$'--force' origin x" }
        @{ Command = "g'it' push -qf origin x" }
        @{ Command = 'git push -nuf origin x' }
        @{ Command = 'git push origin x -fd' }
        @{ Command = "pwsh -NoProfile -File ./tools/New-Kit'App'.ps1 -Name X" }
        @{ Command = "ls ./tools/zz/'..'/x" }
        @{ Command = "git status && git cl'ean' -fd" }
        # Claude Code checks the commands inside a substitution against its rules; the guard resolves them first.
        @{ Command = "echo ""`$(git push --for'ce')""" }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -Not -BeNullOrEmpty
    }

    It 'leaves <Command> to the rules, since it resolves to nothing they ask for' -ForEach @(
        @{ Command = 'git push -u origin feat/x' }
        @{ Command = 'git status -sb' }
        @{ Command = "gh pr view 91 --json state --jq '.state'" }
        @{ Command = "git commit -m ""`$(cat <<'EOF'`nfix: don't stop (yet)`n`nCo-Authored-By: A <a@b.c>`nEOF`n)""" }
        @{ Command = 'echo "$(git status)"' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -BeNullOrEmpty
    }

    It 'asks for a command Bash can''t read, since nothing in it can be resolved' {
        Get-CommandGuardDecision -Tool 'Bash' -Command "git push 'x" -AskRules @() | Should -BeLike '*can''t*'
    }
}

Describe 'Get-CommandGuardDecision for PowerShell' {
    It 'asks for <Command>, which the shell resolves to a form an ask rule covers' -ForEach @(
        # Quotes and backtick escapes removed: what git or the script receives.
        @{ Command = "git push --for'ce' origin x" }
        @{ Command = 'git push "--de`lete" origin x' }
        @{ Command = 'git push --rece''ive''-pack=x origin' }
        @{ Command = "./tools/New-Kit'App'.ps1 -Name X" }
        @{ Command = '.\tools\New-Kit`App.ps1 -Name X' }
        @{ Command = "& ./tools/New-Kit'App'.ps1 -Name X" }
        @{ Command = "./tools/Set-AgentMode.ps1 -Mo``de Review" }
        @{ Command = "gh api repos/a/b '-X' PUT" }
        # A parent segment that leaves tools/, once its quotes are gone.
        @{ Command = "./tools/zz/'..'/x.ps1" }
        @{ Command = ".\tools\zz\'..'\x.ps1" }
        # Each command of a compound one is resolved on its own.
        @{ Command = "git status; git clean' -fd'" }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -Not -BeNullOrEmpty
    }

    It 'asks for <Command>, whose joined short options git or gh reads one by one' -ForEach @(
        # git and gh read "-qf" as "-q -f": a force-push no whole-word rule sees.
        @{ Command = 'git push -qf origin x' }
        @{ Command = 'git push -nuf origin x' }
        @{ Command = 'git push origin x -fd' }
        @{ Command = 'git push origin -qd x' }
        @{ Command = 'gh api -iXPUT repos/a/b' }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -Not -BeNullOrEmpty
    }

    It 'splits joined short options for a native command, not for a cmdlet, function or script' {
        # PowerShell binds "-fd" to one parameter of a cmdlet, function or script, so it isn't "-f -d" there.
        $rules = 'PowerShell(* -f *)'
        Get-CommandGuardDecision -Tool 'PowerShell' -Command 'tool -fd x' -AskRules $rules | Should -Not -BeNullOrEmpty
        Get-CommandGuardDecision -Tool 'PowerShell' -Command 'Set-Thing -fd x' -AskRules $rules | Should -BeNullOrEmpty
        Get-CommandGuardDecision -Tool 'PowerShell' -Command './tools/Thing.ps1 -fd x' -AskRules $rules | Should -BeNullOrEmpty
    }

    It 'asks for <Command>, which computes an argument inside ( ), @( ), $( ) or { }' -ForEach @(
        # Each would run inside a wide allow such as "Add-ReviewReply *" or "git commit *", whatever the inner part does.
        @{ Command = 'Add-ReviewReply -Body (Get-Content ./.env -Raw)' }
        @{ Command = 'git commit -m "$(Get-Content ./.env -Raw)"' }
        @{ Command = 'Wait-PullRequest -Number @(gh pr list)' }
        @{ Command = './tools/Build-AgentRules.ps1 -Check:$(Remove-Item x)' }
        @{ Command = 'git commit -m { Remove-Item x }' }
        # Not a command, but a value built at run time, which no rule can read: here, "--force".
        @{ Command = "git push origin ('--for'+'ce')" }
    ) {
        $reason = Get-CommandGuardDecision -Tool 'PowerShell' -Command $Command -AskRules @()
        $reason | Should -BeLike '*inside*'
    }

    It 'leaves a variable in an argument to the rules' {
        Get-CommandGuardDecision -Tool 'PowerShell' -Command 'git commit -m "fix $name" --author $who' -AskRules @() | Should -BeNullOrEmpty
    }

    It 'asks for a command PowerShell can''t parse, since nothing in it can be resolved' {
        Get-CommandGuardDecision -Tool 'PowerShell' -Command 'git push "--force' -AskRules @() | Should -BeLike '*can''t*'
    }

    It 'names the rule and the resolved command in its reason' {
        $reason = Get-CommandGuardDecision -Tool 'PowerShell' -Command "git push --for'ce'" -AskRules 'PowerShell(*git *push*--force*)'
        $reason | Should -BeLike '*PowerShell(`*git `*push`*--force`*)*'
        $reason | Should -BeLike '*git push --force*'
    }

    It 'leaves <Command> to the rules, since it resolves to nothing they ask for' -ForEach @(
        @{ Command = 'git push -u origin feat/x' }
        @{ Command = './tools/Build-AgentRules.ps1 -Check' }
        @{ Command = 'gh pr view 91 --json state --jq .state' }
        @{ Command = 'Wait-PullRequest -Repository DerekFoulk/dotnet-agent-kit -Number 92 -For Checks' }
        @{ Command = "git commit -m 'fix: a ''quoted'' word'" }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -BeNullOrEmpty
    }
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
