#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The JSON shapes below are real `dotnet list package --deprecated --format json` output (SDK 10.0.403,
# captured 2026-11-02), with the project path replaced by a placeholder.

Describe 'Test-DeprecatedPackages.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-DeprecatedPackages.ps1')

        $script:deprecatedJson = @'
{
  "version": 1,
  "parameters": "--deprecated",
  "sources": [ "https://api.nuget.org/v3/index.json" ],
  "projects": [
    {
      "path": "PROJECT_PATH",
      "frameworks": [
        {
          "framework": "net10.0",
          "topLevelPackages": [
            {
              "id": "Microsoft.Azure.KeyVault",
              "requestedVersion": "3.0.5",
              "resolvedVersion": "3.0.5",
              "deprecationReasons": [ "Legacy" ],
              "alternativePackage": { "id": "Azure.Security.KeyVault.Certificates", "versionRange": ">= 0.0.0" }
            }
          ]
        }
      ]
    }
  ]
}
'@
        $script:cleanJson = '{ "version": 1, "parameters": "--deprecated", "sources": [], "projects": [ { "path": "PROJECT_PATH" } ] }'
        $script:emptyJson = '{ "version": 1, "parameters": "--deprecated", "sources": [], "projects": [] }'
        # A package that doesn't exist: dotnet list's own restore fails, it exits 1, and there's no "projects" key.
        $script:restoreFailedJson = '{ "version": 1, "problems": [ { "text": "Restore failed. Run `dotnet restore` for more details on the issue.", "level": "error" } ] }'

        function Get-Json([string] $Template, [string] $ProjectPath) {
            $Template.Replace('PROJECT_PATH', $ProjectPath)
        }
    }

    BeforeEach {
        Mock Write-Host {}
    }

    Context 'Get-DeprecatedPackage' {
        It 'reads each deprecated top-level package with its reason and alternative' {
            $packages = @(Get-DeprecatedPackage -Json (Get-Json $script:deprecatedJson 'C:/repo/src/Probe/Probe.csproj'))

            $packages.Count | Should -Be 1
            $packages[0].Id | Should -Be 'Microsoft.Azure.KeyVault'
            $packages[0].Version | Should -Be '3.0.5'
            $packages[0].Reasons | Should -Be 'Legacy'
            $packages[0].Alternative | Should -Be 'Azure.Security.KeyVault.Certificates'
            $packages[0].Project | Should -Be 'C:/repo/src/Probe/Probe.csproj'
            $packages[0].Framework | Should -Be 'net10.0'
        }

        It 'finds nothing in <Case> output' -ForEach @(
            @{ Case = 'clean'; Key = 'cleanJson' }
            @{ Case = 'empty-solution'; Key = 'emptyJson' }
        ) {
            @(Get-DeprecatedPackage -Json (Get-Json (Get-Variable -Name $Key -Scope Script -ValueOnly) 'C:/repo/x.csproj')) | Should -BeNullOrEmpty
        }
    }

    Context 'Invoke-DeprecatedPackageCheck' {
        It 'returns 1 and names the package and its alternative' {
            Invoke-DeprecatedPackageCheck -Json (Get-Json $script:deprecatedJson 'C:/repo/src/Probe/Probe.csproj') | Should -Be 1

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Microsoft.Azure.KeyVault 3.0.5*Legacy*Azure.Security.KeyVault.Certificates*' }
        }

        It 'returns 0 for a project with no deprecated packages' {
            Invoke-DeprecatedPackageCheck -Json (Get-Json $script:cleanJson 'C:/repo/src/Probe/Probe.csproj') | Should -Be 0
        }

        It 'returns 0 for a solution with no projects yet, and says so' {
            Invoke-DeprecatedPackageCheck -Json $script:emptyJson | Should -Be 0

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*no projects*' }
        }

        # dotnet list restores the project itself; when that restore fails it exits 1 and reports
        # "problems" with no "projects" key, which must never read as "nothing deprecated".
        It 'returns 1 and shows the problem when dotnet list reports a failed restore' {
            Invoke-DeprecatedPackageCheck -Json $script:restoreFailedJson -ExitCode 1 | Should -Be 1

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Restore failed*' }
        }

        It 'returns 1 for a non-zero exit code even when the output looks clean' {
            Invoke-DeprecatedPackageCheck -Json (Get-Json $script:cleanJson 'C:/repo/x.csproj') -ExitCode 1 | Should -Be 1
        }

        It 'returns 1 for problems reported with exit code 0' {
            Invoke-DeprecatedPackageCheck -Json $script:restoreFailedJson -ExitCode 0 | Should -Be 1
        }

        It 'returns 1 when the output has no projects key' {
            Invoke-DeprecatedPackageCheck -Json '{ "version": 1 }' | Should -Be 1
        }

        It 'exits 1 as a script given saved output with a deprecated package' {
            $jsonFile = Join-Path $TestDrive "deprecated-$(New-Guid).json"
            Set-Content -Path $jsonFile -Value (Get-Json $script:deprecatedJson 'C:/repo/src/Probe/Probe.csproj')
            $script = Join-Path $PSScriptRoot '..' 'Test-DeprecatedPackages.ps1'

            $output = pwsh -NoProfile -File $script -JsonFile $jsonFile 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'Microsoft\.Azure\.KeyVault'
        }
    }
}
