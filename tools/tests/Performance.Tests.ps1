#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# GAP-012, ADR-0062: hot paths get BenchmarkDotNet benchmarks with a budget, and an app with an HTTP endpoint gets a
# Locust load test with a budget. These tests check the kit's files that set that up: the build settings for a
# benchmarks project, the sample's benchmarks and load test, the pinned Locust, and the performance workflows.

Describe 'Performance tests (GAP-012)' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Read-Yaml([string] $RelativePath) {
            $path = Join-Path $root $RelativePath
            $text = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
            [pscustomobject]@{ Text = $text; Yaml = if ($text) { ConvertFrom-Yaml $text } else { @{} } }
        }

        # The steps of one job, or none when the workflow or job is missing.
        function Get-JobStep($Yaml, [string] $Job) {
            if (-not $Yaml.ContainsKey('jobs') -or -not $Yaml['jobs'].ContainsKey($Job)) { return @() }
            @($Yaml['jobs'][$Job]['steps'])
        }

        function Find-Step([object[]] $Steps, [string] $Name) {
            # The comma keeps a one-step result a list, so callers can index it.
            , @($Steps | Where-Object { $_ -and "$($_['name'])" -eq $Name })
        }

        # The solution's benchmarks projects, found as the coverage gate, the SBOM filter and the workflow find them.
        Import-Module (Join-Path $root 'tools' 'KitSolution.psm1') -Force
        $script:BenchmarkProjects = @(Get-SolutionProject -Solution (Join-Path $root 'dotnet-agent-kit.slnx') |
                ForEach-Object Path |
                Where-Object { Test-BenchmarksProject -Name ([IO.Path]::GetFileNameWithoutExtension($_)) })
    }

    Context 'benchmarks projects' {
        It 'has the sample''s benchmarks project in the solution' {
            $script:BenchmarkProjects | Should -Contain 'sample/tests/Bookmarks.Benchmarks/Bookmarks.Benchmarks.csproj'
        }

        # sample/Directory.Build.props is an app's tests/Directory.Build.props (ADR-0032), so an app's benchmarks
        # project gets the same. Not a test project: dotnet test would try to run it.
        It 'makes <Project> an Exe that references BenchmarkDotNet, and not a test project' -ForEach @(
            @{ Project = 'sample/tests/Bookmarks.Benchmarks/Bookmarks.Benchmarks.csproj' }
        ) {
            $path = Join-Path $root $Project
            $path | Should -Exist
            $json = dotnet msbuild $path -nologo -getProperty:OutputType -getProperty:IsTestProject -getProperty:IsPackable -getItem:PackageReference | ConvertFrom-Json

            $json.Properties.OutputType | Should -Be 'Exe'
            $json.Properties.IsTestProject | Should -Not -Be 'true'
            $json.Properties.IsPackable | Should -Be 'false'
            @($json.Items.PackageReference.Identity) | Should -Contain 'BenchmarkDotNet'
        }

        It 'gives every benchmarks project a benchmark-budget.json' {
            $script:BenchmarkProjects.Count | Should -BeGreaterThan 0
            foreach ($project in $script:BenchmarkProjects) {
                Join-Path $root (Split-Path -Parent $project) 'benchmark-budget.json' | Should -Exist
            }
        }
    }

    Context 'the sample''s load test (sample/tests/load)' {
        It 'has a locustfile, its load shape and its budget' {
            foreach ($file in 'locustfile.py', 'locust.conf', 'load-budget.json') {
                Join-Path $root 'sample' 'tests' 'load' $file | Should -Exist
            }
        }

        It 'has a budget Test-LoadBudget accepts' {
            . (Join-Path $root 'tools' 'Test-LoadBudget.ps1')
            $path = Join-Path $root 'sample' 'tests' 'load' 'load-budget.json'
            $path | Should -Exist

            @(Get-BudgetFileProblem (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable)) | Should -BeNullOrEmpty
        }

        # Locust reads locust.conf from the folder it runs in; the workflow passes only what it owns (host, headless, CSV).
        It 'sets the load in locust.conf, not in the workflow' {
            $conf = Get-Content -LiteralPath (Join-Path $root 'sample' 'tests' 'load' 'locust.conf') -ErrorAction SilentlyContinue

            foreach ($key in 'users', 'spawn-rate', 'run-time') {
                @($conf | Where-Object { $_ -match "^$key\s*=\s*\S" }) | Should -HaveCount 1 -Because "locust.conf sets $key"
            }
        }
    }

    Context 'performance.reusable.yml' {
        BeforeAll {
            $workflow = Read-Yaml '.github/workflows/performance.reusable.yml'
            $inputs = if ($workflow.Yaml.ContainsKey('on')) { $workflow.Yaml['on']['workflow_call']['inputs'] } else { @{} }
            $benchmarks = Get-JobStep $workflow.Yaml 'benchmarks'
            $load = Get-JobStep $workflow.Yaml 'load'
            $loadJob = if ($workflow.Yaml.ContainsKey('jobs')) { $workflow.Yaml['jobs']['load'] } else { $null }
        }

        # An app with no HTTP endpoint calls it with the solution alone; the load test is opt-in.
        It 'requires only the solution; the load test''s inputs default to off' {
            $inputs.Keys | Should -Contain 'solution'
            $inputs['solution']['required'] | Should -BeTrue
            $inputs['load-test-project']['default'] | Should -Be ''
            $inputs['load-test-path']['default'] | Should -Be 'tests/load'
            $inputs['load-test-url']['default'] | Should -Match '^http://localhost:\d+$'
            $inputs['load-test-user-jwt']['type'] | Should -Be 'boolean'
            $inputs['load-test-user-jwt']['default'] | Should -BeFalse
        }

        It 'reads only the repo, and holds no secret' {
            $workflow.Yaml['permissions'] | Should -Not -BeNullOrEmpty
            $workflow.Yaml['permissions']['contents'] | Should -Be 'read'
            $workflow.Text | Should -Not -Match '\$\{\{\s*secrets\.'
        }

        # The name is the one the coverage gate and the SBOM filter use (ADR-0062).
        It 'runs every benchmarks project in the solution, and passes saying so when there is none' {
            $run = Find-Step $benchmarks 'Run each benchmarks project and check its budget'

            $run | Should -HaveCount 1
            $run[0]['run'] | Should -Match 'Where-Object \{ Test-BenchmarksProject -Name '
            $run[0]['run'] | Should -Match 'No benchmarks project'
            # CRF-003: it reads the solution as every kit script does.
            $run[0]['run'] | Should -Match 'Import-Module "\$env:KIT/tools/KitSolution\.psm1"'
            $run[0]['run'] | Should -Match 'Get-SolutionProject -Solution \$env:SOLUTION'
            $run[0]['run'] | Should -Not -Match '\[xml\]'
            $run[0]['env']['KIT'] | Should -Be '${{ steps.kit.outputs.path }}'
        }

        It 'runs each in Release with a JSON report, and checks it against the project''s benchmark-budget.json' {
            Find-Step $benchmarks 'Run each benchmarks project and check its budget' | Should -HaveCount 1
            $run = (Find-Step $benchmarks 'Run each benchmarks project and check its budget')[0]['run']

            $run | Should -Match 'dotnet run --project \$project --configuration Release -- --filter ''\*'' --exporters json --artifacts \$artifacts'
            $run | Should -Match 'Test-BenchmarkBudget\.ps1" -Path \(Join-Path \$artifacts ''results''\) -Budget \(Join-Path \(Split-Path -Parent \$project\) ''benchmark-budget\.json''\)'
        }

        It 'uploads the <Job> job''s results, even when it fails' -ForEach @(
            @{ Job = 'benchmarks'; Artifact = 'benchmark-results' }
            @{ Job = 'load'; Artifact = 'load-test-results' }
        ) {
            $upload = @(Get-JobStep $workflow.Yaml $Job | Where-Object { "$($_['uses'])" -like 'actions/upload-artifact@*' })

            $upload | Should -HaveCount 1
            $upload[0]['if'] | Should -Be 'always()'
            $upload[0]['with']['name'] | Should -Be $Artifact
        }

        It 'runs the load test only when the caller names the app to load' {
            $loadJob | Should -Not -BeNullOrEmpty
            $loadJob['if'] | Should -Be "inputs.load-test-project != ''"
        }

        It 'installs Locust from the kit''s hash-pinned requirements, on the Python they were compiled for' {
            $python = @($load | Where-Object { "$($_['uses'])" -like 'actions/setup-python@*' })
            $install = Find-Step $load 'Install Locust (pinned by hash)'

            $python | Should -HaveCount 1
            $python[0]['with']['python-version-file'] | Should -Be '${{ steps.kit.outputs.path }}/.config/locust/.python-version'
            $install | Should -HaveCount 1
            $install[0]['run'] | Should -Match 'pip" install --require-hashes -r "\$KIT/\.config/locust/requirements\.txt"'
        }

        # Microsoft: load test a Release build in Production, not Debug or Development (ASP.NET Core load/stress testing).
        It 'starts the app built in Release, in Production, on the URL Locust loads, and waits for /health' {
            $start = Find-Step $load 'Start the app (Release, Production)'

            $start | Should -HaveCount 1
            $start[0]['run'] | Should -Match 'ASPNETCORE_ENVIRONMENT=Production'
            $start[0]['run'] | Should -Match 'ASPNETCORE_URLS="\$URL"'
            $start[0]['run'] | Should -Match 'dotnet run --project "\$PROJECT" --configuration Release --no-build --no-launch-profile'
            $start[0]['run'] | Should -Match '"\$URL/health"'
            $loadJob['env']['URL'] | Should -Be '${{ inputs.load-test-url }}'
        }

        # Locust reads locustfile.py and locust.conf from the folder it runs in; the budget, not Locust's exit code,
        # decides, so a failure ratio the budget allows doesn't fail the run.
        It 'runs Locust headless from the load test''s folder and checks its load-budget.json' {
            $locust = Find-Step $load 'Load test (Locust, headless)'
            $check = Find-Step $load 'Check the load budget'

            $locust | Should -HaveCount 1
            $locust[0]['working-directory'] | Should -Be '${{ inputs.load-test-path }}'
            $locust[0]['run'] | Should -Match 'locust" --headless --host "\$URL" --csv "\$RESULTS/load" --exit-code-on-error 0'
            $check | Should -HaveCount 1
            $check[0]['run'] | Should -Match 'Test-LoadBudget\.ps1" -Path "\$env:RESULTS/load" -Budget \(Join-Path \$env:LOAD_TEST_PATH ''load-budget\.json''\)'
        }

        It 'stops the app even when a step before failed' {
            $stop = Find-Step $load 'Stop the app'

            $stop | Should -HaveCount 1
            $stop[0]['if'] | Should -Be 'always()'
        }

        # SEC-002 and SEC-008: the token and user-jwts' signing key exist only on the runner, for this run, and are
        # masked before anything could print them. The app runs in Production, which doesn't read user secrets, so
        # it gets the signing settings through the environment.
        It 'issues a token with dotnet user-jwts only when asked, masking it and the signing key before using them' {
            $token = Find-Step $load 'Issue a token for this run (dotnet user-jwts)'

            $token | Should -HaveCount 1
            $token[0]['if'] | Should -Be 'inputs.load-test-user-jwt'
            $run = $token[0]['run']
            $run | Should -Match 'dotnet user-jwts create --project \$env:PROJECT --name load-test --audience \$env:URL --output token'
            $run.IndexOf('::add-mask::$token') | Should -BeGreaterThan -1
            $run.IndexOf('::add-mask::$token') | Should -BeLessThan $run.IndexOf('LOAD_TEST_TOKEN=')
            $run | Should -Match 'dotnet user-secrets list --project \$env:PROJECT --json'
            $run.IndexOf('::add-mask::$value') | Should -BeGreaterThan -1
            $run.IndexOf('::add-mask::$value') | Should -BeLessThan $run.IndexOf('>> $env:GITHUB_ENV', $run.IndexOf('::add-mask::$value'))
        }
    }

    Context 'callers of performance.reusable.yml' {
        It 'runs in the kit nightly, on demand and on every pull request, load testing the sample API with a token' {
            $kit = Read-Yaml '.github/workflows/performance.yml'
            $kit.Yaml.Keys | Should -Contain 'jobs'
            $job = $kit.Yaml['jobs']['performance']

            $kit.Yaml['on'].Keys | Should -Contain 'schedule'
            $kit.Yaml['on'].Keys | Should -Contain 'workflow_dispatch'
            $kit.Yaml['on'].Keys | Should -Contain 'pull_request'
            $job['uses'] | Should -Be './.github/workflows/performance.reusable.yml'
            $job['with']['solution'] | Should -Be 'dotnet-agent-kit.slnx'
            $job['with']['load-test-project'] | Should -Be 'sample/src/Bookmarks.Api/Bookmarks.Api.csproj'
            $job['with']['load-test-path'] | Should -Be 'sample/tests/load'
            $job['with']['load-test-user-jwt'] | Should -BeTrue
        }

        # The sample's token audience must be one the API trusts in Production: the URL Locust loads.
        It 'load tests the sample on the URL its launch profile uses' {
            $kit = Read-Yaml '.github/workflows/performance.yml'
            $profile = Get-Content -Raw (Join-Path $root 'sample/src/Bookmarks.Api/Properties/launchSettings.json') | ConvertFrom-Json
            $kit.Yaml.Keys | Should -Contain 'jobs'

            $kit.Yaml['jobs']['performance']['with']['load-test-url'] | Should -Be $profile.profiles.http.applicationUrl
        }

        # Nightly and on demand, as the intake's performance card says; an app adds the load test's inputs when it has
        # an HTTP endpoint (docs/standards/testing.md).
        It 'runs in an app nightly and on demand, at the kit''s pinned commit' {
            $text = Get-Content -Raw (Join-Path $root 'templates/app/.github/workflows/performance.yml') -ErrorAction SilentlyContinue
            $text | Should -Not -BeNullOrEmpty
            # New-KitApp fills in the placeholders; {{ starts a YAML mapping, so they're filled in here too.
            $app = ConvertFrom-Yaml ($text -replace '\{\{Name\}\}', 'Contoso' -replace '\{\{KitCommit\}\}', ('0' * 40) -replace '\{\{KitVersion\}\}', 'v0.1.0')

            $app['on'].Keys | Should -Contain 'schedule'
            $app['on'].Keys | Should -Contain 'workflow_dispatch'
            $app['jobs']['performance']['uses'] | Should -Be "DerekFoulk/dotnet-agent-kit/.github/workflows/performance.reusable.yml@$('0' * 40)"
            $app['jobs']['performance']['with']['solution'] | Should -Be 'Contoso.slnx'
        }
    }

    # Locust and every package it pulls in are pinned by version and hash, and installed with --require-hashes. Dependabot
    # replays the pip-compile command in requirements.txt's header when it moves Locust, so the header must keep both flags:
    # --generate-hashes, and --allow-unsafe, without which pip-compile leaves setuptools and pip unpinned.
    Context 'pinned Locust (.config/locust)' {
        BeforeAll {
            $locust = Join-Path $root '.config' 'locust'
            $script:Compiled = if (Test-Path (Join-Path $locust 'requirements.txt')) { Get-Content -LiteralPath (Join-Path $locust 'requirements.txt') } else { @() }
        }

        It 'names exactly one pinned Locust in requirements.in' {
            $in = @(Get-Content -LiteralPath (Join-Path $locust 'requirements.in') -ErrorAction SilentlyContinue | Where-Object { $_ -and $_ -notmatch '^\s*#' })

            $in | Should -HaveCount 1
            $in[0] | Should -Match '^locust==\d+\.\d+\.\d+$'
        }

        It 'compiles requirements.txt with pip-compile, hashes and the unsafe packages' {
            $header = $script:Compiled | Where-Object { $_ -match '^#\s+pip-compile ' }

            $header | Should -HaveCount 1
            $header | Should -Match '--generate-hashes'
            $header | Should -Match '--allow-unsafe'
        }

        It 'pins every package in requirements.txt by version and hash, Locust at the version requirements.in names' {
            $text = $script:Compiled -join "`n"
            # One entry per package: "name==version \", then its "--hash=sha256:..." lines.
            $entries = @([regex]::Matches($text, '(?m)^([A-Za-z0-9][A-Za-z0-9._-]*)==(\S+)((?:\s*\\\n\s+--hash=sha256:[0-9a-f]{64})*)'))
            $unpinned = @($script:Compiled | Where-Object { $_ -match '^[A-Za-z0-9]' -and $_ -notmatch '==' })

            $entries.Count | Should -BeGreaterThan 0
            $unpinned | Should -BeNullOrEmpty
            @($entries | Where-Object { -not $_.Groups[3].Value }).Groups | Should -BeNullOrEmpty -Because 'every package needs a hash'
            $pinned = (Get-Content -LiteralPath (Join-Path $locust 'requirements.in') | Where-Object { $_ -match '^locust==' }) -replace '^locust==', ''
            ($entries | Where-Object { $_.Groups[1].Value -eq 'locust' }).Groups[2].Value | Should -Be $pinned
        }

        It 'names the Python version requirements.txt was compiled for, in .python-version' {
            $version = @(Get-Content -LiteralPath (Join-Path $locust '.python-version') -ErrorAction SilentlyContinue)

            $version | Should -HaveCount 1
            $version[0] | Should -Match '^3\.\d+$'
            $script:Compiled | Where-Object { $_ -match "autogenerated by pip-compile with Python $([regex]::Escape($version[0]))$" } | Should -HaveCount 1
        }
    }
}
