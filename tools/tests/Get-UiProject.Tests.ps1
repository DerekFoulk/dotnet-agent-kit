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

    # MAUI builds Apple targets only on a Mac and Windows targets only on Windows, so it needs both runners.
    It 'finds a MAUI project, which builds on Windows and macOS' {
        $solution = New-Solution @(
            @{ Path = 'src/App.Core/App.Core.csproj'; Properties = '' }
            @{ Path = 'src/App.Maui/App.Maui.csproj'; Properties = '<UseMaui>true</UseMaui><OutputType>Exe</OutputType>' }
        )

        $found = @(Get-UiProject -Solution $solution)

        $found | Should -HaveCount 1
        $found[0].Name | Should -Be 'App.Maui'
        $found[0].Path | Should -Be 'src/App.Maui/App.Maui.csproj'
        # Review 3: CI runs from the repo root, which needn't be the solution's folder.
        $found[0].FullPath | Should -Be ([IO.Path]::GetFullPath((Join-Path (Split-Path $solution) 'src/App.Maui/App.Maui.csproj')))
        $found[0].Kind | Should -Be 'Maui'
        $found[0].Os | Should -Be @('windows-latest', 'macos-latest')
    }

    It 'finds a <Kind> project, which builds on Windows only' -ForEach @(
        @{ Property = 'UseWPF'; Kind = 'Wpf' }
        @{ Property = 'UseWindowsForms'; Kind = 'WindowsForms' }
        @{ Property = 'UseWinUI'; Kind = 'WinUI' }
    ) {
        $solution = New-Solution @(@{ Path = 'src/App.Desktop/App.Desktop.csproj'; Properties = "<$Property>true</$Property>" })

        $found = @(Get-UiProject -Solution $solution)

        $found | Should -HaveCount 1
        $found[0].Kind | Should -Be $Kind
        $found[0].Os | Should -Be @('windows-latest')
    }

    # Review 5: the Linux job skips the code shape check whenever there are UI projects, because the Windows ui job
    # runs it. A kind that didn't build on Windows would drop the check without a sound.
    It 'builds every UI kind on Windows, where the code shape check runs for them' {
        $script:UiKinds | Should -Not -BeNullOrEmpty
        foreach ($kind in $script:UiKinds) { $kind.Os | Should -Contain 'windows-latest' -Because "$($kind.Kind) projects need the Windows job's checks" }
    }

    # MSBuild compares property values without regard to case.
    It 'reads the property as MSBuild does: True counts, false doesn''t' {
        $solution = New-Solution @(
            @{ Path = 'src/A/A.csproj'; Properties = '<UseMaui> True </UseMaui>' }
            @{ Path = 'src/B/B.csproj'; Properties = '<UseWPF>false</UseWPF>' }
        )

        @(Get-UiProject -Solution $solution).Name | Should -Be @('A')
    }

    It 'says plainly when the solution file is missing' {
        { Get-UiProject -Solution (Join-Path $TestDrive 'missing.slnx') } | Should -Throw '*No solution file at*'
    }

    It 'says plainly when a project the solution lists is missing' {
        $solution = New-Solution @(@{ Path = 'src/A/A.csproj'; Properties = '' })
        Remove-Item -LiteralPath (Join-Path (Split-Path $solution) 'src/A/A.csproj')

        { Get-UiProject -Solution $solution } | Should -Throw '*lists src/A/A.csproj, which doesn''t exist*'
    }

    # ARC-010: logic lives outside UI projects, so nothing needs to reference one. A test project that did would
    # fail on Linux with a confusing workload error; this says what's wrong instead.
    It 'fails when another project references a UI project' {
        $solution = New-Solution @(
            @{ Path = 'src/App.Maui/App.Maui.csproj'; Properties = '<UseMaui>true</UseMaui>' }
            @{ Path = 'tests/App.Maui.Tests/App.Maui.Tests.csproj'; Properties = '</PropertyGroup><ItemGroup><ProjectReference Include="..\..\src\App.Maui\App.Maui.csproj" /></ItemGroup><PropertyGroup>' }
        )

        { Get-UiProject -Solution $solution } | Should -Throw '*tests/App.Maui.Tests/App.Maui.Tests.csproj references the UI project src/App.Maui/App.Maui.csproj*ARC-010*'
    }

    # The Linux CI job builds and tests everything but the UI projects through this filter (ADR-0057).
    It 'writes a solution filter of every other project, pointing at the solution''s full path' {
        $solution = New-Solution @(
            @{ Path = 'src/App.Core/App.Core.csproj'; Properties = '' }
            @{ Path = 'src/App.Maui/App.Maui.csproj'; Properties = '<UseMaui>true</UseMaui>' }
            @{ Path = 'tests/App.Core.Tests/App.Core.Tests.csproj'; Properties = '' }
        )
        $filter = Join-Path $TestDrive "filter-$(New-Guid).slnf"
        (Get-Command Get-UiProject).Parameters.ContainsKey('FilterPath') | Should -BeTrue

        $found = @(Get-UiProject -Solution $solution -FilterPath $filter)

        $found.Name | Should -Be @('App.Maui')
        $json = Get-Content -Raw -LiteralPath $filter | ConvertFrom-Json
        $json.solution.path | Should -Be (Resolve-Path -LiteralPath $solution).Path
        $json.solution.projects | Should -Be @('src/App.Core/App.Core.csproj', 'tests/App.Core.Tests/App.Core.Tests.csproj')
    }

    # Review 2: macOS builds the MAUI project but not a WPF one beside it, which fails off Windows (NETSDK1100).
    It 'with -Runner, also puts in the filter the UI projects that runner builds: <Runner>' -ForEach @(
        @{ Runner = 'macos-latest'; Expected = @('src/App.Core/App.Core.csproj', 'src/App.Maui/App.Maui.csproj') }
        @{ Runner = 'windows-latest'; Expected = @('src/App.Core/App.Core.csproj', 'src/App.Maui/App.Maui.csproj', 'src/App.Wpf/App.Wpf.csproj') }
    ) {
        $solution = New-Solution @(
            @{ Path = 'src/App.Core/App.Core.csproj'; Properties = '' }
            @{ Path = 'src/App.Maui/App.Maui.csproj'; Properties = '<UseMaui>true</UseMaui>' }
            @{ Path = 'src/App.Wpf/App.Wpf.csproj'; Properties = '<UseWPF>true</UseWPF>' }
        )
        $filter = Join-Path $TestDrive "filter-$(New-Guid).slnf"
        (Get-Command Get-UiProject).Parameters.ContainsKey('Runner') | Should -BeTrue

        Get-UiProject -Solution $solution -FilterPath $filter -Runner $Runner | Out-Null

        (Get-Content -Raw -LiteralPath $filter | ConvertFrom-Json).solution.projects | Should -Be $Expected
    }
}
