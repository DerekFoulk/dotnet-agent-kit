#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Proves the repo's root build configuration is enforced, not just present.
# Each fixture project is copied with the root config files into an isolated, tagged git
# workspace, so the real files are tested and nothing builds inside the repo itself.

Describe 'Repo build configuration' -Tag 'Build' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $configFiles = 'global.json', 'Directory.Build.props', 'Directory.Packages.props', '.editorconfig', 'nuget.config'

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
            git -C $workspace add --all
            git -C $workspace -c user.name=fixture -c user.email=fixture@example.invalid commit --quiet --message fixture
            git -C $workspace tag v1.2.3
            $workspace
        }

        function Invoke-FixtureBuild {
            param([Parameter(Mandatory)] [string] $Workspace)

            $output = dotnet build $Workspace --configuration Release --nologo 2>&1 | Out-String
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
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)

            $build.ExitCode | Should -Not -Be 0 -Because $build.Output
            $build.Output | Should -Match "error $Diagnostic"
        }
    }
}
