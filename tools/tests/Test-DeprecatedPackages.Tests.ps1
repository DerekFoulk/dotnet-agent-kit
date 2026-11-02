#Requires -Version 7.0
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
        # A clean project and a never-restored project both look like this.
        $script:cleanJson = '{ "version": 1, "parameters": "--deprecated", "sources": [], "projects": [ { "path": "PROJECT_PATH" } ] }'
        $script:emptyJson = '{ "version": 1, "parameters": "--deprecated", "sources": [], "projects": [] }'

        function New-Project([switch] $Restored) {
            $folder = Join-Path $TestDrive "proj-$(New-Guid)"
            New-Item -ItemType Directory -Path $folder | Out-Null
            $project = Join-Path $folder 'Probe.csproj'
            Set-Content -Path $project -Value '<Project Sdk="Microsoft.NET.Sdk" />'
            if ($Restored) {
                New-Item -ItemType Directory -Path (Join-Path $folder 'obj') | Out-Null
                Set-Content -Path (Join-Path $folder 'obj' 'project.assets.json') -Value '{}'
            }
            $project -replace '\\', '/'
        }

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
            $project = New-Project -Restored

            Invoke-DeprecatedPackageCheck -Json (Get-Json $script:deprecatedJson $project) | Should -Be 1

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Microsoft.Azure.KeyVault 3.0.5*Legacy*Azure.Security.KeyVault.Certificates*' }
        }

        It 'returns 0 for a restored project with no deprecated packages' {
            $project = New-Project -Restored

            Invoke-DeprecatedPackageCheck -Json (Get-Json $script:cleanJson $project) | Should -Be 0
        }

        It 'returns 0 for a solution with no projects yet, and says so' {
            Invoke-DeprecatedPackageCheck -Json $script:emptyJson | Should -Be 0

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*no projects*' }
        }

        It 'returns 1 for a project that was never restored, because its output looks clean' {
            $project = New-Project

            Invoke-DeprecatedPackageCheck -Json (Get-Json $script:cleanJson $project) | Should -Be 1

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*not restored*' }
        }

        It 'exits 1 as a script given saved output with a deprecated package' {
            $project = New-Project -Restored
            $jsonFile = Join-Path $TestDrive "deprecated-$(New-Guid).json"
            Set-Content -Path $jsonFile -Value (Get-Json $script:deprecatedJson $project)
            $script = Join-Path $PSScriptRoot '..' 'Test-DeprecatedPackages.ps1'

            $output = pwsh -NoProfile -File $script -JsonFile $jsonFile 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'Microsoft\.Azure\.KeyVault'
        }
    }
}
