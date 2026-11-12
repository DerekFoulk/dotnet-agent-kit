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

        # Whether an ask rule catches a command. A rule's '*' matches any text, as in Claude Code's patterns; [, ]
        # and ? are taken literally. By default the match is case-sensitive, the stricter reading for a test that a
        # rule asks. -IgnoreCase is the stricter reading for a test that a rule doesn't ask, and the real one for
        # PowerShell: on 2026-11-11 a scan of the session transcripts found 38 prompts for PowerShell commands that
        # matched '*git *push* -f*' only through a later '-Force' or '-F' (Claude Code's docs don't say either way).
        # A rule ending in ":*" is Claude Code's older prefix syntax: the text before it is a literal prefix and any
        # '*' in it isn't expanded (review 4 of PR 19, from Claude Code's own rule parser).
        function Test-AskRuleMatch([string] $Tool, [string] $Command, [switch] $IgnoreCase) {
            $comparison = if ($IgnoreCase) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            [bool] @(Get-RuleList 'ask' | Where-Object {
                    if ($_ -notmatch "^$Tool\((.*)\)$") { return $false }
                    $pattern = $Matches[1]
                    if ($pattern -match '^(.+):\*$') { return [string]::Equals($Command, $Matches[1], $comparison) -or $Command.StartsWith("$($Matches[1]) ", $comparison) }
                    $wildcard = $pattern -replace '[\[\]?]', '`$0'
                    if ($IgnoreCase) { $Command -ilike $wildcard } else { $Command -clike $wildcard }
                }).Count
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
        ) {
            (Get-RuleList 'ask') -ccontains "Edit($Path)" | Should -BeTrue
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
        # message or a grep, asks as well, and so does any PowerShell command that starts with ./, .\ or & and quotes
        # "playwright.ps1 install" later on; a missed install is worse than an extra prompt. Known misses, left to
        # "Always ask" and the reviewer (ADR-0026, ADR-0061): an install run through a variable or a pipeline
        # ('& $pw install', 'Get-ChildItem -Filter playwright.ps1 | ForEach-Object { & $_ install }'), a quoted
        # path, a wrapper such as 'bash -c', and the kit script by an absolute path, without ./ (as
        # 'pwsh tools/...'), by 'pwsh' with .\ or with flags other than -File and -NoProfile, or dot-sourced and
        # then called. Whether Claude Code checks each command of a compound
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
        ) {
            # A rule's '*' matches any text, as in Claude Code's patterns; [, ] and ? are taken literally. The match
            # is case-sensitive, the stricter reading, since whether Claude Code ignores case isn't documented.
            $matching = @(Get-RuleList 'ask' | Where-Object {
                    $_ -match "^$Tool\((.*)\)$" -and $Command -clike ($Matches[1] -replace '[\[\]?]', '`$0')
                })
            $matching | Should -Not -BeNullOrEmpty -Because "an ask rule should catch $Tool($Command)"
        }

        # ADR-0026 leaves pushes to main to the GitHub ruleset. ADR-0035 adds asks, never denies, for deleting and
        # force-pushing, which the ruleset doesn't guard on other branches; an ordinary push stays unasked.
        It 'leaves pushes to the GitHub ruleset: no deny rule matches git push, and only destructive forms ask' {
            @(Get-RuleList 'deny') -match 'git push' | Should -BeNullOrEmpty
            @(Get-RuleList 'ask') -match 'git \*?push' | Where-Object { $_ -notmatch '--delete|-d( |\))|--force|-f|:\*|\+\*|--mirror|--prune' } | Should -BeNullOrEmpty
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
