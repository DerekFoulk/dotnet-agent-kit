#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# KitSolution.psm1 is the one place the kit's scripts and shared workflows read a solution, and the one place that
# knows which framework MSBuild must evaluate a multi-target project through (CRF-003).

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'KitSolution.psm1') -Force

    # A solution file in its own folder under TestDrive, holding the given XML inside <Solution>.
    function Write-Solution {
        param([string] $Body, [string] $Name = 'App.slnx', [string] $Folder = (Join-Path $TestDrive (New-Guid)))

        New-Item -ItemType Directory -Force -Path $Folder | Out-Null
        $path = Join-Path $Folder $Name
        "<Solution>$Body</Solution>" | Set-Content -LiteralPath $path
        $path
    }
}

Describe 'Get-SolutionProject' {
    It 'lists each project in the order the solution writes them, inside folders too, as written and in full' {
        $solution = Write-Solution '<Project Path="src/App/App.csproj" /><Folder Name="/tests/"><Project Path="tests/App.Tests/App.Tests.csproj" /></Folder>'
        $folder = Split-Path -Parent $solution

        $projects = @(Get-SolutionProject -Solution $solution)

        $projects.Path | Should -Be 'src/App/App.csproj', 'tests/App.Tests/App.Tests.csproj'
        $projects.FullPath | Should -Be ([IO.Path]::GetFullPath((Join-Path $folder 'src' 'App' 'App.csproj'))),
            ([IO.Path]::GetFullPath((Join-Path $folder 'tests' 'App.Tests' 'App.Tests.csproj')))
    }

    It 'lists nothing for a new app''s empty solution' {
        @(Get-SolutionProject -Solution (Write-Solution '')) | Should -BeNullOrEmpty
    }

    # Each caller decides what a missing project means: Test-EmptyProjects reports it, Get-UiProject stops.
    It 'lists a project the disk doesn''t have' {
        (Get-SolutionProject -Solution (Write-Solution '<Project Path="src/Gone/Gone.csproj" />')).Path | Should -Be 'src/Gone/Gone.csproj'
    }

    It 'reads a project the solution reaches through ..' {
        $solution = Write-Solution '<Project Path="../shared/Lib/Lib.csproj" />' -Folder (Join-Path $TestDrive 'repo' 'app')

        (Get-SolutionProject -Solution $solution).FullPath | Should -Be ([IO.Path]::GetFullPath((Join-Path $TestDrive 'repo' 'shared' 'Lib' 'Lib.csproj')))
    }

    # .NET on Linux reads a backslash as part of a name; PowerShell's Join-Path accepts it as a separator on every OS
    # (about_Path_Syntax). This pins that, on Linux in CI.
    It 'reads a path written with backslashes as this OS''s full path, keeping Path as written' {
        $solution = Write-Solution '<Project Path="src\App\App.csproj" />'

        $project = Get-SolutionProject -Solution $solution

        $project.Path | Should -Be 'src\App\App.csproj'
        $project.FullPath | Should -Be ([IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $solution) 'src' 'App' 'App.csproj')))
    }

    It 'reads a solution given by a PowerShell drive path' {
        $solution = Write-Solution '<Project Path="src/App/App.csproj" />' -Folder (Join-Path $TestDrive 'drive')

        $project = Get-SolutionProject -Solution (Join-Path 'TestDrive:' 'drive' 'App.slnx')

        $project.FullPath | Should -Be ([IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $solution) 'src' 'App' 'App.csproj')))
    }

    It 'reads a solution whose path has wildcard characters, and an upper-case .SLNX' {
        $solution = Write-Solution '<Project Path="src/App/App.csproj" />' -Name 'App.SLNX' -Folder (Join-Path $TestDrive '[app]')

        (Get-SolutionProject -Solution $solution).Path | Should -Be 'src/App/App.csproj'
    }

    It 'says plainly when the solution file is missing' {
        $missing = Join-Path $TestDrive 'missing.slnx'

        { Get-SolutionProject -Solution $missing } | Should -Throw "No solution file at '$missing'."
    }

    # The kit's solutions are .slnx (ADR-0050's note): a .sln gets the command that converts it.
    It 'refuses a .sln, saying how to convert it to .slnx' {
        $solution = Join-Path $TestDrive 'Old.sln'
        'Microsoft Visual Studio Solution File, Format Version 12.00' | Set-Content -LiteralPath $solution

        { Get-SolutionProject -Solution $solution } | Should -Throw "*Old.sln isn't a .slnx solution*'dotnet sln *Old.sln migrate'*"
    }

    It 'refuses a file of another kind, naming .slnx' {
        $other = Write-Solution '<Project Path="src/App/App.csproj" />' -Name 'App.xml'

        { Get-SolutionProject -Solution $other } | Should -Throw "*App.xml isn't a .slnx solution*"
    }
}

# ADR-0062: a benchmarks project is known by its name alone, and this is the one statement of that rule (CRF-003).
Describe 'Test-BenchmarksProject' {
    It 'says <Name> is a benchmarks project: <Expected>' -ForEach @(
        @{ Name = 'App.Benchmarks'; Expected = $true }
        @{ Name = 'Contoso.Orders.Benchmarks'; Expected = $true }
        # The case MSBuild's EndsWith in tests/Directory.Build.props matches: exactly.
        @{ Name = 'App.benchmarks'; Expected = $false }
        @{ Name = 'App.BENCHMARKS'; Expected = $false }
        @{ Name = 'AppBenchmarks'; Expected = $false }
        @{ Name = 'Benchmarks'; Expected = $false }
        @{ Name = 'App.Benchmarks.Tests'; Expected = $false }
        @{ Name = 'App.Benchmarks.Core'; Expected = $false }
        @{ Name = 'App'; Expected = $false }
    ) {
        Test-BenchmarksProject -Name $Name | Should -Be $Expected
    }
}

# MSBuild's outer evaluation of a multi-target project (TargetFrameworks, no TargetFramework) has no Compile items or
# output folder; the evaluation for one framework does. Callers evaluate again through the framework this returns.
Describe 'Get-FirstTargetFramework' {
    It 'gives the first framework of a multi-target project' {
        Get-FirstTargetFramework -Properties ([pscustomobject]@{ TargetFramework = ''; TargetFrameworks = 'net10.0;net9.0' }) |
            Should -Be 'net10.0'
    }

    It 'skips an empty entry before the first framework' {
        Get-FirstTargetFramework -Properties ([pscustomobject]@{ TargetFramework = ''; TargetFrameworks = ';net9.0;net10.0' }) |
            Should -Be 'net9.0'
    }

    # Without both, a single-target project and a multi-target one look alike, so the answer would be a guess.
    It 'stops, naming the property, when the caller didn''t ask MSBuild for <Missing>' -ForEach @(
        @{ Missing = 'TargetFramework'; Properties = [pscustomobject]@{ TargetFrameworks = 'net10.0;net9.0' } }
        @{ Missing = 'TargetFrameworks'; Properties = [pscustomobject]@{ TargetFramework = '' } }
    ) {
        { Get-FirstTargetFramework -Properties $Properties } |
            Should -Throw "*MSBuild's evaluated properties have no $Missing*-getProperty:$Missing*"
    }

    It 'gives nothing for a TargetFrameworks of separators only' {
        { $script:first = Get-FirstTargetFramework -Properties ([pscustomobject]@{ TargetFramework = ''; TargetFrameworks = ';' }) } |
            Should -Not -Throw
        $script:first | Should -BeNullOrEmpty
    }

    It 'gives nothing for a single-target project' {
        Get-FirstTargetFramework -Properties ([pscustomobject]@{ TargetFramework = 'net10.0'; TargetFrameworks = '' }) |
            Should -BeNullOrEmpty
    }

    It 'gives nothing when MSBuild already evaluated the project for one framework of several' {
        Get-FirstTargetFramework -Properties ([pscustomobject]@{ TargetFramework = 'net9.0'; TargetFrameworks = 'net10.0;net9.0' }) |
            Should -BeNullOrEmpty
    }
}
