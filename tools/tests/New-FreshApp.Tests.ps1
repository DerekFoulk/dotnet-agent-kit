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

            # An edit nobody committed must not reach the app.
            $edited = @(git -C $kit ls-tree -r --name-only $commit -- "$From/src" | Where-Object { $_ -like '*.cs' })[0]
            Add-Content -LiteralPath (Join-Path $kit $edited) -Value '// uncommitted-edit-marker'

            # The expected bytes: a clean checkout of the commit, line endings as .gitattributes gives them.
            $checkout = Join-Path $TestDrive 'checkout'
            git -C $kit worktree add -q --detach $checkout $commit

            # A developer's preferences must not reach the app: a run here and CI's give the same app.
            Mock Read-KitPreference { throw 'New-FreshApp read a preferences file.' }

            $app = Join-Path $TestDrive 'app'
            New-FreshApp -Type $Type -Destination $app -KitRef $commit -KitRoot $kit
            $profilePath = Join-Path $app 'docs' 'app-profile.md'
            $intake = Get-Content -Raw -LiteralPath (Join-Path $kit 'templates' 'app-intake.json') | ConvertFrom-Json -AsHashtable
        }

        AfterAll {
            git -C $kit worktree remove --force $checkout
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
    }
}
