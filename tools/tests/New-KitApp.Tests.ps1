#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# New-KitApp creates an app repo on GitHub from Export-KitApp's files (PR D2b, ADR-0033). The repo settings
# and the "main protection" ruleset are data in templates/github, so the sync job (PR D3) can apply them again.

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
            foreach ($jobId in $yaml['jobs'].Keys) {
                $uses = $yaml['jobs'][$jobId]['uses']
                if ($uses -notmatch '^DerekFoulk/dotnet-agent-kit/\.github/workflows/([^@]+)@') { continue }
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

        It 'is private unless -Public is given' {
            Test-Path -LiteralPath $script | Should -BeTrue -Because 'New-KitApp.ps1 builds the request'
            (Get-KitAppRepoRequest -Name 'Contoso.Orders' -SettingsText $settingsText).private | Should -BeTrue
            (Get-KitAppRepoRequest -Name 'Contoso.Orders' -SettingsText $settingsText -Public).private | Should -BeFalse
        }
    }
}

# The run, against a throwaway kit repo built from this working tree (as in Export-KitApp.Tests.ps1). GitHub
# is replaced: Invoke-KitGh is mocked, and the "created" repo's clone URL is a local bare repo, so git
# itself runs for real.
Describe 'New-KitApp run' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $script = Join-Path $root 'tools' 'New-KitApp.ps1'

        # Commits made here must not depend on the machine's git identity or signing setup.
        $savedEnv = @{}
        $gitEnv = @{
            GIT_AUTHOR_NAME = 'fixture'; GIT_AUTHOR_EMAIL = 'fixture@example.invalid'
            GIT_COMMITTER_NAME = 'fixture'; GIT_COMMITTER_EMAIL = 'fixture@example.invalid'
            GIT_CONFIG_COUNT = '1'; GIT_CONFIG_KEY_0 = 'commit.gpgsign'; GIT_CONFIG_VALUE_0 = 'false'
        }
        foreach ($key in $gitEnv.Keys) {
            $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $gitEnv[$key])
        }

        $kit = Join-Path $TestDrive 'kit'
        foreach ($file in git -C $root ls-files --cached --others --exclude-standard) {
            $source = Join-Path $root $file
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue } # deleted but not yet staged
            $target = Join-Path $kit $file
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
        }
        git -C $kit init -q -b main
        git -C $kit add -A
        git -C $kit commit -q -m 'chore: kit fixture'
        $commit = (git -C $kit rev-parse HEAD).Trim()

        if (Test-Path -LiteralPath $script) { . $script }

        # A fake GitHub: records every call, answers as the API would, and notes whether main had been
        # pushed when each call was made.
        function Initialize-FakeGitHub([string] $Remote) {
            $script:calls = [Collections.Generic.List[object]]::new()
            $script:remote = $Remote
            git init -q --bare $Remote
            Mock Invoke-KitGh {
                $pushed = [bool] (git -C $script:remote rev-parse --verify --quiet refs/heads/main)
                $script:calls.Add([pscustomobject]@{ Arguments = $Arguments -join ' '; Input = $InputText; Pushed = $pushed })
                $text = switch -Regex ($Arguments -join ' ') {
                    '^auth status' { 'Logged in to github.com account fixture-owner' }
                    '^api user --jq \.login$' { 'fixture-owner' }
                    '^api repos/[^/ ]+/[^/ ]+$' { return [pscustomobject]@{ ExitCode = 1; Output = 'gh: Not Found (HTTP 404)' } }
                    '^api user/repos' { (@{ html_url = 'https://github.com/fixture-owner/Contoso.Orders'; clone_url = $script:remote } | ConvertTo-Json) }
                    default { '{}' }
                }
                [pscustomobject]@{ ExitCode = 0; Output = $text }
            }
        }

        function Get-WriteCall { @($script:calls | Where-Object { $_.Arguments -match '--method (POST|PATCH|PUT|DELETE)' }) }
    }

    AfterAll {
        # PowerShell passes $null to a .NET string parameter as '', which would leave an empty GIT_AUTHOR_NAME
        # behind and break the next test file's commits, so an unset variable is removed instead.
        foreach ($key in $savedEnv.Keys) {
            if ($null -eq $savedEnv[$key]) { Remove-Item -LiteralPath "env:$key" -ErrorAction SilentlyContinue }
            else { Set-Item -LiteralPath "env:$key" -Value $savedEnv[$key] }
        }
    }

    Context 'a private app' {
        BeforeAll {
            $app = Join-Path $TestDrive 'Contoso.Orders'
            Initialize-FakeGitHub -Remote (Join-Path $TestDrive 'remote.git')
            $runError = $null
            try { New-KitApp -Name 'Contoso.Orders' -KitRef $commit -Destination $app -KitRoot $kit 6>$null }
            catch { $runError = $_ }
        }

        It 'exports, commits, creates the repo, pushes main, then adds the ruleset' {
            $runError | Should -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $app '.kit' 'manifest.json') | Should -BeTrue -Because 'the export ran'
            (git -C $remote log -1 --format=%s main) | Should -Match '^chore: start from dotnet-agent-kit'

            $writes = Get-WriteCall
            @($writes.Arguments) | Should -Be @('api user/repos --method POST --input -', 'api repos/fixture-owner/Contoso.Orders/rulesets --method POST --input -')
            ($writes[0].Input | ConvertFrom-Json).name | Should -Be 'Contoso.Orders'
            ($writes[0].Input | ConvertFrom-Json).private | Should -BeTrue
            $writes[1].Pushed | Should -BeTrue -Because 'the ruleset would reject the first push'
            ($writes[1].Input | ConvertFrom-Json).name | Should -Be 'main protection'
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
}
