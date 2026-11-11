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

    # A build writes generated C# (AssemblyInfo, global usings) into obj/, so every built project would pass otherwise.
    It 'doesn''t count what the build writes under obj/ or bin/' {
        $solution = New-Solution @{
            'App.Domain' = @{
                'obj/Debug/net10.0/App.Domain.AssemblyInfo.cs' = '[assembly: System.Reflection.AssemblyTitle("App.Domain")]'
                'obj/Debug/net10.0/App.Domain.GlobalUsings.g.cs' = 'global using System;'
                'bin/Debug/net10.0/Copied.cs' = 'class Copied { }'
            }
        }

        $problems = @(Get-EmptyProjectProblem -Solution $solution)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike '*App.Domain*has no source*'
    }

    # `dotnet new classlib` writes an empty Class1, so a layer scaffolded before anything needed it is never file-less.
    It 'counts a project holding only the class library template''s empty Class1 (<Style>) as empty' -ForEach @(
        @{ Style = 'file-scoped namespace'; Text = "namespace App.Domain;`n`npublic class Class1`n{`n`n}" }
        @{ Style = 'block namespace'; Text = "namespace App.Domain`n{`n    public class Class1`n    {`n    }`n}" }
    ) {
        $solution = New-Solution @{ 'App.Domain' = @{ 'Class1.cs' = $Text } }

        $problems = @(Get-EmptyProjectProblem -Solution $solution)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike '*App.Domain*has no source*'
    }

    It 'passes a Class1 that someone has filled in' {
        $solution = New-Solution @{ 'App.Domain' = @{ 'Class1.cs' = "namespace App.Domain;`n`npublic class Class1`n{`n    public int Count { get; init; }`n}" } }

        @(Get-EmptyProjectProblem -Solution $solution) | Should -BeNullOrEmpty
    }

    It 'fails the template''s empty Class1 left beside real code' {
        $solution = New-Solution @{
            'App.Domain' = @{
                'Class1.cs' = "namespace App.Domain;`n`npublic class Class1`n{`n`n}"
                'Order.cs' = "namespace App.Domain;`n`npublic sealed record Order(int Id);"
            }
        }

        $problems = @(Get-EmptyProjectProblem -Solution $solution)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike '*Class1.cs*placeholder*'
    }

    # A Razor class library can hold only components or pages.
    It 'counts <File> as source' -ForEach @(
        @{ File = 'Components/Counter.razor'; Text = '<button @onclick="() => count++">@count</button>@code { int count; }' }
        @{ File = 'Pages/Index.cshtml'; Text = '@page' }
    ) {
        $solution = New-Solution @{ 'App.Ui' = @{ $File = $Text } }

        @(Get-EmptyProjectProblem -Solution $solution) | Should -BeNullOrEmpty
    }
}
