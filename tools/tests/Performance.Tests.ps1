#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# GAP-012, ADR-0062: hot paths get BenchmarkDotNet benchmarks with a budget, and an app with an HTTP endpoint gets a
# Locust load test with a budget. These tests check the kit's files that set that up: the build settings for a
# benchmarks project, the sample's benchmarks and load test, the pinned Locust, and the performance workflows.

Describe 'Performance tests (GAP-012)' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        # The solution's benchmarks projects: by name, as the coverage gate, the SBOM filter and the workflow find them.
        $script:BenchmarkProjects = @(([xml] (Get-Content -Raw -LiteralPath (Join-Path $root 'dotnet-agent-kit.slnx'))).SelectNodes('//Project') |
                ForEach-Object { $_.GetAttribute('Path') } |
                Where-Object { [IO.Path]::GetFileNameWithoutExtension($_) -like '*.Benchmarks' })
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
