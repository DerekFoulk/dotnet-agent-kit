#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The kit sync in an app repo (PR D3, ADR-0044). Dependabot moves the kit pin in the app's workflows, which a
# workflow's own token can't change; on that PR, the app's kit-sync.yml calls kit-sync.reusable.yml, which runs
# Sync-KitApp and pushes the other kit-managed changes to the same PR with GITHUB_TOKEN. SharedCi.Tests.ps1 checks
# what every shared workflow must do (kit-tools, pins, no ${{ }} in a script); this checks the rest.

Describe 'The kit sync workflows' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Read-Workflow([string] $RelativePath) {
            $path = Join-Path $root $RelativePath
            # {{Name}} placeholders aren't YAML; ${{ }} expressions are plain strings.
            $text = if (Test-Path -LiteralPath $path) { (Get-Content -Raw -LiteralPath $path) -replace '\{\{[A-Za-z]+\}\}', 'X' } else { '' }
            $yaml = if ($text) { ConvertFrom-Yaml $text } else { @{} }
            $on = if ($yaml.ContainsKey('on')) { $yaml['on'] } elseif ($yaml.ContainsKey($true)) { $yaml[$true] } else { @{} }
            [pscustomobject]@{ Text = $text; Yaml = $yaml; On = $on; Jobs = $(if ($yaml.ContainsKey('jobs')) { $yaml['jobs'] } else { @{} }) }
        }

        $shared = Read-Workflow '.github/workflows/kit-sync.reusable.yml'
        $caller = Read-Workflow 'templates/app/.github/workflows/kit-sync.yml'
        $job = if ($shared.Jobs.Count) { @($shared.Jobs.Values)[0] } else { @{} }
        $steps = @($job['steps'] | Where-Object { $_ })
        $run = ($steps | Where-Object { $_.ContainsKey('run') } | ForEach-Object { $_['run'] }) -join "`n"

        # The conditions that make a PR Dependabot's own GitHub Actions PR, from a branch in the app's repo.
        $dependabot = @(
            "github.actor == 'dependabot[bot]'"
            "github.event.pull_request.user.login == 'dependabot[bot]'"
            'github.event.pull_request.head.repo.full_name == github.repository'
            "startsWith(github.head_ref, 'dependabot/github_actions/')"
        )
    }

    Context 'the app''s caller, templates/app/.github/workflows/kit-sync.yml' {
        It 'runs on pull requests, pinned to the kit like the app''s other kit workflows' {
            $caller.Text | Should -Not -BeNullOrEmpty -Because 'every new app gets the kit sync'
            @($caller.On.Keys) | Should -Be @('pull_request')
            $caller.Text | Should -Match ([regex]::Escape('uses: DerekFoulk/dotnet-agent-kit/.github/workflows/kit-sync.reusable.yml@X # X'))
        }

        It 'calls the sync only on Dependabot''s own GitHub Actions PRs in the app''s repo (every condition must hold)' {
            $caller.Jobs.Count | Should -Be 1
            $kit = @($caller.Jobs.Values)[0]
            $conditions = "$($kit['if'])" -split '\s*&&\s*'

            "$($kit['if'])" | Should -Not -Match '\|\|'
            foreach ($condition in $dependabot) { $conditions | Should -Contain $condition }
        }

        It 'grants the sync only what it needs: push to the PR, comment on it, approve its CI' {
            $caller.Jobs.Count | Should -Be 1
            $permissions = @($caller.Jobs.Values)[0]['permissions']

            @($permissions.Keys | Sort-Object) | Should -Be @('actions', 'contents', 'pull-requests')
            @($permissions.Values | Select-Object -Unique) | Should -Be @('write')
            $caller.Yaml['permissions']['contents'] | Should -Be 'read'
        }
    }

    Context 'the shared workflow, .github/workflows/kit-sync.reusable.yml' {
        It 'is a shared workflow that fails unless it''s on Dependabot''s own GitHub Actions PR in the app''s repo' {
            @($shared.On.Keys) | Should -Be @('workflow_call')
            $guard = @($steps | Where-Object { "$($_['if'])" -match '\|\|' -and $_['run'] -match 'exit 1' })
            $guard.Count | Should -Be 1
            $negated = "$($guard[0]['if'])" -replace '\s+', ' '
            $negated | Should -Match ([regex]::Escape("github.event_name != 'pull_request'"))
            $negated | Should -Match ([regex]::Escape("github.actor != 'dependabot[bot]'"))
            $negated | Should -Match ([regex]::Escape("github.event.pull_request.user.login != 'dependabot[bot]'"))
            $negated | Should -Match ([regex]::Escape('github.event.pull_request.head.repo.full_name != github.repository'))
            $negated | Should -Match ([regex]::Escape("!startsWith(github.head_ref, 'dependabot/github_actions/')"))
        }

        It 'checks out the PR''s head without keeping the token' {
            $checkout = @($steps | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })

            $checkout | Should -HaveCount 1
            $checkout[0]['with']['ref'] | Should -Be '${{ github.event.pull_request.head.sha }}'
            $checkout[0]['with']['persist-credentials'] | Should -BeFalse
        }

        It 'runs the release''s own Sync-KitApp on a clone of the kit with its tags, taking the release from the pins' {
            $run | Should -Match 'git clone [^\n]*https://github\.com/DerekFoulk/dotnet-agent-kit\.git'
            $run | Should -Match '\$env:KIT/tools/Sync-KitApp\.ps1'
            $run | Should -Not -Match 'Sync-KitApp\.ps1[^\n]*-KitRef' -Because 'the release is the one the pins name, checked against its tag'
            $run | Should -Not -Match '\.kit/tools' -Because "the write token never meets the app's own scripts"
        }

        It 'never commits a change to a workflow file, which its token can''t push' {
            $run | Should -Match 'git status --porcelain -- \.github/workflows'
        }

        It 'commits with a Conventional subject and pushes to Dependabot''s branch' {
            $run | Should -Match 'git commit [^\n]*-m "chore\(deps\): '
            $run | Should -Match 'HEAD:refs/heads/\$\{HEAD_REF\}'
        }

        It 'comments the sync''s report on the PR, since Dependabot writes its description' {
            $run | Should -Match 'gh pr comment'
            $run | Should -Match '--body-file'
        }

        It "approves the CI runs its commit leaves waiting, and fails if CI didn't start or still waits" {
            $run | Should -Match '--commit "\$sha"'
            $run | Should -Match '--status action_required'
            $run | Should -Match 'actions/runs/\$id/approve'
            $run | Should -Match '--workflow ci\.yml'
            $run | Should -Match 'still waiting for approval'
        }

        It 'uses no stored secret' {
            $shared.Text | Should -Not -Match 'secrets\.'
            $caller.Text | Should -Not -Match 'secrets'
        }
    }
}
