#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# New-KitApp creates an app repo on GitHub from Export-KitApp's files (PR D2b, ADR-0033). The repo settings
# and the "main protection" ruleset are data in templates/github, so the sync job (PR D3) can apply them again.

BeforeAll {
    # The kit's files, listed first, with this checkout's own ignore rules, global ones included: it's the
    # person's checkout, not a test repo.
    $kitFiles = git -C (Join-Path $PSScriptRoot '..' '..') ls-files --cached --others --exclude-standard
    # Every repo these tests make, and every one New-KitApp makes under test, runs with the same git settings:
    # none of this machine's git config, and no background maintenance (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'New-KitApp settings' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $rulesetPath = Join-Path $root 'templates' 'github' 'main-protection.json'
    }

    It 'requires exactly the checks the app''s CI workflows report' {
        # A check's name is "<caller job id> / <shared workflow job name>". Deriving it from the workflows means
        # renaming a job fails here, instead of leaving every app PR waiting for a check that never reports.
        $expected = foreach ($caller in Get-ChildItem -LiteralPath (Join-Path $root 'templates' 'app' '.github' 'workflows') -Filter *.yml) {
            # {{Name}} placeholders aren't YAML; ${{ }} expressions are plain strings.
            $yaml = ConvertFrom-Yaml ((Get-Content -Raw -LiteralPath $caller.FullName) -replace '\{\{[A-Za-z]+\}\}', 'X')
            # Only a workflow that runs on pull requests can report a required check; a nightly one never would.
            if (-not $yaml['on'].ContainsKey('pull_request')) { continue }
            foreach ($jobId in $yaml['jobs'].Keys) {
                $uses = $yaml['jobs'][$jobId]['uses']
                if ($uses -notmatch '^DerekFoulk/dotnet-agent-kit/\.github/workflows/([^@]+)@') { continue }
                # CodeQL isn't required: its job names depend on the app's languages, and a private app skips it
                # (ADR-0036). Requiring it would be a ruleset change, the owner's call.
                if ($Matches[1] -eq 'codeql.reusable.yml') { continue }
                # The kit sync runs only on Dependabot's kit-pin PRs (ADR-0042), so it can't be required on every PR.
                if ($Matches[1] -eq 'kit-sync.reusable.yml') { continue }
                $shared = ConvertFrom-Yaml (Get-Content -Raw -LiteralPath (Join-Path $root '.github' 'workflows' $Matches[1]))
                foreach ($job in $shared['jobs'].Values) { "$jobId / $($job['name'])" }
            }
        }
        @($expected).Count | Should -Be 3

        Test-Path -LiteralPath $rulesetPath | Should -BeTrue -Because 'the app ruleset is data in templates/github'
        $ruleset = Get-Content -Raw -LiteralPath $rulesetPath | ConvertFrom-Json
        $checks = ($ruleset.rules | Where-Object type -EQ 'required_status_checks').parameters.required_status_checks
        @($checks.context | Sort-Object) | Should -Be @($expected | Sort-Object)
        # 15368 is the GitHub Actions app: only a check that Actions reports satisfies the rule.
        @($checks.integration_id | Select-Object -Unique) | Should -Be @(15368)
    }

    It 'protects main as the kit''s ruleset does: no deletion or force-push, a PR, merge commits only, no bypass' {
        $ruleset = Get-Content -Raw -LiteralPath $rulesetPath | ConvertFrom-Json

        $ruleset.name | Should -Be 'main protection'
        $ruleset.enforcement | Should -Be 'active'
        @($ruleset.bypass_actors) | Should -BeNullOrEmpty
        @($ruleset.conditions.ref_name.include) | Should -Be @('~DEFAULT_BRANCH')
        @($ruleset.rules.type | Sort-Object) | Should -Be @('deletion', 'non_fast_forward', 'pull_request', 'required_status_checks')
        $pullRequest = ($ruleset.rules | Where-Object type -EQ 'pull_request').parameters
        @($pullRequest.allowed_merge_methods) | Should -Be @('merge')
        $pullRequest.required_approving_review_count | Should -Be 0 # one owner: the reviewer agent reviews, not a second person
    }

    It 'has a code scanning ruleset that blocks a merge on CodeQL''s errors or high security alerts, as the kit''s does' {
        # A public app's CodeQL job runs on every PR (ADR-0036); a rule requiring a tool the repo doesn't run
        # blocks every merge, so this ruleset is separate and goes on public apps only.
        $path = Join-Path $root 'templates' 'github' 'code-scanning.json'
        Test-Path -LiteralPath $path | Should -BeTrue -Because 'the CodeQL merge rule is data in templates/github'
        $ruleset = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json

        $ruleset.name | Should -Be 'code scanning'
        $ruleset.target | Should -Be 'branch'
        $ruleset.enforcement | Should -Be 'active'
        @($ruleset.bypass_actors) | Should -BeNullOrEmpty
        @($ruleset.conditions.ref_name.include) | Should -Be @('~DEFAULT_BRANCH')
        @($ruleset.rules.type) | Should -Be @('code_scanning')
        $tools = @($ruleset.rules[0].parameters.code_scanning_tools)
        $tools | Should -HaveCount 1
        $tools[0].tool | Should -Be 'CodeQL'
        $tools[0].alerts_threshold | Should -Be 'errors'
        $tools[0].security_alerts_threshold | Should -Be 'high_or_higher'
    }

    It 'requires every review thread to be resolved before merging, as the kit''s ruleset does' {
        # The owner, 2026-11-10: new apps get the merge protections the kit has (README, "GitHub settings").
        $pullRequest = ((Get-Content -Raw -LiteralPath $rulesetPath | ConvertFrom-Json).rules | Where-Object type -EQ 'pull_request').parameters

        $pullRequest.required_review_thread_resolution | Should -BeTrue
    }

    Context 'the create-repo request' {
        BeforeAll {
            $script = Join-Path $root 'tools' 'New-KitApp.ps1'
            $settingsText = Get-Content -Raw -LiteralPath (Join-Path $root 'templates' 'github' 'repo.json') -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $script) { . $script }
        }

        It 'has the kit''s merge settings: merge commits only, titled with the PR title, branches deleted' {
            Test-Path -LiteralPath $script | Should -BeTrue -Because 'New-KitApp.ps1 builds the request'
            $request = Get-KitAppRepoRequest -Name 'Contoso.Orders' -SettingsText $settingsText

            $request.name | Should -Be 'Contoso.Orders'
            $request.allow_merge_commit | Should -BeTrue
            $request.allow_squash_merge | Should -BeFalse
            $request.allow_rebase_merge | Should -BeFalse
            $request.allow_auto_merge | Should -BeFalse
            $request.merge_commit_title | Should -Be 'PR_TITLE'
            $request.merge_commit_message | Should -Be 'BLANK'
            $request.delete_branch_on_merge | Should -BeTrue
            $request.has_wiki | Should -BeFalse
        }

        It 'is always private: a public app is made public after its ruleset' {
            Test-Path -LiteralPath $script | Should -BeTrue -Because 'New-KitApp.ps1 builds the request'
            (Get-KitAppRepoRequest -Name 'Contoso.Orders' -SettingsText $settingsText).private | Should -BeTrue
        }

        It 'keeps the name and visibility it was given, whatever the settings file says' {
            # A stray "private": false in repo.json would otherwise make every new app public (ADR-0031).
            $request = Get-KitAppRepoRequest -Name 'Contoso.Orders' -SettingsText '{ "private": false, "name": "other", "has_wiki": false }'
            $request.private | Should -BeTrue
            $request.name | Should -Be 'Contoso.Orders'
            $request.has_wiki | Should -BeFalse
        }
    }
}

Describe 'Invoke-KitGh' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'New-KitApp.ps1')
    }

    It 'keeps gh''s error output apart from its JSON, so a warning can''t break parsing' {
        # Native stderr arrives as ErrorRecords under 2>&1; Write-Error -ErrorAction Continue stands in for it.
        Mock gh { '{ "html_url": "https://github.com/o/r" }'; Write-Error 'warning: an update is available' -ErrorAction Continue; $global:LASTEXITCODE = 0 }
        $result = Invoke-KitGh -Arguments 'api', 'user/repos'
        { $result.Output | ConvertFrom-Json } | Should -Not -Throw
        ($result.Output | ConvertFrom-Json).html_url | Should -Be 'https://github.com/o/r'
        $result.PSObject.Properties.Name | Should -Contain 'Error'
        $result.Error | Should -Match 'an update is available'
    }

    It 'reports gh''s error output when gh fails' {
        Mock gh { Write-Error 'gh: Not Found (HTTP 404)' -ErrorAction Continue; $global:LASTEXITCODE = 1 }
        $result = Invoke-KitGh -Arguments 'api', 'repos/o/r'
        $result.ExitCode | Should -Be 1
        $result.PSObject.Properties.Name | Should -Contain 'Error'
        $result.Error | Should -Match 'HTTP 404'
        { Invoke-KitGhChecked -Arguments 'api', 'repos/o/r' } | Should -Throw '*HTTP 404*'
    }
}

# The run, against a throwaway kit repo built from this working tree (as in Export-KitApp.Tests.ps1). GitHub
# is replaced: Invoke-KitGh is mocked, and the "created" repo's clone URL is a local bare repo, so git
# itself runs for real.
Describe 'New-KitApp run' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $script = Join-Path $root 'tools' 'New-KitApp.ps1'

        $kit = Join-Path $TestDrive 'kit'
        foreach ($file in $kitFiles) {
            $source = Join-Path $root $file
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue } # deleted but not yet staged
            $target = Join-Path $kit $file
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
        }
        git -C $kit init -q -b main
        git -C $kit add -A
        # As Windows would store it. On Linux the copy keeps the executable bit, and git add would record it
        # without New-KitApp's --chmod, so the hook test couldn't fail there.
        git -C $kit update-index --chmod=-x .githooks/commit-msg
        git -C $kit commit -q -m 'chore: kit fixture'
        $commit = (git -C $kit rev-parse HEAD).Trim()

        if (Test-Path -LiteralPath $script) { . $script }

        # A fake GitHub: records every call, answers as gh does (the JSON body on stdout, gh's own error line
        # on stderr; review 2 of PR 17), and notes whether main had been pushed when each call was made.
        function Initialize-FakeGitHub([string] $Remote) {
            $script:calls = [Collections.Generic.List[object]]::new()
            $script:remote = $Remote
            New-TestGitRemote -Path $Remote | Out-Null
            Mock Invoke-KitGh {
                $pushed = [bool] (git -C $script:remote rev-parse --verify --quiet refs/heads/main)
                $script:calls.Add([pscustomobject]@{ Arguments = $Arguments -join ' '; Input = $InputText; Pushed = $pushed })
                $text = switch -Regex ($Arguments -join ' ') {
                    '^auth status' { 'Logged in to github.com account fixture-owner' }
                    '^api user --jq \.login$' { 'fixture-owner' }
                    '^api repos/[^/ ]+/[^/ ]+$' { return [pscustomobject]@{ ExitCode = 1; Output = '{"message":"Not Found","status":"404"}'; Error = 'gh: Not Found (HTTP 404)' } }
                    '^api user/repos' { (@{ html_url = 'https://github.com/fixture-owner/Contoso.Orders'; clone_url = $script:remote } | ConvertTo-Json) }
                    default { '{}' }
                }
                [pscustomobject]@{ ExitCode = 0; Output = $text; Error = '' }
            }
        }

        function Get-WriteCall { @($script:calls | Where-Object { $_.Arguments -match '--method (POST|PATCH|PUT|DELETE)' }) }
    }

    Context 'a private app' {
        BeforeAll {
            $app = Join-Path $TestDrive 'Contoso.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'remote.git')
            $runError = $null
            try { New-KitApp -Name 'Contoso.Orders' -KitRef $commit -Destination $app -KitRoot $kit -Private 6>$null }
            catch { $runError = $_ }
        }

        It 'exports, commits, creates the repo, pushes main, then adds the ruleset' {
            $runError | Should -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $app '.kit' 'manifest.json') | Should -BeTrue -Because 'the export ran'
            (git -C $remote log -1 --format=%s main) | Should -Match '^chore: start from dotnet-agent-kit'

            $writes = Get-WriteCall
            @($writes.Arguments)[0..1] | Should -Be @('api user/repos --method POST --input -', 'api repos/fixture-owner/Contoso.Orders/rulesets --method POST --input -')
            ($writes[0].Input | ConvertFrom-Json).name | Should -Be 'Contoso.Orders'
            ($writes[0].Input | ConvertFrom-Json).private | Should -BeTrue
            $writes[1].Pushed | Should -BeTrue -Because 'the ruleset would reject the first push'
            ($writes[1].Input | ConvertFrom-Json).name | Should -Be 'main protection'
        }

        # The owner, 2026-11-09 (ADR-0041): Dependabot security updates skip the 7- and 14-day wait version
        # updates have, so a known vulnerability gets its fix PR at once, and the alerts say it's there. Turning
        # alerts on also turns on the dependency graph security updates need, private repos included.
        It 'then turns on Dependabot alerts and security updates, private or public' {
            @((Get-WriteCall).Arguments) | Should -Be @(
                'api user/repos --method POST --input -'
                'api repos/fixture-owner/Contoso.Orders/rulesets --method POST --input -'
                'api repos/fixture-owner/Contoso.Orders/vulnerability-alerts --method PUT'
                'api repos/fixture-owner/Contoso.Orders/automated-security-fixes --method PUT'
                'api repos/fixture-owner/Contoso.Orders/actions/permissions --method PUT --input -'
            )
        }

        # The owner, 2026-11-10: new apps get the kit's merge protections. A workflow may use an action only at
        # a full commit SHA, which no one can move to other code (SUP-008), private or public.
        It 'then requires every action to be pinned to a full commit SHA' {
            $permissions = @(Get-WriteCall | Where-Object Arguments -Match '/actions/permissions ')
            $permissions | Should -HaveCount 1
            $settings = $permissions[0].Input | ConvertFrom-Json
            $settings.enabled | Should -BeTrue
            $settings.allowed_actions | Should -Be 'all'
            $settings.sha_pinning_required | Should -BeTrue
        }

        It 'stores the commit hook as executable, which git on Linux and macOS needs to run it' {
            # Windows doesn't record the executable bit, so the first commit has to set it (ADR-0032).
            (git -C $remote ls-tree main .githooks/commit-msg) | Should -Match '^100755 '
            (git -C $remote ls-tree main .githooks/commit-msg.ps1) | Should -Match '^100644 '
        }

        It 'turns the commit hook on in the local copy' {
            (git -C $app config --local --get core.hooksPath) | Should -Be '.githooks'
        }

        It 'names the kit version in the first commit, which is the only one' {
            @(git -C $remote log --format=%s main) | Should -Be @('chore: start from dotnet-agent-kit unreleased')
        }
    }

    # Public is the default: CI is free on public repos, macOS included, and GitHub Free offers rulesets only
    # on public repos (owner, 2026-11-07).
    Context 'a public app, the default' {
        BeforeAll {
            $app = Join-Path $TestDrive 'Public.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'public-remote.git')
            $runError = $null
            try { New-KitApp -Name 'Public.Orders' -KitRef $commit -Destination $app -KitRoot $kit 6>$null }
            catch { $runError = $_ }
        }

        It 'is created private and made public only after the push and the ruleset' {
            # A failure before then leaves a private repo, not a public one without its protections.
            $runError | Should -BeNullOrEmpty
            $writes = Get-WriteCall
            @($writes.Arguments) | Should -Be @(
                'api user/repos --method POST --input -'
                'api repos/fixture-owner/Public.Orders/rulesets --method POST --input -'
                'api repos/fixture-owner/Public.Orders/vulnerability-alerts --method PUT'
                'api repos/fixture-owner/Public.Orders/automated-security-fixes --method PUT'
                'api repos/fixture-owner/Public.Orders/actions/permissions --method PUT --input -'
                'api repos/fixture-owner/Public.Orders --method PATCH --input -'
                'api repos/fixture-owner/Public.Orders --method PATCH --input -'
                'api repos/fixture-owner/Public.Orders/actions/permissions/fork-pr-contributor-approval --method PUT --input -'
                'api repos/fixture-owner/Public.Orders/rulesets --method POST --input -'
            )
            ($writes[0].Input | ConvertFrom-Json).private | Should -BeTrue
            ($writes[1].Pushed) | Should -BeTrue
            ($writes[5].Input | ConvertFrom-Json).private | Should -BeFalse
        }

        It 'then turns on secret scanning and push protection, free on public repos (ADR-0031)' {
            @(Get-WriteCall).Count | Should -Be 9
            $security = ((Get-WriteCall)[6].Input | ConvertFrom-Json).security_and_analysis
            $security.secret_scanning.status | Should -Be 'enabled'
            $security.secret_scanning_push_protection.status | Should -Be 'enabled'
        }

        It 'runs no fork''s PR until the owner approves it' {
            @(Get-WriteCall).Count | Should -Be 9
            ((Get-WriteCall)[7].Input | ConvertFrom-Json).approval_policy | Should -Be 'all_external_contributors'
        }

        # The owner, 2026-11-10: new apps get the kit's merge protections. Only once public: CodeQL runs only on
        # a public app, and a rule requiring it would block every merge in a private one.
        It 'last, requires CodeQL results to merge, now that CodeQL runs' {
            @(Get-WriteCall).Count | Should -Be 9
            ((Get-WriteCall)[8].Input | ConvertFrom-Json).name | Should -Be 'code scanning'
        }
    }

    Context 'with -WhatIf' {
        BeforeAll {
            $app = Join-Path $TestDrive 'WhatIf.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'whatif-remote.git')
            $runError = $null
            try { New-KitApp -Name 'WhatIf.Orders' -KitRef $commit -Destination $app -KitRoot $kit -WhatIf 6>$null }
            catch { $runError = $_ }
        }

        It 'changes nothing: no folder, no GitHub change, no push' {
            $runError | Should -BeNullOrEmpty
            Test-Path -LiteralPath $app | Should -BeFalse
            Get-WriteCall | Should -BeNullOrEmpty
            git -C $remote rev-parse --verify --quiet refs/heads/main | Should -BeNullOrEmpty
        }

        It 'still checks the sign-in and that the repo doesn''t exist yet, which only read' {
            @($script:calls.Arguments) | Should -Contain 'auth status'
            @($script:calls.Arguments) | Should -Contain 'api repos/fixture-owner/WhatIf.Orders'
        }
    }

    Context 'the default kit version' {
        BeforeAll {
            $tagged = Join-Path $TestDrive 'tagged'
            git init -q -b main $tagged
            git -C $tagged commit -q --allow-empty -m 'chore: one'
            git -C $tagged tag v0.9.0
            git -C $tagged commit -q --allow-empty -m 'chore: two'
            git -C $tagged tag v0.10.0 # newer than v0.9.0 by version, older by name
            git -C $tagged tag v1.0.0-rc.1 # not a release
            git -C $tagged tag spike
        }

        It 'is the newest release tag, compared as versions' {
            Get-Command Get-KitLatestRelease -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-KitLatestRelease -KitRoot $tagged | Should -Be 'v0.10.0'
        }

        It 'is an error naming -KitRef when the kit has no release tag, before any change' {
            $app = Join-Path $TestDrive 'Untagged.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'untagged-remote.git')
            { New-KitApp -Name 'Untagged.Orders' -Destination $app -KitRoot $kit 6>$null } | Should -Throw '*-KitRef*'
            Get-WriteCall | Should -BeNullOrEmpty
            Test-Path -LiteralPath $app | Should -BeFalse
        }
    }

    Context 'a repo name other than the app name' {
        BeforeAll {
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'renamed-remote.git')
            $runError = $null
            # No -Destination: the folder defaults to the repo's name, as git clone would name it.
            try { New-KitApp -Name 'KitAppTest' -RepoName 'kit-app-test' -KitRef $commit -KitRoot $kit 6>$null }
            catch { $runError = $_ }
            $app = Join-Path (Split-Path $kit -Parent) 'kit-app-test'
        }

        It 'creates, checks and protects the repo by its own name' {
            $runError | Should -BeNullOrEmpty
            @($script:calls.Arguments) | Should -Contain 'api repos/fixture-owner/kit-app-test'
            $writes = Get-WriteCall
            ($writes[0].Input | ConvertFrom-Json).name | Should -Be 'kit-app-test'
            $writes[1].Arguments | Should -Be 'api repos/fixture-owner/kit-app-test/rulesets --method POST --input -'
        }

        It 'keeps the app name for the solution, in a folder named after the repo' {
            Test-Path -LiteralPath (Join-Path $app 'KitAppTest.slnx') | Should -BeTrue
        }

        It 'refuses a repo name GitHub doesn''t allow, before any change: <RepoName>' -ForEach @(
            @{ RepoName = 'kit app test' }, @{ RepoName = 'kit/app' }, @{ RepoName = '..' }, @{ RepoName = ('a' * 101) }
        ) {
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive "bad-repo-$($RepoName.Length).git")
            $folder = Join-Path $TestDrive "bad-repo-folder-$($RepoName.Length)"
            { New-KitApp -Name 'KitAppTest' -RepoName $RepoName -KitRef $commit -Destination $folder -KitRoot $kit 6>$null } |
                Should -Throw '*repo name*'
            @($script:calls) | Should -BeNullOrEmpty
            Test-Path -LiteralPath $folder | Should -BeFalse
        }
    }

    Context 'a kit version from before New-KitApp' {
        It 'refuses it before any change, since it has no GitHub settings to apply' {
            git -C $kit switch -q -c no-github-settings
            git -C $kit rm -q -r templates/github
            git -C $kit commit -q -m 'chore: no github settings'
            $old = (git -C $kit rev-parse HEAD).Trim()
            git -C $kit switch -q main
            $app = Join-Path $TestDrive 'Old.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'old-remote.git')

            { New-KitApp -Name 'Old.Orders' -KitRef $old -Destination $app -KitRoot $kit 6>$null } |
                Should -Throw '*has no templates/github/repo.json*'
            Get-WriteCall | Should -BeNullOrEmpty
            Test-Path -LiteralPath $app | Should -BeFalse
        }
    }

    Context 'run as a command' {
        It 'exits 1 with the reason when it refuses' {
            $output = pwsh -NoProfile -File $script -Name '1Bad' -KitRoot $kit 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 1
            $output | Should -Match 'dotted \.NET name'
        }

        # The command line has its own path to New-KitApp: a guard that dropped -Private would make public an app
        # the owner asked to keep private, which can't be fully undone (review 5 of PR 17).
        It 'makes the app public unless -Private is given (<Visibility>)' -ForEach @(
            @{ Visibility = 'public'; Switches = @(); Public = $true }
            @{ Visibility = 'private'; Switches = @('-Private'); Public = $false }
        ) {
            # A fake gh first on PATH, signed in, with no such repo yet. -WhatIf only lists the steps.
            $fake = Join-Path $TestDrive "fake-gh-$Visibility"
            New-Item -ItemType Directory -Force -Path $fake | Out-Null
            Set-Content -LiteralPath (Join-Path $fake 'gh.cmd') -Value @(
                '@echo off', 'if "%1"=="auth" exit /b 0', 'if "%2"=="user" (echo fixture-owner& exit /b 0)'
                'echo gh: Not Found (HTTP 404) 1>&2', 'exit /b 1')
            $sh = "#!/bin/sh`n" + 'if [ "$1" = auth ]; then exit 0; fi' + "`n" + 'if [ "$2" = user ]; then echo fixture-owner; exit 0; fi' +
                "`necho 'gh: Not Found (HTTP 404)' >&2`nexit 1`n"
            [IO.File]::WriteAllText((Join-Path $fake 'gh'), $sh)
            if (-not $IsWindows) { chmod +x (Join-Path $fake 'gh') }
            $savedPath = $env:PATH
            try {
                $env:PATH = $fake + [IO.Path]::PathSeparator + $env:PATH
                $folder = Join-Path $TestDrive "command-$Visibility"
                $output = pwsh -NoProfile -File $script -Name 'Command.Orders' -KitRef $commit -Destination $folder -KitRoot $kit -WhatIf @Switches 2>&1 | Out-String
            }
            finally { $env:PATH = $savedPath }

            $LASTEXITCODE | Should -Be 0 -Because $output
            $output | Should -Match "Add the 'main protection' ruleset" -Because 'the run reached its steps'
            $output | Should -Match 'fixture-owner/Command\.Orders' -Because 'the fake gh answered, not a real sign-in'
            ($output -match 'Make the repo public') | Should -Be $Public
            Test-Path -LiteralPath $folder | Should -BeFalse -Because '-WhatIf changes nothing'
        }

        It 'defaults the folder to one named after the app, next to the kit' {
            $sibling = Join-Path (Split-Path $kit -Parent) 'Sibling.Orders'
            New-Item -ItemType File -Force -Path (Join-Path $sibling 'keep.txt') | Out-Null
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'sibling-remote.git')
            { New-KitApp -Name 'Sibling.Orders' -KitRef $commit -KitRoot $kit 6>$null } |
                Should -Throw "*$([WildcardPattern]::Escape($sibling)) isn't empty*"
        }
    }

    Context 'a step that fails' {
        BeforeAll {
            $app = Join-Path $TestDrive 'Failing.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'failing-remote.git')
            Mock Invoke-KitGh {
                $script:calls.Add([pscustomobject]@{ Arguments = $Arguments -join ' '; Input = $InputText; Pushed = $true })
                [pscustomobject]@{ ExitCode = 1; Output = '{"message":"Validation Failed","status":"422"}'; Error = 'gh: Validation Failed (HTTP 422)' }
            } -ParameterFilter { ($Arguments -join ' ') -match '/rulesets ' }
            $runError = $null
            try { New-KitApp -Name 'Failing.Orders' -KitRef $commit -Destination $app -KitRoot $kit 6>$null }
            catch { $runError = $_ }
        }

        It 'stops there, and says which step failed, what''s done and what''s left' {
            "$runError" | Should -Match "Add the 'main protection' ruleset failed: .*HTTP 422"
            # Exactly: a failed step listed as done would tell the owner main is protected when it isn't.
            $lines = "$runError" -split "`r?`n"
            $lines | Should -Contain "Done: Export the kit's files at $commit; Make the first commit; Create the private repo with the kit's merge settings; Push main."
            # The repo stays private: making it public comes after the ruleset.
            $lines | Should -Contain "Left: Add the 'main protection' ruleset; Turn on Dependabot alerts and security updates; Require actions pinned to a full commit SHA; Make the repo public; Turn on secret scanning and push protection, and require approval for fork PRs; Require CodeQL results to merge; Turn the commit hook on in the local copy."
            @($script:calls.Arguments) | Should -Not -Match '--method PATCH'
            (git -C $app config --local --get core.hooksPath) | Should -BeNullOrEmpty -Because 'no step runs after a failure'
        }

        It 'keeps the GitHub repo it created, and says so' {
            @($script:calls.Arguments) | Should -Not -Match '--method DELETE'
            "$runError" | Should -Match 'https://github\.com/fixture-owner/Contoso\.Orders .*kept'
        }
    }

    Context 'a failure after the export, before the repo exists' {
        BeforeAll {
            $app = Join-Path $TestDrive 'NoRepo.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'norepo-remote.git')
            Mock Invoke-KitGh {
                $script:calls.Add([pscustomobject]@{ Arguments = $Arguments -join ' '; Input = $InputText; Pushed = $false })
                [pscustomobject]@{ ExitCode = 1; Output = '{"message":"Server Error","status":"500"}'; Error = 'gh: Server Error (HTTP 500)' }
            } -ParameterFilter { ($Arguments -join ' ') -match '^api user/repos ' }
            $runError = $null
            try { New-KitApp -Name 'NoRepo.Orders' -KitRef $commit -Destination $app -KitRoot $kit 6>$null }
            catch { $runError = $_ }
        }

        It 'says the folder is kept and must be cleared before running again, since a rerun refuses it' {
            Test-Path -LiteralPath (Join-Path $app '.git') | Should -BeTrue
            "$runError" | Should -Match "$([regex]::Escape($app)) is kept"
            "$runError" | Should -Not -Match 'was created and is kept'
        }

        It 'says where to check for the repo, rather than claiming there is none' {
            # GitHub may have made it before gh failed (a timeout after the server acted), so the run can't know.
            "$runError" | Should -Match 'check https://github\.com/fixture-owner/NoRepo\.Orders'
            "$runError" | Should -Not -Match 'No GitHub repo was created'
        }
    }

    Context 'where the run stops decides what the report says is kept' {
        It 'keeps the folder, and mentions no repo, when the first commit fails' {
            $app = Join-Path $TestDrive 'NoCommit.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'nocommit-remote.git')
            Mock Invoke-KitGit { throw 'git commit failed: no identity' } -ParameterFilter { $Arguments[0] -eq 'commit' }

            $message = $null
            try { New-KitApp -Name 'NoCommit.Orders' -KitRef $commit -Destination $app -KitRoot $kit 6>$null } catch { $message = "$_" }
            $message | Should -Match "Make the first commit failed"
            $message | Should -Match "The folder $([regex]::Escape($app)) is kept"
            $message | Should -Not -Match 'github\.com' -Because 'no create call was made'
            Get-WriteCall | Should -BeNullOrEmpty
        }

        It 'says nothing is kept when the export fails, which removes what it wrote' {
            # A kit commit without the "Sample app" label makes the export fail after it has started writing.
            git -C $kit switch -q -c no-sample-label-run
            $props = Join-Path $kit 'Directory.Packages.props'
            (Get-Content -Raw $props) -replace 'ItemGroup Label="Sample app"', 'ItemGroup' | Set-Content -LiteralPath $props -NoNewline
            git -C $kit commit -q -m 'chore: no label' -- Directory.Packages.props
            $broken = (git -C $kit rev-parse HEAD).Trim()
            git -C $kit switch -q main
            $app = Join-Path $TestDrive 'NoExport.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'noexport-remote.git')

            $message = $null
            try { New-KitApp -Name 'NoExport.Orders' -KitRef $broken -Destination $app -KitRoot $kit 6>$null *>$null } catch { $message = "$_" }
            $message | Should -Match '^Export the kit''s files at .* failed'
            $message | Should -Match 'Done: nothing\.'
            $message | Should -Not -Match 'kept'
            Test-Path -LiteralPath $app | Should -BeFalse
        }
    }

    Context 'refusing before any change: <Case>' -ForEach @(
        @{ Case = 'the repo already exists'; AppName = 'Taken.Orders'; Message = 'fixture-owner/Taken\.Orders already exists'
            Answer = @{ Pattern = '^api repos/fixture-owner/Taken\.Orders$'; ExitCode = 0; Output = '{"full_name":"fixture-owner/Taken.Orders"}'; Error = '' } }
        @{ Case = 'the repo check fails for another reason'; AppName = 'Unknown.Orders'; Message = "Couldn't check whether fixture-owner/Unknown\.Orders exists: gh: Bad credentials \(HTTP 401\)"
            Answer = @{ Pattern = '^api repos/fixture-owner/Unknown\.Orders$'; ExitCode = 1; Output = '{"message":"Bad credentials","status":"401"}'; Error = 'gh: Bad credentials (HTTP 401)' } }
        @{ Case = 'gh isn''t signed in'; AppName = 'Signed.Out'; Message = 'not logged into any GitHub hosts'
            Answer = @{ Pattern = '^auth status$'; ExitCode = 1; Output = ''; Error = 'You are not logged into any GitHub hosts. To log in, run: gh auth login' } }
        @{ Case = 'the folder isn''t empty'; AppName = 'Full.Folder'; Message = "isn't empty"; Answer = $null }
        @{ Case = 'the name isn''t a dotted .NET name'; AppName = '1Bad'; Message = 'dotted \.NET name'; Answer = $null }
    ) {
        BeforeAll {
            $app = Join-Path $TestDrive "refuse-$AppName"
            if ($Case -eq 'the folder isn''t empty') { New-Item -ItemType File -Force -Path (Join-Path $app 'keep.txt') | Out-Null }
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive "refuse-$AppName.git")
            if ($Answer) {
                $script:answer = $Answer
                Mock Invoke-KitGh {
                    $script:calls.Add([pscustomobject]@{ Arguments = $Arguments -join ' '; Input = $InputText; Pushed = $false })
                    [pscustomobject]@{ ExitCode = $script:answer.ExitCode; Output = $script:answer.Output; Error = $script:answer.Error }
                } -ParameterFilter { ($Arguments -join ' ') -match $script:answer.Pattern }
            }
            $runError = $null
            try { New-KitApp -Name $AppName -KitRef $commit -Destination $app -KitRoot $kit 6>$null }
            catch { $runError = $_ }
        }

        It 'stops with a message saying why' {
            "$runError" | Should -Match $Message
        }

        It 'makes no GitHub change and writes no file' {
            Get-WriteCall | Should -BeNullOrEmpty
            $expected = if ($Case -eq 'the folder isn''t empty') { @('keep.txt') } else { @() }
            @(if (Test-Path -LiteralPath $app) { (Get-ChildItem -LiteralPath $app -Force).Name }) | Should -Be $expected
        }
    }
}
