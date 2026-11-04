#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Dependabot updates the lock file of the project that references a package, but not the lock files of
# projects that get it through a project reference under central package management
# (dependabot-core#13950), so locked restore fails in CI. The workflow refreshes them on Dependabot's
# NuGet PRs (research notes §3, checkpoint §1). Restore runs code from the PR, so it runs in a job with
# a read-only token; a second job that never runs restored code validates and pushes the lock files
# (Copilot review, PR 12).

Describe 'dependabot-lockfiles.yml' {
    BeforeAll {
        Import-Module powershell-yaml
        $path = Join-Path $PSScriptRoot '..' '..' '.github' 'workflows' 'dependabot-lockfiles.yml'
        $text = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
        $workflow = if ($text) { ConvertFrom-Yaml $text } else { @{} }
        $jobs = if ($workflow.ContainsKey('jobs')) { $workflow['jobs'] } else { @{} }
        $refresh = if ($jobs.ContainsKey('refresh')) { $jobs['refresh'] } else { @{} }
        $push = if ($jobs.ContainsKey('push')) { $jobs['push'] } else { @{} }

        function Get-RunText([hashtable] $Job) {
            (@($Job['steps']) | Where-Object { $_ -and $_.ContainsKey('run') } | ForEach-Object { $_['run'] }) -join "`n"
        }
        $refreshRun = Get-RunText $refresh
        $pushRun = Get-RunText $push
    }

    It 'runs on pull requests only' {
        $on = if ($workflow.ContainsKey('on')) { $workflow['on'] } elseif ($workflow.ContainsKey($true)) { $workflow[$true] } else { $null }

        $on | Should -Not -BeNullOrEmpty
        @($on.Keys) | Should -Be @('pull_request')
    }

    It "only acts on Dependabot's own NuGet PRs in this repo (every condition must hold)" {
        $conditions = "$($refresh['if'])" -split '\s*&&\s*'

        "$($refresh['if'])" | Should -Not -Match '\|\|'
        $conditions | Should -Contain "github.actor == 'dependabot[bot]'"
        $conditions | Should -Contain "github.event.pull_request.user.login == 'dependabot[bot]'"
        $conditions | Should -Contain 'github.event.pull_request.head.repo.full_name == github.repository'
        $conditions | Should -Contain "startsWith(github.head_ref, 'dependabot/nuget/')"
    }

    It "lets a newer Dependabot run for the same PR replace an older one, and nothing else" {
        $workflow.ContainsKey('concurrency') | Should -BeTrue
        $workflow['concurrency']['group'] | Should -Match 'github\.head_ref'
        $workflow['concurrency']['group'] | Should -Match 'github\.actor'
        $workflow['concurrency']['cancel-in-progress'] | Should -BeTrue
    }

    It 'gives the workflow a read-only token by default' {
        $workflow['permissions'] | Should -Not -BeNullOrEmpty
        @($workflow['permissions'].Keys) | Should -Be @('contents')
        $workflow['permissions']['contents'] | Should -Be 'read'
    }

    Context 'refresh job: runs restore with a read-only token' {
        It 'has only read access' {
            $refresh['permissions'] | Should -Not -BeNullOrEmpty
            @($refresh['permissions'].Keys) | Should -Be @('contents')
            $refresh['permissions']['contents'] | Should -Be 'read'
        }

        It 'checks out the exact commit the run was for, without keeping the token' {
            $checkout = @($refresh['steps'] | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })[0]

            $checkout['with']['ref'] | Should -Be '${{ github.event.pull_request.head.sha }}'
            $checkout['with']['persist-credentials'] | Should -BeFalse
        }

        It 'refreshes every lock file, without the NuGet audit, which CI runs anyway' {
            $refreshRun | Should -Match 'dotnet restore .*--force-evaluate'
            $refreshRun | Should -Match '-p:NuGetAudit=false'
        }

        It 'counts root and new lock files as changes, and uploads only lock files' {
            $refreshRun | Should -Match "git status --porcelain -- '\*packages\.lock\.json'"
            $upload = @($refresh['steps'] | Where-Object { "$($_['uses'])" -like 'actions/upload-artifact@*' })[0]
            $upload | Should -Not -BeNullOrEmpty
            $refresh['outputs']['changed'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'push job: holds the write token and never runs restored code' {
        It 'runs after the refresh, only when lock files changed' {
            $push['needs'] | Should -Be 'refresh'
            "$($push['if'])" | Should -Match "needs\.refresh\.outputs\.changed == 'true'"
        }

        It 'asks for only the permissions it needs: push the lock files, approve the CI runs' {
            @($push['permissions'].Keys | Sort-Object) | Should -Be @('actions', 'contents')
            @($push['permissions'].Values | Select-Object -Unique) | Should -Be @('write')
        }

        It 'never sets up .NET or runs dotnet' {
            $push.ContainsKey('steps') | Should -BeTrue
            @($push['steps'] | Where-Object { "$($_['uses'])" -like 'actions/setup-dotnet@*' }).Count | Should -Be 0
            $pushRun | Should -Not -Match '\bdotnet\b'
        }

        It 'validates every downloaded file before using it' {
            $pushRun | Should -Match 'packages\.lock\.json'
            $pushRun | Should -Match '\*\.csproj'
            $pushRun | Should -Match '\.\.'
            $pushRun | Should -Match 'jq -e'
        }

        It 'commits only lock files, with a Conventional subject' {
            $pushRun | Should -Match "git add -- '\*packages\.lock\.json'"
            $pushRun | Should -Match 'git commit .*-m "chore\(deps\): refresh NuGet lock files"'
        }

        It "approves the CI runs its commit leaves waiting, and fails if CI didn't start or still waits" {
            $pushRun | Should -Match '--commit "\$sha"'
            $pushRun | Should -Match '--status action_required'
            $pushRun | Should -Match 'actions/runs/\$id/approve'
            $pushRun | Should -Match '--workflow ci\.yml'
            $pushRun | Should -Match 'still waiting for approval'
        }
    }

    It 'uses no stored secret' {
        $text | Should -Not -BeNullOrEmpty
        $text | Should -Not -Match 'secrets\.'
    }

    It 'pins every action to a full commit SHA (SUP-008)' {
        $uses = [regex]::Matches($text, 'uses: (\S+)') | ForEach-Object { $_.Groups[1].Value }

        @($uses).Count | Should -BeGreaterThan 0
        $uses | Should -Match '@[0-9a-f]{40}$'
    }
}
