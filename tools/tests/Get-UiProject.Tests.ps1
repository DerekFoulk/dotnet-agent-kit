#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Get-UiProject.ps1 lists a solution's UI projects: the MAUI and desktop projects (ARC-010, ADR-0057). The coverage
# gate exempts them, and the shared .NET CI builds them on Windows and macOS; this is the one place they're found.

Describe 'Get-UiProject.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Get-UiProject.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        # Writes a solution in its own folder with one project file per entry: @{ Path = 'src/A/A.csproj'; Properties = '<UseMaui>true</UseMaui>' }.
        function New-Solution([hashtable[]] $Projects) {
            $dir = Join-Path $TestDrive "sln-$(New-Guid)"
            New-Item -ItemType Directory -Path $dir | Out-Null
            $entries = foreach ($project in $Projects) {
                $file = Join-Path $dir $project.Path
                New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
                "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net10.0</TargetFramework>$($project.Properties)</PropertyGroup></Project>" |
                    Set-Content -LiteralPath $file
                "<Project Path=`"$($project.Path)`" />"
            }
            $path = Join-Path $dir 'App.slnx'
            "<Solution><Folder Name=`"/src/`">$($entries -join '')</Folder></Solution>" | Set-Content -LiteralPath $path
            $path
        }
    }

    It 'finds no UI project in a solution of plain projects' {
        Get-Command Get-UiProject -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $solution = New-Solution @(
            @{ Path = 'src/App.Domain/App.Domain.csproj'; Properties = '' }
            @{ Path = 'tests/App.Domain.Tests/App.Domain.Tests.csproj'; Properties = '<IsTestProject>true</IsTestProject>' }
        )

        @(Get-UiProject -Solution $solution) | Should -HaveCount 0
    }
}
