#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The release workflow and release-please config, as proven by the step 5 spike
# (spikes/release-please/README.md, ADR-0022).

Describe 'Release configuration' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $workflowPath = Join-Path $root '.github' 'workflows' 'release.yml'
        $configPath = Join-Path $root 'release-please-config.json'
        $manifestPath = Join-Path $root '.release-please-manifest.json'

        $workflowText = if (Test-Path $workflowPath) { Get-Content -Raw $workflowPath } else { '' }
        $workflow = if ($workflowText) { ConvertFrom-Yaml $workflowText } else { @{} }
        $config = if (Test-Path $configPath) { Get-Content -Raw $configPath | ConvertFrom-Json -AsHashtable } else { @{} }
        $manifest = if (Test-Path $manifestPath) { Get-Content -Raw $manifestPath | ConvertFrom-Json -AsHashtable } else { @{} }
    }

    Context 'release.yml' {
        It 'runs on pushes to main only' {
            # YAML 1.1 parsers can read the key "on" as the boolean true.
            $on = if ($workflow.ContainsKey('on')) { $workflow['on'] } elseif ($workflow.ContainsKey($true)) { $workflow[$true] } else { $null }

            $on | Should -Not -BeNullOrEmpty
            @($on.Keys) | Should -Be @('push')
            @($on['push']['branches']) | Should -Be @('main')
        }

        It 'pins release-please-action to a full commit SHA (SUP-008)' {
            $workflowText | Should -Match 'uses: googleapis/release-please-action@[0-9a-f]{40} # v\d+\.\d+\.\d+'
            $workflowText | Should -Not -Match 'uses: [^\s#]+@(v\d+|main|master)\s'
        }

        It 'asks for only the permissions release-please and the approval step need' {
            $permissions = $workflow['permissions']

            $permissions | Should -Not -BeNullOrEmpty
            @($permissions.Keys | Sort-Object) | Should -Be @('actions', 'contents', 'issues', 'pull-requests')
            @($permissions.Values | Select-Object -Unique) | Should -Be @('write')
        }

        It 'uses no stored secret: the built-in GITHUB_TOKEN only' {
            $workflowText | Should -Not -BeNullOrEmpty
            $workflowText | Should -Not -Match 'secrets\.'
        }

        # A release PR opened with GITHUB_TOKEN gets pull_request runs that wait for approval.
        It "approves only the release PR's pull_request runs that are waiting for approval" {
            $workflowText | Should -Match '--event pull_request'
            $workflowText | Should -Match '--status action_required'
            $workflowText | Should -Match 'actions/runs/\$id/approve'
        }

        # A fork PR can use the same branch name; only the release PR's own head commit identifies it.
        It "approves only runs for the release PR's head commit, not every run on a branch of that name" {
            $workflowText | Should -Match 'headRefOid'
            $workflowText | Should -Match '--commit "\$sha"'
        }

        # release-please returns no PR when the release PR is unchanged, so a rerun on the same commit
        # must still find the open release PR (Copilot review, PR 9).
        It "finds the open release PR when release-please reports none, and only one opened by GitHub Actions" {
            $approve = @($workflow['jobs']['release-please']['steps'] | Where-Object { $_['name'] -eq 'Approve CI on the release PR' })[0]

            $approve | Should -Not -BeNullOrEmpty
            "$($approve['if'])" | Should -Not -Match 'steps\.release\.outputs\.pr' -Because 'the step must also run when the output is empty'
            $approve['run'] | Should -Match 'gh pr list'
            $approve['run'] | Should -Match '--author app/github-actions'
            $approve['run'] | Should -Match '--label "autorelease: pending"'
            $approve['run'] | Should -Match 'release-please--branches--main'
        }

        # If GitHub ever stops creating the waiting runs, the release PR would block with no signal.
        It 'fails when the release PR has no CI run at all, instead of warning' {
            $workflowText | Should -Match '::error::'
        }
    }

    Context 'release-please config' {
        It 'sets <Key> to <Expected>' -ForEach @(
            @{ Key = 'release-type'; Expected = 'simple' }
            @{ Key = 'include-v-in-tag'; Expected = $true }
            @{ Key = 'bump-minor-pre-major'; Expected = $true }
            @{ Key = 'initial-version'; Expected = '0.1.0' }
            @{ Key = 'changelog-type'; Expected = 'github' }
        ) {
            $config[$Key] | Should -Be $Expected
        }

        It 'releases the repo root as one package' {
            @($config['packages'].Keys) | Should -Be @('.')
            @($manifest.Keys) | Should -Be @('.')
        }
    }
}
