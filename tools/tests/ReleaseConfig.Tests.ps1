#Requires -Version 7.0
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
        It "approves only the waiting pull_request runs on release-please's own branch" {
            $workflowText | Should -Match '--event pull_request'
            $workflowText | Should -Match '--status action_required'
            $workflowText | Should -Match 'headBranchName'
            $workflowText | Should -Match 'actions/runs/\$id/approve'
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
