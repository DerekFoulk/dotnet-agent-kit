#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Get-SolutionProjectCount.ps1 counts the projects in a .slnx solution. The shared .NET CI and mutation workflows both
# skip their .NET steps while a new app's solution is still empty; this is the one place that count is made (DRY).

Describe 'Get-SolutionProjectCount.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Get-SolutionProjectCount.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Write-Solution([string] $Body) {
            $path = Join-Path $TestDrive 'App.slnx'
            "<Solution>$Body</Solution>" | Set-Content -LiteralPath $path
            $path
        }
    }

    It 'counts every project, inside folders too' {
        Get-Command Get-SolutionProjectCount -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $path = Write-Solution '<Project Path="src/App/App.csproj" /><Folder Name="/tests/"><Project Path="tests/App.Tests/App.Tests.csproj" /></Folder>'

        Get-SolutionProjectCount -Solution $path | Should -Be 2
    }

    It 'counts zero in a new app''s empty solution' {
        Get-Command Get-SolutionProjectCount -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-SolutionProjectCount -Solution (Write-Solution '') | Should -Be 0
    }

    It 'says plainly when the solution file is missing' {
        Get-Command Get-SolutionProjectCount -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        { Get-SolutionProjectCount -Solution (Join-Path $TestDrive 'missing.slnx') } | Should -Throw '*No solution file at*'
    }

    It 'is what both shared .NET workflows use to count projects' {
        foreach ($workflow in 'dotnet-ci.reusable.yml', 'mutation.reusable.yml') {
            $text = Get-Content -Raw (Join-Path $root '.github' 'workflows' $workflow)
            $text | Should -Match '\$env:KIT/tools/Get-SolutionProjectCount\.ps1' -Because "$workflow counts projects with the kit's script"
            $text | Should -Not -Match "SelectNodes\('//Project'\)" -Because "$workflow shouldn't repeat the count inline"
        }
    }
}
