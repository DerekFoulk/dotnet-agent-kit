#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Proves the repo's root build configuration is enforced, not just present.
# Each fixture project is copied with the root config files into an isolated, tagged git
# workspace, so the real files are tested and nothing builds inside the repo itself.

BeforeAll {
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'Repo build configuration' -Tag 'Build' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $configFiles = 'global.json', 'Directory.Build.props', 'Directory.Packages.props', '.editorconfig', 'nuget.config', '.globalconfig', 'CodeMetricsConfig.txt'

        function New-FixtureWorkspace {
            param([Parameter(Mandatory)] [string] $Fixture)

            $workspace = Join-Path $TestDrive $Fixture
            New-Item -ItemType Directory -Path $workspace | Out-Null
            foreach ($file in $configFiles) {
                $source = Join-Path $repoRoot $file
                if (Test-Path $source) {
                    Copy-Item -Path $source -Destination $workspace
                }
            }
            Copy-Item -Path (Join-Path $PSScriptRoot 'fixtures' $Fixture '*') -Destination $workspace -Recurse

            git -C $workspace init --quiet --initial-branch main
            git -C $workspace -c core.autocrlf=false add --all
            git -C $workspace commit --quiet --message fixture
            git -C $workspace tag v1.2.3
            $workspace
        }

        function Invoke-FixtureBuild {
            param([Parameter(Mandatory)] [string] $Workspace, [string] $Project = '')

            $target = if ($Project) { Join-Path $Workspace $Project } else { $Workspace }
            $output = dotnet build $target --configuration Release --nologo 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
    }

    Context 'clean code' {
        BeforeAll {
            $workspace = New-FixtureWorkspace -Fixture 'Clean'
            $build = Invoke-FixtureBuild -Workspace $workspace
        }

        It 'builds with no warnings or errors' {
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }

        It 'takes its version from the v-prefixed git tag (MinVer)' {
            $assembly = Join-Path $workspace 'bin' 'Release' 'net10.0' 'Clean.dll'
            [System.Diagnostics.FileVersionInfo]::GetVersionInfo($assembly).ProductVersion | Should -Match '^1\.2\.3\+'
        }

        It 'writes a package lock file' {
            Join-Path $workspace 'packages.lock.json' | Should -Exist
        }
    }

    Context 'violations fail the build' {
        It 'rejects <Description> (<Diagnostic>)' -ForEach @(
            @{ Fixture = 'UsesVar'; Diagnostic = 'IDE0008'; Description = 'var, because code style is enforced on build' }
            @{ Fixture = 'NullableViolation'; Diagnostic = 'CS8600'; Description = 'a null assigned to a non-nullable type' }
            @{ Fixture = 'CatchAll'; Diagnostic = 'CA1031'; Description = 'catching Exception, a rule only AnalysisLevel latest-all turns on' }
            @{ Fixture = 'MsBuildWarning'; Diagnostic = 'KIT0001'; Description = 'a warning from an MSBuild task, which TreatWarningsAsErrors alone misses' }
            @{ Fixture = 'AwaitInLibrary'; Diagnostic = 'CA2007'; Description = 'an await without ConfigureAwait in a class library' }
            @{ Fixture = 'TooComplex'; Diagnostic = 'CA1502'; Description = 'a method with a cyclomatic complexity of 16, over the limit of 15 (CRF-008)' }
            @{ Fixture = 'TooCoupledMember'; Diagnostic = 'CA1506'; Description = 'a method coupled to 41 types, over the limit of 40 per member (CRF-008)' }
            @{ Fixture = 'TooCoupledType'; Diagnostic = 'CA1506'; Description = 'a class coupled to 96 types, over the limit of 95 per type (CRF-008)' }
            @{ Fixture = 'TooDeep'; Diagnostic = 'CA1501'; Description = 'a class 6 levels deep, over the limit of 5 (CRF-008)' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)

            $build.ExitCode | Should -Not -Be 0 -Because $build.Output
            $build.Output | Should -Match "error $Diagnostic"
        }
    }

    # ADR-0043: the metric limits sit exactly where the ADR puts them, not lower.
    Context 'code at the metric limits' {
        It 'builds <Description>' -ForEach @(
            @{ Fixture = 'AtComplexityLimit'; Description = 'a method with a cyclomatic complexity of 15' }
            @{ Fixture = 'AtMemberCouplingLimit'; Description = 'a method coupled to 40 types' }
            @{ Fixture = 'AtTypeCouplingLimit'; Description = 'a class coupled to 95 types' }
            @{ Fixture = 'AtInheritanceLimit'; Description = 'a class 5 levels deep' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)

            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # ADR-0029: CA2007 is for libraries; Microsoft advises suppressing it for application code.
    Context 'CA2007 applies to libraries only' {
        It 'allows an await without ConfigureAwait in <Description>' -ForEach @(
            @{ Fixture = 'AwaitInApp'; Project = ''; Description = 'an app' }
            @{ Fixture = 'AwaitInTests'; Project = 'Widgets.Tests'; Description = 'a test project (a library in a *Tests folder)' }
            @{ Fixture = 'AwaitInNestedTests'; Project = 'tests/Widgets.Tests'; Description = 'a test project nested under tests/' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture) -Project $Project

            $build.Output | Should -Not -Match 'CA2007'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }
}
