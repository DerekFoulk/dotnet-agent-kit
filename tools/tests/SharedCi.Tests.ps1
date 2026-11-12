#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Shared CI for app repos (step 6, PR D1; spikes/kit-sharing/README.md). App repos call the kit's shared
# workflows pinned to a kit release. They reach the kit's scripts through
# `uses: $/.github/actions/kit-tools`, which GitHub downloads at the shared workflow's own commit, so an
# app always runs the scripts of the version it pins. (The kit was private when this was built, so a
# checkout of the kit wasn't possible; ADR-0031 made it public, and $/ still keeps the versions matched.)

BeforeAll {
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'Shared CI for app repos' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Read-Yaml([string] $RelativePath) {
            $path = Join-Path $root $RelativePath
            $text = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
            [pscustomobject]@{ Text = $text; Yaml = if ($text) { ConvertFrom-Yaml $text } else { @{} } }
        }

        function Get-Steps($Yaml) {
            if (-not $Yaml.ContainsKey('jobs')) { return @() }
            @($Yaml['jobs'].Values | ForEach-Object { @($_['steps']) })
        }

        $action = Read-Yaml '.github/actions/kit-tools/action.yml'
        $dotnet = Read-Yaml '.github/workflows/dotnet-ci.reusable.yml'
        $app = Read-Yaml '.github/workflows/app-checks.reusable.yml'
    }

    Context 'kit-tools action' {
        It 'is a composite action that outputs the kit folder it was downloaded to' {
            $action.Yaml.ContainsKey('runs') | Should -BeTrue
            $action.Yaml['runs']['using'] | Should -Be 'composite'
            $action.Yaml['outputs'].ContainsKey('path') | Should -BeTrue
            $action.Text | Should -Match 'GITHUB_ACTION_PATH'
        }
    }

    Context '<Name>' -ForEach @(
        @{ Name = 'dotnet-ci.reusable.yml'; File = '.github/workflows/dotnet-ci.reusable.yml' }
        @{ Name = 'app-checks.reusable.yml'; File = '.github/workflows/app-checks.reusable.yml' }
        @{ Name = 'kit-sync.reusable.yml'; File = '.github/workflows/kit-sync.reusable.yml' }
    ) {
        BeforeAll {
            $workflow = Read-Yaml $File
        }

        It 'never runs the calling repo''s ./tools: an app repo has none' {
            $workflow.Text | Should -Not -BeNullOrEmpty
            $workflow.Text | Should -Not -Match '\./tools/'
        }

        It 'gets the kit''s scripts at its own version through $/.github/actions/kit-tools' {
            $kit = @(Get-Steps $workflow.Yaml | Where-Object { "$($_['uses'])" -eq '$/.github/actions/kit-tools' })

            $kit.Count | Should -BeGreaterThan 0
            $kit | ForEach-Object { $_['id'] | Should -Be 'kit' }
            $workflow.Text | Should -Match 'steps\.kit\.outputs\.path'
        }

        # A value from the event pasted into a script could inject commands; values come in through env.
        It 'never pastes a ${{ }} value into a run: script' {
            $runs = @(Get-Steps $workflow.Yaml | Where-Object { $_ -and $_.ContainsKey('run') } | ForEach-Object { $_['run'] })

            $runs.Count | Should -BeGreaterThan 0
            $runs | Should -Not -Match '\$\{\{'
        }

        It 'pins every external action to a full commit SHA (SUP-008)' {
            # Real uses: lines only, not the example calls in the header comments.
            $uses = @([regex]::Matches($workflow.Text, '(?m)^\s*(?:-\s*)?uses: (\S+)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notlike '$/*' })

            $uses | Should -Match '@[0-9a-f]{40}$'
        }
    }

    # GAP-005 (ADR-0036): CodeQL code scanning, free on public repos, through one shared workflow.
    Context 'codeql.reusable.yml' {
        BeforeAll {
            $codeql = Read-Yaml '.github/workflows/codeql.reusable.yml'
            $jobs = if ($codeql.Yaml.ContainsKey('jobs')) { $codeql.Yaml['jobs'] } else { @{} }
        }

        It 'is a shared workflow that scans the workflows always, and C# when the repo has any' {
            $codeql.Text | Should -Not -BeNullOrEmpty -Because 'codeql.reusable.yml runs CodeQL for the kit and its apps'
            $codeql.Text | Should -Match '(?m)^\s*workflow_call:'
            $jobs['languages']['outputs'].ContainsKey('languages') | Should -BeTrue
            $codeql.Text | Should -Match "git ls-files -- '\*\.cs'"
            $codeql.Text | Should -Match '"actions","csharp"'
            $jobs['analyze']['strategy']['matrix']['language'] | Should -Match 'fromJSON\(needs\.languages\.outputs\.languages\)'
        }

        # Review 1 of PR 20: under GitHub's bash -e -o pipefail, `git ls-files | grep -q` can kill git with SIGPIPE
        # on a large repo, and the if then drops C# silently. The step is run here, as CI runs it.
        It 'finds <Expected> in a repo with <Case>, reading git''s whole output' -ForEach @(
            @{ Case = 'no C#'; Files = @('README.md'); Expected = '["actions"]' }
            @{ Case = 'C#'; Files = @('README.md', 'src/App.cs'); Expected = '["actions","csharp"]' }
        ) {
            $step = @($jobs['languages']['steps'] | Where-Object { $_['id'] -eq 'detect' })[0]
            $step['run'] | Should -Not -Match 'ls-files[^\n]*\|' -Because 'a pipe into grep -q can end git with SIGPIPE'
            $repo = Join-Path $TestDrive "langs-$(New-Guid)"
            git init -q $repo
            foreach ($file in $Files) {
                New-Item -ItemType File -Force -Path (Join-Path $repo $file) | Out-Null
                git -C $repo add -- $file
            }
            $output = Join-Path $repo 'github-output'
            Set-Content -LiteralPath (Join-Path $repo 'detect.sh') -Value ($step['run'] -replace "`r`n", "`n") -NoNewline
            # On Windows, Git's own bash: the one on PATH may be WSL's, with no Linux installed.
            $bash = if ($IsWindows) { Join-Path (Split-Path (Split-Path (Get-Command git).Source)) 'bin' 'bash.exe' } else { 'bash' }
            Push-Location $repo
            try { $env:GITHUB_OUTPUT = $output; & $bash --noprofile --norc -e -o pipefail ./detect.sh }
            finally { Pop-Location; Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue }

            $LASTEXITCODE | Should -Be 0
            (Get-Content -Raw -LiteralPath $output).Trim() | Should -Be "languages=$Expected"
        }

        It 'analyzes with the CodeQL action, needing no build, and uploads with only security-events: write' {
            $jobs.ContainsKey('analyze') | Should -BeTrue -Because 'an analyze job runs CodeQL per language'
            $steps = @($jobs['analyze']['steps'])
            $init = @($steps | Where-Object { "$($_['uses'])" -like 'github/codeql-action/init@*' })
            $analyze = @($steps | Where-Object { "$($_['uses'])" -like 'github/codeql-action/analyze@*' })
            $init | Should -HaveCount 1
            $analyze | Should -HaveCount 1
            $init[0]['with']['build-mode'] | Should -Be 'none'
            $jobs['analyze']['permissions']['security-events'] | Should -Be 'write'
            $jobs['analyze']['permissions']['contents'] | Should -Be 'read'
            @($jobs['analyze']['permissions'].Keys | Where-Object { $jobs['analyze']['permissions'][$_] -eq 'write' }) | Should -Be @('security-events')
        }

        It 'runs in <Caller>, with security-events: write for the upload' -ForEach @(
            @{ Caller = 'the kit''s own CI'; File = '.github/workflows/ci.yml'; Uses = './.github/workflows/codeql.reusable.yml'; SkipsPrivate = $false }
            @{ Caller = 'every app''s CI'; File = 'templates/app/.github/workflows/ci.yml'; Uses = 'DerekFoulk/dotnet-agent-kit/.github/workflows/codeql.reusable.yml@X'; SkipsPrivate = $true }
        ) {
            # {{Name}} placeholders aren't YAML.
            $text = (Get-Content -Raw -LiteralPath (Join-Path $root $File)) -replace '\{\{[A-Za-z]+\}\}', 'X'
            $job = (ConvertFrom-Yaml $text)['jobs']['codeql']

            $job | Should -Not -BeNullOrEmpty -Because "$File should have a codeql job"
            $job['uses'] | Should -Be $Uses
            $job['permissions']['security-events'] | Should -Be 'write'
            $job['permissions']['contents'] | Should -Be 'read'
            # Code scanning on a private repo needs GitHub Code Security, a paid licence (ADR-0036).
            if ($SkipsPrivate) { $job['if'] | Should -Match '!\s*github\.event\.repository\.private' }
        }

        It 'pins every action to a full commit SHA and checks out without keeping the token' {
            $uses = @([regex]::Matches($codeql.Text, '(?m)^\s*(?:-\s*)?uses: (\S+)') | ForEach-Object { $_.Groups[1].Value })
            $uses.Count | Should -BeGreaterThan 2
            $uses | Should -Match '@[0-9a-f]{40}$'
            foreach ($job in $jobs.Values) {
                foreach ($step in @($job['steps'] | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })) {
                    $step['with']['persist-credentials'] | Should -BeFalse
                }
            }
        }
    }

    # GAP-014 (SUP-010, ADR-0056): OpenSSF Scorecard, through one shared workflow. Publishing the results needs a
    # workflow that keeps the action's restrictions (github.com/ossf/scorecard-action, "Workflow Restrictions").
    Context 'scorecard.reusable.yml' {
        BeforeAll {
            $scorecard = Read-Yaml '.github/workflows/scorecard.reusable.yml'
            $scJobs = if ($scorecard.Yaml.ContainsKey('jobs')) { $scorecard.Yaml['jobs'] } else { @{} }
            $scJob = @($scJobs.Values)[0]
        }

        It 'is a shared workflow with one job, on Ubuntu, with no env, defaults, container or services' {
            $scorecard.Text | Should -Match '(?m)^\s*workflow_call:' -Because 'scorecard.reusable.yml runs Scorecard for the kit and its apps'
            $scJobs.Count | Should -Be 1
            $scJob['runs-on'] | Should -Be 'ubuntu-latest'
            foreach ($key in 'env', 'defaults') { $scorecard.Yaml.ContainsKey($key) | Should -BeFalse; $scJob.ContainsKey($key) | Should -BeFalse }
            foreach ($key in 'container', 'services') { $scJob.ContainsKey($key) | Should -BeFalse }
        }

        It 'runs only actions the restrictions allow, each pinned to a full commit SHA' {
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
            $steps = @($scJob['steps'])
            $steps.Count | Should -BeGreaterThan 0
            foreach ($step in $steps) {
                $step.ContainsKey('run') | Should -BeFalse
                "$($step['uses'])" | Should -Match '^(actions/checkout|actions/upload-artifact|github/codeql-action/upload-sarif|ossf/scorecard-action|step-security/harden-runner)@[0-9a-f]{40}$'
            }
        }

        It 'publishes the results and uploads them to code scanning as SARIF' {
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
            $steps = @($scJob['steps'])
            $action = @($steps | Where-Object { "$($_['uses'])" -like 'ossf/scorecard-action@*' })
            $upload = @($steps | Where-Object { "$($_['uses'])" -like 'github/codeql-action/upload-sarif@*' })

            $action | Should -HaveCount 1
            $action[0]['with']['publish_results'] | Should -BeTrue
            $action[0]['with']['results_format'] | Should -Be 'sarif'
            $upload | Should -HaveCount 1
            $upload[0]['with']['sarif_file'] | Should -Be $action[0]['with']['results_file']
        }

        It 'has only the permissions the action documents: security-events and id-token, nothing written at workflow level' {
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
            $permissions = $scJob['permissions']
            @($permissions.Keys | Sort-Object) | Should -Be @('id-token', 'security-events')
            $permissions['id-token'] | Should -Be 'write'
            $permissions['security-events'] | Should -Be 'write'
            @($scorecard.Yaml['permissions'].Values) | Should -Not -Contain 'write'
        }

        It 'checks out without keeping the token' {
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
            $checkout = @($scJob['steps'] | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })

            $checkout | Should -HaveCount 1
            $checkout[0]['with']['persist-credentials'] | Should -BeFalse
        }

        It 'runs in <Caller> on main and weekly, never on a pull request, granting only what the job needs' -ForEach @(
            @{ Caller = 'the kit'; File = '.github/workflows/scorecard.yml'; Uses = './.github/workflows/scorecard.reusable.yml'; SkipsPrivate = $false }
            @{ Caller = 'every app'; File = 'templates/app/.github/workflows/scorecard.yml'; Uses = 'DerekFoulk/dotnet-agent-kit/.github/workflows/scorecard.reusable.yml@X'; SkipsPrivate = $true }
        ) {
            $path = Join-Path $root $File
            Test-Path -LiteralPath $path | Should -BeTrue -Because "$File calls the shared Scorecard workflow"
            # {{Name}} placeholders aren't YAML.
            $yaml = ConvertFrom-Yaml ((Get-Content -Raw -LiteralPath $path) -replace '\{\{[A-Za-z]+\}\}', 'X')
            $on = if ($yaml.ContainsKey('on')) { $yaml['on'] } else { $yaml[$true] }
            $job = @($yaml['jobs'].Values)[0]

            @($on['push']['branches']) | Should -Be @('main')
            @($on['schedule']).Count | Should -Be 1
            $on.ContainsKey('pull_request') | Should -BeFalse
            foreach ($key in 'env', 'defaults') { $yaml.ContainsKey($key) | Should -BeFalse }
            @($yaml['permissions'].Values) | Should -Not -Contain 'write'
            $job['uses'] | Should -Be $Uses
            @($job['permissions'].Keys | Sort-Object) | Should -Be @('id-token', 'security-events')
            # Publishing a private repo's results would make them public; its code scanning needs a paid licence.
            if ($SkipsPrivate) { $job['if'] | Should -Match '!\s*github\.event\.repository\.private' }
        }
    }

    Context 'dotnet-ci.reusable.yml input' {
        # An app that left out the solution would get the kit's own default and fail obscurely.
        It 'requires the caller to name its solution, and the kit''s own CI does' {
            $on = if ($dotnet.Yaml.ContainsKey('on')) { $dotnet.Yaml['on'] } elseif ($dotnet.Yaml.ContainsKey($true)) { $dotnet.Yaml[$true] } else { @{} }
            $solution = $on['workflow_call']['inputs']['solution']

            $solution['required'] | Should -BeTrue
            $solution.ContainsKey('default') | Should -BeFalse
            $ci = Read-Yaml '.github/workflows/ci.yml'
            $ci.Yaml['jobs']['dotnet']['with']['solution'] | Should -Be 'dotnet-agent-kit.slnx'
        }
    }

    # GAP-013 (SUP-009, ADR-0055): every build lists what it's made of, as a CycloneDX SBOM.
    Context 'dotnet-ci.reusable.yml SBOM' {
        BeforeAll {
            $steps = @(Get-Steps $dotnet.Yaml)
            $sbomRun = ($steps | Where-Object { "$($_['run'])" -match 'dotnet-CycloneDX' } | ForEach-Object { $_['run'] }) -join "`n"
        }

        It 'pins the CycloneDX .NET tool in the kit''s tool manifest, where Dependabot keeps it current' {
            $manifest = Get-Content -Raw (Join-Path $root '.config/dotnet-tools.json') | ConvertFrom-Json -AsHashtable

            $manifest['tools'].ContainsKey('cyclonedx') | Should -BeTrue -Because 'the manifest pins the CycloneDX tool'
            $manifest['tools']['cyclonedx']['version'] | Should -Match '^\d+\.\d+\.\d+$'
            @($manifest['tools']['cyclonedx']['commands']) | Should -Contain 'dotnet-CycloneDX'
        }

        It 'installs the version the kit''s manifest pins, for this run only' {
            $install = @($steps | Where-Object { "$($_['run'])" -match 'dotnet tool install CycloneDX' })

            $install | Should -HaveCount 1
            $install[0]['run'] | Should -Match '\$env:KIT/\.config/dotnet-tools\.json'
            $install[0]['run'] | Should -Match '--version \$version --tool-path "\$env:RUNNER_TEMP/'
            $install[0]['if'] | Should -Be "steps.projects.outputs.count != '0'"
        }

        It 'lists the solution''s shipped projects as JSON, from the restore already done' {
            $sbomRun | Should -Match '"\$SOLUTION"'
            $sbomRun | Should -Match '--exclude-test-projects'
            $sbomRun | Should -Match '--disable-package-restore'
            $sbomRun | Should -Match '--output-format Json'
            $sbomRun | Should -Match '--filename sbom\.cdx\.json'
        }

        It 'uploads the SBOM as the "sbom" artifact, failing when it''s missing' {
            $upload = @($steps | Where-Object { "$($_['uses'])" -like 'actions/upload-artifact@*' })

            $upload | Should -HaveCount 1
            $upload[0]['with']['name'] | Should -Be 'sbom'
            $upload[0]['with']['if-no-files-found'] | Should -Be 'error'
            $upload[0]['if'] | Should -Be "steps.projects.outputs.count != '0'"
        }
    }

    Context 'app-checks.reusable.yml' {
        BeforeAll {
            $run = (@(Get-Steps $app.Yaml) | Where-Object { $_ -and $_.ContainsKey('run') } | ForEach-Object { $_['run'] }) -join "`n"
        }

        It 'is a shared workflow with a job named "App checks"' {
            $on = if ($app.Yaml.ContainsKey('on')) { $app.Yaml['on'] } elseif ($app.Yaml.ContainsKey($true)) { $app.Yaml[$true] } else { $null }

            @($on.Keys) | Should -Be @('workflow_call')
            @($app.Yaml['jobs'].Values)[0]['name'] | Should -Be 'App checks'
        }

        It 'reads the full history without keeping the token' {
            $checkout = @(Get-Steps $app.Yaml | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })[0]

            $checkout | Should -Not -BeNullOrEmpty
            $checkout['with']['fetch-depth'] | Should -Be 0
            $checkout['with']['persist-credentials'] | Should -BeFalse
        }

        It 'checks the PR title, passed through the environment' {
            $app.Text | Should -Match 'PR_TITLE: \$\{\{ github\.event\.pull_request\.title \}\}'
            $run | Should -Match 'Test-ConventionalTitle\.ps1"? -Title \$env:PR_TITLE'
        }

        It 'checks the PR''s commit subjects and red-to-green order' {
            $run | Should -Match 'Test-ConventionalTitle\.ps1"? -Range \$env:RANGE'
            $run | Should -Match 'Test-RedGreenOrder\.ps1"? -Range \$env:RANGE'
        }

        # Called from another event, the PR steps would all skip and "App checks" would pass having
        # checked nothing (review of PR D1).
        It 'fails when called from an event it can''t check' {
            $guard = @(Get-Steps $app.Yaml | Where-Object { "$($_['if'])" -match "github\.event_name != 'pull_request'" -and "$($_['if'])" -match "github\.event_name != 'push'" })

            $guard.Count | Should -Be 1
            $guard[0]['run'] | Should -Match 'exit 1'
        }

        It 'checks ADR sections in the app''s own docs/adr, when it has one' {
            $run | Should -Match 'Test-AdrSections\.ps1"? -AdrPath'
            $run | Should -Match 'docs/adr'
        }

        # Every app gets docs/runbook.md, so a missing one fails rather than skipping the check (OPS-004).
        It 'checks the app''s runbook on every run, failing when it''s missing' {
            $step = @(Get-Steps $app.Yaml | Where-Object { "$($_['run'])" -match 'Test-Runbook\.ps1' })

            $step.Count | Should -Be 1
            $step[0]['run'] | Should -Match 'Test-Runbook\.ps1"? -Path'
            $step[0]['run'] | Should -Match 'docs/runbook\.md'
            $step[0]['run'] | Should -Not -Match 'Test-Path'
            $step[0].ContainsKey('if') | Should -BeFalse
        }
    }
}
