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
    # tests run them. GlobalConfig marks a rule that .globalconfig turns on, and the '.globalconfig' test checks that the
    # marked rules are exactly the ones it turns on.
    $violations = @(
        @{ Fixture = 'UsesVar'; Diagnostic = 'IDE0008'; Description = 'var, because code style is enforced on build' }
        @{ Fixture = 'NullableViolation'; Diagnostic = 'CS8600'; Description = 'a null assigned to a non-nullable type' }
        @{ Fixture = 'CatchAll'; Diagnostic = 'CA1031'; Description = 'catching Exception, a rule only AnalysisLevel latest-all turns on' }
        @{ Fixture = 'MsBuildWarning'; Diagnostic = 'KIT0001'; Description = 'a warning from an MSBuild task, which TreatWarningsAsErrors alone misses' }
        @{ Fixture = 'AwaitInLibrary'; Diagnostic = 'CA2007'; Description = 'an await without ConfigureAwait in a class library' }
        @{ Fixture = 'TooComplex'; Diagnostic = 'CA1502'; Description = 'a method with a cyclomatic complexity of 16, over the limit of 15 (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'TooCoupledMember'; Diagnostic = 'CA1506'; Description = 'a method coupled to 41 types, over the limit of 40 per member (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'TooCoupledType'; Diagnostic = 'CA1506'; Description = 'a class coupled to 96 types, over the limit of 95 per type (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'TooDeep'; Diagnostic = 'CA1501'; Description = 'a class 6 levels deep, over the limit of 5 (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'Unmaintainable'; Diagnostic = 'CA1505'; Description = 'a method with a maintainability index of 7, under the limit of 10 (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1005'; Description = 'a type with three type parameters, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1021'; Description = 'an out parameter outside the Try pattern, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1045'; Description = 'a ref parameter, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'PlatformIntrinsics'; Diagnostic = 'CA1516'; Description = 'an x86-only intrinsic where a cross-platform one exists, a rule latest-all sets to none (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'NoComVisible'; Diagnostic = 'CA1017'; Description = 'an assembly that doesn''t say whether COM sees it, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'NoClsCompliant'; Diagnostic = 'CA1014'; Description = 'an assembly that doesn''t say whether it''s CLS-compliant, a rule latest-all leaves off (STY-003, ADR-0049)'; GlobalConfig = $true }
        @{ Fixture = 'PInvokeOutsideNativeMethods'; Diagnostic = 'CA1060'; Description = 'a P/Invoke outside a NativeMethods class, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'BadMetricsConfig'; Diagnostic = 'CA1509'; Description = 'a CodeMetricsConfig.txt entry the metric rules would ignore, so a typo can''t switch a limit off'; GlobalConfig = $true }
        @{ Fixture = 'NonPublicReflection'; Diagnostic = 'RS0030'; Description = 'reading a non-public member by reflection (CRF-010)' }
        @{ Fixture = 'UnsafeAccessorUse'; Diagnostic = 'RS0030'; Description = 'reaching a non-public member through UnsafeAccessor (CRF-010)' }
        @{ Fixture = 'PrivateAccessor'; Diagnostic = 'RS0030'; Description = 'getting a property''s private setter with GetSetMethod(true) (CRF-010)' }
        @{ Fixture = 'AccessorProperty'; Diagnostic = 'RS0030'; Description = 'getting a property''s private setter through its SetMethod property (CRF-010)' }
        @{ Fixture = 'ModuleTypes'; Diagnostic = 'RS0030'; Description = 'listing a module''s types, internal ones included (CRF-010)' }
        @{ Fixture = 'ByNameDelegate'; Diagnostic = 'RS0030'; Description = 'binding a delegate to a method by name, which finds private methods too (CRF-010)' }
        @{ Fixture = 'DeclaredMembersReflection'; Diagnostic = 'RS0030'; Description = 'listing non-public members through TypeInfo.DeclaredFields, with no BindingFlags (CRF-010)' }
        @{ Fixture = 'TypeInitializerUse'; Diagnostic = 'RS0030'; Description = 'reading a type''s static constructor, which is always private, through Type.TypeInitializer (CRF-010)' }
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
            # the error, never into the path this returns (as New-TestGitRemote does, TestGit.psm1). The exit codes are
            # read here, so pwsh mustn't turn one into its own error first (as Test-RepoGitIgnore does).
            $PSNativeCommandUseErrorActionPreference = $false
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

            # A failed build is an answer the tests read, so its exit code mustn't become pwsh's error.
            $PSNativeCommandUseErrorActionPreference = $false
            $target = if ($Project) { Join-Path $Workspace $Project } else { $Workspace }
            $output = dotnet build $target --configuration Release --nologo 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
    }

    # SUP-012: nuget.config requires every package to carry a signature from a trusted signer, nuget.org's repository
    # signature. The clean fixture restores nuget.org's packages under that policy; this one restores an unsigned
    # package from a local folder, which the policy must refuse.
    Context 'package signatures' {
        BeforeAll {
            $workspace = New-FixtureWorkspace -Fixture 'UnsignedPackage'

            # A package with no signature: a .nupkg is a zip with a .nuspec and a file for the target framework.
            $local = Join-Path $workspace 'local-packages'
            New-Item -ItemType Directory -Path $local | Out-Null
            $staging = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Path (Join-Path $staging 'lib' 'net10.0') | Out-Null
            Set-Content -Path (Join-Path $staging 'lib' 'net10.0' '_._') -Value ''
            Set-Content -Path (Join-Path $staging 'Kit.Unsigned.nuspec') -Value @'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>Kit.Unsigned</id>
    <version>1.0.0</version>
    <authors>kit-tests</authors>
    <description>An unsigned package for the signature policy test.</description>
  </metadata>
</package>
'@
            Compress-Archive -Path (Join-Path $staging '*') -DestinationPath (Join-Path $local 'kit.unsigned.1.0.0.zip')
            Rename-Item -Path (Join-Path $local 'kit.unsigned.1.0.0.zip') -NewName 'kit.unsigned.1.0.0.nupkg'

            # The kit's config, plus that folder as a source for this one package only.
            $config = Join-Path $workspace 'nuget.config'
            [xml] $xml = Get-Content -Raw -Path $config
            $source = $xml.CreateElement('add'); $source.SetAttribute('key', 'local'); $source.SetAttribute('value', 'local-packages')
            [void] $xml.configuration.packageSources.AppendChild($source)
            $mapping = $xml.CreateElement('packageSource'); $mapping.SetAttribute('key', 'local')
            $pattern = $xml.CreateElement('package'); $pattern.SetAttribute('pattern', 'Kit.Unsigned')
            [void] $mapping.AppendChild($pattern)
            [void] $xml.configuration.packageSourceMapping.AppendChild($mapping)
            $xml.Save($config)

            $props = Join-Path $workspace 'Directory.Packages.props'
            (Get-Content -Raw -Path $props) -replace '</Project>', "  <ItemGroup>`n    <PackageVersion Include=`"Kit.Unsigned`" Version=`"1.0.0`" />`n  </ItemGroup>`n</Project>" |
                Set-Content -Path $props -NoNewline

            # NuGet checks a signature when it extracts a package, so this build gets an empty global packages folder
            # of its own: a copy already extracted on the machine would skip the check, and this one stays out of it.
            $savedPackages = $env:NUGET_PACKAGES
            $env:NUGET_PACKAGES = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            try { $build = Invoke-FixtureBuild -Workspace $workspace }
            finally { $env:NUGET_PACKAGES = $savedPackages }
        }

        # .NET doesn't verify signatures during a restore on macOS (SUP-012's exception), so there the unsigned package
        # restores and this would fail with the configuration right (Copilot's review of PR #69).
        It 'refuses a package that no trusted signer signed (NU3004)' -Skip:$IsMacOS {
            $build.ExitCode | Should -Not -Be 0 -Because 'the policy refuses unsigned packages'
            $build.Output | Should -Match 'NU3004' -Because $build.Output
        }

        # Copilot's review of PR #69: .NET doesn't verify signatures during a restore on macOS, and Microsoft advises
        # leaving it so (https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification). SUP-012 says
        # so plainly, and no workflow may turn verification off where it does run (Windows always, Linux by default).
        It 'SUP-012 states its macOS exception' {
            $text = Get-Content -Raw -Path (Join-Path $repoRoot 'docs' 'standards' 'supply-chain.md')
            $statement = [regex]::Match($text, '(?m)^  - id: SUP-012\r?\n    statement: "(?<s>[^"]+)"').Groups['s'].Value
            $statement | Should -Not -BeNullOrEmpty
            $statement | Should -Match 'macOS'
        }

        It 'no workflow turns NuGet signature verification off' {
            foreach ($workflow in Get-ChildItem -Path (Join-Path $repoRoot '.github' 'workflows') -Filter '*.yml') {
                Get-Content -Raw -Path $workflow.FullName | Should -Not -Match 'DOTNET_NUGET_SIGNATURE_VERIFICATION\s*:\s*["'']?false' -Because $workflow.Name
            }
        }

        # Copilot's review of PR #69: with every package already extracted on the machine, a wrong certificate list
        # passed every test. A cold cache extracts, and so checks, each of nuget.org's packages the fixture uses.
        It 'restores nuget.org''s packages under the policy with a cold cache' {
            $clean = New-FixtureWorkspace -Fixture 'Clean'
            $savedPackages = $env:NUGET_PACKAGES
            $env:NUGET_PACKAGES = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            try { $cold = Invoke-FixtureBuild -Workspace $clean }
            finally { $env:NUGET_PACKAGES = $savedPackages }

            $cold.ExitCode | Should -Be 0 -Because $cold.Output
        }

        # Copilot's review of PR #69: NuGet merges trustedSigners from every config above the repo, the user's and the
        # machine's, so a signer trusted there would be trusted here too unless the repo's config clears them.
        It 'trusts only nuget.org''s repository, whatever a config above the repo adds' {
            $isolated = New-FixtureWorkspace -Fixture 'Clean'
            Set-Content -Path (Join-Path (Split-Path -Path $isolated -Parent) 'nuget.config') -Value @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <trustedSigners>
    <author name="kit-test-extra-signer">
      <certificate fingerprint="AA12DA22A49BCE7D5C1AE64CC1F3D892F150DA76140F210ABD2CBFFCA2C18A27" hashAlgorithm="SHA256" allowUntrustedRoot="false" />
    </author>
  </trustedSigners>
</configuration>
'@
            $PSNativeCommandUseErrorActionPreference = $false
            Push-Location $isolated
            try { $list = dotnet nuget trust list 2>&1 | Out-String }
            finally { Pop-Location }

            $list | Should -Match 'nuget\.org' -Because $list
            $list | Should -Not -Match 'kit-test-extra-signer' -Because $list
        }
    }

    # STY-002 (rules audit, owner 2026-11-12): var is allowed where the type is named on the right side (a new, a cast),
    # as in dotnet/runtime's .editorconfig; everywhere else the type is written (the UsesVar fixture).
    Context 'var where the type is named on the right' {
        It 'builds with no warnings or errors' {
            $workspace = New-FixtureWorkspace -Fixture 'VarWhenApparent'
            $build = Invoke-FixtureBuild -Workspace $workspace

            $build.ExitCode | Should -Be 0 -Because $build.Output
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

        # A workspace with no commit or no tag would still build, and only MinVer's version would show it. With
        # $PSNativeCommandUseErrorActionPreference on (a profile can turn it on), pwsh's own NativeCommandExitException
        # mustn't replace the error that names the git step (review 10 of PR 36).
        It 'stops when a git step fails, instead of returning an untagged workspace (native exit codes as errors: <NativeErrors>)' -ForEach @(
            @{ NativeErrors = $false }
            @{ NativeErrors = $true }
        ) {
            $ErrorActionPreference = 'Stop'
            $PSNativeCommandUseErrorActionPreference = $NativeErrors
            $savedDate = $env:GIT_COMMITTER_DATE
            try {
                $env:GIT_COMMITTER_DATE = 'not a date'

                { New-FixtureWorkspace -Fixture 'Clean' } | Should -Throw -ExpectedMessage '*git commit*'
            }
            finally {
                $env:GIT_COMMITTER_DATE = $savedDate
            }
        }

        # A build that fails is the answer the violation tests read, so it comes back as an exit code, not pwsh's error.
        It 'returns a failed build''s exit code and output, even where native exit codes are errors' {
            $ErrorActionPreference = 'Stop'
            $PSNativeCommandUseErrorActionPreference = $true
            $workspace = New-FixtureWorkspace -Fixture 'UsesVar'

            $build = try { Invoke-FixtureBuild -Workspace $workspace } catch { [pscustomobject]@{ ExitCode = 'threw'; Output = $_.Exception.Message } }

            $build.ExitCode | Should -BeOfType [int] -Because $build.Output
            $build.ExitCode | Should -Not -Be 0
            $build.Output | Should -Match 'error IDE0008'
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

    # ADR-0062: BenchmarkDotNet runs only public benchmark classes, so CA1515 (make an app's public types internal) is
    # off in a benchmarks project, whose name ends in .Benchmarks, and nowhere else.
    Context 'CA1515 is off in benchmarks projects only' {
        It 'allows a public class in a benchmarks project' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'PublicTypeInBenchmarks') -Project 'tests/Widgets.Benchmarks'

            $build.Output | Should -Not -Match 'CA1515'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }

        It 'still rejects a public class in any other app' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'PublicTypeInApp') -Project 'src/Widgets.App'

            $build.Output | Should -Match 'CA1515'
            $build.ExitCode | Should -Not -Be 0
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
        # The IDs of the rules these lines turn on: any severity but none. It reads them as Roslyn's analyzer config
        # parser does, at dotnet/roslyn e141f0d31c796c99f5a7c31e54e0b597c03381be:
        #   https://github.com/dotnet/roslyn/blob/e141f0d31c796c99f5a7c31e54e0b597c03381be/src/Compilers/Core/Portable/CommandLine/AnalyzerConfig.cs
        #   https://github.com/dotnet/roslyn/blob/e141f0d31c796c99f5a7c31e54e0b597c03381be/src/Compilers/Core/Portable/CommandLine/AnalyzerConfigSet.cs
        # A key is [\w.-]+ ('_' is in \w), then '=' or ':', then the value; a comment starts at the first '#' or ';';
        # case doesn't matter, and the last value a key gets wins; the ID is everything between dotnet_diagnostic. and
        # .severity; and the severities are TryParseSeverity's. It stops at any other line but is_global and
        # global_level, so nothing in the file turns rules on unseen: a section, a bulk severity, an option, a typo.
        function Get-EnabledRule([string[]] $Line) {
            $severities = 'default', 'error', 'warning', 'suggestion', 'silent', 'refactoring', 'none'
            $severityOf = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($text in $Line) {
                $setting = ($text -replace '[#;].*$', '').Trim()
                if (-not $setting) { continue }
                $unrecognised = "Get-EnabledRule doesn't recognise this .globalconfig line: '$text'"
                if ($setting -notmatch '^(?<key>[\w.-]+)\s*[=:]\s*(?<value>.*)$') { throw $unrecognised }
                $key, $value = $Matches['key'], $Matches['value']
                if ($key -in 'is_global', 'global_level') { continue }
                if ($key -notmatch '^dotnet_diagnostic\.(?<id>[\w.-]+)\.severity$' -or $value -notin $severities) { throw $unrecognised }
                $severityOf[$Matches['id']] = $value
            }
            $severityOf.Keys | Where-Object { $severityOf[$_] -ne 'none' }
        }
    }

    It 'reads <Line> as turning on <Expected>' -ForEach @(
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = error'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = suggestion'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = silent'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = refactoring'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = default'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity: warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning # a trailing comment'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning ; a trailing comment'; Expected = 'CA1014' }
        @{ Line = '  dotnet_diagnostic.CA1014.severity = warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = none'; Expected = $null }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = None'; Expected = $null }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = none # off for now'; Expected = $null }
        @{ Line = '# dotnet_diagnostic.CA1014.severity = warning'; Expected = $null }
        # Roslyn's key takes '.' and '-' too, and everything between dotnet_diagnostic. and .severity is the ID.
        @{ Line = 'dotnet_diagnostic.My-Rule.v2.severity = warning'; Expected = 'My-Rule.v2' }
        @{ Line = 'is_global = true'; Expected = $null }
        @{ Line = 'global_level = 100'; Expected = $null }
    ) {
        { $script:enabled = Get-EnabledRule -Line $Line } | Should -Not -Throw
        $script:enabled | Should -Be $Expected
    }

    # Roslyn keeps the last value a key gets, and lowercases keys first, so a later line turns a rule back off.
    It 'lets the last line for a rule win: <Description>' -ForEach @(
        @{ Description = 'on, then off'; Lines = @('dotnet_diagnostic.CA1014.severity = warning', 'dotnet_diagnostic.CA1014.severity = none'); Expected = @() }
        @{ Description = 'on, then off in other case'; Lines = @('dotnet_diagnostic.CA1014.severity = warning', 'DOTNET_DIAGNOSTIC.ca1014.SEVERITY = none'); Expected = @() }
        @{ Description = 'off, then on'; Lines = @('dotnet_diagnostic.CA1014.severity = none', 'dotnet_diagnostic.CA1014.severity = error'); Expected = @('CA1014') }
        @{ Description = 'on twice'; Lines = @('dotnet_diagnostic.CA1014.severity = warning', 'dotnet_diagnostic.CA1014.severity = error'); Expected = @('CA1014') }
    ) {
        { $script:enabled = @(Get-EnabledRule -Line $Lines) } | Should -Not -Throw
        $script:enabled | Should -Be $Expected
    }

    # Review 10 of PR 36: a line the function can't read would turn nothing on in its eyes, so the real-file test
    # would pass while Roslyn read the line as something else (a bulk severity, say), or ignored a typo.
    It 'stops at <Line>, which it doesn''t recognise' -ForEach @(
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warn' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = info' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning error' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity warning' }
        @{ Line = 'dotnet_diagnostic.CA1014 = warning' }
        @{ Line = 'dotnet_analyzer_diagnostic.severity = warning' }
        @{ Line = 'dotnet_analyzer_diagnostic.category-Design.severity = warning' }
        @{ Line = 'dotnet_code_quality.CA1501.api_surface = public' }
        @{ Line = '[*.cs]' }
    ) {
        { Get-EnabledRule -Line $Line } | Should -Throw -ExpectedMessage "*doesn't recognise*"
    }

    # Any severity but none counts as on, so suggestion, silent and default ask for a fixture too, erring toward one;
    # the table is the one the fixture builds run from, so a row that's commented out doesn't count. Both ways, so a
    # line the parser misread, or one taken out of .globalconfig, shows too (review 10 of PR 36).
    It 'turns on exactly the rules whose failing fixtures are marked GlobalConfig' -ForEach @(@{ Violations = $violations }) {
        $root = Join-Path $PSScriptRoot '..' '..'
        $turnedOn = @(Get-EnabledRule -Line (Get-Content -LiteralPath (Join-Path $root '.globalconfig')))
        $marked = @($Violations | Where-Object { $_['GlobalConfig'] } | ForEach-Object { $_.Diagnostic } | Sort-Object -Unique)

        $marked.Count | Should -BeGreaterThan 0
        @($turnedOn | Where-Object { $_ -notin $marked }) | Should -BeNullOrEmpty -Because 'each rule on in .globalconfig needs a failing fixture marked GlobalConfig, to prove it fires'
        @($marked | Where-Object { $_ -notin $turnedOn }) | Should -BeNullOrEmpty -Because 'each rule marked GlobalConfig should be on in .globalconfig'
    }
}