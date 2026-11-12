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
            # The restrictions apply to the job that runs the action; the visibility job only reads the API.
            $scName = @($scJobs.Keys | Where-Object { @($scJobs[$_]['steps'] | Where-Object { "$($_['uses'])" -like 'ossf/scorecard-action@*' }).Count -gt 0 })[0]
            $scJob = if ($scName) { $scJobs[$scName] } else { $null }

            # Review of PR 48: `write-all` is a string, with no .Values to search, so check the shape itself.
            function Assert-ReadOnly($Permissions, [string] $Where) {
                $Permissions | Should -BeOfType ([System.Collections.IDictionary]) -Because "$Where's permissions name each scope, with no write-all"
                foreach ($value in $Permissions.Values) { $value | Should -BeIn @('read', 'none') -Because "$Where writes nothing at workflow level" }
            }
        }

        It 'is a shared workflow whose Scorecard job runs on Ubuntu, with no env, defaults, container or services' {
            $scorecard.Text | Should -Match '(?m)^\s*workflow_call:' -Because 'scorecard.reusable.yml runs Scorecard for the kit and its apps'
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
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
            Assert-ReadOnly $scorecard.Yaml['permissions'] 'scorecard.reusable.yml'
            # Review 2 of PR 48: a job's `write-all` would include id-token, so the other jobs get no permission at all.
            foreach ($name in @($scJobs.Keys | Where-Object { $_ -ne $scName })) {
                $other = $scJobs[$name]['permissions']
                $other | Should -BeOfType ([System.Collections.IDictionary]) -Because "$name names its permissions, with no write-all"
                $other.Count | Should -Be 0 -Because "$name only reads the repo's metadata, which every token can"
            }
        }

        # Review 2 of PR 48: a wrong step id empties the output, and Scorecard would skip every repo with a green run.
        It 'passes the visibility on from the step that reads it, and fails the run when the API call fails' -ForEach @(
            @{ Case = 'a public repo'; Gh = 'echo false'; Exit = 0; Expected = 'private=false' }
            @{ Case = 'a private repo'; Gh = 'echo true'; Exit = 0; Expected = 'private=true' }
            @{ Case = 'a failed API call'; Gh = 'exit 1'; Exit = 1; Expected = '' }
        ) {
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
            $visibility = $scJobs[@($scJob['needs'])[0]]
            $step = @($visibility['steps'] | Where-Object { "$($_['run'])" -match 'gh api' })[0]
            $visibility['outputs']['private'] | Should -Be "`${{ steps.$($step['id']).outputs.private }}"
            $step['env']['GH_TOKEN'] | Should -Be '${{ github.token }}'

            $dir = Join-Path $TestDrive "visibility-$(New-Guid)"
            New-Item -ItemType Directory -Path (Join-Path $dir 'bin') | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'bin' 'gh') -Value "#!/usr/bin/env bash`n$Gh" -NoNewline
            Set-Content -LiteralPath (Join-Path $dir 'step.sh') -Value ($step['run'] -replace "`r`n", "`n") -NoNewline
            $output = Join-Path $dir 'github-output'
            New-Item -ItemType File -Path $output | Out-Null
            # On Windows, Git's own bash: the one on PATH may be WSL's, with no Linux installed.
            $bash = if ($IsWindows) { Join-Path (Split-Path (Split-Path (Get-Command git).Source)) 'bin' 'bash.exe' } else { 'bash' }
            Push-Location $dir
            try {
                $env:GITHUB_OUTPUT = $output; $env:REPO = 'owner/app'
                & $bash --noprofile --norc -e -c 'chmod +x bin/gh; PATH="$PWD/bin:$PATH" bash -e ./step.sh'
            }
            finally { Pop-Location; Remove-Item Env:GITHUB_OUTPUT, Env:REPO -ErrorAction SilentlyContinue }

            ($LASTEXITCODE -ne 0) | Should -Be ($Exit -ne 0) -Because "the step should $(if ($Exit) { 'fail' } else { 'pass' }) for $Case"
            "$(Get-Content -Raw -LiteralPath $output)".Trim() | Should -Be $Expected
        }

        # Review of PR 48: a scheduled run's event carries no repository, so github.event.repository.private is empty
        # there and an `if` on it lets a private repo's weekly run through. The API answers on every trigger.
        It 'skips a private repo on every trigger, asking the API for its visibility' {
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
            $needs = @($scJob['needs'] | Where-Object { $_ })
            $needs | Should -HaveCount 1
            $visibility = $scJobs[$needs[0]]
            $step = @($visibility['steps'] | Where-Object { "$($_['run'])" -match 'gh api' })

            $step | Should -HaveCount 1
            $step[0]['run'] | Should -Match 'gh api "repos/\$REPO" --jq \.private'
            $step[0]['env']['REPO'] | Should -Be '${{ github.repository }}'
            $step[0]['run'] | Should -Not -Match '\$\{\{'
            $scJob['if'] | Should -Be "needs.$($needs[0]).outputs.private == 'false'"
            $scorecard.Text | Should -Not -Match 'github\.event\.repository\.private'
        }

        It 'checks out without keeping the token' {
            $scJob | Should -Not -BeNullOrEmpty -Because 'scorecard.reusable.yml has a Scorecard job'
            $checkout = @($scJob['steps'] | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })

            $checkout | Should -HaveCount 1
            $checkout[0]['with']['persist-credentials'] | Should -BeFalse
        }

        It 'runs in <Caller> on main and weekly, never on a pull request, granting only what the job needs' -ForEach @(
            @{ Caller = 'the kit'; File = '.github/workflows/scorecard.yml'; Uses = './.github/workflows/scorecard.reusable.yml' }
            @{ Caller = 'every app'; File = 'templates/app/.github/workflows/scorecard.yml'; Uses = 'DerekFoulk/dotnet-agent-kit/.github/workflows/scorecard.reusable.yml@X' }
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
            Assert-ReadOnly $yaml['permissions'] $File
            $job['uses'] | Should -Be $Uses
            @($job['permissions'].Keys | Sort-Object) | Should -Be @('id-token', 'security-events')
            # The first run on main failed to start (PR 48): GitHub refuses a called workflow that asks, at its top or
            # in a job, for a permission its caller's job doesn't grant ("requesting 'contents: read', but is only
            # allowed 'contents: none'").
            $rank = @{ none = 0; read = 1; write = 2 }
            foreach ($asked in @(@($scorecard.Yaml['permissions']) + @($scJobs.Values | ForEach-Object { $_['permissions'] }))) {
                foreach ($scope in @($asked.Keys)) {
                    $granted = if ($job['permissions'].Contains($scope)) { $job['permissions'][$scope] } else { 'none' }
                    $rank.ContainsKey($asked[$scope]) -and $rank.ContainsKey($granted) | Should -BeTrue -Because "'$($asked[$scope])' and '$granted' are permission levels"
                    $rank[$granted] | Should -BeGreaterOrEqual $rank[$asked[$scope]] -Because "scorecard.reusable.yml asks for '${scope}: $($asked[$scope])', and $File grants '${scope}: $granted'"
                }
            }
            # The shared workflow skips a private repo itself, on every trigger.
            $job.ContainsKey('if') | Should -BeFalse
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

        # A project scaffolded before anything needed it fails the kit's CI and every app's (ARC-009).
        It 'checks the solution for empty projects, with the solution passed through the environment' {
            $step = @(Get-Steps $dotnet.Yaml | Where-Object { "$($_['run'])" -match 'Test-EmptyProjects\.ps1' })

            $step.Count | Should -Be 1
            $step[0]['run'] | Should -Match '\$env:KIT/tools/Test-EmptyProjects\.ps1"? -Solution \$env:SOLUTION'
            $step[0]['shell'] | Should -Be 'pwsh'
            $step[0]['env']['KIT'] | Should -Be '${{ steps.kit.outputs.path }}'
            $step[0].ContainsKey('if') | Should -BeFalse
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
            $install[0]['run'] | Should -Match '\.tools\.cyclonedx\.version'
            $install[0]['run'] | Should -Match '--version \$version --tool-path "\$env:RUNNER_TEMP/'
        }

        # Review of PR 48: CycloneDX's --exclude-test-projects reads only each .csproj, so it misses a test project that
        # Directory.Build.props marks, as the kit's and every app's are. MSBuild decides instead, in the kit's script.
        It 'lists the shipped projects MSBuild names, as JSON, from the restore already done' {
            $sbomRun | Should -Match '\$filter = & "\$env:KIT/tools/New-ShippedSolutionFilter\.ps1" -Solution \$env:SOLUTION'
            # Review 2 of PR 48: CycloneDX reads that filter, not the solution.
            $sbomRun | Should -Match '/dotnet-CycloneDX" \$filter '
            $sbomRun | Should -Not -Match '--exclude-test-projects' -Because 'the filter already leaves the test projects out'
            $sbomRun | Should -Match '--disable-package-restore'
            $sbomRun | Should -Match '--output-format Json'
            $sbomRun | Should -Match '--filename sbom\.cdx\.json'
        }

        It 'runs every SBOM step only once the solution has projects' {
            $sbomSteps = @($steps | Where-Object { "$($_['run'])" -match 'CycloneDX' -or "$($_['uses'])" -like 'actions/upload-artifact@*' })

            $sbomSteps | Should -HaveCount 3
            foreach ($step in $sbomSteps) { $step['if'] | Should -Be "steps.projects.outputs.count != '0'" }
        }

        It 'uploads the SBOM it wrote as the "sbom" artifact, failing when it''s missing' {
            $upload = @($steps | Where-Object { "$($_['uses'])" -like 'actions/upload-artifact@*' })
            $output = [regex]::Match($sbomRun, '--output "([^"]+)"').Groups[1].Value -replace '\$env:RUNNER_TEMP', '${{ runner.temp }}'

            $upload | Should -HaveCount 1
            $upload[0]['with']['name'] | Should -Be 'sbom'
            $upload[0]['with']['if-no-files-found'] | Should -Be 'error'
            $output | Should -Not -BeNullOrEmpty
            $upload[0]['with']['path'] | Should -Be "$output/sbom.cdx.json"
        }
    }

    # GAP-023 (ADR-0060): PMD's version is in the kit's .config/pmd/pom.xml, where Dependabot moves it, and the zip's
    # SHA-256 beside it. An app's CI runs this workflow at its kit pin, so it reads the kit's copy ($env:KIT), never
    # the app's workspace, which has none.
    Context 'dotnet-ci.reusable.yml PMD' {
        BeforeAll {
            $download = @(Get-Steps $dotnet.Yaml | Where-Object { $_['name'] -eq 'Download PMD' })
        }

        It "pins PMD in the kit's own manifest, consistently" {
            Import-Module (Join-Path $root 'tools' 'KitPmd.psm1') -Force

            $pin = Get-PmdPin -Path (Join-Path $root '.config' 'pmd')

            $pin.Version | Should -Match '^\d+\.\d+\.\d+$'
        }

        It "reads PMD's version and SHA-256 from the kit's pin, through KitPmd.psm1" {
            $download | Should -HaveCount 1
            $download[0]['shell'] | Should -Be 'pwsh'
            $download[0]['env']['KIT'] | Should -Be '${{ steps.kit.outputs.path }}'
            $download[0]['run'] | Should -Match 'Import-Module "\$env:KIT/tools/KitPmd\.psm1"'
            $download[0]['run'] | Should -Match '\$pin = Get-PmdPin -Path "\$env:KIT/\.config/pmd"'
        }

        It 'holds no PMD version or hash of its own' {
            $download[0].ContainsKey('env') | Should -BeTrue
            @($download[0]['env'].Keys) | Should -Be @('KIT')
            $download[0]['run'] | Should -Not -Match '[0-9a-f]{64}'
            $download[0]['run'] | Should -Not -Match '\d+\.\d+\.\d+'
        }

        It 'downloads the URL the pin names, checks it against the pin file, and stops on any failed command' {
            $download[0]['run'] | Should -Match '\$PSNativeCommandUseErrorActionPreference = \$true'
            $download[0]['run'] | Should -Match 'curl --fail .*\$pin\.Url'
            $download[0]['run'] | Should -Match 'sha256sum --check --strict \$pin\.PinFile'
            $download[0]['if'] | Should -Be "steps.projects.outputs.count != '0'"
        }
    }

    # GAP-023 (ADR-0060): the gitleaks image is pinned by tag and digest in the kit's .config/gitleaks/Dockerfile, where
    # Dependabot's docker updater moves both. The job keeps its name: the ruleset requires "Secret scan (gitleaks)".
    Context 'dotnet-ci.reusable.yml secret scan' {
        BeforeAll {
            $secrets = $dotnet.Yaml['jobs']['secrets']
            $scan = @(@($secrets['steps']) | Where-Object { "$($_['run'])" -match 'docker run' })
            $dockerfile = Get-Content -LiteralPath (Join-Path $root '.config' 'gitleaks' 'Dockerfile')
        }

        It "pins the image in the kit's Dockerfile: one FROM line, by tag and digest, and nothing else" {
            $instructions = @($dockerfile | Where-Object { $_ -notmatch '^\s*(#|$)' })

            $instructions | Should -HaveCount 1
            $instructions[0] | Should -Match '^FROM ghcr\.io/gitleaks/gitleaks:v\d+\.\d+\.\d+@sha256:[0-9a-f]{64}$'
        }

        It 'runs the image the kit''s Dockerfile names, requiring its tag and digest, and names none itself' {
            $secrets['name'] | Should -Be 'Secret scan (gitleaks)'
            @(@($secrets['steps']) | Where-Object { "$($_['uses'])" -eq '$/.github/actions/kit-tools' }) | Should -HaveCount 1
            $scan | Should -HaveCount 1
            $scan[0]['env']['KIT'] | Should -Be '${{ steps.kit.outputs.path }}'
            $scan[0]['run'] | Should -Match '"\$KIT/\.config/gitleaks/Dockerfile"'
            $scan[0]['run'] | Should -Match ([regex]::Escape('@sha256:[0-9a-f]{64}'))
            $scan[0]['run'] | Should -Match '"\$image" git /repo --redact --verbose'
            # The step's pattern names the image too, but no tag: v[0-9]+, never v8.
            $dotnet.Text | Should -Not -Match 'gitleaks/gitleaks:v\d' -Because 'the Dockerfile is the one pin'
        }
    }

    Context 'app-checks.reusable.yml' {
        BeforeAll {
            $run =(@(Get-Steps $app.Yaml) | Where-Object { $_ -and $_.ContainsKey('run') } | ForEach-Object { $_['run'] }) -join "`n"
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
