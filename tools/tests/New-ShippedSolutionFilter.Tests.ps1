#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# New-ShippedSolutionFilter.ps1 writes a solution filter (.slnf) of the projects a build ships, for the SBOM (SUP-009,
# ADR-0055). CycloneDX's own --exclude-test-projects reads only each .csproj's XML, so it misses a test project marked
# by Directory.Build.props, as the kit's sample and every app's tests are (review of PR 48). MSBuild decides instead.

Describe 'New-ShippedSolutionFilter.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'New-ShippedSolutionFilter.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        function New-Project([string] $Repo, [string] $RelativePath, [string] $Body = '') {
            $path = Join-Path $Repo $RelativePath
            New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
            "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup>$Body</Project>" |
                Set-Content -LiteralPath $path
        }

        # A repo laid out like an app: a test project marked only by tests/Directory.Build.props, as the kit's is.
        $repo = Join-Path $TestDrive 'repo'
        New-Project $repo 'src/App/App.csproj'
        New-Project $repo 'src/App.Contracts/App.Contracts.csproj'
        New-Project $repo 'tests/App.Tests/App.Tests.csproj'
        New-Project $repo 'tests/App.Probe/App.Probe.csproj' '<PropertyGroup><IsTestProject>true</IsTestProject></PropertyGroup>'
        '<Project><PropertyGroup Condition="$(MSBuildProjectName.EndsWith(''Tests''))"><IsTestProject>true</IsTestProject></PropertyGroup></Project>' |
            Set-Content -LiteralPath (Join-Path $repo 'tests/Directory.Build.props')
        $solution = Join-Path $repo 'App.slnx'
        @'
<Solution>
  <Folder Name="/src/">
    <Project Path="src/App/App.csproj" />
    <Project Path="src/App.Contracts/App.Contracts.csproj" />
  </Folder>
  <Folder Name="/tests/">
    <Project Path="tests/App.Tests/App.Tests.csproj" />
    <Project Path="tests/App.Probe/App.Probe.csproj" />
  </Folder>
</Solution>
'@ | Set-Content -LiteralPath $solution
    }

    It 'lists only the projects MSBuild doesn''t call test projects, wherever IsTestProject is set' {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

        $filter = New-ShippedSolutionFilter -Solution $solution -Destination (Join-Path $TestDrive 'out1')
        $json = Get-Content -Raw -LiteralPath $filter | ConvertFrom-Json

        @($json.solution.projects) | Should -Be @('src/App/App.csproj', 'src/App.Contracts/App.Contracts.csproj')
    }

    It 'names the filter after the solution, and points it at the solution from wherever it''s written' {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $destination = Join-Path $TestDrive 'elsewhere' 'sbom'

        $filter = New-ShippedSolutionFilter -Solution $solution -Destination $destination
        $json = Get-Content -Raw -LiteralPath $filter | ConvertFrom-Json

        Split-Path -Leaf $filter | Should -Be 'App.slnf'
        [IO.Path]::IsPathRooted($json.solution.path) | Should -BeFalse -Because 'a solution filter names its solution relative to itself'
        (Resolve-Path -LiteralPath (Join-Path $destination $json.solution.path)).Path | Should -Be (Resolve-Path -LiteralPath $solution).Path
    }

    It 'fails when MSBuild can''t read a project, rather than guessing whether it ships' {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $broken = Join-Path $TestDrive 'broken'
        New-Item -ItemType Directory -Force -Path (Join-Path $broken 'src/Bad') | Out-Null
        'not a project' | Set-Content -LiteralPath (Join-Path $broken 'src/Bad/Bad.csproj')
        '<Solution><Project Path="src/Bad/Bad.csproj" /></Solution>' | Set-Content -LiteralPath (Join-Path $broken 'Bad.slnx')

        { New-ShippedSolutionFilter -Solution (Join-Path $broken 'Bad.slnx') -Destination (Join-Path $TestDrive 'out3') } |
            Should -Throw '*src/Bad/Bad.csproj*'
    }

    # Review 2 of PR 48: MSBuild prints an evaluation warning before the value, so the whole output isn't the value.
    It 'reads the value past an MSBuild warning, and keeps one shipped project as a list' {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $warned = Join-Path $TestDrive 'warned'
        New-Project $warned 'src/App/App.csproj'
        New-Project $warned 'tests/T/T.csproj' '<PropertyGroup><IsTestProject>true</IsTestProject></PropertyGroup><Import Project="x.props" /><Import Project="x.props" />'
        '<Project />' | Set-Content -LiteralPath (Join-Path $warned 'tests/T/x.props')
        '<Solution><Project Path="src/App/App.csproj" /><Project Path="tests/T/T.csproj" /></Solution>' | Set-Content -LiteralPath (Join-Path $warned 'W.slnx')

        $filter = New-ShippedSolutionFilter -Solution (Join-Path $warned 'W.slnx') -Destination (Join-Path $TestDrive 'out5')
        $text = Get-Content -Raw -LiteralPath $filter

        @(($text | ConvertFrom-Json).solution.projects) | Should -Be @('src/App/App.csproj')
        $text | Should -Match '"projects":\s*\[' -Because 'CycloneDX reads projects as an array, even with one'
    }

    # CycloneDX reads only C#, F#, Visual Basic and X# projects; MSBuild may not evaluate the rest (a .shproj) on Linux.
    It 'asks MSBuild only about the project types CycloneDX reads' {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $mixed = Join-Path $TestDrive 'mixed'
        New-Project $mixed 'src/App/App.csproj'
        New-Item -ItemType Directory -Force -Path (Join-Path $mixed 'src/Shared') | Out-Null
        'not a project' | Set-Content -LiteralPath (Join-Path $mixed 'src/Shared/Shared.shproj')
        '<Solution><Project Path="src/App/App.csproj" /><Project Path="src/Shared/Shared.shproj" /></Solution>' | Set-Content -LiteralPath (Join-Path $mixed 'M.slnx')

        { $script:filter = New-ShippedSolutionFilter -Solution (Join-Path $mixed 'M.slnx') -Destination (Join-Path $TestDrive 'out6') } |
            Should -Not -Throw
        $filter = $script:filter

        @((Get-Content -Raw -LiteralPath $filter | ConvertFrom-Json).solution.projects) | Should -Be @('src/App/App.csproj')
    }

    # Review 3 of PR 48: the list matches CycloneDX 6.3.1's Utils.IsSupportedProjectType, .xsproj (X#) included.
    It 'asks MSBuild about a <Extension> project, a type CycloneDX reads' -ForEach @(
        @{ Extension = '.csproj' }, @{ Extension = '.fsproj' }, @{ Extension = '.vbproj' }, @{ Extension = '.xsproj' }
    ) {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $typed = Join-Path $TestDrive "typed$Extension"
        New-Item -ItemType Directory -Force -Path (Join-Path $typed 'src/Lib') | Out-Null
        'not a project' | Set-Content -LiteralPath (Join-Path $typed "src/Lib/Lib$Extension")
        "<Solution><Project Path=`"src/Lib/Lib$Extension`" /></Solution>" | Set-Content -LiteralPath (Join-Path $typed 'T.slnx')

        # An unreadable project fails only if MSBuild was asked about it.
        { New-ShippedSolutionFilter -Solution (Join-Path $typed 'T.slnx') -Destination (Join-Path $TestDrive "out-$Extension") } |
            Should -Throw "*src/Lib/Lib$Extension*"
    }

    It 'fails on an IsTestProject value that is neither true nor false' {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $odd = Join-Path $TestDrive 'odd'
        New-Project $odd 'src/App/App.csproj' '<PropertyGroup><IsTestProject>maybe</IsTestProject></PropertyGroup>'
        '<Solution><Project Path="src/App/App.csproj" /></Solution>' | Set-Content -LiteralPath (Join-Path $odd 'O.slnx')

        { New-ShippedSolutionFilter -Solution (Join-Path $odd 'O.slnx') -Destination (Join-Path $TestDrive 'out7') } |
            Should -Throw "*'maybe'*"
    }

    It 'says plainly when the solution file is missing' {
        Get-Command New-ShippedSolutionFilter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        { New-ShippedSolutionFilter -Solution (Join-Path $TestDrive 'missing.slnx') -Destination $TestDrive } |
            Should -Throw '*No solution file at*'
    }
}
