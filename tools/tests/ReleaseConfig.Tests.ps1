#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The release workflow and release-please config, as proven by the step 5 spike
# (spikes/release-please/README.md, ADR-0022). The kit and every app release the same way, through one shared
# workflow, release-please.reusable.yml (ADR-0096).

Describe 'Release configuration' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        # A workflow file's text and YAML; {{Name}} placeholders in app templates aren't YAML, so they read as X.
        function Read-Workflow([string] $RelativePath) {
            $path = Join-Path $root $RelativePath
            $text = if (Test-Path -LiteralPath $path) { Get-Content -Raw -LiteralPath $path } else { '' }
            [pscustomobject]@{ Text = $text; Yaml = if ($text) { ConvertFrom-Yaml ($text -replace '\{\{[A-Za-z]+\}\}', 'X') } else { @{} } }
        }

        # YAML 1.1 parsers can read the key "on" as the boolean true.
        function Get-On($Yaml) {
            if ($Yaml.ContainsKey('on')) { $Yaml['on'] } elseif ($Yaml.ContainsKey($true)) { $Yaml[$true] } else { $null }
        }

        $shared = Read-Workflow '.github/workflows/release-please.reusable.yml'
        $sharedJob = if ($shared.Yaml.ContainsKey('jobs')) { $shared.Yaml['jobs']['release-please'] } else { $null }

        function Read-Json([string] $RelativePath) {
            $path = Join-Path $root $RelativePath
            if (Test-Path -LiteralPath $path) { Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable } else { @{} }
        }
    }

    Context 'release-please.reusable.yml, the shared release job' {
        It 'runs only when a workflow calls it' {
            $on = Get-On $shared.Yaml

            $on | Should -Not -BeNullOrEmpty -Because 'release-please.reusable.yml holds the release job'
            @($on.Keys) | Should -Be @('workflow_call')
        }

        It 'pins release-please-action to a full commit SHA (SUP-008)' {
            $shared.Text | Should -Match 'uses: googleapis/release-please-action@[0-9a-f]{40} # v\d+\.\d+\.\d+'
            $shared.Text | Should -Not -Match 'uses: [^\s#]+@(v\d+|main|master)\s'
        }

        It 'asks for only the permissions release-please and the approval step need' {
            $sharedJob | Should -Not -BeNullOrEmpty -Because 'the shared workflow has a release-please job'
            $permissions = $sharedJob['permissions']

            @($permissions.Keys | Sort-Object) | Should -Be @('actions', 'contents', 'issues', 'pull-requests')
            @($permissions.Values | Select-Object -Unique) | Should -Be @('write')
            # A called workflow's top-level permissions would apply to every job it ever gets.
            $shared.Yaml.ContainsKey('permissions') | Should -BeFalse
        }

        It 'uses no stored secret: the built-in GITHUB_TOKEN only' {
            $shared.Text | Should -Not -BeNullOrEmpty
            $shared.Text | Should -Not -Match 'secrets\.'
        }

        # A release PR opened with GITHUB_TOKEN gets pull_request runs that wait for approval.
        It "approves only the release PR's pull_request runs that are waiting for approval" {
            $shared.Text | Should -Match '--event pull_request'
            $shared.Text | Should -Match '--status action_required'
            $shared.Text | Should -Match 'actions/runs/\$id/approve'
        }

        # A fork PR can use the same branch name; only the release PR's own head commit identifies it.
        It "approves only runs for the release PR's head commit, not every run on a branch of that name" {
            $shared.Text | Should -Match 'headRefOid'
            $shared.Text | Should -Match '--commit "\$sha"'
        }

        # release-please returns no PR when the release PR is unchanged, so a rerun on the same commit
        # must still find the open release PR (Copilot review, PR 9).
        It "finds the open release PR when release-please reports none, and only one opened by GitHub Actions" {
            $sharedJob | Should -Not -BeNullOrEmpty -Because 'the shared workflow has a release-please job'
            $approve = @($sharedJob['steps'] | Where-Object { $_['name'] -eq 'Approve CI on the release PR' })[0]

            $approve | Should -Not -BeNullOrEmpty
            "$($approve['if'])" | Should -Not -Match 'steps\.release\.outputs\.pr' -Because 'the step must also run when the output is empty'
            $approve['run'] | Should -Match 'gh pr list'
            $approve['run'] | Should -Match '--author app/github-actions'
            $approve['run'] | Should -Match '--label "autorelease: pending"'
            $approve['run'] | Should -Match 'release-please--branches--main'
        }

        # A ${{ }} expression in a run: script is pasted in before the shell parses it (script injection).
        It 'never pastes a ${{ }} value into a run: script; values come in through env' {
            $sharedJob | Should -Not -BeNullOrEmpty -Because 'the shared workflow has a release-please job'
            $scripts = @($sharedJob['steps'] | Where-Object { $_.ContainsKey('run') } | ForEach-Object { $_['run'] })

            $scripts | Should -Not -BeNullOrEmpty
            foreach ($script in $scripts) { $script | Should -Not -Match '\$\{\{' }
        }

        # If GitHub ever stops creating the waiting runs, the release PR would block with no signal.
        It 'fails when the release PR has no CI run at all, instead of warning' {
            $shared.Text | Should -Match '::error::'
        }
    }

    Context 'release.yml in <Caller>' -ForEach @(
        @{ Caller = 'the kit'; File = '.github/workflows/release.yml'; Uses = './.github/workflows/release-please.reusable.yml' }
        @{ Caller = 'every app'; File = 'templates/app/.github/workflows/release.yml'; Uses = 'DerekFoulk/dotnet-agent-kit/.github/workflows/release-please.reusable.yml@X' }
    ) {
        BeforeAll {
            $caller = Read-Workflow $File
            # @() outside the if: an if expression unrolls a one-item array into the item itself.
            $jobs = @(if ($caller.Yaml.ContainsKey('jobs')) { $caller.Yaml['jobs'].Values })
        }

        It 'runs on pushes to main only' {
            $on = Get-On $caller.Yaml

            $on | Should -Not -BeNullOrEmpty -Because "$File starts releases"
            @($on.Keys) | Should -Be @('push')
            @($on['push']['branches']) | Should -Be @('main')
        }

        It 'calls the shared release job, and nothing else' {
            $jobs | Should -HaveCount 1
            $jobs[0]['uses'] | Should -Be $Uses
        }

        It 'grants the shared job exactly what it asks for, and nothing at the top' {
            $jobs | Should -HaveCount 1
            # GitHub refuses a called workflow that asks for a permission its caller's job doesn't grant (PR 48).
            $granted = $jobs[0]['permissions']
            $asked = if ($sharedJob) { $sharedJob['permissions'] } else { @{} }

            @($granted.Keys | Sort-Object) | Should -Be @($asked.Keys | Sort-Object)
            foreach ($scope in @($asked.Keys)) { $granted[$scope] | Should -Be $asked[$scope] -Because "the shared job asks for '${scope}: $($asked[$scope])'" }
            @($caller.Yaml['permissions'].Keys) | Should -Be @('contents')
            $caller.Yaml['permissions']['contents'] | Should -Be 'read'
        }
    }

    It 'pins the shared workflow in every app to the kit commit its release tag points to (ADR-0031)' {
        $text = (Read-Workflow 'templates/app/.github/workflows/release.yml').Text

        $text | Should -Match 'release-please\.reusable\.yml@\{\{KitCommit\}\} # \{\{KitVersion\}\}'
    }

    Context 'release-please config' {
        BeforeAll {
            $config = Read-Json 'release-please-config.json'
            $manifest = Read-Json '.release-please-manifest.json'
        }

        It 'sets <Key> to <Expected>' -ForEach @(
            @{ Key = 'release-type'; Expected = 'simple' }
            @{ Key = 'include-v-in-tag'; Expected = $true }
            @{ Key = 'bump-minor-pre-major'; Expected = $true }
            @{ Key = 'initial-version'; Expected = '0.1.0' }
            @{ Key = 'changelog-type'; Expected = 'github' }
        ) {
            $config[$Key] | Should -Be $Expected
        }

        # Under SemVer 2.0.0, a feature before 1.0.0 is a new minor version, as after it (ADR-0096).
        It 'bumps the minor version for a feature before 1.0.0, not the patch' {
            $config.ContainsKey('bump-patch-for-minor-pre-major') | Should -BeFalse
        }

        # Every app gets this file, kit-managed (ADR-0096), so a forced version here would reach every app with the next
        # sync. 1.0.0 is declared with a Release-As footer on a commit of the repo's own instead (review 1).
        It 'never forces a version, which every app would get with the file' {
            $config | Should -Not -BeNullOrEmpty
            $config.ContainsKey('release-as') | Should -BeFalse
            foreach ($package in @($config['packages'].Values)) { $package.ContainsKey('release-as') | Should -BeFalse }
        }

        It 'releases the repo root as one package' {
            @($config['packages'].Keys) | Should -Be @('.')
            @($manifest.Keys) | Should -Be @('.')
        }
    }
}
