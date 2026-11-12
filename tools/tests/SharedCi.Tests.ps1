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

    # ADR-0059: Linux can't build MAUI or desktop (UI) projects. A small job finds them; a matrix job builds the whole
    # solution on the runners they need, with the workload set pinned; the required job waits for it.
    Context 'dotnet-ci.reusable.yml UI builds' {
        BeforeAll {
            $jobs = if ($dotnet.Yaml.ContainsKey('jobs')) { $dotnet.Yaml['jobs'] } else { @{} }
            function Get-JobStep($Job, [string] $Name) {
                $step = if ($Job) { @($Job['steps'] | Where-Object { $_['name'] -eq $Name })[0] }
                $step | Should -Not -BeNullOrEmpty -Because "the job should have a step named '$Name'"
                $step
            }

            # A solution in its own folder: a plain project, then one project per UI property given (src/Ui<n>).
            function New-StepSolution([string[]] $Properties) {
                $dir = Join-Path $TestDrive "step-$(New-Guid)"
                $entries = @('<Project Path="src/Core/Core.csproj" />')
                New-Item -ItemType Directory -Force -Path (Join-Path $dir 'src/Core') | Out-Null
                '<Project Sdk="Microsoft.NET.Sdk" />' | Set-Content -LiteralPath (Join-Path $dir 'src/Core/Core.csproj')
                for ($i = 0; $i -lt $Properties.Count; $i++) {
                    New-Item -ItemType Directory -Force -Path (Join-Path $dir "src/Ui$i") | Out-Null
                    "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup>$($Properties[$i])</PropertyGroup></Project>" | Set-Content -LiteralPath (Join-Path $dir "src/Ui$i/Ui$i.csproj")
                    $entries += "<Project Path=`"src/Ui$i/Ui$i.csproj`" />"
                }
                "<Solution>$($entries -join '')</Solution>" | Set-Content -LiteralPath (Join-Path $dir 'App.slnx')
                Join-Path $dir 'App.slnx'
            }

            # Runs a pwsh step's script as CI does, with the given environment, and puts back what was there before.
            function Invoke-Step([string] $Run, [hashtable] $Environment) {
                $script = Join-Path $TestDrive "step-$(New-Guid).ps1"
                Set-Content -LiteralPath $script -Value $Run
                $saved = @{}
                foreach ($name in $Environment.Keys) {
                    $saved[$name] = [Environment]::GetEnvironmentVariable($name)
                    [Environment]::SetEnvironmentVariable($name, $Environment[$name])
                }
                try {
                    $output = & pwsh -NoProfile -File $script 2>&1 | Out-String
                    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
                }
                finally {
                    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
                }
            }
        }

        It 'finds the UI projects with the kit''s script and outputs their runners as a JSON list' {
            $jobs.ContainsKey('ui-projects') | Should -BeTrue -Because 'a ui-projects job finds the UI projects'
            $find = Get-JobStep $jobs['ui-projects'] 'Find UI projects'
            $find['run'] | Should -Match '\$env:KIT/tools/Get-UiProject\.ps1" -Solution \$env:SOLUTION'
            $find['run'] | Should -Match 'ConvertTo-Json -Compress -InputObject '
            $jobs['ui-projects']['outputs']['os'] | Should -Be "`${{ steps.$($find['id']).outputs.os }}"
        }

        # Review 2: -AsArray with -InputObject wrapped the list in another array, so the ui job ran with a runner
        # label nobody has and the required job never started. The step is run here, as CI runs it.
        It 'outputs os=<Expected> for a solution with <Case>' -ForEach @(
            @{ Case = 'no UI project'; Properties = @(); Expected = '[]' }
            @{ Case = 'a WPF project'; Properties = @('<UseWPF>true</UseWPF>'); Expected = '["windows-latest"]' }
            @{ Case = 'a MAUI and a WPF project'; Properties = @('<UseMaui>true</UseMaui>', '<UseWPF>true</UseWPF>'); Expected = '["windows-latest","macos-latest"]' }
        ) {
            $find = Get-JobStep $jobs['ui-projects'] 'Find UI projects'
            $solution = New-StepSolution $Properties
            $output = Join-Path (Split-Path $solution) 'github-output'

            $result = Invoke-Step $find['run'] @{ KIT = $root; SOLUTION = $solution; GITHUB_OUTPUT = $output }

            $result.ExitCode | Should -Be 0 -Because $result.Output
            (Get-Content -Raw -LiteralPath $output).Trim() | Should -Be "os=$Expected"
        }

        # Review 3: a mutant that dropped -Runner from the script's own entry point survived every test, and both
        # runners would then have built no UI project at all. The step is run here, as CI runs it.
        It 'writes a filter with the UI projects <Runner> builds, run as CI runs it' -ForEach @(
            @{ Runner = 'macos-latest'; Expected = @('src/Core/Core.csproj', 'src/Ui0/Ui0.csproj') }
            @{ Runner = 'windows-latest'; Expected = @('src/Core/Core.csproj', 'src/Ui0/Ui0.csproj', 'src/Ui1/Ui1.csproj') }
        ) {
            $step = Get-JobStep $jobs['ui'] 'Solution filter'
            $solution = New-StepSolution @('<UseMaui>true</UseMaui>', '<UseWPF>true</UseWPF>')
            $dir = Split-Path $solution
            $githubEnv = Join-Path $dir 'github-env'

            $result = Invoke-Step $step['run'] @{ KIT = $root; SOLUTION = $solution; RUNNER_LABEL = $Runner; RUNNER_TEMP = $dir; GITHUB_ENV = $githubEnv }

            $result.ExitCode | Should -Be 0 -Because $result.Output
            $filter = (@(Get-Content -LiteralPath $githubEnv) -match '^FILTER=') -replace '^FILTER=', ''
            (Get-Content -Raw -LiteralPath $filter | ConvertFrom-Json).solution.projects | Should -Be $Expected
        }

        It 'builds on each of those runners, and is skipped when there are none (an empty matrix would fail the run)' {
            $ui = $jobs['ui']
            $ui | Should -Not -BeNullOrEmpty
            $ui['needs'] | Should -Be 'ui-projects'
            $ui['if'] | Should -Be "needs.ui-projects.outputs.os != '[]'"
            $ui['strategy']['matrix']['os'] | Should -Be '${{ fromJSON(needs.ui-projects.outputs.os) }}'
            $ui['strategy']['fail-fast'] | Should -BeFalse
            $ui['runs-on'] | Should -Be '${{ matrix.os }}'
            @($ui['steps'] | Where-Object { "$($_['uses'])" -like 'actions/checkout@*' })[0]['with']['persist-credentials'] | Should -BeFalse
        }

        # Review 2: each runner builds only what it can. An app with a MAUI client and a WPF tool would fail on macOS
        # building the WPF one (NETSDK1100), so each runner works on a filter: every project but the UI ones it
        # doesn't build. On Windows, that's the whole solution.
        It 'works on a filter of the projects its runner can build' {
            $ui = $jobs['ui']
            $ui['env']['RUNNER_LABEL'] | Should -Be '${{ matrix.os }}'
            $ui['env'].ContainsKey('EnableWindowsTargeting') | Should -BeFalse -Because 'macOS no longer builds Windows-only projects'
            $filter = Get-JobStep $ui 'Solution filter'
            $filter['run'] | Should -Match 'Get-UiProject\.ps1" -Solution \$env:SOLUTION -FilterPath \$filter -Runner \$env:RUNNER_LABEL'
            $filter['run'] | Should -Match 'FILTER=\$filter" >> \$env:GITHUB_ENV'
        }

        # SUP-011: the workload set whose version is the SDK's own, so a build never picks up the latest workloads.
        It 'restores the workloads of the UI projects it builds, at the workload set of the SDK in use, never unpinned' {
            $restore = Get-JobStep $jobs['ui'] 'Restore workloads (pinned)'
            $restore['run'] | Should -Match 'Where-Object \{ \$_\.Os -contains \$env:RUNNER_LABEL \}'
            # Review 3: the full path, since CI runs from the repo root and the solution may sit in a subfolder.
            $restore['run'] | Should -Match 'dotnet workload restore \$project\.FullPath --version \$version'
            $restore['run'] | Should -Match '\$version = dotnet --version'
            $dotnet.Text | Should -Not -Match 'dotnet workload (install|update)'
        }

        It 'restores locked on Windows; on macOS restores, then checks each lock file against the committed one' {
            $windows = Get-JobStep $jobs['ui'] 'Restore (locked)'
            $windows['if'] | Should -Be "runner.os == 'Windows'"
            $windows['run'] | Should -Be 'dotnet restore $env:FILTER --locked-mode'
            $mac = Get-JobStep $jobs['ui'] 'Restore (macOS)'
            $mac['if'] | Should -Be "runner.os == 'macOS'"
            $mac['run'] | Should -Be 'dotnet restore $env:FILTER -p:RestoreLockedMode=false'
            $subset = Get-JobStep $jobs['ui'] 'Lock files match the committed ones'
            $subset['if'] | Should -Be "runner.os == 'macOS'"
            $subset['run'] | Should -Match '\$env:KIT/tools/Test-LockFileSubset\.ps1" -RepoRoot \$env:GITHUB_WORKSPACE'
        }

        It 'builds its filter with zero warnings, and on Windows checks its format and deprecated packages' {
            (Get-JobStep $jobs['ui'] 'Build (zero warnings)')['run'] | Should -Be 'dotnet build $env:FILTER --no-restore --configuration Release -warnaserror'
            $format = Get-JobStep $jobs['ui'] 'Format check'
            $format['if'] | Should -Be "runner.os == 'Windows'"
            $format['run'] | Should -Be 'dotnet format $env:FILTER --verify-no-changes --no-restore'
            $deprecated = Get-JobStep $jobs['ui'] 'Deprecated packages'
            $deprecated['if'] | Should -Be "runner.os == 'Windows'"
            $deprecated['run'] | Should -Match 'Test-DeprecatedPackages\.ps1" -Path \$env:FILTER'
        }

        # The code shape check (CRF-011) evaluates every project with MSBuild, and a MAUI project doesn't evaluate on
        # Linux, which has no workloads. So with UI projects it runs on Windows, over the whole solution; without, on
        # Linux as before. Either way the required job gates it.
        It 'checks code shape on Linux only without UI projects, and on Windows over the whole solution with them' {
            $count = Get-JobStep $jobs['dotnet'] 'Count projects'
            $count['run'] | Should -Match '"ui=\$\(\$ui\.Count\)" >> \$env:GITHUB_OUTPUT'
            $linux = Get-JobStep $jobs['dotnet'] 'Code shape'
            $linux['if'] | Should -Be "steps.projects.outputs.count != '0' && steps.projects.outputs.ui == '0'"
            $windows = Get-JobStep $jobs['ui'] 'Code shape'
            $windows['if'] | Should -Be "runner.os == 'Windows'"
            $windows['run'] | Should -Match 'Test-CodeShape\.ps1" -Solution \$env:SOLUTION'
        }

        # The duplicate code check (CRF-003) lists each project's files through the same MSBuild evaluation, so it
        # follows code shape: on Windows with UI projects, on Linux without. One PMD release and digest for both.
        It 'checks duplicate code on Linux only without UI projects, and on Windows over the whole solution with them' {
            $linuxOnly = "steps.projects.outputs.count != '0' && steps.projects.outputs.ui == '0'"
            (Get-JobStep $jobs['dotnet'] 'Download PMD')['if'] | Should -Be $linuxOnly
            (Get-JobStep $jobs['dotnet'] 'Duplicate code')['if'] | Should -Be $linuxOnly
            $download = Get-JobStep $jobs['ui'] 'Download PMD'
            $download['if'] | Should -Be "runner.os == 'Windows'"
            $download['run'] | Should -Match 'Get-FileHash'
            # Review 6: a hash mismatch must stop the job, and Windows runs PMD's batch launcher.
            $download['run'] | Should -Match 'if \(\$hash -ne \$env:PMD_SHA256\) \{\s+"::error::[^"]+"\s+exit 1\s+\}'
            $download['run'] | Should -Match 'bin/pmd\.bat"\)" >> \$env:GITHUB_ENV'
            $windows = Get-JobStep $jobs['ui'] 'Duplicate code'
            $windows['if'] | Should -Be "runner.os == 'Windows'"
            $windows['run'] | Should -Match 'Test-Duplication\.ps1" -Solution \$env:SOLUTION -Pmd \$env:PMD'
            foreach ($step in @((Get-JobStep $jobs['dotnet'] 'Download PMD'), $download)) { $step.Contains('env') -and $step['env'].Contains('PMD_VERSION') | Should -BeFalse }
            $dotnet.Yaml['env']['PMD_VERSION'] | Should -Match '^\d+\.\d+\.\d+$'
            $dotnet.Yaml['env']['PMD_SHA256'] | Should -Match '^[0-9a-f]{64}$'
        }

        # The SBOM (SUP-009) lists the shipped projects through MSBuild too, and must include the UI app, which ships.
        # So with UI projects the Windows leg writes it, after restoring the whole solution; the steps are the Linux
        # job's, word for word, so the SBOM is made one way.
        It 'writes the SBOM on Windows over the whole solution when there are UI projects, with the Linux job''s steps' {
            foreach ($name in 'Install CycloneDX', 'Write the SBOM', 'Upload the SBOM') {
                $linux = Get-JobStep $jobs['dotnet'] $name
                $windows = Get-JobStep $jobs['ui'] $name
                $windows['if'] | Should -Be "runner.os == 'Windows'" -Because "'$name' runs on the Windows leg only"
                # Review 7: after the locked restore, whose assets CycloneDX's --disable-package-restore reads.
                $names = @($jobs['ui']['steps'] | ForEach-Object { $_['name'] })
                $names.IndexOf($name) | Should -BeGreaterThan $names.IndexOf('Restore (locked)') -Because "'$name' needs the restore's assets"
                foreach ($key in 'shell', 'env', 'run', 'uses', 'with') {
                    ($windows[$key] | ConvertTo-Json -Depth 5) | Should -Be ($linux[$key] | ConvertTo-Json -Depth 5) -Because "'$name' has the Linux job's $key"
                }
            }
        }

        # The ruleset requires "dotnet / Build, test and package checks" by name (templates/github/main-protection.json),
        # so that job waits for the UI builds and fails when they did: a required check can't be weakened by them.
        It 'keeps the required job''s name, and has it wait for the UI builds unless the run was cancelled' {
            $required = $jobs['dotnet']
            $required['name'] | Should -Be 'Build, test and package checks'
            @($required['needs']) | Should -Be @('ui-projects', 'ui')
            $required['if'] | Should -Be '${{ !cancelled() }}'
            $check = Get-JobStep $required 'UI projects built'
            $check['if'] | Should -Be '${{ !cancelled() }}'
            $check['env']['FIND'] | Should -Be '${{ needs.ui-projects.result }}'
            $check['env']['UI'] | Should -Be '${{ needs.ui.result }}'
            $check['env']['OS'] | Should -Be '${{ needs.ui-projects.outputs.os }}'
        }

        # One path for every app: the kit's own CI runs it on each pull request. The coverage gate still reads the
        # whole solution, so it can tell a UI project (exempt) from a project no test loads (a failure).
        It 'builds, formats, tests and checks packages on Linux through a filter of every project but the UI ones' {
            $required = $jobs['dotnet']
            $count = Get-JobStep $required 'Count projects'
            $count['run'] | Should -Match 'Get-UiProject\.ps1" -Solution \$env:SOLUTION -FilterPath \$filter'
            $count['run'] | Should -Match 'FILTER=\$filter" >> \$env:GITHUB_ENV'
            $count['run'] | Should -Match 'Get-SolutionProjectCount\.ps1" -Solution \$env:SOLUTION\) - \$ui\.Count'
            (Get-JobStep $required 'Restore (locked)')['run'] | Should -Be 'dotnet restore "$FILTER" --locked-mode'
            (Get-JobStep $required 'Build (zero warnings)')['run'] | Should -Match '^dotnet build "\$FILTER" '
            (Get-JobStep $required 'Format check')['run'] | Should -Match '^dotnet format "\$FILTER" '
            (Get-JobStep $required 'Test with coverage')['run'] | Should -Match '^dotnet test --solution "\$FILTER" '
            (Get-JobStep $required 'Coverage gate')['run'] | Should -Match '-Solution \$env:SOLUTION'
            (Get-JobStep $required 'Deprecated packages')['run'] | Should -Match '-Path \$env:FILTER'
        }

        It 'passes the required job only when the UI builds <Case>' -ForEach @(
            @{ Case = 'succeeded'; Find = 'success'; Ui = 'success'; Os = '["windows-latest","macos-latest"]'; Exit = 0 }
            @{ Case = 'were skipped because there are no UI projects'; Find = 'success'; Ui = 'skipped'; Os = '[]'; Exit = 0 }
            @{ Case = 'failed: not when one leg failed'; Find = 'success'; Ui = 'failure'; Os = '["windows-latest"]'; Exit = 1 }
            @{ Case = 'were cancelled: not then'; Find = 'success'; Ui = 'cancelled'; Os = '["windows-latest"]'; Exit = 1 }
            @{ Case = 'were skipped though there are UI projects: not then'; Find = 'success'; Ui = 'skipped'; Os = '["windows-latest"]'; Exit = 1 }
            @{ Case = 'never ran because finding them failed: not then'; Find = 'failure'; Ui = 'skipped'; Os = ''; Exit = 1 }
        ) {
            $check = Get-JobStep $jobs['dotnet'] 'UI projects built'
            $check['shell'] | Should -Be 'pwsh'
            $script = Join-Path $TestDrive "ui-check-$(New-Guid).ps1"
            Set-Content -LiteralPath $script -Value $check['run']
            $env:FIND = $Find; $env:UI = $Ui; $env:OS = $Os
            try { & pwsh -NoProfile -File $script *> $null }
            finally { Remove-Item Env:FIND, Env:UI, Env:OS -ErrorAction SilentlyContinue }

            $LASTEXITCODE | Should -Be $Exit
        }
    }

    # GAP-013 (SUP-009, ADR-0055): every build lists what it's made of, as a CycloneDX SBOM.
    Context 'dotnet-ci.reusable.yml SBOM' {
        BeforeAll {
            # The Linux job's steps. With UI projects the ui job writes the SBOM instead, with the same steps (ADR-0059),
            # which the UI builds context checks against these.
            $steps = @($dotnet.Yaml['jobs']['dotnet']['steps'])
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

        It 'runs every SBOM step only once the solution has projects, and on Linux only without UI projects' {
            $sbomSteps = @($steps | Where-Object { "$($_['run'])" -match 'CycloneDX' -or "$($_['uses'])" -like 'actions/upload-artifact@*' })

            $sbomSteps | Should -HaveCount 3
            foreach ($step in $sbomSteps) { $step['if'] | Should -Be "steps.projects.outputs.count != '0' && steps.projects.outputs.ui == '0'" }
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
