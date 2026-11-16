#Requires -Version 7.6
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

        # Whether a rule of the given kind (ask by default) catches a command, matched as Claude Code's permissions
        # page describes, by the command guard's own matcher (KitCommandGuard.psm1, ADR-0076). By default the match is
        # case-sensitive, the stricter reading for a test that a rule asks. -IgnoreCase is the stricter reading for a
        # test that a rule doesn't ask, and the real one for PowerShell, whose matching the permissions page calls
        # case-insensitive (on 2026-11-11 a scan of the session transcripts found 38 prompts for PowerShell commands
        # that matched '*git *push* -f*' only through a later '-Force' or '-F').
        # Claude Code also splits compound commands and canonicalizes PowerShell aliases (ls, cat, gc) before
        # matching; these helpers don't, so each test names one command by its cmdlet name.
        Import-Module -Name (Join-Path $repoRoot 'tools' 'KitCommandGuard.psm1') -Force
        function Test-RuleMatch([string] $Kind, [string] $Tool, [string] $Command, [switch] $IgnoreCase) {
            [bool] @(Get-RuleList $Kind | Where-Object { Test-PermissionRuleMatch -Rule $_ -Tool $Tool -Command $Command -IgnoreCase:$IgnoreCase }).Count
        }
        function Test-AskRuleMatch([string] $Tool, [string] $Command, [switch] $IgnoreCase) {
            Test-RuleMatch -Kind 'ask' -Tool $Tool -Command $Command -IgnoreCase:$IgnoreCase
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
            # Installs on the owner's machine. -I* catches -Install and its prefixes (-Ins), which PowerShell accepts.
            @{ Command = 'winget install *' }, @{ Command = '*Initialize-DevMachine*-I*' }
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
            # The agent's own permissions and connectors (SEC-004), and the working mode (ADR-0035).
            @{ Path = './.claude/settings.json' }, @{ Path = './.claude/settings.local.json' }, @{ Path = './.agent-mode' }
            @{ Path = './.mcp.json' }, @{ Path = './.vscode/mcp.json' },
            # An app's kit-managed scripts and manifest (ADR-0032): the sync job changes them, not a hand edit.
            @{ Path = './.kit/**' }
            # The command guard (ADR-0076), which an edit could turn off as surely as one to the settings.
            @{ Path = './tools/KitCommandGuard.psm1' }, @{ Path = './tools/Invoke-CommandGuard.ps1' }
        ) {
            (Get-RuleList 'ask') -ccontains "Edit($Path)" | Should -BeTrue
        }

        # ADR-0076: before every Bash or PowerShell call, the command guard applies the ask rules to the command as the
        # shell resolves it. Exec form (args), so the project path needs no quoting; pwsh, the kit's PowerShell 7.
        It 'runs the command guard before every Bash or PowerShell call' {
            $groups = @(if ($settings.ContainsKey('hooks') -and $settings['hooks'].ContainsKey('PreToolUse')) { $settings['hooks']['PreToolUse'] })
            $guard = @($groups | Where-Object { $_['matcher'] -ceq 'Bash|PowerShell' } | ForEach-Object { $_['hooks'] } |
                    Where-Object { $_['type'] -ceq 'command' -and $_['command'] -ceq 'pwsh' })
            $guard.Count | Should -Be 1
            $guard[0]['args'] | Should -Be @('-NoProfile', '-NonInteractive', '-File', '${CLAUDE_PROJECT_DIR}/tools/Invoke-CommandGuard.ps1')
            Join-Path $repoRoot 'tools' 'Invoke-CommandGuard.ps1' | Should -Exist
        }

        # Auto mode is the default (ADR-0035): the rules review mode adds can't also be in the shared file, or
        # auto mode would ask too. Review mode adds them to the owner's .claude/settings.local.json.
        It 'leaves the review-mode rules out of the shared settings: <Rule>' -ForEach @(
            @{ Rule = 'Bash(gh pr merge *)' }, @{ Rule = 'PowerShell(gh pr merge *)' }
            @{ Rule = 'Bash(gh repo edit *)' }, @{ Rule = 'PowerShell(gh repo edit *)' }
            @{ Rule = 'Bash(dotnet add * package *)' }, @{ Rule = 'PowerShell(dotnet add * package *)' }
            @{ Rule = 'Edit(./**/Directory.Packages.props)' }, @{ Rule = 'Edit(./**/Directory.Build.props)' }
            @{ Rule = 'Edit(./nuget.config)' }, @{ Rule = 'Edit(./global.json)' }, @{ Rule = 'Edit(./.config/dotnet-tools.json)' }
            @{ Rule = 'Edit(./.github/workflows/**)' }, @{ Rule = 'Edit(./.github/dependabot.yml)' }
        ) {
            (Get-RuleList 'ask') -ccontains $Rule | Should -BeFalse
            . (Join-Path $repoRoot 'tools' 'Set-AgentMode.ps1')
            $script:ReviewAskRules | Should -Contain $Rule -Because 'review mode must still ask for it'
        }

        # Switching modes is the owner's call in both modes, so an agent can't turn its own prompts off. Any form
        # that passes -Mode, or a prefix of it such as -M (PowerShell accepts one), asks, whatever the path; the
        # script takes no positional arguments, so -M is the only way in (review 1 of the modes PR).
        It 'asks before switching modes with <Tool>(<Command>)' -ForEach @(
            @{ Tool = 'PowerShell'; Command = './tools/Set-AgentMode.ps1 -Mode Auto' }
            @{ Tool = 'PowerShell'; Command = './tools/Set-AgentMode -Mode Review' }
            @{ Tool = 'PowerShell'; Command = '.\tools\Set-AgentMode.ps1 -Mode Auto' }
            @{ Tool = 'PowerShell'; Command = './tools/./Set-AgentMode.ps1 -M Auto' }
            @{ Tool = 'PowerShell'; Command = 'pwsh -NoProfile -File ./tools/Set-AgentMode.ps1 -Mode Auto' }
            @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools/../tools/Set-AgentMode.ps1 -Mode Auto' }
            @{ Tool = 'PowerShell'; Command = './.kit/tools/Set-AgentMode.ps1 -RepoRoot . -Mode Auto' }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command $Command | Should -BeTrue -Because "an ask rule should catch $Tool($Command)"
        }

        # Checking the mode happens at the start of every task; in auto mode it mustn't prompt (review 1).
        It 'doesn''t ask just to show the mode: <Tool>(<Command>)' -ForEach @(
            @{ Tool = 'PowerShell'; Command = './tools/Set-AgentMode.ps1' }
            @{ Tool = 'PowerShell'; Command = './.kit/tools/Set-AgentMode.ps1 -RepoRoot .' }
            # A worktree path with "-m" in it isn't -Mode (review 2 of the modes PR).
            @{ Tool = 'PowerShell'; Command = './tools/Set-AgentMode.ps1 -RepoRoot ../dotnet-agent-kit-main' }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command $Command | Should -BeFalse
        }

        # "Always ask" in AGENTS.md: the common forms of deleting, force-pushing, publishing and releasing prompt
        # in both modes, though `git push *` and the like are allowed (review 1 of the modes PR).
        It 'asks before the hard limit <Tool>(<Command>)' -ForEach @(
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'git push origin --delete feat/x' }
                @{ Tool = $tool; Command = 'git push -d origin feat/x' }
                @{ Tool = $tool; Command = 'git push --force origin feat/x' }
                @{ Tool = $tool; Command = 'git push --force-with-lease origin feat/x' }
                @{ Tool = $tool; Command = 'git push -f origin feat/x' }
                @{ Tool = $tool; Command = 'gh repo edit --visibility public' }
                @{ Tool = $tool; Command = 'gh repo delete DerekFoulk/kit-app-test' }
                @{ Tool = $tool; Command = 'gh release create v0.1.0' }
                @{ Tool = $tool; Command = 'gh api repos/DerekFoulk/x --method DELETE' }
                @{ Tool = $tool; Command = 'gh api -X DELETE repos/DerekFoulk/x' }
                # Review 2 of the modes PR: refspec forms, git -C, mirror and prune; rulesets and merge settings.
                @{ Tool = $tool; Command = 'git push origin :feat/x' }
                @{ Tool = $tool; Command = 'git push origin +feat/x' }
                @{ Tool = $tool; Command = 'git -C . push --force origin x' }
                @{ Tool = $tool; Command = 'git -C . push origin --delete x' }
                @{ Tool = $tool; Command = 'git push --mirror origin' }
                @{ Tool = $tool; Command = 'git push --prune origin' }
                @{ Tool = $tool; Command = 'gh api -X PUT repos/o/r/rulesets/1 --input r.json' }
                @{ Tool = $tool; Command = 'gh api -X PUT repos/o/r/branches/main/protection --input p.json' }
                @{ Tool = $tool; Command = 'gh api -X PATCH repos/o/r -f allow_squash_merge=true' }
                @{ Tool = $tool; Command = 'gh api -X PATCH repos/o/r -f visibility=public' }
                @{ Tool = $tool; Command = 'gh repo edit --enable-squash-merge' }
                @{ Tool = $tool; Command = 'gh repo edit --delete-branch-on-merge=false' }
                @{ Tool = $tool; Command = 'gh repo edit --default-branch dev' }
                # Review 3 of PR 19: gh api's other repo fields, quoted refspecs and a trailing -d.
                @{ Tool = $tool; Command = 'gh api -X PATCH repos/o/r -F private=false' }
                @{ Tool = $tool; Command = 'gh api -X PATCH repos/o/r -F delete_branch_on_merge=false' }
                @{ Tool = $tool; Command = 'gh api -X PATCH repos/o/r -f default_branch=dev' }
                @{ Tool = $tool; Command = "git push origin ':feat/x'" }
                @{ Tool = $tool; Command = 'git push origin ":feat/x"' }
                @{ Tool = $tool; Command = "git push origin '+feat/x'" }
                @{ Tool = $tool; Command = 'git push origin feat/x -d' }
                # Review 3 of ADR-0075's PR: 'git push *' is allowed, and these run a program (probed with a local bare repo).
                @{ Tool = $tool; Command = 'git push --receive-pack=./evil.sh origin feat/x' }
                @{ Tool = $tool; Command = 'git push --exec=./evil.sh origin feat/x' }
                # Review 4: git takes any unique prefix of a long option (probed with git 2.56.0).
                @{ Tool = $tool; Command = 'git push --receive=../evil.sh ../remote.git HEAD:refs/heads/x' }
                @{ Tool = $tool; Command = 'git push --rece=../evil.sh origin feat/x' }
                @{ Tool = $tool; Command = 'git push --exe=../evil.sh origin feat/x' }
                @{ Tool = $tool; Command = 'git push --e=../evil.sh origin feat/x' }
                @{ Tool = $tool; Command = 'git push --dele origin feat/x' }
                @{ Tool = $tool; Command = 'git push origin --del feat/x' }
                @{ Tool = $tool; Command = 'git push --mir origin' }
                @{ Tool = $tool; Command = 'git push --pru origin' }
                # Review 5: --m alone is --mirror, and a quoted long option must still match (as the quoted refspecs do).
                @{ Tool = $tool; Command = 'git push --m origin' }
                @{ Tool = $tool; Command = 'git push origin --m' }
                @{ Tool = $tool; Command = "git push '--exec=./evil.sh' origin feat/x" }
                @{ Tool = $tool; Command = 'git push "--e=./evil.sh" origin feat/x' }
                # Review 6: the likeliest joined short options, matched as whole words (probed: -uf force-pushes,
                # -ud deletes). Other clusters, such as -qf, are a known limit (ADR-0075, GAP-044).
                @{ Tool = $tool; Command = 'git push -uf origin feat/x' }
                @{ Tool = $tool; Command = 'git push -fu origin feat/x' }
                @{ Tool = $tool; Command = 'git push -ud origin feat/x' }
                @{ Tool = $tool; Command = 'git push -du origin feat/x' }
                @{ Tool = $tool; Command = 'git push origin feat/x -uf' }
                @{ Tool = $tool; Command = 'git push origin feat/x -ud' }
                # Review 7: the end-of-command -fu and -du forms.
                @{ Tool = $tool; Command = 'git push origin feat/x -fu' }
                @{ Tool = $tool; Command = 'git push origin feat/x -du' }
            }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command $Command | Should -BeTrue -Because "an ask rule should catch $Tool($Command)"
        }

        # Claude Code warns that a rule mixing '*' with a trailing ":*" "will likely never match".
        It 'has no rule that mixes * with the trailing :* prefix syntax' {
            @((Get-RuleList 'allow') + (Get-RuleList 'ask') + (Get-RuleList 'deny')) |
                Where-Object { $_ -match '^\w+\((.*)\)$' -and $Matches[1] -match '^(.+):\*$' -and $Matches[1] -match '\*' } |
                Should -BeNullOrEmpty
        }

        It 'still lets an ordinary push run unasked' {
            Test-AskRuleMatch -Tool 'Bash' -Command 'git push -q -u origin feat/agent-modes' -IgnoreCase | Should -BeFalse
            Test-AskRuleMatch -Tool 'PowerShell' -Command 'git push origin feat/defer-fix' -IgnoreCase | Should -BeFalse
        }

        # The owner asked (2026-11-11) to be asked only before destructive steps and releases. A push followed by
        # cleanup with -Force isn't a force-push. (A later separate -F, as in 'git commit -F msg.txt', still asks:
        # a rule can't tell it from a force-push's -f.)
        It 'doesn''t ask for a push that only a later -Force follows: <Tool>(<Command>)' -ForEach @(
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'git push -u origin feat/x 2>&1 | Select-Object -Last 2; if (Test-Path $c) { Remove-Item $c -Recurse -Force }' }
                @{ Tool = $tool; Command = 'git push -u origin feat/x; Remove-Item -LiteralPath $d -Recurse -Force' }
            }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command $Command -IgnoreCase | Should -BeFalse
        }

        It 'asks before a force-push with -f at the end: <Tool>(git push origin feat/x -f)' -ForEach @(
            @{ Tool = 'Bash' }, @{ Tool = 'PowerShell' }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command 'git push origin feat/x -f' | Should -BeTrue
        }

        # Installing software on the owner's machine is "Always ask" (ADR-0061): a local Playwright browser install,
        # by Playwright's own script, npx or the kit's script, prompts in both modes, in any case. The rules are
        # anchored at the start of a command, as the New-KitApp rules are, so a command that only names the script
        # or quotes the install (git add, git diff, grep, a commit message, Invoke-Mutant) doesn't prompt: the
        # owner asked (2026-11-11) to be asked only before destructive steps and releases. Playwright's script
        # always sits under bin/<config>/<tfm>/, so a bare or absolute path to it asks too (review 2). The trade-off
        # (review 3): a command that quotes the full path through bin with "install" after it, such as a commit
        # message or a grep, asks as well, and so does any command that starts with pwsh, ./, .\ or & and quotes
        # "playwright.ps1 install" later on; a missed install is worse than an extra prompt. Known misses, left to
        # "Always ask" and the reviewer (ADR-0026, ADR-0061): an install run through a variable or a pipeline
        # ('& $pw install', 'Get-ChildItem -Filter playwright.ps1 | ForEach-Object { & $_ install }'), a quoted
        # path, a wrapper such as 'bash -c', and the kit script by an absolute path, without ./ or .\ in some
        # forms (such as 'pwsh tools/...', 'tools\...' or '& tools/...'), by 'pwsh' with .\ or with flags other than -File and
        # -NoProfile, or dot-sourced and then called. Whether Claude Code checks each command of a compound
        # line on its own isn't verified. The kit script is kit-only (apps run it in CI from the kit's download),
        # so its rules use the kit's paths and app copies drop them.
        It 'asks before installing a browser locally: <Tool>(<Command>)' -ForEach @(
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'pwsh fixtures/WebUi/tests/Kit.WebUi.E2E.Tests/bin/Debug/net10.0/playwright.ps1 install chromium' }
                @{ Tool = $tool; Command = 'pwsh bin/Debug/net10.0/playwright.ps1 install --with-deps' }
                @{ Tool = $tool; Command = 'pwsh -NoProfile -File ./tools/Install-PlaywrightBrowser.ps1 -Solution dotnet-agent-kit.slnx' }
                @{ Tool = $tool; Command = 'npx playwright install chromium' }
                @{ Tool = $tool; Command = 'npx playwright@1.49.0 install chromium' }
                @{ Tool = $tool; Command = 'npx -y playwright install chromium' }
                @{ Tool = $tool; Command = 'pwsh ./tools/Install-PlaywrightBrowser.ps1 -Solution dotnet-agent-kit.slnx' }
                @{ Tool = $tool; Command = 'pwsh -File ./tools/Install-PlaywrightBrowser.ps1 dotnet-agent-kit.slnx' }
                @{ Tool = $tool; Command = 'fixtures/WebUi/tests/Kit.WebUi.E2E.Tests/bin/Debug/net10.0/playwright.ps1 install chromium' }
                @{ Tool = $tool; Command = 'pwsh tests/App.E2E.Tests/bin/Debug/net10.0/playwright.ps1 install --with-deps' }
                @{ Tool = $tool; Command = 'pwsh -NoProfile ./tools/Install-PlaywrightBrowser.ps1 -Solution dotnet-agent-kit.slnx' }
                # The trade-off above: quoting the full path through bin asks too.
                @{ Tool = $tool; Command = 'git commit -m "docs: pwsh fixtures/WebUi/tests/Kit.WebUi.E2E.Tests/bin/Debug/net10.0/playwright.ps1 install chromium"' }
            }
            # Run from the test project's folder by a bare path (review 5).
            @{ Tool = 'PowerShell'; Command = 'bin/Debug/net10.0/playwright.ps1 install chromium' }
            @{ Tool = 'PowerShell'; Command = 'bin\Debug\net10.0\playwright.ps1 install' }
            @{ Tool = 'Bash'; Command = 'bin/Debug/net10.0/playwright.ps1 install chromium' }
            # Run from the output folder itself, after cd bin/Debug/net10.0.
            @{ Tool = 'PowerShell'; Command = './playwright.ps1 install chromium' }
            @{ Tool = 'PowerShell'; Command = '.\playwright.ps1 install' }
            @{ Tool = 'PowerShell'; Command = '& ./playwright.ps1 install chromium' }
            @{ Tool = 'PowerShell'; Command = '& .\tools\Install-PlaywrightBrowser.ps1 -Solution dotnet-agent-kit.slnx' }
            @{ Tool = 'PowerShell'; Command = 'C:\src\app\tests\App.E2E.Tests\bin\Debug\net10.0\playwright.ps1 install chromium' }
            @{ Tool = 'PowerShell'; Command = '.\bin\Debug\net10.0\playwright.ps1 install chromium' }
            @{ Tool = 'PowerShell'; Command = '& ./tools/Install-PlaywrightBrowser.ps1 -Solution dotnet-agent-kit.slnx' }
            @{ Tool = 'PowerShell'; Command = 'tools/Install-PlaywrightBrowser.ps1 dotnet-agent-kit.slnx' }
            @{ Tool = 'PowerShell'; Command = '& ./bin/Debug/net10.0/playwright.ps1 install chromium' }
            @{ Tool = 'PowerShell'; Command = './bin/Debug/net10.0/playwright.ps1 install chromium' }
            @{ Tool = 'PowerShell'; Command = './tools/Install-PlaywrightBrowser.ps1 -Solution dotnet-agent-kit.slnx' }
            @{ Tool = 'PowerShell'; Command = './tools/Install-PlaywrightBrowser.ps1 dotnet-agent-kit.slnx' }
            @{ Tool = 'PowerShell'; Command = '.\tools\Install-PlaywrightBrowser.ps1 -Solution dotnet-agent-kit.slnx' }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command $Command -IgnoreCase | Should -BeTrue -Because "an ask rule should catch $Tool($Command)"
        }

        It 'doesn''t ask for a command that only names the install: <Tool>(<Command>)' -ForEach @(
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'dotnet test --project fixtures/WebUi/tests/Kit.WebUi.E2E.Tests' }
                @{ Tool = $tool; Command = 'Invoke-Pester -Path ./tools/tests/Install-PlaywrightBrowser.Tests.ps1' }
                @{ Tool = $tool; Command = 'git add tools/Install-PlaywrightBrowser.ps1 tools/tests/Install-PlaywrightBrowser.Tests.ps1' }
                @{ Tool = $tool; Command = 'git diff origin/main -- tools/Install-PlaywrightBrowser.ps1' }
                @{ Tool = $tool; Command = './tools/Invoke-Mutant.ps1 -Path ./tools/Install-PlaywrightBrowser.ps1 -TestPath ./tools/tests/Install-PlaywrightBrowser.Tests.ps1' }
                @{ Tool = $tool; Command = 'grep -rn "playwright.ps1 install" docs' }
                @{ Tool = $tool; Command = 'rg -n "playwright install" docs' }
                @{ Tool = $tool; Command = "git commit -m 'docs: the owner runs playwright.ps1 install chromium'" }
                @{ Tool = $tool; Command = 'gh pr create --title x --body "npx playwright install asks first"' }
                @{ Tool = $tool; Command = 'pwsh -NoProfile -Command "Invoke-Pester -Path ./tools/tests/Install-PlaywrightBrowser.Tests.ps1"' }
                @{ Tool = $tool; Command = "git commit -m 'docs: run pwsh bin/Debug/net10.0/playwright.ps1 install'" }
                @{ Tool = $tool; Command = "git commit -m 'docs: or & ./playwright.ps1 install'" }
                @{ Tool = $tool; Command = "git commit -m 'docs: or .\playwright.ps1 install'" }
                @{ Tool = $tool; Command = 'npx playwright test tests/install.spec.ts' }
                @{ Tool = $tool; Command = 'npx vitest install-helpers' }
                @{ Tool = $tool; Command = 'pwsh bin/Debug/net10.0/playwright.ps1 show-trace trace.zip' }
                # Review 4: pins each rule's "install" anchor, so running playwright.ps1 for anything else stays quiet.
                @{ Tool = $tool; Command = 'pwsh tests/App.E2E.Tests/bin/Debug/net10.0/playwright.ps1 show-trace trace.zip' }
                @{ Tool = $tool; Command = 'git diff -- tests/App/bin/Debug/net10.0/playwright.ps1' }
            }
            @{ Tool = 'PowerShell'; Command = './playwright.ps1 show-trace trace.zip' }
            @{ Tool = 'PowerShell'; Command = '.\playwright.ps1 --help' }
            @{ Tool = 'PowerShell'; Command = '& ./playwright.ps1 codegen' }
            @{ Tool = 'PowerShell'; Command = 'C:\src\app\bin\Debug\net10.0\playwright.ps1 codegen' }
            @{ Tool = 'PowerShell'; Command = 'bin/Debug/net10.0/playwright.ps1 show-trace trace.zip' }
            @{ Tool = 'PowerShell'; Command = 'bin\Debug\net10.0\playwright.ps1 codegen' }
            @{ Tool = 'Bash'; Command = 'bin/Debug/net10.0/playwright.ps1 show-trace trace.zip' }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command $Command -IgnoreCase | Should -BeFalse
        }

        It 'gives review mode exactly the rules auto mode drops from the shared settings' {
            . (Join-Path $repoRoot 'tools' 'Set-AgentMode.ps1')
            @($script:ReviewAskRules | Sort-Object) | Should -Be @(
                'Bash(dotnet add * package *)', 'Bash(gh pr merge *)', 'Bash(gh repo edit *)'
                'Edit(./.config/dotnet-tools.json)', 'Edit(./.github/dependabot.yml)', 'Edit(./.github/workflows/**)'
                'Edit(./**/Directory.Build.props)', 'Edit(./**/Directory.Packages.props)', 'Edit(./global.json)', 'Edit(./nuget.config)'
                'PowerShell(dotnet add * package *)', 'PowerShell(gh pr merge *)', 'PowerShell(gh repo edit *)'
            )
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
            # ADR-0075 allows '& ./tools/*' and '& .\tools\*', so the call operator's forms ask too (review 1 of PR 1).
            @{ Tool = 'PowerShell'; Command = '& ./tools/New-KitApp.ps1 -Name Contoso.Orders' }
            @{ Tool = 'PowerShell'; Command = '& .\tools\New-KitApp -Name Contoso.Orders' }
        ) {
            # A rule's '*' matches any text, as in Claude Code's patterns; [, ] and ? are taken literally. The match
            # is case-sensitive, the stricter reading, since whether Claude Code ignores case isn't documented.
            $matching = @(Get-RuleList 'ask' | Where-Object {
                    $_ -match "^$Tool\((.*)\)$" -and $Command -clike ($Matches[1] -replace '[\[\]?]', '`$0')
                })
            $matching | Should -Not -BeNullOrEmpty -Because "an ask rule should catch $Tool($Command)"
        }

        # ADR-0026 leaves pushes to main to the GitHub ruleset. ADR-0035 adds asks, never denies, for deleting and
        # force-pushing, which the ruleset doesn't guard on other branches; an ordinary push stays unasked. ADR-0075
        # adds asks for the two push options that run a program, and spells each long option as git's shortest
        # unique prefix (--de, --m, --pru, --rece, --e), since git takes any of them.
        It 'leaves pushes to the GitHub ruleset: no deny rule matches git push, and only destructive forms ask' {
            @(Get-RuleList 'deny') -match 'git push' | Should -BeNullOrEmpty
            @(Get-RuleList 'ask') -match 'git \*?push' | Where-Object { $_ -notmatch '--de\*|-d( |\))|--force|-f|:\*|\+\*|--m\*|--pru\*|--rece\*|--e\*| -uf| -ud| -du' } | Should -BeNullOrEmpty
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

        # ADR-0075 (owner, 2026-11-15): every command outside the allow list prompted, so he was asked about routine
        # commands he couldn't judge, turned on Bypass, which also skips the asks that matter, and turned it off again.
        # Routine commands are allowed; each must match an allow rule, case for case, and no ask or deny rule. Reading
        # files and read-only git aren't here: the Read, Grep and Glob tools and the Bash tool's built-in read-only
        # check (ls, cat, grep, git log, git diff and the rest) run them unasked, and Claude Code itself keeps their
        # risky forms out.
        It 'runs the routine command <Tool>(<Command>) unasked' -ForEach @(
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'gh pr view 76 --json state,headRefOid' }
                @{ Tool = $tool; Command = 'gh pr list --state open' }
                @{ Tool = $tool; Command = 'gh pr checks 76' }
                @{ Tool = $tool; Command = 'gh pr diff 76 --name-only' }
                @{ Tool = $tool; Command = 'gh run view 123 --log-failed' }
                @{ Tool = $tool; Command = 'gh run list --branch feat/x' }
                @{ Tool = $tool; Command = 'gh api repos/DerekFoulk/dotnet-agent-kit/pulls/76/comments --paginate' }
                @{ Tool = $tool; Command = 'gh api -H "Accept: application/vnd.github+json" repos/o/r/commits/abc/check-runs' }
                @{ Tool = $tool; Command = 'git fetch' }
                @{ Tool = $tool; Command = 'git fetch origin' }
                @{ Tool = $tool; Command = 'git fetch -q origin' }
                @{ Tool = $tool; Command = 'git merge origin/main' }
                @{ Tool = $tool; Command = 'git merge --no-edit origin/main' }
                @{ Tool = $tool; Command = 'git pull --ff-only' }
                @{ Tool = $tool; Command = 'pwsh -NoProfile -File ./tools/Test-RuleSources.ps1' }
            }
            @{ Tool = 'PowerShell'; Command = 'git status' }
            @{ Tool = 'PowerShell'; Command = 'git status --short --ignored' }
            @{ Tool = 'PowerShell'; Command = 'git branch --list' }
            @{ Tool = 'PowerShell'; Command = 'git branch --show-current' }
            @{ Tool = 'PowerShell'; Command = 'git rev-parse HEAD' }
            @{ Tool = 'PowerShell'; Command = 'git merge-base HEAD origin/main' }
            @{ Tool = 'PowerShell'; Command = 'git ls-files tools' }
            @{ Tool = 'PowerShell'; Command = '.\tools\Test-AdrSections.ps1' }
            @{ Tool = 'PowerShell'; Command = '& ./tools/Test-AdrSections.ps1' }
            @{ Tool = 'PowerShell'; Command = '.\.kit\tools\Test-ConventionalTitle.ps1 -Range origin/main..HEAD' }
            @{ Tool = 'PowerShell'; Command = 'Import-Module ./tools/KitReview.psm1 -Force' }
            @{ Tool = 'PowerShell'; Command = 'Import-Module ./.kit/tools/KitReview.psm1' }
            @{ Tool = 'PowerShell'; Command = 'Wait-PullRequest -Repository o/r -Number 76 -For Checks' }
            @{ Tool = 'PowerShell'; Command = 'Get-OpenFinding -Repository o/r -Number 76' }
            @{ Tool = 'PowerShell'; Command = 'Add-ReviewReply -Repository o/r -Number 76 -CommentId 1 -Body x' }
            @{ Tool = 'PowerShell'; Command = 'Resolve-ReviewFinding -Repository o/r -ThreadId x' }
        ) {
            Test-RuleMatch -Kind 'allow' -Tool $Tool -Command $Command | Should -BeTrue -Because "an allow rule should cover $Tool($Command)"
            Test-RuleMatch -Kind 'ask' -Tool $Tool -Command $Command -IgnoreCase | Should -BeFalse -Because 'an ask rule wins over an allow rule'
            Test-RuleMatch -Kind 'deny' -Tool $Tool -Command $Command -IgnoreCase | Should -BeFalse
        }

        # 'gh api *' is allowed for reads. gh api sends a GET unless a method or a field is given, so every form that
        # writes asks, as it did before the allow rule (an ask rule wins over it). That keeps, among others, a merge
        # through the API (PUT .../pulls/<n>/merge) asking in review mode, as 'gh pr merge' does. Matched case by
        # case: Claude Code doesn't say whether Bash rules ignore case, so -f and -F each have a rule. gh parses flags
        # with pflag, which joins short flags, and -i is gh api's one boolean short flag, so '-iXPUT' sends a PUT and
        # '-ifbody=x' a POST; any -i asks (review 1 of PR 1, probed against an unresolvable host).
        It 'asks before the gh api write <Tool>(<Command>)' -ForEach @(
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'gh api repos/o/r/pulls/1/merge -iXPUT' }
                @{ Tool = $tool; Command = 'gh api repos/o/r/issues/1/comments -ifbody=x' }
                @{ Tool = $tool; Command = 'gh api -X PUT repos/o/r/pulls/1/merge' }
                @{ Tool = $tool; Command = 'gh api repos/o/r/issues/1/comments -XPOST' }
                @{ Tool = $tool; Command = 'gh api --method POST repos/o/r/issues/1/comments' }
                @{ Tool = $tool; Command = 'gh api repos/o/r/issues/1/comments -f body=hi' }
                @{ Tool = $tool; Command = 'gh api repos/o/r/issues/1/labels -F labels[]=bug' }
                @{ Tool = $tool; Command = 'gh api repos/o/r/issues --field title=x' }
                @{ Tool = $tool; Command = 'gh api repos/o/r/issues --raw-field title=x' }
                @{ Tool = $tool; Command = 'gh api repos/o/r/rulesets --input r.json' }
                @{ Tool = $tool; Command = "gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: \""x\""}) { thread { id } } }'" }
            }
        ) {
            Test-AskRuleMatch -Tool $Tool -Command $Command | Should -BeTrue -Because "an ask rule should catch $Tool($Command)"
        }

        # Look-alikes of the routine commands that write, run a program, read a secret or drop work, which no allow
        # rule may cover (ADR-0075). git fetch, merge and pull are allowed only as exact commands, since --upload-pack
        # runs a program. A 'pwsh -Command "..."' string is opaque to Claude Code's command splitting, as 'bash -c' is
        # in its docs, so a wildcard there would allow anything after a ';' inside the quotes; run Invoke-Pester or a
        # ./tools script directly instead. ForEach-Object, Where-Object and the other cmdlets that take a script block
        # stay unallowed too, since whether Claude Code checks the commands inside one isn't documented.
        # Reviews 1 and 2 of PR 1 probed the rest: git log, diff and show write any file with --output (.agent-mode,
        # the settings), diff --no-index and blame --contents print any file, gh pr comment deletes or rewrites a
        # comment or posts a file, and a parent segment in a path or a second module after a comma leaves the kit's
        # scripts. Reading files and read-only git therefore go through the Read, Grep and Glob tools, which honor the
        # Read deny rules, and the Bash tool's built-in read-only check, which applies Claude Code's own list of risky
        # flags; a PowerShell cmdlet that reads a file or Env: prompts, since a pipeline can hand it a secret's path
        # that no rule's text names.
        It 'leaves <Tool>(<Command>) to prompt' -ForEach @(
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'gh pr comment 76 --delete-last --yes' }
                @{ Tool = $tool; Command = 'gh pr comment 76 --edit-last --body x' }
                # Review 2: gh reads a --body-file itself, which the Read deny rules don't cover, so posting stays asked.
                @{ Tool = $tool; Command = 'gh pr comment 76 --body-file ./src/App/.env' }
                # Review 2: a parent segment anywhere in the path leaves tools/, not only right after it.
                @{ Tool = $tool; Command = 'pwsh -NoProfile -File ./tools/zz/../../x.ps1' }
            }
            # Review 2: these cmdlets run a script block (a calculated property, a delay-bind parameter) or a
            # subexpression, probed in a scratch folder; whether Claude Code checks the commands inside isn't documented.
            @{ Tool = 'PowerShell'; Command = "Select-Object @{n='x';e={Set-Content ./x.txt y}}" }
            @{ Tool = 'PowerShell'; Command = 'Measure-Object -Property { Set-Content ./x.txt y }' }
            @{ Tool = 'PowerShell'; Command = 'Test-Path -Path { Set-Content ./x.txt y }' }
            @{ Tool = 'PowerShell'; Command = 'ConvertFrom-Json $(Set-Content ./x.txt y)' }
            @{ Tool = 'PowerShell'; Command = './tools/zz/../../x.ps1' }
            @{ Tool = 'PowerShell'; Command = './tools/./../x.ps1' }
            @{ Tool = 'PowerShell'; Command = './tools//../x.ps1' }
            @{ Tool = 'PowerShell'; Command = '.\tools\zz\..\..\x.ps1' }
            @{ Tool = 'PowerShell'; Command = 'git log -1 --format=%B --output=.claude/settings.json' }
            @{ Tool = 'PowerShell'; Command = 'git diff --output=.agent-mode' }
            @{ Tool = 'PowerShell'; Command = 'git show -s --format=%s --output=.agent-mode HEAD' }
            @{ Tool = 'PowerShell'; Command = 'git diff --no-index NUL ./src/App/.env' }
            @{ Tool = 'PowerShell'; Command = 'git blame --contents ./src/App/.env -- README.md' }
            @{ Tool = 'PowerShell'; Command = 'Get-Content .env' }
            @{ Tool = 'PowerShell'; Command = 'Get-Content Env:GH_TOKEN' }
            @{ Tool = 'PowerShell'; Command = 'Get-ChildItem Env:' }
            @{ Tool = 'PowerShell'; Command = 'Get-ChildItem -Recurse -Force -Filter .env' }
            @{ Tool = 'PowerShell'; Command = 'Get-Item Env:GH_TOKEN' }
            @{ Tool = 'PowerShell'; Command = 'Select-String -Path ./.env -Pattern KEY' }
            @{ Tool = 'PowerShell'; Command = 'Write-Output $env:GH_TOKEN' }
            @{ Tool = 'PowerShell'; Command = 'Import-Module ./tools/KitReview.psm1 ,./scratch/x.psm1' }
            @{ Tool = 'PowerShell'; Command = './tools/../scratch/x.ps1' }
            @{ Tool = 'PowerShell'; Command = '& ./tools/../scratch/x.ps1' }
            @{ Tool = 'PowerShell'; Command = '.\tools\..\scratch\x.ps1' }
            @{ Tool = 'PowerShell'; Command = './.kit/tools/../scratch/x.ps1' }
            @{ Tool = 'PowerShell'; Command = 'pwsh -NoProfile -File ./tools/../scratch/x.ps1' }
            @{ Tool = 'Bash'; Command = 'pwsh -NoProfile -File ./tools/../scratch/x.ps1' }
            foreach ($tool in 'Bash', 'PowerShell') {
                @{ Tool = $tool; Command = 'git fetch --upload-pack=./evil.sh origin' }
                @{ Tool = $tool; Command = 'git fetch origin --upload-pack=./evil.sh' }
                @{ Tool = $tool; Command = 'git merge feat/other' }
                @{ Tool = $tool; Command = 'git pull' }
                @{ Tool = $tool; Command = 'git switch -c feat/x --discard-changes' }
                @{ Tool = $tool; Command = 'gh pr merge 76 --merge' }
                @{ Tool = $tool; Command = 'pwsh -NoProfile -Command "Invoke-Pester -Path ./tools/tests; Remove-Item -Recurse -Force ~"' }
            }
            @{ Tool = 'PowerShell'; Command = 'git branch -D feat/x' }
            @{ Tool = 'PowerShell'; Command = 'Set-Content ./AGENTS.md x' }
            @{ Tool = 'PowerShell'; Command = 'Remove-Item ./docs -Recurse' }
            @{ Tool = 'PowerShell'; Command = 'ForEach-Object { Remove-Item $_ }' }
            @{ Tool = 'PowerShell'; Command = 'Where-Object { Remove-Item $_ }' }
        ) {
            $allowed = (Test-RuleMatch -Kind 'allow' -Tool $Tool -Command $Command -IgnoreCase) -and
                -not (Test-RuleMatch -Kind 'ask' -Tool $Tool -Command $Command) -and
                -not (Test-RuleMatch -Kind 'deny' -Tool $Tool -Command $Command)
            $allowed | Should -BeFalse -Because "no allow rule should run $Tool($Command) unasked"
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

    # ADR-0067: the reviewer agent reviews every branch, against the code-review instructions and the rule files.
    # The owner's yes for a guardrail PR is given in chat, which neither GitHub nor Copilot can see; a PR comment
    # records it, so each guardrail merge can be checked from the PR alone (owner, 2026-11-13; Copilot's review of PR 66).
    # Cleanup step 4 of the rules audit: these sections hold the rules themselves, filled by Build-AgentRules, not a
    # hand-made copy that drifts (CRF-003, ADR-0065); Build-AgentRules -Check keeps the blocks current.
    Context 'rule sections generated from the standards' {
        It '<File>''s "<Section>" section holds the rules of <Standard>' -ForEach @(
            @{ File = 'AGENTS.md'; Section = 'Git'; Standard = 'git.md' }
            @{ File = 'AGENTS.md'; Section = 'Done means'; Standard = 'definition-of-done.md' }
            @{ File = 'templates/app/AGENTS.md'; Section = 'Done means'; Standard = 'definition-of-done.md' }
        ) {
            $text = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $File)
            $body = [regex]::Match($text, "(?s)## $([regex]::Escape($Section))\r?\n(.*?)(?=\r?\n## |\r?\n<!-- kit:end|\z)").Groups[1].Value

            $body | Should -Match ([regex]::Escape("<!-- rules from docs/standards/$Standard"))
            $body | Should -Match '<!-- end rules -->'
        }
    }

    # The kit's one watcher (owner, 2026-11-14): every place that tells an agent how to wait for a review or CI names it.
    Context 'watching a pull request' {
        It '<File> names Wait-PullRequest' -ForEach @(
            @{ File = '.claude/skills/finish-work/SKILL.md' }
            @{ File = '.claude/skills/address-review/SKILL.md' }
            @{ File = 'AGENTS.md' }
            @{ File = 'templates/app/AGENTS.md' }
        ) {
            Get-Content -Raw -LiteralPath (Join-Path $repoRoot $File) | Should -Match '\bWait-PullRequest\b'
        }

        # A foreground wait costs no model call while it runs; a background one's notice arrived 6.5 hours late on kit PR
        # #73 (ADR-0068). Every line naming Wait-PullRequest is checked, so "background" anywhere on one fails. None states
        # the time-out: its one source is the module's default (CRF-003; the first review round of ADR-0068's PR).
        It '<File> runs Wait-PullRequest in the foreground, never in the background, and leaves its time-out to the module' -ForEach @(
            @{ File = '.claude/skills/finish-work/SKILL.md' }
            @{ File = '.claude/skills/address-review/SKILL.md' }
            @{ File = 'CLAUDE.md' }
            @{ File = 'AGENTS.md' }
            @{ File = 'templates/app/AGENTS.md' }
        ) {
            $lines = @(Get-Content -LiteralPath (Join-Path $repoRoot $File) | Where-Object { $_ -match '\bWait-PullRequest\b' })

            @($lines | Where-Object { $_ -match '(?i)\bforeground\b' }) | Should -Not -BeNullOrEmpty
            @($lines | Where-Object { $_ -match '(?i)\bbackground\b' }) | Should -BeNullOrEmpty
            @($lines | Where-Object { $_ -match '(?i)\b\d+\s*min(ute)?s?\b|-TimeoutMinutes\s+\d' }) | Should -BeNullOrEmpty
        }

        # Both of finish-work's instructions to wait say foreground, not just one of them (the fix round of ADR-0068's PR).
        It 'finish-work says foreground in each instruction to wait' {
            $lines = @(Get-Content -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md'))
            $instructions = @($lines | Where-Object { $_ -match '^- \*\*Watch for CI|^  - \*\*CI or a Copilot review\*\*' })

            $instructions.Count | Should -Be 2
            @($instructions | Where-Object { $_ -notmatch '(?i)\bin the foreground\b' }) | Should -BeNullOrEmpty
        }

        It 'finish-work never polls in a loop, never waits in a background shell job, and ends the turn while the owner decides' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md')

            $skill | Should -Match '\*\*Never poll in a loop\.\*\*'
            $skill | Should -Match '\*\*Not in a background shell job either\.\*\*'
            $skill | Should -Match '(?i)\*\*Waiting on the owner\*\*[^\n]*\bthen end the turn\b'
        }

        # Wait-PullRequest covers most of what the desktop app's PR monitor did, which woke the session about 20 times on kit
        # PR #73 (ADR-0068).
        It '<File> leaves the desktop app''s PR monitor off by default' -ForEach @(
            @{ File = '.claude/skills/finish-work/SKILL.md' }
            @{ File = '.claude/skills/address-review/SKILL.md' }
        ) {
            Get-Content -Raw -LiteralPath (Join-Path $repoRoot $File) | Should -Match '(?i)PR monitor[^.\n]*\boff by default\b'
        }

        It 'finish-work turns the PR monitor on only when the owner asks' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md')

            $skill | Should -Match '(?i)Turn it on for a PR only when the owner asks'
        }

        # With the monitor off, a plain PR comment posted between turns reaches no check, and the kit is public, so anyone can
        # post one: step 5 reads them before a merge (review round 3 of ADR-0068's PR).
        It 'finish-work reads people''s plain PR comments before a merge' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md')
            $merge = [regex]::Match($skill, '(?s)## 5\. Merge, in auto mode(.*?)(?=\r?\n## )').Groups[1].Value

            $merge | Should -Match '(?i)\*\*No plain PR comment from a person is unanswered\.\*\*[^\n]*gh pr view <n> --comments'
        }
    }

    # Review that costs less without reviewing less (ADR-0068): the first round sees everything; a fix round sees the fix.
    Context 'review rounds' {
        It 'finish-work runs the first round on the session''s own model, over the whole branch' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md')

            $skill | Should -Match '(?i)\*\*The first round reviews the whole branch, on the session''s own model\*\* \(in Claude Code, leave the agent''s `model` unset\)'
        }

        It 'finish-work reviews a fix round''s diff only, on a cheaper model only when it is small and touches no guardrail' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md')

            $skill | Should -Match 'run one `reviewer` on the new commits only'
            $skill | Should -Match 'git diff <reviewed head>\.\.HEAD'
            $skill | Should -Match '(?i)under 100 changed lines[^.\n]*\band touches no guardrail \(step 5 lists them\), run it on a cheaper model\b'
            $skill | Should -Match '(?i)run it on a cheaper model[^\n]*\. Otherwise use the session''s model\.'
        }

        It 'the reviewer agent reviews a fix round''s diff, not the whole branch' {
            $agent = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'agents' 'reviewer.md')

            $agent | Should -Match '\*\*A fix round\*\*[^\n]*git diff <reviewed head>\.\.HEAD'
            $agent | Should -Match '\*\*A fix round\*\*[^\n]*Read the rest of the branch only where the fix reaches it'
        }

        # Each call carries the whole conversation, so a PR's work starts in a session of its own (Claude Code, ADR-0068).
        It 'CLAUDE.md starts each new PR''s work in a fresh session' {
            Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'CLAUDE.md') | Should -Match '(?i)Start each new PR''s work in a fresh session'
        }

        It 'is exported by KitReview.psm1, which apps get' {
            Import-Module -Name (Join-Path $repoRoot 'tools' 'KitReview.psm1') -Force
            Get-Command Wait-PullRequest -Module KitReview -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context 'guardrail merges' {
        It 'finish-work records the owner''s yes on the PR, with his words and the head commit, before merging' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md')
            $step = [regex]::Match($skill, '(?s)A PR that changes any of them(.*?)(?=\r?\n- \*\*|\r?\n## )').Groups[1].Value

            $step | Should -Match 'PR comment'
            $step | Should -Match 'his words'
            $step | Should -Match 'head commit'
            $step | Should -Match 'before (you )?merg'
        }

        It 'AGENTS.md "Working modes" says the yes is recorded on the PR' {
            $agents = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'AGENTS.md')
            $modes = [regex]::Match($agents, '(?s)## Working modes(.*?)(?=\r?\n## )').Groups[1].Value

            $modes | Should -Match 'record (it|his yes) on the PR'
        }
    }

    Context 'code review instructions' {
        BeforeAll {
            $script:reviewPath = Join-Path $repoRoot '.github' 'instructions' 'code-review.instructions.md'
        }

        It 'apply to every file, for code review only' {
            $script:reviewPath | Should -Exist
            $frontMatter = Read-FrontMatter -Path $script:reviewPath

            "$($frontMatter['applyTo'])" | Should -Be '**'
            "$($frontMatter['excludeAgent'])" | Should -Be 'cloud-agent'
        }

        It 'rank findings as Blocking, Should fix and Consider' {
            $text = if (Test-Path -LiteralPath $script:reviewPath) { Get-Content -Raw -LiteralPath $script:reviewPath } else { '' }
            foreach ($rank in 'Blocking', 'Should fix', 'Consider') { $text | Should -Match "\*\*$rank\*\*" }
        }

        # In a public repo a pin by SHA can resolve to a fork's commit, so a full SHA alone isn't enough (ADR-0031).
        It 'require a kit release tag to point to a changed kit pin' {
            $text = if (Test-Path -LiteralPath $script:reviewPath) { Get-Content -Raw -LiteralPath $script:reviewPath } else { '' }
            $text | Should -Match 'release tag'
            $text | Should -Match ([regex]::Escape('gh api repos/DerekFoulk/dotnet-agent-kit/commits/<tag> --jq .sha'))
        }

        # ADR-0067: DOD-003 names the reviewer agent and its checklist. No tool makes an agent run the reviewer, so every
        # part of DOD-003 is advisory.
        It 'are what DOD-003''s reviewer agent uses' {
            $frontMatter = Read-FrontMatter -Path (Join-Path $repoRoot 'docs' 'standards' 'definition-of-done.md')
            $rule = @($frontMatter['rules'] | Where-Object { $_['id'] -eq 'DOD-003' })[0]

            "$($rule['statement'])" | Should -Match 'reviewer agent'
            "$($rule['statement'])" | Should -Match ([regex]::Escape('docs/code-review.md'))
            @(@($rule['enforcement']) | Where-Object { "$($_['kind'])" -ne 'advisory' }).Count | Should -Be 0
        }

        # ADR-0067: the reviewer agent's rounds come before the PR opens, and a merge waits for a clean one at the head.
        It 'are reviewed by the reviewer agent in finish-work, whose clean round on the head commit a merge needs' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'finish-work' 'SKILL.md')
            $review = [regex]::Match($skill, '(?s)## 2\.(.*?)(?=\r?\n## )').Groups[1].Value
            $merge = [regex]::Match($skill, '(?s)## 5\.(.*?)(?=\r?\n## )').Groups[1].Value

            $review | Should -Match 'Run the `reviewer` subagent.*before the PR opens'
            $merge | Should -Match 'The latest `reviewer` round is on that head commit,\*\* with no unanswered blocking or should-fix finding'
        }

        # The reviewer's round on finish-work step 5. A merge condition that drops "clean" lets an agent merge past an open
        # blocking finding, so both copies pin it (the reviewer agent's review of this change, ADR-0067).
        It 'are what AGENTS.md "Working modes" holds a merge to: a clean reviewer round on the head commit' {
            $agents = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'AGENTS.md')
            $modes = [regex]::Match($agents, '(?s)## Working modes(.*?)(?=\r?\n## )').Groups[1].Value

            $modes | Should -Match 'the latest `reviewer` round on that commit has no unanswered blocking or should-fix finding'
        }

        It 'are what start-work''s plan review uses: the reviewer agent reviews a non-trivial plan' {
            $skill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude' 'skills' 'start-work' 'SKILL.md')
            $step = [regex]::Match($skill, '(?m)^5\. \*\*Review the plan\*\*.*$').Value

            $step | Should -Match 'run the `reviewer` on the plan'
        }

        # A plan is posted in chat, before any code: no code review sees it, so the rules credit start-work's plan
        # review, which the reviewer agent runs (ADR-0067), never code review.
        It 'aren''t said to check the plan in <Id>' -ForEach @(
            @{ Id = 'ARC-006'; File = 'architecture.md' }
            @{ Id = 'TST-002'; File = 'testing.md' }
            @{ Id = 'DAT-001'; File = 'data.md' }
        ) {
            $frontMatter = Read-FrontMatter -Path (Join-Path $repoRoot 'docs' 'standards' $File)
            $rule = @($frontMatter['rules'] | Where-Object { $_['id'] -eq $Id })[0]
            $how = @(@($rule['enforcement']) | ForEach-Object { "$($_['how'])" }) -join ' '

            $how | Should -Match 'start-work'
            $how | Should -Not -Match 'code review'
        }

        # ADR-0067: Copilot code review is off, so the read-only reviewer agent is back, and it works from the same
        # checklist Copilot would read (CRF-003: one source for what a review looks for).
        It 'are what the read-only reviewer agent reviews against' {
            $agentPath = Join-Path $repoRoot '.claude' 'agents' 'reviewer.md'
            $agentPath | Should -Exist
            $frontMatter = Read-FrontMatter -Path $agentPath

            foreach ($tool in 'Edit', 'Write', 'NotebookEdit') { "$($frontMatter['disallowedTools'])" | Should -Match "\b$tool\b" }
            $text = Get-Content -Raw -LiteralPath $agentPath
            $text | Should -Match ([regex]::Escape('docs/code-review.md'))
            # It keeps Bash and PowerShell, so this rule is what keeps it from committing or resetting from the shell.
            $text | Should -Match ([regex]::Escape("- **Don't change anything.**"))
        }
    }

    Context 'skills' {
        BeforeDiscovery {
            # Every skill folder: the kit's own and the curated ones from dotnet/skills (ADR-0042).
            $skillFolders = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..' '..' '.claude' 'skills') -Directory |
                    ForEach-Object { @{ Skill = $_.Name } })
            $kitSkills = @('start-work', 'plan-checklist', 'tdd-cycle', 'write-adr', 'finish-work', 'address-review', 'new-app')
        }

        It 'has the kit''s <Skill> skill' -ForEach @($kitSkills | ForEach-Object { @{ Skill = $_ } }) {
            Join-Path $repoRoot '.claude' 'skills' $Skill 'SKILL.md' | Should -Exist
        }

        # A skill taken out of tools/dotnet-skills.json would otherwise stay behind: unpinned, unchecked, and still
        # copied into every app.
        It 'has no skill folder besides the kit''s own and the curated ones in tools/dotnet-skills.json' -ForEach @(@{ KitSkills = $kitSkills }) {
            $lock = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'tools' 'dotnet-skills.json') | ConvertFrom-Json -AsHashtable
            $expected = @($KitSkills) + @($lock['skills'] | ForEach-Object { $_['name'] }) | Sort-Object
            $folders = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot '.claude' 'skills') -Directory | ForEach-Object Name | Sort-Object)

            $folders | Should -Be $expected
        }

        # Claude Code truncates description + when_to_use at 1,536 characters. The reviewer recalled a
        # 1,024 cap in the Agent Skills spec that Visual Studio and VS Code follow (not verified), so the
        # test uses the stricter number.
        It 'names the <Skill> skill after its folder, with a description under 1,024 characters' -ForEach $skillFolders {
            $path = Join-Path $repoRoot '.claude' 'skills' $Skill 'SKILL.md'
            $path | Should -Exist
            $frontMatter = Read-FrontMatter -Path $path

            $frontMatter['name'] | Should -Be $Skill
            "$($frontMatter['description'])".Length | Should -BeGreaterThan 0
            "$($frontMatter['description'])".Length | Should -BeLessThan 1024
        }

        # Claude Code lists every skill's description in each session and drops descriptions once the listing passes
        # 1% of the context window (code.claude.com/docs/en/skills, "Skill descriptions are cut short"). On a
        # 200,000-token window at about four characters a token, that's 8,000 characters; the exact count Claude Code
        # uses isn't verified. Adding a skill may mean taking one out (ADR-0042, docs/dotnet-skills.md). That doc states
        # the totals, and DotnetSkills.Tests.ps1 checks them, so changing any skill's description means updating it.
        It 'keeps every skill''s description together within 8,000 characters' {
            $total = 0
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repoRoot '.claude' 'skills') -Directory) {
                $total += "$((Read-FrontMatter -Path (Join-Path $file.FullName 'SKILL.md'))['description'])".Length
            }

            $total | Should -BeGreaterThan 0
            $total | Should -BeLessOrEqual 8000 -Because 'Claude Code drops descriptions past its listing budget'
        }
    }
}
