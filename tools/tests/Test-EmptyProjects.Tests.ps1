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

    It 'counts an empty class Class1 in a file of another name as code' {
        $solution = New-Solution @{ 'App.Domain' = @{ 'Marker.cs' = "namespace App.Domain;`n`npublic class Class1`n{`n}" } }

        @(Get-EmptyProjectProblem -Solution $solution) | Should -BeNullOrEmpty
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
        $problems[0].Message | Should -BeLike 'src/App.Domain/Class1.cs is*placeholder*'
    }

    # A Razor class library can hold only components or pages.
    It 'counts <File> as source' -ForEach @(
        @{ File = 'Components/Counter.razor'; Text = '<button @onclick="() => count++">@count</button>@code { int count; }' }
        @{ File = 'Pages/Index.cshtml'; Text = '@page' }
    ) {
        $solution = New-Solution @{ 'App.Ui' = @{ $File = $Text } }

        @(Get-EmptyProjectProblem -Solution $solution) | Should -BeNullOrEmpty
    }

    # Only a C# project's code is something the check can read; a database, compose or JavaScript project holds
    # other kinds of files.
    It 'leaves out a <Kind> project' -ForEach @(
        @{ Kind = 'SQL'; Project = 'App.Db.sqlproj'; File = 'Tables/Orders.sql' }
        @{ Kind = 'Docker Compose'; Project = 'docker-compose.dcproj'; File = 'docker-compose.yml' }
        @{ Kind = 'JavaScript'; Project = 'App.Web.esproj'; File = 'src/main.ts' }
        @{ Kind = 'F#'; Project = 'App.Fs.fsproj'; File = 'Library.fs' }
    ) {
        $folder = Join-Path $TestDrive "sln-$(New-Guid)"
        New-Item -ItemType Directory -Force -Path (Join-Path $folder 'src' 'P' (Split-Path $File)) | Out-Null
        Set-Content -LiteralPath (Join-Path $folder 'src' 'P' $Project) -Value '<Project />'
        Set-Content -LiteralPath (Join-Path $folder 'src' 'P' $File) -Value 'x'
        $solution = Join-Path $folder 'App.slnx'
        "<Solution><Project Path=""src/P/$Project"" /></Solution>" | Set-Content -LiteralPath $solution

        @(Get-EmptyProjectProblem -Solution $solution) | Should -BeNullOrEmpty
    }

    # A link back up the tree would loop forever if followed; Get-ChildItem -Recurse doesn't follow links.
    It 'doesn''t follow a link inside a project''s folder' {
        $solution = New-Solution @{ 'App.Api' = @{ 'Features/Orders.cs' = 'class Orders { }' } }
        $features = Join-Path (Split-Path $solution) 'src' 'App.Api' 'Features'
        $type = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        $link = Join-Path $features 'up'
        New-Item -ItemType $type -Path $link -Target $features | Out-Null
        try {
            { $script:problems = @(Get-EmptyProjectProblem -Solution $solution) } | Should -Not -Throw
            $script:problems | Should -BeNullOrEmpty
        }
        finally {
            # Pester's TestDrive cleanup would follow the link; deleting it without recursing removes only the link.
            [IO.Directory]::Delete($link)
        }
    }

    It 'counts a Bin or Obj folder below the project''s top level as source' {
        $solution = New-Solution @{ 'App.Domain' = @{ 'Features/Bin/Order.cs' = 'class Order { }' } }

        @(Get-EmptyProjectProblem -Solution $solution) | Should -BeNullOrEmpty
    }

    # The project at the root has to remove the nested folder from its Compile items (<Compile Remove="tests/**" />),
    # since the SDK's default **/*.cs glob would compile the tests' files too.
    It 'doesn''t count files that belong to a nested <Kind> project' -ForEach @(
        @{ Kind = 'C#'; Project = 'App.Tests.csproj' }
        @{ Kind = 'SQL'; Project = 'App.Db.sqlproj' }
    ) {
        $folder = Join-Path $TestDrive "sln-$(New-Guid)"
        New-Item -ItemType Directory -Force -Path (Join-Path $folder 'tests' 'Nested') | Out-Null
        Set-Content -LiteralPath (Join-Path $folder 'App.csproj') -Value '<Project Sdk="Microsoft.NET.Sdk" />'
        Set-Content -LiteralPath (Join-Path $folder 'tests' 'Nested' $Project) -Value '<Project />'
        Set-Content -LiteralPath (Join-Path $folder 'tests' 'Nested' 'Script.cs') -Value 'class Script { }'
        $solution = Join-Path $folder 'App.slnx'
        '<Solution><Project Path="App.csproj" /></Solution>' | Set-Content -LiteralPath $solution

        @(Get-EmptyProjectProblem -Solution $solution) | Should -HaveCount 1
    }

    # A console tool and its tests (ARC-009) may sit with the tool's project at the root and the tests beneath it.
    It 'doesn''t count files that belong to another project in a subfolder' {
        $folder = Join-Path $TestDrive "sln-$(New-Guid)"
        New-Item -ItemType Directory -Force -Path (Join-Path $folder 'tests' 'App.Tests' 'obj') | Out-Null
        Set-Content -LiteralPath (Join-Path $folder 'App.csproj') -Value '<Project Sdk="Microsoft.NET.Sdk" />'
        Set-Content -LiteralPath (Join-Path $folder 'tests' 'App.Tests' 'App.Tests.csproj') -Value '<Project Sdk="Microsoft.NET.Sdk" />'
        Set-Content -LiteralPath (Join-Path $folder 'tests' 'App.Tests' 'AppTests.cs') -Value 'public class AppTests { }'
        Set-Content -LiteralPath (Join-Path $folder 'tests' 'App.Tests' 'obj' 'Generated.cs') -Value 'class Generated { }'
        $solution = Join-Path $folder 'App.slnx'
        '<Solution><Project Path="App.csproj" /><Project Path="tests/App.Tests/App.Tests.csproj" /></Solution>' | Set-Content -LiteralPath $solution

        $problems = @(Get-EmptyProjectProblem -Solution $solution)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike 'App.csproj has no source*'
    }

    # Grpc.Tools generates the C# from .proto files at build time, so a contracts project may hold only those.
    It 'counts .proto files as source' {
        $solution = New-Solution @{ 'App.Contracts' = @{ 'Protos/orders.proto' = 'syntax = "proto3";' } }

        @(Get-EmptyProjectProblem -Solution $solution) | Should -BeNullOrEmpty
    }

    It 'says plainly when the solution file is missing' {
        { Get-EmptyProjectProblem -Solution (Join-Path $TestDrive 'missing.slnx') } | Should -Throw '*No solution file at*'
    }

    It 'reports a project the solution lists but the disk doesn''t have' {
        $solution = New-Solution @{ 'App.Api' = @{ 'Program.cs' = 'return;' } }
        Remove-Item -LiteralPath (Join-Path (Split-Path $solution) 'src' 'App.Api') -Recurse -Force

        { $script:problems = @(Get-EmptyProjectProblem -Solution $solution) } | Should -Not -Throw
        $script:problems | Should -HaveCount 1
        $script:problems[0].Message | Should -BeLike '*src/App.Api/App.Api.csproj*isn''t there*'
    }

    # The shared .NET CI runs the check on the kit's own solution too.
    It 'passes the kit''s own solution' {
        @(Get-EmptyProjectProblem -Solution (Join-Path $PSScriptRoot '..' '..' 'dotnet-agent-kit.slnx')) | Should -BeNullOrEmpty
    }

    Context 'run as a script' {
        BeforeAll {
            $script:check = Join-Path $PSScriptRoot '..' 'Test-EmptyProjects.ps1'
        }

        It 'prints each problem and exits 1' {
            $solution = New-Solution @{ 'App.Api' = @{ 'Program.cs' = 'return;' }; 'App.Domain' = @{} }

            $output = pwsh -NoProfile -File $script:check -Solution $solution 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'App\.Domain.*has no source'
        }

        It 'says so and exits 0 when every project holds code' {
            $solution = New-Solution @{ 'App.Api' = @{ 'Program.cs' = 'return;' } }

            $output = pwsh -NoProfile -File $script:check -Solution $solution 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 0 -Because $output
            $output | Should -Match 'Every project in .*App\.slnx holds code of its own'
        }
    }
}
