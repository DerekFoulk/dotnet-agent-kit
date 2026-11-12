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
}
