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

    It "only acts on Dependabot's own NuGet PRs in this repo (every condition must hold)" {
        $conditions = "$($job['if'])" -split '\s*&&\s*'

        "$($job['if'])" | Should -Not -Match '\|\|'
        $conditions | Should -Contain "github.actor == 'dependabot[bot]'"
        $conditions | Should -Contain "github.event.pull_request.user.login == 'dependabot[bot]'"
        $conditions | Should -Contain 'github.event.pull_request.head.repo.full_name == github.repository'
        $conditions | Should -Contain "startsWith(github.head_ref, 'dependabot/nuget/')"
    }

    It 'checks out the exact commit the run was for, so a later push is never swept in' {
        $checkout = @($job['steps'] | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })[0]

        $checkout['with']['ref'] | Should -Be '${{ github.event.pull_request.head.sha }}'
    }

    It 'lets a newer run for the same PR replace an older one' {
        $workflow.ContainsKey('concurrency') | Should -BeTrue
        $workflow['concurrency']['group'] | Should -Match 'github\.head_ref'
        $workflow['concurrency']['cancel-in-progress'] | Should -BeTrue
    }

    It 'gives the write token only to the steps that push or approve, not to the restore' {
        @($job['env'].Keys) | Should -Not -Contain 'GH_TOKEN'
        $restore = @($job['steps'] | Where-Object { "$($_['run'])" -match 'dotnet restore' })[0]
        @($restore['env'].Keys) | Should -Not -Contain 'GH_TOKEN'
    }

    It 'counts root and new lock files as changes too' {
        $run | Should -Match "git status --porcelain -- '\*packages\.lock\.json'"
    }

    It 'refreshes without the NuGet audit, which CI runs anyway' {
        $run | Should -Match 'dotnet restore .*-p:NuGetAudit=false'
    }

    It "fails when CI is still waiting for approval, or never started, after it's done" {
        $run | Should -Match '--status action_required'
        $run | Should -Match '--workflow ci\.yml'
        $run | Should -Match 'still waiting for approval'
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
        $run | Should -Match "git add -- '\*packages\.lock\.json'"
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
