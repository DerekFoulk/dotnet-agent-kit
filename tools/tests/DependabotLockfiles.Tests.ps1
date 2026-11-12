#Requires -Version 7.6
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
        $pin = if ($jobs.ContainsKey('pin-pmd')) { $jobs['pin-pmd'] } else { @{} }

        function Get-RunText([hashtable] $Job) {
            (@($Job['steps']) | Where-Object { $_ -and $_.ContainsKey('run') } | ForEach-Object { $_['run'] }) -join "`n"
        }
        $refreshRun = Get-RunText $refresh
        $pushRun = Get-RunText $push
        $pinRun = Get-RunText $pin
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
        # GAP-023 (ADR-0060): one push job for both kinds of Dependabot PR, so one place holds the write token.
        It 'runs after either job, only when that job succeeded and changed something' {
            @($push['needs']) | Should -Be @('refresh', 'pin-pmd')
            # In ${{ }}: a bare ! at the start of a YAML value is a tag.
            "$($push['if'])" | Should -Match '^\$\{\{ !cancelled\(\) && '
            "$($push['if'])" | Should -Match "needs\.refresh\.result == 'success' && needs\.refresh\.outputs\.changed == 'true'"
            "$($push['if'])" | Should -Match "needs\.pin-pmd\.result == 'success' && needs\.pin-pmd\.outputs\.changed == 'true'"
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

        It "commits only lock files and PMD's pin, with a Conventional subject" {
            $pushRun | Should -Match "(?m)git add -- '\*packages\.lock\.json' \.config/pmd/pmd-dist-bin\.zip\.sha256$"
            $pushRun | Should -Match '"chore\(deps\): refresh NuGet lock files"'
            $pushRun | Should -Match '"chore\(deps\): pin the SHA-256 of PMD''s release zip"'
            $pushRun | Should -Match 'git commit --quiet -m "\$subject"'
        }

        # The pin comes from a job that ran the PR's own copy of KitPmd.psm1, so this job trusts only its shape: one
        # regular file, one line of a SHA-256, two spaces and a release zip's name. A pin for another version than the
        # pom names is CI's to refuse (Get-PmdPin), as the lock files are locked restore's.
        It "validates PMD's pin before placing it, and runs no PowerShell or kit script" {
            $pushRun | Should -Match ([regex]::Escape("grep -Eqx '[0-9a-f]{64}  pmd-dist-[0-9]+\.[0-9]+\.[0-9]+-bin\.zip'"))
            $pushRun | Should -Match '"\$\(find \. -mindepth 1\)" != "\./pmd-dist-bin\.zip\.sha256"'
            $pushRun | Should -Match '\[ -L pmd-dist-bin\.zip\.sha256 \]'
            $pushRun | Should -Match '"\$\(wc -l < pmd-dist-bin\.zip\.sha256\)" -ne 1'
            $pushRun | Should -Match 'cp -- pmd-dist-bin\.zip\.sha256 "\$GITHUB_WORKSPACE/\.config/pmd/pmd-dist-bin\.zip\.sha256"'
            $pushRun | Should -Not -Match 'pwsh|Import-Module|tools/'
            @($push['steps'] | Where-Object { $_.ContainsKey('shell') }).Count | Should -Be 0
        }

        It "approves the CI runs its commit leaves waiting, and fails if CI didn't start or still waits" {
            $pushRun | Should -Match '--commit "\$sha"'
            $pushRun | Should -Match '--status action_required'
            $pushRun | Should -Match 'actions/runs/\$id/approve'
            $pushRun | Should -Match '--workflow ci\.yml'
            $pushRun | Should -Match 'still waiting for approval'
        }
    }

    # GAP-023 (ADR-0060): Dependabot moves PMD's version in .config/pmd/pom.xml; the zip's SHA-256 needs pinning too.
    Context "pin-pmd job: pins PMD's zip with a read-only token" {
        It "only acts on Dependabot's own maven PRs in this repo (every condition must hold)" {
            $conditions = "$($pin['if'])" -split '\s*&&\s*'

            "$($pin['if'])" | Should -Not -Match '\|\|'
            $conditions | Should -Contain "github.actor == 'dependabot[bot]'"
            $conditions | Should -Contain "github.event.pull_request.user.login == 'dependabot[bot]'"
            $conditions | Should -Contain 'github.event.pull_request.head.repo.full_name == github.repository'
            $conditions | Should -Contain "startsWith(github.head_ref, 'dependabot/maven/')"
        }

        It 'has only read access, and checks out the exact commit without keeping the token' {
            @($pin['permissions'].Keys) | Should -Be @('contents')
            $pin['permissions']['contents'] | Should -Be 'read'
            $checkout = @($pin['steps'] | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })[0]
            $checkout['with']['ref'] | Should -Be '${{ github.event.pull_request.head.sha }}'
            $checkout['with']['persist-credentials'] | Should -BeFalse
        }

        It "pins GitHub's digest for the release of the pom's version, through KitPmd.psm1, stopping on any failure" {
            $step = @($pin['steps'] | Where-Object { "$($_['run'])" -match 'Set-PmdPin' })

            $step | Should -HaveCount 1
            $step[0]['shell'] | Should -Be 'pwsh'
            $step[0]['env']['GH_TOKEN'] | Should -Be '${{ github.token }}'
            $pinRun | Should -Match '\$PSNativeCommandUseErrorActionPreference = \$true'
            $pinRun | Should -Match 'Import-Module \./tools/KitPmd\.psm1'
            $pinRun | Should -Match '\$version = Get-PmdVersion -Path \.config/pmd'
            $pinRun | Should -Match 'gh api "repos/pmd/pmd/releases/tags/pmd_releases%2F\$version"'
            $pinRun | Should -Match 'Set-PmdPin -Path \.config/pmd -Release \$release'
        }

        It 'uploads only the pin file, and says whether it changed' {
            $pinRun | Should -Match "git status --porcelain -- \.config/pmd/pmd-dist-bin\.zip\.sha256"
            $upload = @($pin['steps'] | Where-Object { "$($_['uses'])" -like 'actions/upload-artifact@*' })
            $upload | Should -HaveCount 1
            $upload[0]['with']['name'] | Should -Be 'pmd-pin'
            $upload[0]['with']['path'] | Should -Be '.config/pmd/pmd-dist-bin.zip.sha256'
            $pin['outputs']['changed'] | Should -Not -BeNullOrEmpty
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
