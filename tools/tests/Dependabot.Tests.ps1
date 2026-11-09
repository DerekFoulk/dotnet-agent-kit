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
        }
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
