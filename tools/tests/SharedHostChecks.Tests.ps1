#Requires -Version 7.6
# GAP-037, ADR-0081: tests/Directory.Build.props (the kit's sample/Directory.Build.props) compiles the kit's shared host
# checks, tools/AppTests/Functional, into every *.FunctionalTests project, as it compiles the architecture tests into
# every *.Architecture.Tests project. The sample's FunctionalTests runs them in the kit's CI.

BeforeAll {
    $script:root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..'))
    $script:shared = Join-Path $root 'tools' 'AppTests' 'Functional'
}

Describe 'the kit''s shared host checks' {
    It 'compile, every one, into the sample''s FunctionalTests project' {
        $project = Join-Path $root 'sample' 'tests' 'Bookmarks.FunctionalTests' 'Bookmarks.FunctionalTests.csproj'
        $checks = @(Get-ChildItem -LiteralPath $shared -Filter '*.cs' -Recurse | ForEach-Object FullName)

        $output = @(& dotnet msbuild $project -nologo -getItem:Compile 2>&1)

        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        $compiled = @(($output -join "`n" | ConvertFrom-Json).Items.Compile | ForEach-Object { [IO.Path]::GetFullPath($_.FullPath) })
        $checks.Count | Should -BeGreaterThan 0 -Because 'tools/AppTests/Functional holds the host checks'
        $checks | Where-Object { $_ -notin $compiled } | Should -BeNullOrEmpty -Because 'every shared host check runs in a FunctionalTests project'
    }
}
