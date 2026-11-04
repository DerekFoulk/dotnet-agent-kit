#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Dependabot updates the lock file of the project that references a package, but not the lock files of
# projects that get it through a project reference under central package management
# (dependabot-core#13950), so locked restore fails in CI. The workflow refreshes them on Dependabot's
# NuGet PRs (research notes §3, checkpoint §1).

Describe 'dependabot-lockfiles.yml' {
    BeforeAll {
        Import-Module powershell-yaml
        $path = Join-Path $PSScriptRoot '..' '..' '.github' 'workflows' 'dependabot-lockfiles.yml'
        $text = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
        $workflow = if ($text) { ConvertFrom-Yaml $text } else { @{} }
        $job = if ($workflow.ContainsKey('jobs')) { @($workflow['jobs'].Values)[0] } else { @{} }
        $run = (@($job['steps']) | Where-Object { $_ -and $_.ContainsKey('run') } | ForEach-Object { $_['run'] }) -join "`n"
    }

    It 'runs on pull requests only' {
        $on = if ($workflow.ContainsKey('on')) { $workflow['on'] } elseif ($workflow.ContainsKey($true)) { $workflow[$true] } else { $null }

        $on | Should -Not -BeNullOrEmpty
        @($on.Keys) | Should -Be @('pull_request')
    }

    It "only acts on Dependabot's NuGet PRs" {
        "$($job['if'])" | Should -Match "github\.actor == 'dependabot\[bot\]'"
        "$($job['if'])" | Should -Match "startsWith\(github\.head_ref, 'dependabot/nuget/'\)"
    }

    It 'asks for only the permissions it needs: push the lock files, approve the CI runs' {
        $permissions = $workflow['permissions']

        $permissions | Should -Not -BeNullOrEmpty
        @($permissions.Keys | Sort-Object) | Should -Be @('actions', 'contents')
        @($permissions.Values | Select-Object -Unique) | Should -Be @('write')
    }

    It 'uses no stored secret and never leaves the token in the checkout' {
        $text | Should -Not -BeNullOrEmpty
        $text | Should -Not -Match 'secrets\.'
        $text | Should -Match 'persist-credentials: false'
    }

    It 'refreshes every lock file and commits only lock files, with a Conventional subject' {
        $run | Should -Match 'dotnet restore .*--force-evaluate'
        $run | Should -Match "git add -- '\*\*/packages\.lock\.json'"
        $run | Should -Match 'git commit .*-m "chore\(deps\): refresh NuGet lock files"'
    }

    It 'approves the CI runs its commit leaves waiting, for that commit only' {
        $run | Should -Match '--commit "\$sha"'
        $run | Should -Match '--status action_required'
        $run | Should -Match 'actions/runs/\$id/approve'
    }

    It 'pins every action to a full commit SHA (SUP-008)' {
        $uses = [regex]::Matches($text, 'uses: (\S+)') | ForEach-Object { $_.Groups[1].Value }

        @($uses).Count | Should -BeGreaterThan 0
        $uses | Should -Match '@[0-9a-f]{40}$'
    }
}
