#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Proves the repo's root build configuration is enforced, not just present.
# Each fixture project is copied with the root config files into an isolated, tagged git
# workspace, so the real files are tested and nothing builds inside the repo itself.

BeforeAll {
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

BeforeDiscovery {
    # The fixtures that must fail the build, and the diagnostic each must fail with. The 'violations fail the build'
    # tests run them, and the '.globalconfig' test checks that every rule .globalconfig turns on is among them.
    $violations = @(
        @{ Fixture = 'UsesVar'; Diagnostic = 'IDE0008'; Description = 'var, because code style is enforced on build' }
        @{ Fixture = 'NullableViolation'; Diagnostic = 'CS8600'; Description = 'a null assigned to a non-nullable type' }
        @{ Fixture = 'CatchAll'; Diagnostic = 'CA1031'; Description = 'catching Exception, a rule only AnalysisLevel latest-all turns on' }
        @{ Fixture = 'MsBuildWarning'; Diagnostic = 'KIT0001'; Description = 'a warning from an MSBuild task, which TreatWarningsAsErrors alone misses' }
        @{ Fixture = 'AwaitInLibrary'; Diagnostic = 'CA2007'; Description = 'an await without ConfigureAwait in a class library' }
        @{ Fixture = 'TooComplex'; Diagnostic = 'CA1502'; Description = 'a method with a cyclomatic complexity of 16, over the limit of 15 (CRF-008)' }
        @{ Fixture = 'TooCoupledMember'; Diagnostic = 'CA1506'; Description = 'a method coupled to 41 types, over the limit of 40 per member (CRF-008)' }
        @{ Fixture = 'TooCoupledType'; Diagnostic = 'CA1506'; Description = 'a class coupled to 96 types, over the limit of 95 per type (CRF-008)' }
        @{ Fixture = 'TooDeep'; Diagnostic = 'CA1501'; Description = 'a class 6 levels deep, over the limit of 5 (CRF-008)' }
        @{ Fixture = 'Unmaintainable'; Diagnostic = 'CA1505'; Description = 'a method with a maintainability index of 7, under the limit of 10 (CRF-008)' }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1005'; Description = 'a type with three type parameters, a rule latest-all leaves off (STY-003)' }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1021'; Description = 'an out parameter outside the Try pattern, a rule latest-all leaves off (STY-003)' }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1045'; Description = 'a ref parameter, a rule latest-all leaves off (STY-003)' }
        @{ Fixture = 'PlatformIntrinsics'; Diagnostic = 'CA1516'; Description = 'an x86-only intrinsic where a cross-platform one exists, a rule latest-all sets to none (STY-003)' }
        @{ Fixture = 'NoComVisible'; Diagnostic = 'CA1017'; Description = 'an assembly that doesn''t say whether COM sees it, a rule latest-all leaves off (STY-003)' }
        @{ Fixture = 'PInvokeOutsideNativeMethods'; Diagnostic = 'CA1060'; Description = 'a P/Invoke outside a NativeMethods class, a rule latest-all leaves off (STY-003)' }
        @{ Fixture = 'BadMetricsConfig'; Diagnostic = 'CA1509'; Description = 'a CodeMetricsConfig.txt entry the metric rules would ignore, so a typo can''t switch a limit off' }
        @{ Fixture = 'NonPublicReflection'; Diagnostic = 'RS0030'; Description = 'reading a non-public member by reflection (CRF-010)' }
        @{ Fixture = 'UnsafeAccessorUse'; Diagnostic = 'RS0030'; Description = 'reaching a non-public member through UnsafeAccessor (CRF-010)' }
        @{ Fixture = 'PrivateAccessor'; Diagnostic = 'RS0030'; Description = 'getting a property''s private setter with GetSetMethod(true) (CRF-010)' }
        @{ Fixture = 'AccessorProperty'; Diagnostic = 'RS0030'; Description = 'getting a property''s private setter through its SetMethod property (CRF-010)' }
        @{ Fixture = 'ModuleTypes'; Diagnostic = 'RS0030'; Description = 'listing a module''s types, internal ones included (CRF-010)' }
        @{ Fixture = 'ByNameDelegate'; Diagnostic = 'RS0030'; Description = 'binding a delegate to a method by name, which finds private methods too (CRF-010)' }
        @{ Fixture = 'DeclaredMembersReflection'; Diagnostic = 'RS0030'; Description = 'listing non-public members through TypeInfo.DeclaredFields, with no BindingFlags (CRF-010)' }
    )
}

Describe 'Repo build configuration' -Tag 'Build' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $configFiles = 'global.json', 'Directory.Build.props', 'Directory.Packages.props', '.editorconfig', 'nuget.config', '.globalconfig', 'CodeMetricsConfig.txt', 'BannedSymbols.txt'

        function New-FixtureWorkspace {
            param([Parameter(Mandatory)] [string] $Fixture)

            # A folder of its own under a random name, so a fixture can back several tests; the leaf keeps the
            # fixture's name.
            $workspace = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName()) $Fixture
            New-Item -ItemType Directory -Path $workspace | Out-Null
            foreach ($file in $configFiles) {
                $source = Join-Path $repoRoot $file
                if (Test-Path $source) {
                    Copy-Item -Path $source -Destination $workspace
                }
            }
            Copy-Item -Path (Join-Path $PSScriptRoot 'fixtures' $Fixture '*') -Destination $workspace -Recurse

            # Each git step must succeed, or the workspace has no commit or tag to version from; git's output goes into
            # the error, never into the path this returns (as New-TestGitRemote does, TestGit.psm1).
            foreach ($step in @(
                    @('init', '--quiet', '--initial-branch', 'main'),
                    @('-c', 'core.autocrlf=false', 'add', '--all'),
                    @('commit', '--quiet', '--message', 'fixture'),
                    @('tag', 'v1.2.3'))) {
                $output = git -C $workspace @step 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) { throw "git $($step -join ' ') failed in ${workspace}: $($output.Trim())" }
            }
            $workspace
        }

        function Invoke-FixtureBuild {
            param([Parameter(Mandatory)] [string] $Workspace, [string] $Project = '')

            $target = if ($Project) { Join-Path $Workspace $Project } else { $Workspace }
            $output = dotnet build $target --configuration Release --nologo 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
    }

    Context 'clean code' {
        BeforeAll {
            $workspace = New-FixtureWorkspace -Fixture 'Clean'
            $build = Invoke-FixtureBuild -Workspace $workspace
        }

        It 'builds with no warnings or errors' {
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }

        It 'takes its version from the v-prefixed git tag (MinVer)' {
            $assembly = Join-Path $workspace 'bin' 'Release' 'net10.0' 'Clean.dll'
            [System.Diagnostics.FileVersionInfo]::GetVersionInfo($assembly).ProductVersion | Should -Match '^1\.2\.3\+'
        }

        It 'writes a package lock file' {
            Join-Path $workspace 'packages.lock.json' | Should -Exist
        }
    }

    # Several rows build the same fixture (LegacyDesign covers three rules), so each build needs a workspace of its own,
    # or the next row finds the last one's folder and fails before it builds (CI on PR 36).
    Context 'fixture workspaces' {
        # GitHub Actions runs pwsh with $ErrorActionPreference = 'stop', so the test does too.
        It 'gives each build of the same fixture a workspace of its own' {
            $ErrorActionPreference = 'Stop'
            $first = New-FixtureWorkspace -Fixture 'Clean'

            { $script:second = New-FixtureWorkspace -Fixture 'Clean' } | Should -Not -Throw
            @($script:second) | Should -HaveCount 1 -Because 'the function returns only the workspace path'
            $script:second | Should -Not -Be $first -Because 'a reused folder would share one build between rows'
            $first | Should -Exist
        }

        # A workspace with no commit or no tag would still build, and only MinVer's version would show it.
        It 'stops when a git step fails, instead of returning an untagged workspace' {
            $savedDate = $env:GIT_COMMITTER_DATE
            try {
                $env:GIT_COMMITTER_DATE = 'not a date'

                { New-FixtureWorkspace -Fixture 'Clean' } | Should -Throw -ExpectedMessage '*git commit*'
            }
            finally {
                $env:GIT_COMMITTER_DATE = $savedDate
            }
        }
    }

    Context 'violations fail the build' {
        It 'rejects <Description> (<Diagnostic>)' -ForEach $violations {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)

            $build.ExitCode | Should -Not -Be 0 -Because $build.Output
            $build.Output | Should -Match "error $Diagnostic"
        }
    }

    # ADR-0043: the metric limits sit exactly where the ADR puts them, not lower.
    Context 'code at the metric limits' {
        It 'builds <Description>' -ForEach @(
            @{ Fixture = 'AtComplexityLimit'; Description = 'a method with a cyclomatic complexity of 15' }
            @{ Fixture = 'AtMemberCouplingLimit'; Description = 'a method coupled to 40 types' }
            @{ Fixture = 'AtTypeCouplingLimit'; Description = 'a class coupled to 95 types' }
            @{ Fixture = 'AtInheritanceLimit'; Description = 'a class 5 levels deep' }
            @{ Fixture = 'AtMaintainabilityLimit'; Description = 'a method with a maintainability index of 10' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)

            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # ADR-0029: CA2007 is for libraries; Microsoft advises suppressing it for application code.
    Context 'CA2007 applies to libraries only' {
        It 'allows an await without ConfigureAwait in <Description>' -ForEach @(
            @{ Fixture = 'AwaitInApp'; Project = ''; Description = 'an app' }
            @{ Fixture = 'AwaitInTests'; Project = 'Widgets.Tests'; Description = 'a test project (a library in a *Tests folder)' }
            @{ Fixture = 'AwaitInNestedTests'; Project = 'tests/Widgets.Tests'; Description = 'a test project nested under tests/' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture) -Project $Project

            $build.Output | Should -Not -Match 'CA2007'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }
}

# The banned-API analyzer ignores an entry that names no symbol, so a typo in BannedSymbols.txt would lift a ban
# without a sound (review 1 of PR 36). Each documentation comment ID must resolve on the runtime these tests use.
Describe 'BannedSymbols.txt' {
    BeforeAll {
        $bannedPath = Join-Path $PSScriptRoot '..' '..' 'BannedSymbols.txt'

        function Find-KitType {
            param([Parameter(Mandatory)] [string] $FullName)

            # Load the assembly named by the namespace, or a prefix of it, so types outside CoreLib resolve too.
            $parts = $FullName.Split('.')
            for ($length = $parts.Count - 1; $length -ge 1; $length--) {
                try { [void][Reflection.Assembly]::Load(($parts[0..($length - 1)] -join '.')) } catch [IO.FileNotFoundException] { }
            }
            [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType($FullName, $false) } | Where-Object { $_ } | Select-Object -First 1
        }

        function Test-DocumentationId {
            param([Parameter(Mandatory)] [string] $Id)

            if ($Id -notmatch '^(?<kind>[TFPM]):(?<name>[^(]+)(\((?<params>.*)\))?$') { return $false }
            if ($Matches['kind'] -in 'T', 'F', 'P' -and $Matches['params']) { return $false }
            $name = $Matches['name']
            if ($Matches['kind'] -eq 'T') { return $null -ne (Find-KitType $name) }

            # Roslyn finds only members declared on the named type, so an inherited member mustn't count, and it compares
            # with case. Generic methods (`0), ref or out parameters (@), nested types (. where FullName has +) and
            # generic type arguments ({...}) aren't parsed; such an entry fails here until this function learns them.
            $declared = [Reflection.BindingFlags]'Public, NonPublic, Static, Instance, DeclaredOnly'
            $owner = Find-KitType ($name.Substring(0, $name.LastIndexOf('.')))
            $member = $name.Substring($name.LastIndexOf('.') + 1)
            if ($null -eq $owner) { return $false }
            switch ($Matches['kind']) {
                'F' { return $null -ne $owner.GetField($member, $declared) }
                'P' { return $null -ne $owner.GetProperty($member, $declared) }
                'M' {
                    $wanted = if ($Matches['params']) { $Matches['params'].Split(',') } else { @() }
                    return [bool]($owner.GetMethods($declared) | Where-Object {
                        $_.Name -ceq $member -and ((@($_.GetParameters() | ForEach-Object { $_.ParameterType.FullName }) -join ',') -ceq ($wanted -join ','))
                    })
                }
            }
        }
    }

    # Review 4 of PR 36: documentation comment IDs are case-sensitive, so a mis-cased entry bans nothing.
    It 'rejects an ID that differs from the symbol only in case' {
        Test-DocumentationId -Id 'M:System.Reflection.Module.gettypes' | Should -BeFalse
        Test-DocumentationId -Id 'M:System.Reflection.Module.FindTypes(System.Reflection.typefilter,System.object)' | Should -BeFalse
    }

    It 'names only symbols that exist' {
        $ids = @(Get-Content -LiteralPath $bannedPath | Where-Object { $_ -and $_ -notmatch '^\s*//' } | ForEach-Object { $_.Split(';')[0].Trim() })

        $ids.Count | Should -BeGreaterThan 0
        foreach ($id in $ids) {
            Test-DocumentationId -Id $id | Should -BeTrue -Because "'$id' should name a real symbol, or the ban does nothing"
        }
    }
}

# CodeMetricsConfig.txt is the one source of the metric limits; CRF-008 states them for readers, so the two must agree
# (CRF-003, review 1 of PR 36).
Describe 'CodeMetricsConfig.txt' {
    It 'sets exactly the limits CRF-008 states' {
        $root = Join-Path $PSScriptRoot '..' '..'
        $statement = (Select-String -LiteralPath (Join-Path $root 'docs' 'standards' 'craft.md') -Pattern '^\s*statement: "Stay within the metric limits:.*').Line
        $config = @{}
        foreach ($line in Get-Content -LiteralPath (Join-Path $root 'CodeMetricsConfig.txt')) {
            if ($line -match '^\s*(?<key>CA\d{4}(\(\w+\))?)\s*:\s*(?<limit>\d+)\s*$') { $config[$Matches['key']] = $Matches['limit'] }
        }
        $stated = [ordered]@{
            'CA1502'         = 'cyclomatic complexity (\d+) per method'
            'CA1506(Method)' = 'class coupling (\d+) types per member'
            'CA1506(Type)'   = 'and (\d+) per type'
            'CA1501'         = 'inheritance (\d+) levels deep'
            'CA1505'         = 'maintainability index of at least (\d+)'
        }

        $statement | Should -Not -BeNullOrEmpty
        @($config.Keys | Sort-Object) | Should -Be @($stated.Keys | Sort-Object) -Because 'every limit in the file is one CRF-008 states'
        foreach ($key in $stated.Keys) {
            $statement | Should -Match $stated[$key]
            [regex]::Match($statement, $stated[$key]).Groups[1].Value | Should -Be $config[$key] -Because "CRF-008 and CodeMetricsConfig.txt should agree on $key"
        }
    }
}

# STY-003: every rule .globalconfig turns on has a fixture that must fail with it, so a rule added there without one, or
# one that silently doesn't fire, can't slip in (review 4 of PR 36).
Describe '.globalconfig' {
    BeforeAll {
        # The IDs of the rules these lines turn on: any severity but none. Like Roslyn's analyzer config parser, it takes
        # '=' or ':' between key and value, ignores case, and drops a comment that starts with '#' or ';'. Unlike it, it
        # reads a rule ID as word characters only, which every CA, IDE and RS ID is.
        function Get-EnabledRule([string[]] $Line) {
            foreach ($text in $Line) {
                $setting = ($text -replace '[#;].*$', '').Trim()
                if ($setting -match '^dotnet_diagnostic\.(?<id>\w+)\.severity\s*[=:]\s*(?<severity>\w+)$' -and $Matches['severity'] -ne 'none') {
                    $Matches['id']
                }
            }
        }
    }

    It 'reads <Line> as turning on <Expected>' -ForEach @(
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = error'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity: warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning # a trailing comment'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning ; a trailing comment'; Expected = 'CA1014' }
        @{ Line = '  dotnet_diagnostic.CA1014.severity = warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = none'; Expected = $null }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = None'; Expected = $null }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = none # off for now'; Expected = $null }
        @{ Line = '# dotnet_diagnostic.CA1014.severity = warning'; Expected = $null }
    ) {
        Get-EnabledRule -Line $Line | Should -Be $Expected
    }

    # Any severity but none counts as on, so suggestion, silent and default ask for a fixture too, erring toward one;
    # the table is the one the fixture builds run from, so a row that's
    # commented out doesn't count.
    It 'turns on only rules that have a failing fixture' -ForEach @(@{ Violations = $violations }) {
        $root = Join-Path $PSScriptRoot '..' '..'
        $turnedOn = @(Get-EnabledRule -Line (Get-Content -LiteralPath (Join-Path $root '.globalconfig')))
        $tested = @($Violations | ForEach-Object { $_.Diagnostic })

        $turnedOn.Count | Should -BeGreaterThan 0
        foreach ($rule in $turnedOn) {
            $tested | Should -Contain $rule -Because "$rule is on in .globalconfig, so a fixture should prove it fires"
        }
    }
}