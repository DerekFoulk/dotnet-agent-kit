#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# New-FreshApp writes a fresh app of one app type, with a probe project of that type, for the kit's CI to check
# (GAP-049, ADR-0095). Like Export-KitApp's tests, these build a throwaway kit repo from this working tree (tracked and
# new files), commit it, and export from that commit, so they run before the kit's own changes are committed.

BeforeAll {
    # The kit's files, listed before the test git settings, with this checkout's own ignore rules.
    $kitFiles = git -C (Join-Path $PSScriptRoot '..' '..') ls-files --cached --others --exclude-standard
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'New-FreshApp' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        . (Join-Path $root 'tools' 'New-FreshApp.ps1')

        # One kit fixture for every app type: copying the kit is most of these tests' time.
        $kit = Join-Path $TestDrive 'kit'
        foreach ($file in $kitFiles) {
            $source = Join-Path $root $file
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue } # deleted but not yet staged
            $target = Join-Path $kit $file
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
        }
        git -C $kit init -q -b main
        git -C $kit add -A
        git -C $kit commit -q -m 'chore: kit fixture'
        $commit = (git -C $kit rev-parse HEAD).Trim()

        # An edit nobody committed must not reach an app: one in each probe's src.
        $editedFiles = @{}
        foreach ($from in 'sample', 'fixtures/WebUi') {
            $editedFiles[$from] = @(git -C $kit ls-tree -r --name-only $commit -- "$from/src" | Where-Object { $_ -like '*.cs' })[0]
            Add-Content -LiteralPath (Join-Path $kit $editedFiles[$from]) -Value '// uncommitted-edit-marker'
        }

        # The expected bytes: a clean checkout of the commit, line endings as .gitattributes gives them.
        $checkout = Join-Path $TestDrive 'checkout'
        git -C $kit worktree add -q --detach $checkout $commit
    }

    AfterAll {
        git -C $kit worktree remove --force $checkout
    }

    # The kit's CI exports a fresh app of every type New-FreshApp has a probe for, and checks it with the shared workflows'
    # app-bundle input (ADR-0095). Not required: the kit's ruleset is the owner's call.
    Context 'the kit''s fresh-app jobs' {
        BeforeAll {
            Import-Module powershell-yaml
            $ci = ConvertFrom-Yaml (Get-Content -Raw -LiteralPath (Join-Path $root '.github' 'workflows' 'ci.yml'))
            $jobs = $ci['jobs']
            $probeMatrix = @($script:Probes.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value.Name)" } | Sort-Object)
            function Get-MatrixEntry($Job) { @($Job['strategy']['matrix']['include'] | ForEach-Object { "$($_['type'])=$($_['name'])" } | Sort-Object) }
        }

        It 'exports a fresh app of every type with a probe, and no other, and uploads its bundle' {
            $export = $jobs['fresh-app']

            $export | Should -Not -BeNullOrEmpty
            Get-MatrixEntry $export | Should -Be $probeMatrix
            $export['strategy']['fail-fast'] | Should -BeFalse
            $steps = @($export['steps'])
            ($steps | Where-Object { "$($_['run'])" -match '\./tools/New-FreshApp\.ps1 -Type \$env:TYPE' }) | Should -HaveCount 1
            ($steps | Where-Object { "$($_['run'])" -match 'dotnet restore .*-p:RestoreLockedMode=false' }) | Should -HaveCount 1
            ($steps | Where-Object { "$($_['run'])" -match 'git (-C \S+ )?bundle create' }) | Should -HaveCount 1
            $upload = @($steps | Where-Object { "$($_['uses'])" -like 'actions/upload-artifact@*' })
            $upload | Should -HaveCount 1
            $upload[0]['with']['name'] | Should -Be 'fresh-app-${{ matrix.type }}'
            $upload[0]['with']['if-no-files-found'] | Should -Be 'error'
            # The export runs the app's own Build-AgentRules, which imports powershell-yaml: the kit checks' pinned version,
            # installed before the export (CI's first run failed here).
            $pin = [regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $root '.github' 'workflows' 'kit-checks.reusable.yml')), 'Install-PSResource -Name powershell-yaml -Version [\d.]+').Value
            $pin | Should -Not -BeNullOrEmpty
            $install = [array]::FindIndex($steps, [Predicate[object]] { param($s) "$($s['run'])".Contains($pin) })
            $exportAt = [array]::FindIndex($steps, [Predicate[object]] { param($s) "$($s['run'])" -match 'New-FreshApp\.ps1' })
            $install | Should -BeGreaterOrEqual 0 -Because "the job runs '$pin'"
            $install | Should -BeLessThan $exportAt
            # A runner has no git identity, and the app's commits need one.
            foreach ($variable in 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL') {
                $export['env'][$variable] | Should -Not -BeNullOrEmpty
            }
        }

        It 'checks each one with the shared .NET CI and app checks, as an app''s own workflows call them' {
            foreach ($check in @(
                    @{ Id = 'fresh-dotnet'; Uses = './.github/workflows/dotnet-ci.reusable.yml' }
                    @{ Id = 'fresh-app-checks'; Uses = './.github/workflows/app-checks.reusable.yml' })) {
                $job = $jobs[$check.Id]

                $job | Should -Not -BeNullOrEmpty -Because "ci.yml has a $($check.Id) job"
                $job['uses'] | Should -Be $check.Uses
                @($job['needs']) | Should -Be @('fresh-app')
                Get-MatrixEntry $job | Should -Be $probeMatrix
                $job['strategy']['fail-fast'] | Should -BeFalse
                $job['with']['app-bundle'] | Should -Be 'fresh-app-${{ matrix.type }}'
            }
            $jobs['fresh-dotnet']['with']['solution'] | Should -Be '${{ matrix.name }}.slnx'
        }

        It 'leaves the kit''s own checks on the kit''s checkout' {
            foreach ($id in 'dotnet', 'kit') {
                $with = if ($jobs[$id].Contains('with')) { $jobs[$id]['with'] } else { @{} }
                $with.Contains('app-bundle') | Should -BeFalse
            }
        }

        # Every app type either has a probe or waits, with its reason, and GAP-049 stays open while one waits.
        It 'covers every app type, or says why one waits, while GAP-049 stays open for it' {
            $types = @((ConvertFrom-Yaml (Get-Content -Raw -LiteralPath (Join-Path $root 'docs' 'standards' 'app-types.yml')))['types'] | ForEach-Object { $_['id'] } | Sort-Object)
            @(@($script:Probes.Keys) + @($script:Waiting.Keys) | Sort-Object) | Should -Be $types
            $scorecard = Get-Content -Raw -LiteralPath (Join-Path $root 'docs' 'quality' 'scorecard.md')
            $gap = [regex]::Match($scorecard, '(?ms)^\s+- id: GAP-049\r?\n\s+gap: "(?<gap>[^"]*)"\r?\n\s+status: (?<status>\w+)')
            $gap.Success | Should -BeTrue
            if ($script:Waiting.Count) {
                $gap.Groups['status'].Value | Should -Be 'proposed'
                foreach ($type in $script:Waiting.Keys) { $gap.Groups['gap'].Value | Should -Match "\b$type\b" -Because "GAP-049 names the $type leg that waits" }
            }
        }
    }

    # Export-KitApp cleans up after its own failures; a later step's failure must too, or a rerun is refused as "isn't empty".
    It 'removes the app it was writing when a step after the export fails' {
        Mock Copy-FreshAppProbe { throw 'probe copy failed' }
        $destination = Join-Path $TestDrive 'failed-app'

        { New-FreshApp -Type web-api -Destination $destination -KitRef $commit -KitRoot $kit } | Should -Throw -ExpectedMessage '*probe copy failed*'

        $destination | Should -Not -Exist
    }

    # A project path is an XML attribute: a character such as & would break the solution file.
    It 'escapes each project''s path in the solution, so the file stays well-formed' {
        $folder = Join-Path $TestDrive 'escaped'
        New-Item -ItemType Directory -Force -Path (Join-Path $folder 'src' 'A&B') | Out-Null
        Set-Content -LiteralPath (Join-Path $folder 'src' 'A&B' 'A&B.csproj') -Value '<Project />'

        [xml] $solution = Get-FreshAppSolutionText -Destination $folder

        @($solution.SelectNodes('//Project') | ForEach-Object { $_.GetAttribute('Path') }) | Should -Be @('src/A&B/A&B.csproj')
    }

    # MAUI's leg waits for GAP-028 (the Windows and macOS jobs proven), and the owner put MAUI after the practice run.
    It 'refuses an app type it has no probe for, naming the gap that waits for it' {
        { New-FreshApp -Type maui -Destination (Join-Path $TestDrive 'maui') -KitRef HEAD -KitRoot $root } |
            Should -Throw -ExpectedMessage '*maui*GAP-028*'
    }

    Context 'a fresh <Type> app' -ForEach @(
        @{ Type = 'web-api'; Name = 'Fresh.WebApi'; From = 'sample' }
        @{ Type = 'blazor'; Name = 'Fresh.Blazor'; From = 'fixtures/WebUi' }
    ) {
        BeforeAll {
            $edited = $editedFiles[$From]

            # A developer's preferences must not reach the app: a run here and CI's give the same app.
            Mock Read-KitPreference { throw 'New-FreshApp read a preferences file.' }

            $app = Join-Path $TestDrive "app-$Type"
            New-FreshApp -Type $Type -Destination $app -KitRef $commit -KitRoot $kit
            $profilePath = Join-Path $app 'docs' 'app-profile.md'
            $intake = Get-Content -Raw -LiteralPath (Join-Path $kit 'templates' 'app-intake.json') | ConvertFrom-Json -AsHashtable
        }

        It 'gets the core ruleset and its own type''s, from a profile of the intake''s defaults' {
            $profilePath | Should -Exist
            $text = Get-Content -Raw -LiteralPath $profilePath
            @([regex]::Matches($text, '(?m)^App types: .*$').Value) | Should -Be @("App types: $Type")
            $label = @($intake['cards'] | Where-Object { $_['id'] -eq 'appType' })[0]['options'] |
                Where-Object { "$($_['appTypes'])" -ceq $Type } | ForEach-Object { $_['label'] }
            $text | Should -Match ([regex]::Escape("| $label |"))
            # One row per card, under the Choices table's header.
            $choices = [regex]::Match($text, '(?s)## Choices.*?\|---\|---\|---\|\r?\n(?<rows>(\|[^\r\n]*\r?\n)+)').Groups['rows'].Value
            @($choices -split '\r?\n' | Where-Object { $_ }).Count | Should -Be @($intake['cards']).Count
            Should -Invoke Read-KitPreference -Times 0 -Exactly
        }

        # ADR-0090: the checks skip a rule only where the profile answers its condition no, so the fresh app's profile
        # answers every condition the kit lists, as New-KitApp's does, and the checks' own reader accepts it.
        It 'answers each condition the kit lists on its Conditions line, as New-KitApp''s profile does' {
            Import-Module powershell-yaml
            Import-Module (Join-Path $root 'tools' 'KitRuleStrength.psm1') -Force
            $listed = @((ConvertFrom-Yaml (Get-Content -Raw -LiteralPath (Join-Path $kit 'docs' 'standards' 'conditions.yml')))['conditions'] |
                    ForEach-Object { $_['id'] } | Sort-Object)

            $answers = (Read-AppProfile -Path $profilePath).Conditions

            @($answers.Keys | Sort-Object) | Should -Be $listed
            $answers['has-sign-in'] | Should -Be 'yes' -Because 'the intake''s default sign-in is customers or the public'
        }

        # The app's history is what its secret scan and commit checks read, so it starts as New-KitApp's does.
        It 'starts its history with New-KitApp''s first commit, on main, with the commit-msg hook executable' {
            Test-Path -LiteralPath (Join-Path $app '.git') | Should -BeTrue
            git -C $app branch --show-current | Should -Be 'main'
            @(git -C $app log --format=%s) | Should -Be @('chore: start from dotnet-agent-kit unreleased')
            (git -C $app ls-files --stage -- .githooks/commit-msg) | Should -Match '^100755 '
            # The kit's files only, as New-KitApp's first commit; the probe comes after it.
            @(git -C $app ls-tree -r --name-only HEAD -- src tests | Where-Object { $_ -ne 'tests/Directory.Build.props' }) | Should -BeNullOrEmpty
        }

        # The probe is the kit's own reference app of the type (ADR-0095): its src/ and tests/ become the app's. Lock
        # files stay behind: the app's first restore writes its own, against the app's Directory.Packages.props.
        It 'holds the probe''s src and tests from the chosen commit, without their lock files' {
            $expected = @(git -C $kit ls-tree -r --name-only $commit -- "$From/src" "$From/tests" |
                    Where-Object { $_ -notmatch '(^|/)packages\.lock\.json$' })
            $expected.Count | Should -BeGreaterThan 5
            foreach ($file in $expected) {
                $target = Join-Path $app $file.Substring($From.Length + 1)
                $target | Should -Exist
                [IO.File]::ReadAllBytes($target) | Should -Be ([IO.File]::ReadAllBytes((Join-Path $checkout $file))) -Because "$file is copied unchanged"
            }
            $copied = @(Get-ChildItem -LiteralPath (Join-Path $app 'src'), (Join-Path $app 'tests') -Recurse -File |
                    ForEach-Object { [IO.Path]::GetRelativePath($app, $_.FullName).Replace('\', '/') })
            @($copied | Where-Object { $_ -ne 'tests/Directory.Build.props' } | Sort-Object) |
                Should -Be @($expected | ForEach-Object { $_.Substring($From.Length + 1) } | Sort-Object)
            (Get-Content -Raw -LiteralPath (Join-Path $app $edited.Substring($From.Length + 1))) | Should -Not -Match 'uncommitted-edit-marker'
        }

        # Export-KitApp leaves the sample's packages out of an app; the web-api probe is the sample, so it needs them back,
        # as an app adds the packages its first task uses. The web UI fixture's are all in groups an app keeps.
        It 'has the versions of the packages its probe uses, and no others the kit leaves out' {
            [xml] $kitProps = git -C $kit show "${commit}:Directory.Packages.props" | Out-String
            $sample = @($kitProps.Project.ItemGroup | Where-Object { $_.GetAttribute('Label') -eq 'Sample app' } | ForEach-Object { $_.PackageVersion })
            $sample.Count | Should -BeGreaterThan 0
            [xml] $appProps = Get-Content -Raw -LiteralPath (Join-Path $app 'Directory.Packages.props')
            $versions = @{}
            foreach ($package in $appProps.SelectNodes('//PackageVersion')) { $versions[$package.Include] = $package.Version }

            foreach ($package in $sample) {
                if ($Type -eq 'web-api') { $versions[$package.Include] | Should -Be $package.Version -Because "the sample uses $($package.Include)" }
                else { $versions.ContainsKey($package.Include) | Should -BeFalse -Because "the web UI fixture doesn't use $($package.Include)" }
            }
            $versions.ContainsKey('Microsoft.CodeAnalysis.CSharp') | Should -BeFalse -Because 'the kit tools'' packages stay out of an app'
        }

        # The web-api probe is the sample, a server app only its owner runs, so it carries the license entries this repo
        # adds for the sample (.config/package-licenses.json: MSAL's broker interop, ADR-0098), as an app on SQL Server
        # adds its own. The web UI fixture needs none.
        It 'carries the kit repo''s license entries only when its probe is the sample' {
            $policy = Join-Path $app '.config' 'package-licenses.json'

            if ($Type -eq 'web-api') { $policy | Should -Exist; [IO.File]::ReadAllBytes($policy) | Should -Be ([IO.File]::ReadAllBytes((Join-Path $checkout '.config' 'package-licenses.json'))) }
            else { $policy | Should -Not -Exist }
        }

        # The shared CI builds and checks what the solution lists, so a probe project left out would go unchecked.
        It 'lists every probe project in the app''s solution, and nothing else' {
            [xml] $solution = Get-Content -Raw -LiteralPath (Join-Path $app "$Name.slnx")
            $listed = @($solution.SelectNodes('//Project') | ForEach-Object { $_.GetAttribute('Path') } | Sort-Object)
            $projects = @(Get-ChildItem -LiteralPath (Join-Path $app 'src'), (Join-Path $app 'tests') -Recurse -Filter *.csproj |
                    ForEach-Object { [IO.Path]::GetRelativePath($app, $_.FullName).Replace('\', '/') } | Sort-Object)

            $projects.Count | Should -BeGreaterThan 1
            $listed | Should -Be $projects
        }
    }
}
