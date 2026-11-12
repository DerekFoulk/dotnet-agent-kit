#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Test-LockFileSubset.ps1 (ADR-0057). A MAUI project builds fewer target frameworks on macOS than on Windows, where
# its lock file is made, so NuGet refuses a locked restore there (NU1004). The macOS CI job restores without locked
# mode, then this check fails unless every lock file it wrote matches the committed one for each framework it lists.

BeforeAll {
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'Test-LockFileSubset.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Test-LockFileSubset.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        # A lock file with the given frameworks, each mapping a package name to its resolved version.
        function ConvertTo-LockJson([hashtable] $Frameworks) {
            $dependencies = [ordered]@{}
            foreach ($framework in $Frameworks.Keys | Sort-Object) {
                $packages = [ordered]@{}
                foreach ($name in $Frameworks[$framework].Keys | Sort-Object) {
                    $packages[$name] = [ordered]@{ type = 'Direct'; requested = "[$($Frameworks[$framework][$name]), )"; resolved = $Frameworks[$framework][$name] }
                }
                $dependencies[$framework] = $packages
            }
            ConvertTo-Json -Depth 10 -InputObject ([ordered]@{ version = 1; dependencies = $dependencies })
        }

        # A repo with one committed lock file, for a MAUI app restored on Windows.
        function New-LockRepo {
            $repo = Join-Path $TestDrive "repo-$(New-Guid)"
            New-Item -ItemType Directory -Path (Join-Path $repo 'src/App.Maui') -Force | Out-Null
            git init -q $repo
            ConvertTo-LockJson @{
                'net10.0-android'                = @{ 'CommunityToolkit.Mvvm' = '8.4.0' }
                'net10.0-ios'                    = @{ 'CommunityToolkit.Mvvm' = '8.4.0' }
                'net10.0-windows10.0.19041.0'    = @{ 'CommunityToolkit.Mvvm' = '8.4.0'; 'Microsoft.WindowsAppSDK' = '1.8.0' }
            } | Set-Content -LiteralPath (Join-Path $repo 'src/App.Maui/packages.lock.json')
            git -C $repo add -A
            git -C $repo commit -q -m 'chore: lock'
            $repo
        }
    }

    It 'passes when a restore left the lock file as committed, or dropped a framework it doesn''t build' {
        Get-Command Get-LockFileSubsetProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = New-LockRepo
        @(Get-LockFileSubsetProblem -RepoRoot $repo) | Should -BeNullOrEmpty

        # What macOS writes: the same packages for each framework it builds, and no Windows framework.
        ConvertTo-LockJson @{
            'net10.0-android' = @{ 'CommunityToolkit.Mvvm' = '8.4.0' }
            'net10.0-ios'     = @{ 'CommunityToolkit.Mvvm' = '8.4.0' }
        } | Set-Content -LiteralPath (Join-Path $repo 'src/App.Maui/packages.lock.json')

        @(Get-LockFileSubsetProblem -RepoRoot $repo) | Should -BeNullOrEmpty
    }
}
