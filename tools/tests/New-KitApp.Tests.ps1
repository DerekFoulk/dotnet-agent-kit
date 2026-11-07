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
