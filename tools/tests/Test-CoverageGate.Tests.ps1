#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The XML below has the shape of Microsoft.Testing.Extensions.CodeCoverage's Cobertura output
# (`dotnet test --coverage --coverage-output-format cobertura`, 18.12.0, captured 2026-11-04), cut down
# to the elements the gate reads.

Describe 'Test-CoverageGate.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-CoverageGate.ps1')

        # Writes one Cobertura report. $Packages maps a package (assembly) name to its classes; each class
        # is @{ File = '...'; Lines = @(@(number, hits), ...) }.
        function New-CoberturaReport {
            param([Parameter(Mandatory)] [string] $Directory, [Parameter(Mandatory)] [hashtable] $Packages)

            New-Item -ItemType Directory -Force -Path $Directory | Out-Null
            $packagesXml = foreach ($name in $Packages.Keys) {
                $classesXml = foreach ($class in $Packages[$name]) {
                    $linesXml = foreach ($line in $class.Lines) { "<line number=`"$($line[0])`" hits=`"$($line[1])`" branch=`"False`" />" }
                    "<class name=`"C`" filename=`"$($class.File)`" line-rate=`"0`"><methods /><lines>$($linesXml -join '')</lines></class>"
                }
                "<package name=`"$name`" line-rate=`"0`"><classes>$($classesXml -join '')</classes></package>"
            }
            $path = Join-Path $Directory "$([guid]::NewGuid()).cobertura.xml"
            Set-Content -LiteralPath $path -Value "<?xml version=`"1.0`"?><coverage line-rate=`"0`"><packages>$($packagesXml -join '')</packages></coverage>"
            $path
        }

        # Writes a solution, and a project file for each of its projects with the given properties.
        function New-TestSolution([string] $Name, [hashtable] $Projects) {
            $dir = Join-Path $TestDrive "sln-$Name"
            $entries = foreach ($path in $Projects.Keys) {
                $file = Join-Path $dir $path
                New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
                "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup>$($Projects[$path])</PropertyGroup></Project>" | Set-Content -LiteralPath $file
                "<Project Path=`"$path`" />"
            }
            $solution = Join-Path $dir "$Name.slnx"
            "<Solution>$($entries -join '')</Solution>" | Set-Content -LiteralPath $solution
            $solution
        }

        function Get-Lines([int] $Covered, [int] $Missed) {
            $n = 0
            # 1..0 counts down in PowerShell, so guard zero counts.
            @(if ($Covered) { foreach ($i in 1..$Covered) { , @((++$n), 1) } }) + @(if ($Missed) { foreach ($i in 1..$Missed) { , @((++$n), 0) } })
        }
    }

    Context 'Get-CoverageSummary' {
        It 'merges reports: a line covered in any report counts as covered' {
            $dir = Join-Path $TestDrive 'merge'
            New-CoberturaReport -Directory $dir -Packages @{ 'Bookmarks.Domain' = @(@{ File = 'src/Bookmark.cs'; Lines = @(@(1, 1), @(2, 0)) }) } | Out-Null
            New-CoberturaReport -Directory $dir -Packages @{ 'Bookmarks.Domain' = @(@{ File = 'src/Bookmark.cs'; Lines = @(@(1, 0), @(2, 3)) }) } | Out-Null

            $domain = Get-CoverageSummary -Path $dir | Where-Object Package -EQ 'Bookmarks.Domain'

            $domain | Should -Not -BeNullOrEmpty
            $domain.Covered | Should -Be 2
            $domain.Total | Should -Be 2
            $domain.Percent | Should -Be 100
        }

        It 'leaves out test assemblies and generated files' {
            $dir = Join-Path $TestDrive 'exclude'
            New-CoberturaReport -Directory $dir -Packages @{
                'Bookmarks.Api'          = @(
                    @{ File = 'src/Bookmarks.Api/BookmarkEndpoints.cs'; Lines = Get-Lines 4 0 }
                    @{ File = 'src/Bookmarks.Api/obj/Release/net10.0/Generated/OpenApiXmlCommentSupport.generated.cs'; Lines = Get-Lines 1 9 }
                    @{ File = 'src/Bookmarks.Api/obj/Release/net10.0/Program.g.cs'; Lines = Get-Lines 0 3 }
                )
                'Bookmarks.Domain.Tests' = @(@{ File = 'tests/BookmarkTests.cs'; Lines = Get-Lines 0 5 })
            } | Out-Null

            $summary = @(Get-CoverageSummary -Path $dir)

            ($summary | ForEach-Object Package) | Should -Be @('Bookmarks.Api')
            $summary[0].Total | Should -Be 4
            $summary[0].Percent | Should -Be 100
        }
    }

    Context 'Invoke-CoverageGate (TST-004: Domain 100%, Application 95%, overall 90%)' {
        It 'passes when every assembly meets its minimum' {
            $dir = Join-Path $TestDrive 'pass'
            New-CoberturaReport -Directory $dir -Packages @{
                'Bookmarks.Domain'         = @(@{ File = 'd.cs'; Lines = Get-Lines 10 0 })
                'Bookmarks.Application'    = @(@{ File = 'a.cs'; Lines = Get-Lines 19 1 })
                'Bookmarks.Infrastructure' = @(@{ File = 'i.cs'; Lines = Get-Lines 9 1 })
            } | Out-Null

            Invoke-CoverageGate -Path $dir 6>$null | Should -Be 0
        }

        It 'fails when <Case>' -ForEach @(
            @{ Case = 'the domain is below 100%'; Domain = @(9, 1); Application = @(20, 0); Other = @(20, 0); Expected = '*Bookmarks.Domain*90*100*' }
            @{ Case = 'the application is below 95%'; Domain = @(10, 0); Application = @(18, 2); Other = @(20, 0); Expected = '*Bookmarks.Application*90*95*' }
            @{ Case = 'the overall total is below 90%'; Domain = @(10, 0); Application = @(20, 0); Other = @(5, 15); Expected = '*overall*70*90*' }
        ) {
            $dir = Join-Path $TestDrive "fail-$([guid]::NewGuid())"
            New-CoberturaReport -Directory $dir -Packages @{
                'Bookmarks.Domain'         = @(@{ File = 'd.cs'; Lines = Get-Lines $Domain[0] $Domain[1] })
                'Bookmarks.Application'    = @(@{ File = 'a.cs'; Lines = Get-Lines $Application[0] $Application[1] })
                'Bookmarks.Infrastructure' = @(@{ File = 'i.cs'; Lines = Get-Lines $Other[0] $Other[1] })
            } | Out-Null

            $output = Invoke-CoverageGate -Path $dir 6>&1
            $exitCode = @($output | Where-Object { $_ -is [int] })[-1]
            $text = ($output | Where-Object { $_ -isnot [int] }) -join "`n"

            $exitCode | Should -Be 1
            $text | Should -BeLike $Expected
        }

        # Rounding for display must not decide the result: 2000/2001 is 99.95%, below 100%.
        It 'compares the exact coverage, not the rounded figure' {
            $dir = Join-Path $TestDrive 'rounding'
            New-CoberturaReport -Directory $dir -Packages @{ 'Bookmarks.Domain' = @(@{ File = 'd.cs'; Lines = Get-Lines 2000 1 }) } | Out-Null

            Invoke-CoverageGate -Path $dir 6>$null | Should -Be 1
        }

        # A production project that no test loads isn't in any report; the solution says it should be.
        It 'fails when a production project in the solution has no coverage at all' {
            $dir = Join-Path $TestDrive 'missing'
            New-CoberturaReport -Directory $dir -Packages @{ 'Bookmarks.Domain' = @(@{ File = 'd.cs'; Lines = Get-Lines 10 0 }) } | Out-Null
            $solution = New-TestSolution -Name 'Missing' -Projects @{
                'src/Bookmarks.Domain/Bookmarks.Domain.csproj'                   = ''
                'src/Bookmarks.Worker/Bookmarks.Worker.csproj'                   = ''
                'tests/Bookmarks.Domain.Tests/Bookmarks.Domain.Tests.csproj' = ''
            }

            $output = Invoke-CoverageGate -Path $dir -Solution $solution 6>&1
            $exitCode = @($output | Where-Object { $_ -is [int] })[-1]

            $exitCode | Should -Be 1
            ($output | Where-Object { $_ -isnot [int] }) -join "`n" | Should -BeLike '*Bookmarks.Worker*no coverage*'
        }

        # ARC-010, ADR-0059: a UI project holds only views, platform code and startup wiring, which no plain test
        # project can load, so the gate exempts it and says so. Its logic lives in libraries the gate does count.
        It 'exempts a UI project that no test loads, and says so' {
            $dir = Join-Path $TestDrive 'ui-unloaded'
            New-CoberturaReport -Directory $dir -Packages @{ 'App.Core' = @(@{ File = 'c.cs'; Lines = Get-Lines 10 0 }) } | Out-Null
            $solution = New-TestSolution -Name 'UiUnloaded' -Projects @{
                'src/App.Core/App.Core.csproj' = ''
                'src/App.Maui/App.Maui.csproj' = '<UseMaui>true</UseMaui>'
            }

            $output = Invoke-CoverageGate -Path $dir -Solution $solution 6>&1
            $exitCode = @($output | Where-Object { $_ -is [int] })[-1]

            ($output | Where-Object { $_ -isnot [int] }) -join "`n" | Should -BeLike '*App.Maui*exempt (UI project, ARC-010)*'
            $exitCode | Should -Be 0
        }

        # ADR-0062: a benchmarks project (its name ends in .Benchmarks) is test-side code, like a test project: it
        # measures production code and ships nothing, and no test loads it.
        It 'leaves out a benchmarks project, says so, and leaves its lines out of the overall' {
            $dir = Join-Path $TestDrive 'benchmarks'
            New-CoberturaReport -Directory $dir -Packages @{
                'App.Core'       = @(@{ File = 'c.cs'; Lines = Get-Lines 10 0 })
                'App.Benchmarks' = @(@{ File = 'b.cs'; Lines = Get-Lines 0 40 })
            } | Out-Null
            $solution = New-TestSolution -Name 'Benchmarks' -Projects @{
                'src/App.Core/App.Core.csproj'                   = ''
                'tests/App.Benchmarks/App.Benchmarks.csproj' = '<OutputType>Exe</OutputType>'
            }

            $output = Invoke-CoverageGate -Path $dir -Solution $solution 6>&1
            $exitCode = @($output | Where-Object { $_ -is [int] })[-1]
            $text = ($output | Where-Object { $_ -isnot [int] }) -join "`n"

            $text | Should -BeLike '*App.Benchmarks*left out (benchmarks project, ADR-0062)*'
            $text | Should -Not -BeLike '*App.Benchmarks*FAIL*'
            $exitCode | Should -Be 0
        }

        It 'leaves a UI project''s lines out of the overall when a report has them' {
            $dir = Join-Path $TestDrive 'ui-loaded'
            New-CoberturaReport -Directory $dir -Packages @{
                'App.Core' = @(@{ File = 'c.cs'; Lines = Get-Lines 10 0 })
                'App.Maui' = @(@{ File = 'MauiProgram.cs'; Lines = Get-Lines 0 90 })
            } | Out-Null
            $solution = New-TestSolution -Name 'UiLoaded' -Projects @{
                'src/App.Core/App.Core.csproj' = ''
                'src/App.Maui/App.Maui.csproj' = '<UseMaui>true</UseMaui>'
            }

            $output = Invoke-CoverageGate -Path $dir -Solution $solution 6>&1
            $exitCode = @($output | Where-Object { $_ -is [int] })[-1]

            ($output | Where-Object { $_ -isnot [int] }) -join "`n" | Should -BeLike '*overall*100*(10/10 lines)*'
            $exitCode | Should -Be 0
        }

        It 'fails when there is no coverage report, instead of passing an empty run' {
            $dir = Join-Path $TestDrive 'none'
            New-Item -ItemType Directory -Path $dir | Out-Null

            Invoke-CoverageGate -Path $dir 6>$null | Should -Be 1
        }
    }
}
