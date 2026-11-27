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

# SEC-017 asks for a fallback authorization policy only in "a server-side app where most or all endpoints require
# authentication". The app says which it is in its part of AppHost (MostEndpointsRequireSignIn), and the authorization
# checks skip, with a reason, when most endpoints are public. A copy of a public fixture site, built with the kit's
# build files and its shared checks as an app's tests/Directory.Build.props compiles them, runs only those checks.
Describe 'the kit''s shared authorization checks' {
    BeforeAll {
        $script:site = Join-Path $TestDrive 'site'
        Copy-Item -LiteralPath (Join-Path $root 'tools' 'tests' 'fixtures' 'SharedHostChecks') -Destination $site -Recurse
        New-Item -ItemType Directory -Path (Join-Path $site 'tools') | Out-Null
        foreach ($file in 'Directory.Build.props', 'Directory.Packages.props', 'global.json', 'nuget.config', '.globalconfig',
            '.editorconfig', 'BannedSymbols.txt', 'BannedSymbols.Pure.txt', 'CodeMetricsConfig.txt') {
            Copy-Item -LiteralPath (Join-Path $root $file) -Destination $site
        }
        Copy-Item -LiteralPath (Join-Path $root 'sample' 'Directory.Build.props') -Destination (Join-Path $site 'tests')
        Copy-Item -LiteralPath (Join-Path $root 'tools' 'AppTests') -Destination (Join-Path $site 'tools') -Recurse

        # The copy isn't a git repo, so MinVer is skipped; it has no lock files, so restore isn't locked, even in CI.
        $script:build = dotnet build (Join-Path $site 'Contoso.Site.slnx') -p:MinVerSkip=true -p:RestoreLockedMode=false 2>&1 | Out-String
        $script:buildExit = $LASTEXITCODE

        # Runs one class of shared checks in the built copy, with the fixture's sign-in setting and document, and returns
        # the exit code and output. --no-ansi: on GitHub's runner the test platform colors "failed", which splits it from
        # the test's name in the text the assertions read.
        function Invoke-SiteCheck([string] $Class, [bool] $MostEndpointsRequireSignIn, [string] $Document = 'protected') {
            $env:KIT_FIXTURE_SIGN_IN = "$MostEndpointsRequireSignIn".ToLowerInvariant()
            $env:KIT_FIXTURE_DOCUMENT = $Document
            try {
                $output = dotnet test --project (Join-Path $site 'tests' 'Contoso.Site.FunctionalTests') --no-build `
                    --no-ansi --filter-class "Kit.AppTests.Functional.$Class" 2>&1 | Out-String
                [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
            }
            finally { Remove-Item Env:KIT_FIXTURE_SIGN_IN, Env:KIT_FIXTURE_DOCUMENT -ErrorAction Ignore }
        }
    }

    It 'build into a public site''s FunctionalTests project' {
        $buildExit | Should -Be 0 -Because $build
    }

    It 'skip, both of them, in an app whose endpoints are mostly public' {
        $result = Invoke-SiteCheck -Class AuthorizationTests -MostEndpointsRequireSignIn $false

        $result.Output | Should -Match 'skipped: 2\b'
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'fail an app whose endpoints mostly require sign-in but that sets no fallback policy' {
        $result = Invoke-SiteCheck -Class AuthorizationTests -MostEndpointsRequireSignIn $true

        $result.Output | Should -Match 'failed Kit\.AppTests\.Functional\.AuthorizationTests\.TheFallbackPolicyRequiresASignedInUser'
        $result.Output | Should -Match 'failed: 1\b'
    }

    # Skipping it would drop SEC-008's document check from a public API that has signed-in endpoints: only "every
    # operation not listed as anonymous is protected" rests on SEC-017's condition.
    It 'pass the document check in a public site whose one signed-in operation requires the Bearer scheme' {
        $result = Invoke-SiteCheck -Class OpenApiDocumentTests -MostEndpointsRequireSignIn $false

        $result.Output | Should -Match 'succeeded: 2\b'
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'fail the document check in a public site whose signed-in operation doesn''t require the Bearer scheme' {
        $result = Invoke-SiteCheck -Class OpenApiDocumentTests -MostEndpointsRequireSignIn $false -Document unprotected

        $result.Output | Should -Match 'failed Kit\.AppTests\.Functional\.OpenApiDocumentTests\.TheDocumentSays'
        $result.Output | Should -Match 'POST /admin/notices'
        $result.Output | Should -Not -Match '"GET /"'
    }
}
