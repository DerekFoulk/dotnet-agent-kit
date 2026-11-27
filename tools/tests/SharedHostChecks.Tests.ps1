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
# authentication". Each host says which it is in the app's part of AppHost (MostEndpointsRequireSignIn): the
# authorization checks skip, with a reason, when most endpoints are public, and the document check looks only at the
# operations whose endpoints require authorization. A copy of a public fixture site, built with the kit's build files
# and its shared checks as an app's tests/Directory.Build.props compiles them, runs those two classes of checks.
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

        # Runs one class of shared checks in the built copy, with the fixture's sign-in settings and document, and
        # returns the exit code and output. --no-ansi: on GitHub's runner the test platform colors "failed", which splits
        # it from the test's name in the text the assertions read.
        function Invoke-SiteCheck([string] $Class, [bool] $MostEndpointsRequireSignIn, [string] $Document = 'protected',
            [bool] $SignsUsersIn = $true, [switch] $PublicOnly, [switch] $FallbackOnly) {
            $env:KIT_FIXTURE_SIGN_IN = "$MostEndpointsRequireSignIn".ToLowerInvariant()
            $env:KIT_FIXTURE_SIGNS_USERS_IN = "$SignsUsersIn".ToLowerInvariant()
            $env:KIT_FIXTURE_PUBLIC_ONLY = "$PublicOnly".ToLowerInvariant()
            $env:KIT_FIXTURE_FALLBACK_ONLY = "$FallbackOnly".ToLowerInvariant()
            $env:KIT_FIXTURE_DOCUMENT = $Document
            try {
                $output = dotnet test --project (Join-Path $site 'tests' 'Contoso.Site.FunctionalTests') --no-build `
                    --no-ansi --filter-class "Kit.AppTests.Functional.$Class" 2>&1 | Out-String
                [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
            }
            finally { Remove-Item Env:KIT_FIXTURE_SIGN_IN, Env:KIT_FIXTURE_SIGNS_USERS_IN, Env:KIT_FIXTURE_PUBLIC_ONLY, Env:KIT_FIXTURE_FALLBACK_ONLY, Env:KIT_FIXTURE_DOCUMENT -ErrorAction Ignore }
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
    It 'pass the document check in a public site whose signed-in operations require the Bearer scheme' {
        $result = Invoke-SiteCheck -Class OpenApiDocumentTests -MostEndpointsRequireSignIn $false

        $result.Output | Should -Match 'succeeded: 2\b'
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    # The admin group is mapped without a leading slash, its feed endpoint answers every method, and its status endpoint
    # allows anonymous callers again, so each is matched to its operation as the document names it. The staff endpoint
    # is protected by its own requirement metadata alone.
    It 'fail the document check in a public site whose signed-in operations don''t require the Bearer scheme' {
        $result = Invoke-SiteCheck -Class OpenApiDocumentTests -MostEndpointsRequireSignIn $false -Document unprotected

        $result.Output | Should -Match 'failed Kit\.AppTests\.Functional\.OpenApiDocumentTests\.TheDocumentSays'
        $result.Output | Should -Match '"post /admin/notices"'
        $result.Output | Should -Match '"get /admin/feed"'
        $result.Output | Should -Match '"get /staff"'
        $result.Output | Should -Not -Match '"get /"'
        $result.Output | Should -Not -Match '"get /admin/status"'
    }

    # Declared as signed-in, every operation not on an anonymous route must be protected. The fixture lists its group's
    # anonymous route as AuthorizationTests reads it, RawText without the leading slash, which the document writes.
    It 'hold every operation but the anonymous routes, slash or not, in a host whose endpoints mostly require sign-in' {
        $result = Invoke-SiteCheck -Class OpenApiDocumentTests -MostEndpointsRequireSignIn $true

        $result.Output | Should -Match 'failed Kit\.AppTests\.Functional\.OpenApiDocumentTests\.TheDocumentSays'
        $result.Output | Should -Match '"get /"'
        $result.Output | Should -Not -Match '"get /admin/status"'
    }

    It 'pass the document check in a public site whose document describes only its public operations, with no Bearer scheme' {
        $result = Invoke-SiteCheck -Class OpenApiDocumentTests -MostEndpointsRequireSignIn $false -Document public

        $result.Output | Should -Match 'succeeded: 2\b'
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    # A host that signs nobody in, such as a public website or a public read-only API, has no signed-in user for SEC-008's
    # token checks to compare a bad token with, so all five of them skip, with a reason. The check of that statement
    # passes: none of its endpoints requires authorization.
    It 'skip the token checks, all five, in a host that signs nobody in' {
        $result = Invoke-SiteCheck -Class TokenTests -MostEndpointsRequireSignIn $false -SignsUsersIn $false -PublicOnly

        $result.Output | Should -Match 'skipped: 5\b'
        $result.Output | Should -Match 'The host signs nobody in \(HostUnderTest\.SignsUsersIn\)'
        $result.Output | Should -Match 'succeeded: 1\b'
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    # Saying it signs nobody in would skip the token checks of a host that does, so the statement is checked against the
    # host's endpoints: one that requires authorization needs a signed-in user. The check names each such endpoint.
    It 'fail a host that says it signs nobody in but has endpoints that require authorization' {
        $result = Invoke-SiteCheck -Class TokenTests -MostEndpointsRequireSignIn $false -SignsUsersIn $false

        $result.Output | Should -Match 'failed Kit\.AppTests\.Functional\.TokenTests\.AHostThatSignsNobodyInHasNoEndpointThatRequiresAuthorization'
        $result.Output | Should -Match '"POST admin/notices"'
        $result.Output | Should -Match '"\* admin/feed"'
        $result.Output | Should -Match '"GET /staff"'
        $result.Output | Should -Not -Match '"GET admin/status"'
    }

    # Most endpoints can't require sign-in in a host that signs nobody in, so the two statements are checked together.
    It 'fail a host that says it signs nobody in and that most of its endpoints require sign-in' {
        $result = Invoke-SiteCheck -Class TokenTests -MostEndpointsRequireSignIn $true -SignsUsersIn $false -PublicOnly

        $result.Output | Should -Match 'failed Kit\.AppTests\.Functional\.TokenTests\.AHostThatSignsNobodyInHasNoEndpointThatRequiresAuthorization'
        $result.Output | Should -Match 'Expected described\.MostEndpointsRequireSignIn to be False'
    }

    # A host that signs users in, with a sign-in that takes any bearer token without checking its signature: the token
    # checks run as before and fail it for each token it lets through, with a 200. The control and the missing token,
    # which the host answers with a 401 Problem, pass.
    It 'fail a host that signs users in but lets an unsigned token through' {
        $result = Invoke-SiteCheck -Class TokenTests -MostEndpointsRequireSignIn $false
        $row = 'failed Kit\.AppTests\.Functional\.TokenTests\.ACallerWithoutAValidTokenIsA401Problem\(host: "Contoso\.Site", caller: "{0}"\)'

        $result.Output | Should -Match ($row -f 'an unsigned token')
        $result.Output | Should -Match ($row -f 'a token whose claims changed after it was signed')
        $result.Output | Should -Match ($row -f "a token signed with a key the host doesn't trust")
        $result.Output | Should -Match 'to be HttpStatusCode\.Unauthorized \{value: 401\} because an unsigned token is no signed-in user, but found HttpStatusCode\.OK'
        $result.Output | Should -Not -Match ($row -f 'no token')
        $result.Output | Should -Not -Match 'failed Kit\.AppTests\.Functional\.TokenTests\.TheSignedInClientsBearerTokenGetsThrough'
        $result.Output | Should -Match 'failed: 3\b'
        $result.Output | Should -Match 'succeeded: 2\b'
    }

    # A fallback policy protects every endpoint without any metadata showing it, as SEC-017 sets one, so the statement is
    # checked against the host's sign-in too: a host that signs nobody in has no authentication scheme. The check names
    # each scheme it finds.
    It 'fail a host that says it signs nobody in but has an authentication scheme' {
        $result = Invoke-SiteCheck -Class TokenTests -MostEndpointsRequireSignIn $false -SignsUsersIn $false -PublicOnly -FallbackOnly

        $result.Output | Should -Match 'failed Kit\.AppTests\.Functional\.TokenTests\.AHostThatSignsNobodyIn'
        $result.Output | Should -Match 'because an authentication scheme signs users in \(HostUnderTest\.SignsUsersIn\), but found .*\{"Bearer"\}'
    }
}
