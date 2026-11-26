#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The command guard (ADR-0077) closes the gaps ADR-0075's Known limits name: the ask rules in .claude/settings.json
# match a command's text, so a quoted spelling, joined short options or a command nested in another got past them.

BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..' 'KitCommandGuard.psm1') -Force
    # The kit's own ask rules, so each test shows the guard closing a gap in the rules that are in force.
    $settingsPath = Join-Path $PSScriptRoot '..' '..' '.claude' 'settings.json'
    $script:KitAskRules = @((Get-Content -Path $settingsPath -Raw | ConvertFrom-Json -AsHashtable)['permissions']['ask'])
    $script:KitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    # A file's 8.3 short name, from cmd's %~snx, or nothing where Windows made none.
    function Get-ShortName([string] $Path) {
        if (-not $IsWindows) { return }
        $short = cmd /c "for %I in (""$Path"") do @echo %~snxI"
        if ($short -and $short -ne (Split-Path -Leaf $Path)) { $short }
    }
    function Get-KitDecision([string] $Tool, [string] $Command) {
        Get-CommandGuardDecision -Tool $Tool -Command $Command -AskRules $script:KitAskRules -WorkingDirectory $script:KitRoot
    }
}

Describe 'Invoke-CommandGuard' {
    # The hook's input and output, as Claude Code's hooks page gives them: tool_name and tool_input.command in, and
    # hookSpecificOutput with permissionDecision "ask" out, or nothing, which leaves the call to the permission rules.
    BeforeEach {
        $project = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $project '.claude') -Force | Out-Null
        Set-Content -Path (Join-Path $project '.claude' 'settings.json') -Value '{"permissions":{"ask":["PowerShell(*git *push*--force*)"]}}'
        function New-HookInput([string] $Tool, [string] $Command) {
            @{ hook_event_name = 'PreToolUse'; cwd = $project; tool_name = $Tool; tool_input = @{ command = $Command; description = 'x' } } | ConvertTo-Json
        }
    }

    It 'asks, with the reason, for a command the guard resolves to an asked form' {
        $output = Invoke-CommandGuard -InputJson (New-HookInput 'PowerShell' "git push --for'ce'") -ProjectDir $project
        $output | Should -Not -BeNullOrEmpty
        $decision = ($output | ConvertFrom-Json -AsHashtable)['hookSpecificOutput']
        $decision['hookEventName'] | Should -Be 'PreToolUse'
        $decision['permissionDecision'] | Should -Be 'ask'
        $decision['permissionDecisionReason'] | Should -BeLike '*git push --force*'
    }

    It 'writes nothing for a command it leaves to the rules, or for another tool' {
        Invoke-CommandGuard -InputJson (New-HookInput 'PowerShell' 'git push origin x') -ProjectDir $project | Should -BeNullOrEmpty
        $read = @{ hook_event_name = 'PreToolUse'; tool_name = 'Read'; tool_input = @{ file_path = 'x' } } | ConvertTo-Json
        Invoke-CommandGuard -InputJson $read -ProjectDir $project | Should -BeNullOrEmpty
    }

    It 'reads the ask rules of .claude/settings.local.json too, where review mode adds its asks' {
        Set-Content -Path (Join-Path $project '.claude' 'settings.local.json') -Value '{"permissions":{"ask":["PowerShell(gh pr merge *)"]}}'
        Invoke-CommandGuard -InputJson (New-HookInput 'PowerShell' "gh pr mer'ge' 5") -ProjectDir $project | Should -BeLike '*"ask"*'
    }

    It 'expands a glob against the input''s cwd, where the shell runs the command' {
        $tools = Join-Path $project 'tools'
        New-Item -ItemType Directory -Path $tools -Force | Out-Null
        Set-Content -Path (Join-Path $tools 'New-KitApp.ps1') -Value '#'
        Set-Content -Path (Join-Path $project '.claude' 'settings.json') -Value '{"permissions":{"ask":["PowerShell(./tools/New-KitApp*)"]}}'
        Invoke-CommandGuard -InputJson (New-HookInput 'PowerShell' './tools/New-K*.ps1') -ProjectDir $project | Should -BeLike '*"ask"*'
    }

    It 'takes the project from the input''s cwd when it isn''t given one' {
        Invoke-CommandGuard -InputJson (New-HookInput 'PowerShell' "git push --for'ce'") -ProjectDir '' | Should -BeLike '*"ask"*'
    }

    It 'asks when <Case>, rather than let the call through unchecked' -ForEach @(
        @{ Case = 'the settings are missing'; Settings = $null; InputJson = $null }
        @{ Case = 'the settings aren''t JSON'; Settings = '{'; InputJson = $null }
        @{ Case = 'the ask rules aren''t a list of strings'; Settings = '{"permissions":{"ask":"x"}}'; InputJson = $null }
        @{ Case = 'the input isn''t JSON'; Settings = '{}'; InputJson = 'not json' }
        @{ Case = 'the command isn''t a string'; Settings = '{}'; InputJson = '{"tool_name":"Bash","tool_input":{"command":5}}' }
    ) {
        $path = Join-Path $project '.claude' 'settings.json'
        if ($null -eq $Settings) { Remove-Item -Path $path } else { Set-Content -Path $path -Value $Settings }
        $json = if ($InputJson) { $InputJson } else { New-HookInput 'Bash' 'git status' }
        $output = Invoke-CommandGuard -InputJson $json -ProjectDir $project
        $output | Should -BeLike '*"permissionDecision":"ask"*'
        ($output | ConvertFrom-Json).hookSpecificOutput.permissionDecisionReason | Should -BeLike '*command guard*'
    }

    It 'writes ASCII only, so the console''s code page can''t garble it' {
        $output = Invoke-CommandGuard -InputJson (New-HookInput 'PowerShell' "git push --for'ce' → é") -ProjectDir $project
        $output | Should -Not -BeNullOrEmpty
        $output | Should -Match '^[\x20-\x7E]*$'
        ($output | ConvertFrom-Json).hookSpecificOutput.permissionDecisionReason | Should -BeLike '*→ é*'
    }
}

Describe 'Invoke-CommandGuard.ps1' {
    # The script Claude Code runs: the hook's JSON on stdin, the decision on stdout, exit code 0 either way.
    BeforeAll {
        $script:GuardScript = Join-Path $PSScriptRoot '..' 'Invoke-CommandGuard.ps1'
        $script:GuardProject = Join-Path $TestDrive 'project'
        New-Item -ItemType Directory -Path (Join-Path $script:GuardProject '.claude') -Force | Out-Null
        Set-Content -Path (Join-Path $script:GuardProject '.claude' 'settings.json') -Value '{"permissions":{"ask":["Bash(*git *push*--force*)"]}}'
        function Invoke-GuardScript([string] $Command) {
            $json = @{ hook_event_name = 'PreToolUse'; cwd = $TestDrive; tool_name = 'Bash'; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
            $env:CLAUDE_PROJECT_DIR = $script:GuardProject
            try { $output = $json | pwsh -NoProfile -NonInteractive -File $script:GuardScript } finally { Remove-Item Env:CLAUDE_PROJECT_DIR }
            [pscustomobject]@{ Output = ($output -join "`n"); ExitCode = $LASTEXITCODE }
        }
    }

    It 'asks on stdout for a command an ask rule covers once resolved, taking the project from CLAUDE_PROJECT_DIR' {
        $result = Invoke-GuardScript "git push --for'ce' origin x"
        $result.ExitCode | Should -Be 0
        ($result.Output | ConvertFrom-Json).hookSpecificOutput.permissionDecision | Should -Be 'ask'
    }

    It 'prints nothing for a command it leaves to the rules' {
        $result = Invoke-GuardScript 'git push origin x'
        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeNullOrEmpty
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
        # Inside double quotes, '$' before the closing quote is a literal '$', not Bash's $"..." quoting (found by
        # replaying the kit's session transcripts through the guard).
        @{ Command = 'grep -v "^\s*$" "id: $id$"'; Words = @('grep', '-v', '^\s*$', 'id: $id$') }
    ) {
        # A throw counts as no commands, so a misread fails on the assertion below.
        $commands = @(try { InModuleScope KitCommandGuard -Parameters @{ Command = $Command } { param($Command) Get-BashCommand -Command $Command } } catch { })
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

    It 'reads a case statement''s patterns as patterns, whose '')'' closes nothing, and its commands as commands' {
        # Valid Bash: 'bash -n' accepts it.
        $text = 'case "$r" in *completed*|x) echo "$r"; git push --for''ce'';; (y) exit 1 ;; esac; echo done'
        $commands = @(try { InModuleScope KitCommandGuard -Parameters @{ Text = $text } { param($Text) Get-BashCommand -Command $Text } } catch { })
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Be @('case $r in', 'echo $r', 'git push --force', 'exit 1', 'echo done')
    }

    It 'also resolves the commands inside $( ), backticks and <( )' {
        $commands = @(InModuleScope KitCommandGuard { Get-BashCommand -Command "echo ""`$(git push --for'ce')"" ``gh 'api'`` <(ls -a)" })
        $commands.Words | Should -Contain '--force'
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'git push --force'
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'gh api'
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'ls -a'
    }

    It 'also resolves the command inside <Command>, which Bash runs as it expands it' -ForEach @(
        # Review of the rebased branch: unset X; echo ${X:-$(echo ran)} prints "ran".
        @{ Command = "echo `${X:-`$(git push --for'ce')}" }
        @{ Command = "echo ""`${X:-`$(git push --for'ce')}""" }
        @{ Command = ": `${X:=``git push --for'ce'``}" }
        @{ Command = "echo `$(( `$(git push --for'ce') ))" }
        @{ Command = "echo `${X:-`${Y:-`$(git push --for'ce')}}" }
    ) {
        $commands = @(InModuleScope KitCommandGuard -Parameters @{ Text = $Command } { param($Text) Get-BashCommand -Command $Text })
        ($commands | ForEach-Object { $_.Words -join ' ' }) | Should -Contain 'git push --force'
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

Describe 'Get-CommandGuardDecision for a path, a program''s name or a glob' {
    # Review round 1: each of these runs the asked script or program, yet its spelling matched no ask rule.
    It 'asks for <Tool> command <Command>, which names an asked script or program another way' -ForEach @(
        @{ Tool = 'PowerShell'; Command = './tools/./New-KitApp.ps1 -Name x' }
        @{ Tool = 'PowerShell'; Command = './tools/.\New-KitApp.ps1 -Name x' }
        @{ Tool = 'PowerShell'; Command = './tools/./Install-PlaywrightBrowser.ps1' }
        @{ Tool = 'PowerShell'; Command = 'git.exe push --force' }
        @{ Tool = 'PowerShell'; Command = '& "C:\Program Files\Git\cmd\git.exe" push --force' }
        @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools//New-KitApp.ps1 -Name x' }
        # NTFS opens a file whatever its case, and Bash's rules match case-sensitively.
        @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools/new-kitapp.ps1 -Name x' }
        @{ Tool = 'Bash'; Command = 'GIT push --force' }
        @{ Tool = 'Bash'; Command = '/usr/bin/git push --force' }
        # A glob the shell expands, against the working directory, to an asked script.
        @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools/New-K*.ps1 -Name x' }
        @{ Tool = 'PowerShell'; Command = './tools/New-K*.ps1 -Name x' }
    ) {
        Get-KitDecision -Tool $Tool -Command $Command | Should -Not -BeNullOrEmpty
    }

    # Review of the rebased branch: Windows opens a file by its 8.3 short name too (NEW-KI~1.PS1), where the volume
    # makes them. Skipped where there's none: on Linux and macOS, or on a volume with short names turned off.
    It 'asks in <Tool> for <Script> named by its Windows short name, as in <Command>' -ForEach @(
        @{ Tool = 'PowerShell'; Script = 'New-KitApp.ps1'; Command = './tools/{0} -Name x' }
        @{ Tool = 'PowerShell'; Script = 'Set-AgentMode.ps1'; Command = './tools/{0} -Mode Review' }
        @{ Tool = 'Bash'; Script = 'Set-AgentMode.ps1'; Command = 'pwsh -NoProfile -File ./tools/{0} -Mode Review' }
    ) {
        $short = Get-ShortName -Path (Join-Path $script:KitRoot 'tools' $Script)
        if (-not $short) { Set-ItResult -Skipped -Because "$Script has no 8.3 short name here"; return }
        Get-KitDecision -Tool $Tool -Command ($Command -f $short) | Should -BeLike "*$Script*"
    }

    # Review round 4: a splat leaves no option text for the rule, so only the built-value check can ask, and it must
    # know the script by the same spellings.
    It 'asks for a splat onto <Command>, an asked script named by a glob' -ForEach @(
        @{ Command = "`$p = @{ Mode = 'Review' }; ./tools/Set-Agent*.ps1 @p" }
        @{ Command = "`$o = @{ Install = `$true }; ./tools/Initialize-Dev*.ps1 @o" }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -BeLike '*builds an argument*'
    }

    It 'asks for a splat onto <Script> named by its Windows short name' -ForEach @(
        @{ Script = 'Set-AgentMode.ps1'; Command = "`$p = @{ Mode = 'Review' }; ./tools/{0} @p" }
        @{ Script = 'Initialize-DevMachine.ps1'; Command = "`$o = @{ Install = `$true }; ./tools/{0} @o" }
    ) {
        $short = Get-ShortName -Path (Join-Path $script:KitRoot 'tools' $Script)
        if (-not $short) { Set-ItResult -Skipped -Because "$Script has no 8.3 short name here"; return }
        Get-KitDecision -Tool 'PowerShell' -Command $Command.Replace('{0}', $short) | Should -BeLike '*builds an argument*'
    }

    # Review round 5: Bash's bracket expressions negate with ! or ^ and name classes such as [:upper:], which
    # PowerShell's wildcards don't, so the glob matched nothing and kept its spelling.
    It 'asks for <Command>, whose Bash bracket glob expands to an asked script' -ForEach @(
        @{ Command = 'pwsh -NoProfile -File ./tools/[!X]ew-KitApp.ps1 -Name x' }
        @{ Command = 'pwsh -NoProfile -File ./tools/[[:upper:]]et-AgentMode.ps1 -Mode Review' }
        @{ Command = 'pwsh -NoProfile -File ./tools/[^X]nitialize-DevMachine.ps1 -Install' }
        # Review round 6: an escaped or quoted ']' is a member of the set, and [=c=] and [.c.] are classes too.
        @{ Command = 'pwsh -NoProfile -File ./tools/[N\]]ew-KitApp.ps1 -Name x' }
        @{ Command = 'pwsh -NoProfile -File ./tools/[N'']'']ew-KitApp.ps1 -Name x' }
        @{ Command = 'pwsh -NoProfile -File ./tools/[[=N=]]ew-KitApp.ps1 -Name x' }
        @{ Command = 'pwsh -NoProfile -File ./tools/[[.S.]]et-AgentMode.ps1 -Mode Review' }
        # Review round 7: Bash splits a pattern only at '/', so a quoted '\' is a member of the set, not a folder.
        @{ Command = 'pwsh -NoProfile -File ./tools/[N\\]ew-KitApp.ps1 -Name x' }
        @{ Command = 'pwsh -NoProfile -File ./tools/[S''\'']et-AgentMode.ps1 -Mode Review' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -BeLike '*resolved this command*'
    }

    It 'tries each file a glob matches on its own, as Bash runs it when only that one matches' {
        # Ten brackets give more readings than the guard keeps, so it matches every file in tools/; the asked script
        # must still be tried alone in the glob's place, where the rule expects it.
        $command = 'pwsh -NoProfile -File ./tools/[N][e][w]-[K][i][t][A][p][p].ps1 -Name x'
        Get-KitDecision -Tool 'Bash' -Command $command | Should -BeLike '*"pwsh -NoProfile -File ./tools/New-KitApp.ps1 -Name x"*'
    }

    It 'leaves a * glob whose first match, which the shell runs, is no asked script to the rules' {
        # Review round 7: Bash runs Export-KitApp.ps1 here, with the others as its arguments; only a bracket glob,
        # which the guard reads more widely than Bash, has each match tried alone.
        Get-KitDecision -Tool 'Bash' -Command 'pwsh -NoProfile -File ./tools/*-K*.ps1 -Name x' | Should -BeNullOrEmpty
    }

    It 'asks, rather than risk the hook''s time-out, for a bracket glob that matches more than 200 files' {
        # Review round 8: each match is tried alone, so the cost grows with the square of the files, and a hook that
        # times out leaves the call unchecked.
        $folder = Join-Path $TestDrive 'many'
        New-Item -ItemType Directory -Path $folder | Out-Null
        1..201 | ForEach-Object { New-Item -ItemType File -Path (Join-Path $folder "f$_.txt") | Out-Null }
        Get-CommandGuardDecision -Tool 'Bash' -Command 'ls ./many/[a-z]*' -AskRules @() -WorkingDirectory $TestDrive | Should -BeLike '*more than 200*'
    }

    It 'asks for bracket globs that together match more than 200 files in one command' {
        # Review round 9: the cost grows with all the files the command's bracket globs try, not one glob's.
        foreach ($name in 'a', 'b') {
            $folder = Join-Path $TestDrive $name
            New-Item -ItemType Directory -Path $folder | Out-Null
            1..101 | ForEach-Object { New-Item -ItemType File -Path (Join-Path $folder "f$_.txt") | Out-Null }
        }
        Get-CommandGuardDecision -Tool 'Bash' -Command 'ls ./a/[a-z]* ./b/[a-z]*' -AskRules @() -WorkingDirectory $TestDrive | Should -BeLike '*more than 200*'
    }

    It 'leaves a glob that expands to no asked script to the rules' {
        Get-KitDecision -Tool 'Bash' -Command 'ls ./tools/*.ps1' | Should -BeNullOrEmpty
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
        # A substitution whose output is fixed text: cat reading a heredoc whose quoted delimiter stops expansion.
        @{ Command = "git commit -m ""`$(cat <<'EOF'`nfix: don't stop (yet)`n`nCo-Authored-By: A <a@b.c>`nEOF`n)""" }
        @{ Command = 'gh pr view $n --json state' }
        @{ Command = 'echo ${HOME} {a} {} x,y' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -BeNullOrEmpty
    }

    # Review round 1: these words take their value only when Bash runs the command, so no rule can read them. Each is
    # in a command whose program and subcommand an ask rule names (git push, git clean), so it could be an asked form.
    It 'asks for <Command>, which builds an argument of an asked command when it runs' -ForEach @(
        @{ Command = 'git push origin {x,-f}' }
        @{ Command = 'git {clean,} -fd' }
        @{ Command = 'git push origin -{f,q}' }
        @{ Command = 'git push origin x{1..2}' }
        @{ Command = 'git push origin ${u:--f}' }
        @{ Command = "git push origin ""`${x:-`$(git status)}""" }
        @{ Command = 'git push origin $((git status) )' }
        @{ Command = 'git push "$(printf -- --for)ce"' }
        @{ Command = 'git push `printf -- -f`' }
        @{ Command = 'git $(echo push) --force' }
        @{ Command = 's=New-KitApp; pwsh -NoProfile -File ./tools/$s.ps1' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -BeLike '*builds an argument*'
    }

    # Review rounds 1 and 2: a variable's value is known only when the command runs, however the input or the
    # environment set it, so in an asked command any variable asks.
    It 'asks for <Command>, which uses a variable in an asked command' -ForEach @(
        @{ Command = 'f=-f; git push origin $f' }
        @{ Command = 'for f in -f; do git push origin "$f"; done' }
        @{ Command = 'read f; git push origin ${f}' }
        @{ Command = 'export F=--force && git push origin $F' }
        @{ Command = 'printf -v X %s --for""ce; git push origin "$X"' }
        @{ Command = 'mapfile -t X <<< --for""ce; git push origin "$X"' }
        @{ Command = ': ${X:=--for""ce}; git push origin $X' }
        @{ Command = 'git push origin $B' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -BeLike '*builds an argument*'
    }

    # Review round 2: git's global options come before the subcommand, so a built one can sit later than right after
    # the program.
    It 'asks for <Command>, whose subcommand is built after a global option' -ForEach @(
        @{ Command = 'p=pu""sh; git -C . $p --force origin main' }
        @{ Command = 'git -C . ${p:-pu""sh} --force origin main' }
        @{ Command = 'git --no-pager $p --force origin main' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -BeLike '*builds an argument*'
    }

    # Review round 2: Bash ends a heredoc at its first delimiter line and runs what follows, so a second one can hide a
    # command whose output becomes the argument.
    It 'asks for a substitution whose heredoc ends before its last delimiter line' {
        $command = "git push origin `$(cat <<'EOF'`nx`nEOF`necho --for''ce`nEOF`n)"
        Get-KitDecision -Tool 'Bash' -Command $command | Should -BeLike '*builds an argument*'
    }

    It 'leaves a quoted heredoc that ends at its one delimiter line, in an asked command, to the rules' {
        # Its output is fixed text, so it's no built value even where an ask rule names the command.
        $command = "git push origin ""`$(cat <<'EOF'`nfeat/x`nEOF`n)"""
        Get-KitDecision -Tool 'Bash' -Command $command | Should -BeNullOrEmpty
    }

    # A built value matters only where it could make an asked command: replaying the kit's sessions showed these
    # forms in routine work, and no ask rule names their program and subcommand.
    It 'leaves <Command> to the rules: it builds a value, but no ask rule names its command' -ForEach @(
        @{ Command = 'M=/tmp/msg.txt && cat > $M <<''EOF''' + "`nfix: x`nEOF`n" + 'git commit -F $M' }
        @{ Command = "id=`$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') && gh run view `$id --log-failed" }
        @{ Command = 'echo "$(git status)" {a,b}' }
        @{ Command = 'for f in a b; do git add "$f"; done' }
        # "--repo" isn't gh's repo subcommand: a subcommand is a whole word.
        @{ Command = 'r=a/b; gh pr view 8 --repo $r --json state' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -BeNullOrEmpty
    }

    It 'asks for <Command>, which an ask rule covers once its expansions are taken out (an unset one is empty)' -ForEach @(
        @{ Command = 'git push --for${X}ce' }
        @{ Command = 'git push "--for$X"ce' }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -Not -BeNullOrEmpty
    }

    It 'asks for a command Bash can''t read, since nothing in it can be resolved' {
        Get-CommandGuardDecision -Tool 'Bash' -Command "git push 'x" -AskRules @() | Should -BeLike '*can''t*'
    }

    # Claude Code's permissions page: before matching, it strips the wrappers timeout, time, nice, nohup, stdbuf,
    # command, builtin, noglob and bare xargs, and an ask rule matches past any leading assignment. A rule that starts
    # with the command's name ("git clean *") then sees the inner command, so the guard must too (review round 1).
    It 'asks for <Command>, whose inner command, past a wrapper, an assignment or a reserved word, an ask rule covers' -ForEach @(
        @{ Command = "timeout 60 pwsh -NoProfile -File ./tools/New-Kit'App'.ps1 -Name X" }
        @{ Command = "timeout -s KILL 5m git cl'ean' -fd" }
        @{ Command = "FOO=1 BAR='a b' git cl'ean' -fd" }
        @{ Command = "command pwsh -NoProfile -File ./tools/Install-Playwright'Browser'.ps1" }
        @{ Command = "nice -n 5 nohup stdbuf -o L time -p git cl'ean' -fd" }
        @{ Command = "builtin noglob xargs git cl'ean' -fd" }
        @{ Command = "if true; then git cl'ean' -fd; fi" }
        @{ Command = "for x in a; do git cl'ean' -fd; done" }
        @{ Command = "{ git cl'ean' -fd; }" }
        @{ Command = "! git cl'ean' -fd" }
        @{ Command = "while false; do :; done; until true; do git reset --ha'rd' x; done" }
    ) {
        Get-KitDecision -Tool 'Bash' -Command $Command | Should -Not -BeNullOrEmpty
    }

    It 'doesn''t strip a wrapper Claude Code keeps: <Command>' -ForEach @(
        # "command -v" looks a command up rather than running it, and xargs with options is matched as xargs.
        @{ Command = 'command -v git clean -fd' }
        @{ Command = 'xargs -n1 git clean -fd' }
    ) {
        Get-CommandGuardDecision -Tool 'Bash' -Command $Command -AskRules 'Bash(git clean *)' | Should -BeNullOrEmpty
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
        # Dot-sourcing runs the script too, and the asks name it without the "." (review round 1).
        @{ Command = ". ./tools/New-Kit'App'.ps1 -Name X" }
        # An expansion in a string that's empty when it runs (review round 1).
        @{ Command = 'git push "--for${null}ce"' }
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
        $reason | Should -BeLike '*builds an argument*'
    }

    It 'asks for <Command>, which uses a variable in an asked command' -ForEach @(
        # Review rounds 1 and 2: a variable's value is known only when the command runs, however it was set.
        @{ Command = "`$f = '--for' + 'ce'; git push origin `$f" }
        @{ Command = "foreach (`$f in '--force') { git push origin `$f }" }
        @{ Command = "`$F = '-f'; git push origin ""x`$f""" }
        @{ Command = "Set-Variable p --force; git push origin `$p" }
        @{ Command = "Write-Output '--force' -OutVariable p; git push origin `$p" }
        @{ Command = "`$p = 'push'; git -C . `$p --force origin main" }
        # The program ./*playwright.ps1 names, with a built subcommand that could be "install".
        @{ Command = './fixtures/x/playwright.ps1 $a' }
        # A splat past a one-word rule, *Initialize-DevMachine*-I*: its program is its first literal part.
        @{ Command = "`$o = @{ Install = `$true }; ./tools/Initialize-DevMachine.ps1 @o" }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -BeLike '*builds an argument*'
    }

    It 'asks for <Command>, which computes a value from a literal in an asked command' -ForEach @(
        # Review of the rebased branch: a method call, an index or a list on a literal is a value known only as it runs.
        @{ Command = "git push origin '--forXe'.Replace('X','c')" }
        @{ Command = "git push origin '-F'.ToLower()" }
        @{ Command = "git push origin '-f-'[0..1]" }
        @{ Command = "git push origin 'x','--for''ce'" }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -BeLike '*builds an argument*'
    }

    It 'asks for <Command>, which passes a command''s output through a variable, whatever the command it reaches' -ForEach @(
        # Review round 1: the nested-command ask, moved one statement earlier.
        @{ Command = "`$b = Get-Content ./.env -Raw; Add-ReviewReply -Body `$b" }
        @{ Command = "Get-Content ./.env -Raw -OutVariable b; Add-ReviewReply -Body `$b" }
        @{ Command = "Get-Content ./.env -Raw -ov:+b; Add-ReviewReply -Body `$b" }
        # Review of the rebased branch: a pipeline fills a variable too.
        @{ Command = "Get-Content ./.env -Raw | Tee-Object -Variable b; Add-ReviewReply -Body `$b" }
        @{ Command = "Get-Content ./.env -Raw | Set-Variable b; Add-ReviewReply -Body `$b" }
        @{ Command = "Get-Content ./.env -Raw | sv -Name b; Add-ReviewReply -Body `$b" }
        @{ Command = "foreach (`$line in (Get-Content ./.env)) { Add-ReviewReply -Body `$line }" }
    ) {
        Get-CommandGuardDecision -Tool 'PowerShell' -Command $Command -AskRules @() | Should -BeLike '*builds an argument*'
    }

    It 'leaves <Command> to the rules: its variable holds a value the input chose, and no ask rule names its command' -ForEach @(
        # Review round 3: ./*playwright.ps1 install* names a playwright.ps1 script, not every ./ script.
        @{ Command = './tools/Invoke-KitTests.ps1 -Path $p' }
        @{ Command = '.\tools\Test-Scorecard.ps1 -Path $x' }
        @{ Command = "`$n = 92; Wait-PullRequest -Repository a/b -Number `$n -For Checks" }
        @{ Command = "`$m = 'fix: x'; git commit -m `$m" }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -BeNullOrEmpty
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

Describe 'Get-CommandGuardDecision for a kit script that runs a command' {
    # Review of the rebased branch: Invoke-WithPlaywrightImage.ps1 runs the words after its own parameters on the host
    # when no project uses Playwright, under the ./tools/* allow.
    It 'asks in <Tool> for <Command>, whose command the script runs is asked' -ForEach @(
        @{ Tool = 'PowerShell'; Command = './tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx -- git clean -fdx' }
        @{ Tool = 'PowerShell'; Command = './tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx git reset --hard HEAD~3' }
        @{ Tool = 'PowerShell'; Command = "./.kit/tools/Invoke-WithPlaywrightImage.ps1 -Solution:x.slnx -Pin p -- git push --for'ce'" }
        @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx -- git clean -fdx' }
        # Review round 2: a switch before its parameters, or the script named by a glob, still runs the command.
        @{ Tool = 'PowerShell'; Command = './tools/Invoke-WithPlaywrightImage.ps1 -Verbose -Solution x.slnx -- git clean -fdx' }
        @{ Tool = 'PowerShell'; Command = './tools/Invoke-WithPlaywrightImage.ps1 -Debug -Solution x.slnx winget install foo' }
        @{ Tool = 'PowerShell'; Command = './tools/Invoke-WithPlaywright*.ps1 -Solution x.slnx -- git clean -fdx' }
        @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools/Invoke-WithPlaywright*.ps1 -Solution x.slnx -- git clean -fdx' }
        # Review round 3: pwsh runs its first argument that isn't an option as the script, -File or not.
        @{ Tool = 'Bash'; Command = 'pwsh ./tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx -- git clean -fdx' }
        @{ Tool = 'PowerShell'; Command = 'pwsh -NoProfile ./tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx -- git clean -fdx' }
    ) {
        Get-KitDecision -Tool $Tool -Command $Command | Should -Not -BeNullOrEmpty
    }

    It 'asks for <Command>, whose command the script runs takes a value built as it runs' -ForEach @(
        # Review round 3: a variable or a method call in the command the script runs, as in any asked command.
        @{ Command = './tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx -- git push origin $b' }
        @{ Command = "./tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx -- git push origin '--forXe'.Replace('X','c')" }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -BeLike '*builds an argument*'
    }

    It 'asks for the command Invoke-WithPlaywrightImage.ps1 runs when the script is named by its Windows short name' {
        $short = Get-ShortName -Path (Join-Path $script:KitRoot 'tools' 'Invoke-WithPlaywrightImage.ps1')
        if (-not $short) { Set-ItResult -Skipped -Because 'Invoke-WithPlaywrightImage.ps1 has no 8.3 short name here'; return }
        Get-KitDecision -Tool 'PowerShell' -Command "./tools/$short -Solution x.slnx -- git clean -fdx" | Should -BeLike '*git clean*'
    }

    It 'leaves <Command> to the rules, since the command it runs is one they allow' -ForEach @(
        @{ Command = './tools/Invoke-WithPlaywrightImage.ps1 -Solution x.slnx -- dotnet test --no-build' }
    ) {
        Get-KitDecision -Tool 'PowerShell' -Command $Command | Should -BeNullOrEmpty
    }
}

Describe 'Get-CommandGuardDecision for a rule written with quotes' {
    It 'asks in <Tool> for <Command>, which an ask rule written with double quotes around a word with a space covers' -ForEach @(
        # The kit's rule "pwsh -NoProfile -Command ""Install-PSResource *" spells the quotes Claude Code usually writes.
        # Another quoting of the same word reaches pwsh as the same text, so it asks too.
        @{ Tool = 'PowerShell'; Command = "pwsh -NoProfile -Command 'Install-PSResource Pester'" }
        @{ Tool = 'PowerShell'; Command = 'pwsh -NoProfile -Command "Install-PSResource Pester"' }
        @{ Tool = 'Bash'; Command = "pwsh -NoProfile -Command 'Install-PSResource Pester'" }
        @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -Command Install-PSResource\ Pester' }
    ) {
        Get-KitDecision -Tool $Tool -Command $Command | Should -BeLike '*Install-PSResource*'
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
