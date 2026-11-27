#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Dependabot's version updates wait before proposing a new version (ADR-0041), so a release that's pulled or
# found to be compromised in its first days never reaches a PR. Agents merge patch and minor updates of
# NuGet packages, .NET tools and the SDK in auto mode; major updates and GitHub Actions stay the owner's.

Describe 'Dependabot configuration' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Get-Update([string] $RelativePath) {
            $yaml = Get-Content -Raw -LiteralPath (Join-Path $root $RelativePath) | ConvertFrom-Yaml
            @($yaml['updates'])
        }
    }

    # The owner, 2026-11-09: 7 days, and 14 for a major. Dependabot's own default is 3, and security updates
    # never wait, so a longer wait only delays routine updates.
    It 'waits at least 7 days before proposing any new version, in <Path>' -ForEach @(
        @{ Path = '.github/dependabot.yml' }, @{ Path = 'templates/app/.github/dependabot.yml' }
    ) {
        $updates = Get-Update $Path

        $updates.Count | Should -BeGreaterThan 0
        foreach ($update in $updates) {
            $update.Contains('cooldown') | Should -BeTrue -Because "$($update['package-ecosystem']) needs a cooldown"
            [int] $update['cooldown']['default-days'] | Should -BeGreaterOrEqual 7
            # Review 2 of PR 33: an exclude list skips the wait for what it names, and an include list keeps the
            # wait only for what it names, so either would narrow the wait without shortening a number.
            $update['cooldown'].Keys | Should -Not -Contain 'exclude' -Because 'every dependency waits'
            $update['cooldown'].Keys | Should -Not -Contain 'include' -Because 'every dependency waits'
            # Review 3 of PR 33: default-days covers only updates without their own wait, so a semver-minor-days
            # or semver-patch-days below it would shorten the wait for exactly the updates agents merge.
            foreach ($key in @($update['cooldown'].Keys | Where-Object { $_ -like '*-days' })) {
                [int] $update['cooldown'][$key] | Should -BeGreaterOrEqual 7 -Because "$($update['package-ecosystem'])'s $key is a wait too"
            }
        }
    }

    # GAP-023 (ADR-0060): the tools the shared .NET CI downloads itself are pinned in manifests under .config, so
    # Dependabot proposes their new versions: PMD in a Maven pom, the gitleaks image in a Dockerfile.
    It 'watches the manifest that pins <Tool> for the shared workflows, in the kit' -ForEach @(
        @{ Tool = 'PMD'; Ecosystem = 'maven'; Directory = '/.config/pmd' }
        @{ Tool = 'the gitleaks image'; Ecosystem = 'docker'; Directory = '/.config/gitleaks' }
        # GAP-012 (ADR-0062): Locust, for the shared performance workflow's load tests.
        @{ Tool = 'Locust'; Ecosystem = 'pip'; Directory = '/.config/locust' }
    ) {
        $matching = @(Get-Update '.github/dependabot.yml' |
                Where-Object { $_['package-ecosystem'] -eq $Ecosystem -and $_['directory'] -eq $Directory })

        $matching.Count | Should -Be 1 -Because "Dependabot's $Ecosystem updater must read $Directory"
    }

    # GAP-033 (ADR-0061): the Playwright image the shared CI runs browser tests in is pinned in the repo's own
    # .config/playwright/Dockerfile, since its version follows the repo's Microsoft.Playwright: the kit's, and each app's.
    It 'watches the Playwright image pin, in <Path>' -ForEach @(
        @{ Path = '.github/dependabot.yml' }, @{ Path = 'templates/app/.github/dependabot.yml' }
    ) {
        $matching = @(Get-Update $Path |
                Where-Object { $_['package-ecosystem'] -eq 'docker' -and $_['directory'] -eq '/.config/playwright' })

        $matching.Count | Should -Be 1 -Because "Dependabot's docker updater must read /.config/playwright"
    }

    # GAP-025: the SQL Server image the sample's tests and load test run, pinned once in sample/tests/SqlServer.
    It 'watches the sample''s SQL Server image pin, with the docker cooldown' {
        $matching = @(Get-Update '.github/dependabot.yml' |
                Where-Object { $_['package-ecosystem'] -eq 'docker' -and $_['directory'] -eq '/sample/tests/SqlServer' })

        $matching.Count | Should -Be 1 -Because "Dependabot's docker updater must read /sample/tests/SqlServer"
        $matching[0]['cooldown']['default-days'] | Should -Be 7
    }

    # GAP-025: packages that only work at one another's versions move in one PR: Roslyn's, each of which requires
    # exactly its own version of the others, and EF Core's with the dotnet-ef tool that runs its design-time code.
    It 'moves <Group> together, in the kit''s NuGet updates' -ForEach @(
        # By name: a wildcard would also catch Microsoft.CodeAnalysis.BannedApiAnalyzers, on a version line of its own.
        @{ Group = 'roslyn'; Patterns = @('Microsoft.CodeAnalysis.Common', 'Microsoft.CodeAnalysis.CSharp', 'Microsoft.CodeAnalysis.CSharp.Workspaces', 'Microsoft.CodeAnalysis.Workspaces.Common', 'Microsoft.CodeAnalysis.Workspaces.MSBuild') }
        @{ Group = 'ef-core'; Patterns = @('Microsoft.EntityFrameworkCore*', 'dotnet-ef') }
    ) {
        $nuget = @(Get-Update '.github/dependabot.yml' | Where-Object { $_['package-ecosystem'] -eq 'nuget' })

        $nuget.Count | Should -Be 1
        $nuget[0].ContainsKey('groups') | Should -BeTrue
        $nuget[0]['groups'].Keys | Should -Contain $Group
        @($nuget[0]['groups'][$Group]['patterns']) | Should -Be $Patterns
    }

    # GAP-022: an app's .kit holds a copy of the kit's Directory.Packages.props and the code shape tool's project, which
    # the kit manages and the sync replaces. A Dependabot PR there would edit a kit-managed file, so the app's NuGet
    # updates leave .kit out; the kit's own release moves those versions.
    It 'keeps the app''s NuGet updates out of the kit-managed .kit folder' {
        $nuget = @(Get-Update 'templates/app/.github/dependabot.yml' | Where-Object { $_['package-ecosystem'] -eq 'nuget' })

        $nuget.Count | Should -Be 1
        @($nuget[0]['exclude-paths']) | Should -Contain '.kit/**'
    }

    It 'waits at least 14 days before proposing a major version of a package or the SDK, in <Path>' -ForEach @(
        @{ Path = '.github/dependabot.yml' }, @{ Path = 'templates/app/.github/dependabot.yml' }
    ) {
        $updates = @(Get-Update $Path | Where-Object { $_['package-ecosystem'] -in 'nuget', 'dotnet-sdk' })

        $updates.Count | Should -BeGreaterThan 0
        foreach ($update in $updates) {
            $cooldown = if ($update.Contains('cooldown')) { $update['cooldown'] } else { @{} }
            [int] $cooldown['semver-major-days'] | Should -BeGreaterOrEqual 14 -Because "$($update['package-ecosystem']) majors are the owner's, after a longer wait"
        }
    }
}
