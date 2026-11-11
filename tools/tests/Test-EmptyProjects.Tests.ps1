#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Test-EmptyProjects.ps1 fails on a project in the solution that holds no code of its own (ARC-009, ADR-0049):
# a layer made before anything needed it.

Describe 'Test-EmptyProjects.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-EmptyProjects.ps1')

        # A solution in its own folder, with one project per entry in $Projects: a name and the files under it, each
        # file a relative path and its text.
        function New-Solution([hashtable] $Projects) {
            $folder = Join-Path $TestDrive "sln-$(New-Guid)"
            $entries = foreach ($name in $Projects.Keys) {
                $projectFolder = Join-Path $folder 'src' $name
                New-Item -ItemType Directory -Force -Path $projectFolder | Out-Null
                Set-Content -LiteralPath (Join-Path $projectFolder "$name.csproj") -Value '<Project Sdk="Microsoft.NET.Sdk" />'
                foreach ($file in $Projects[$name].Keys) {
                    $path = Join-Path $projectFolder $file
                    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
                    Set-Content -LiteralPath $path -Value $Projects[$name][$file]
                }
                "<Project Path=""src/$name/$name.csproj"" />"
            }
            $solution = Join-Path $folder 'App.slnx'
            "<Solution><Folder Name=""/src/"">$($entries -join '')</Folder></Solution>" | Set-Content -LiteralPath $solution
            $solution
        }
    }

    It 'fails a project with no source files of its own' {
        $solution = New-Solution @{
            'App.Api' = @{ 'Program.cs' = 'var app = WebApplication.Create(); app.Run();' }
            'App.Domain' = @{}
        }

        $problems = @(Get-EmptyProjectProblem -Solution $solution)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike '*App.Domain*has no source*'
    }
}
