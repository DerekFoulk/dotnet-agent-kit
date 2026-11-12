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

    It 'says plainly when the solution file is missing' {
        $missing = Join-Path $TestDrive 'missing.slnx'

        { Get-SolutionProject -Solution $missing } | Should -Throw "No solution file at '$missing'."
    }

    # The kit's solutions are .slnx (ADR-0050's note): a .sln gets the command that converts it.
    It 'refuses a .sln, saying how to convert it to .slnx' {
        $solution = Join-Path $TestDrive 'Old.sln'
        'Microsoft Visual Studio Solution File, Format Version 12.00' | Set-Content -LiteralPath $solution

        { Get-SolutionProject -Solution $solution } | Should -Throw "*Old.sln isn't a .slnx solution*dotnet sln migrate*"
    }

    It 'refuses a file of another kind, naming .slnx' {
        $other = Write-Solution '<Project Path="src/App/App.csproj" />' -Name 'App.xml'

        { Get-SolutionProject -Solution $other } | Should -Throw "*App.xml isn't a .slnx solution*"
    }
}
