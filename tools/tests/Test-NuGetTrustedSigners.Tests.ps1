#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# GAP-038 (SUP-012, ADR-0066): nuget.config trusts the repository certificates nuget.org's service index announced when
# it was written. When nuget.org rotates its certificate, a package signed with the new one fails NU3004 until someone
# runs `dotnet nuget trust sync nuget.org`. This check compares the two, so a scheduled run notices a rotation first.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Test-NuGetTrustedSigners.ps1')

    $script:serviceIndex = 'https://api.nuget.org/v3/index.json'
    $script:signatures = 'https://api.nuget.org/v3-index/repository-signatures/5.0.0/index.json'
    $script:old = '0e5f38f57dc1bcc806d8494f4f90fbcedd988b46760709cbeec6f4219aa6157d'
    $script:current = '1f4b311d9acc115c8dc8018b5a49e00fce6da8e2855f9f014ca6f34570bc482d'
    $script:next = 'aa' * 32

    # A nuget.config like the kit's, trusting the given SHA-256 fingerprints for the repository named $Name.
    function New-NuGetConfig([string[]] $Fingerprint, [string] $Name = 'nuget.org') {
        $certificates = ($Fingerprint | ForEach-Object {
                "      <certificate fingerprint=""$_"" hashAlgorithm=""SHA256"" allowUntrustedRoot=""false"" />"
            }) -join "`n"
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).config"
        Set-Content -LiteralPath $path -Value @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <trustedSigners>
    <clear />
    <repository name="$Name" serviceIndex="$serviceIndex">
$certificates
    </repository>
  </trustedSigners>
</configuration>
"@
        $path
    }

    # nuget.org's service index and its RepositorySignatures resource, as Invoke-RestMethod returns them.
    function Set-AnnouncedCertificate([string[]] $Fingerprint, [string[]] $Type = @('RepositorySignatures/4.7.0', 'RepositorySignatures/5.0.0')) {
        $resources = @($Type | ForEach-Object { [pscustomobject]@{ '@id' = "https://api.nuget.org/v3-index/repository-signatures/$($_.Split('/')[1])/index.json"; '@type' = $_ } })
        $resources += [pscustomobject]@{ '@id' = 'https://azuresearch-usnc.nuget.org/query'; '@type' = 'SearchQueryService' }
        $index = [pscustomobject]@{ version = '3.0.0'; resources = $resources }
        $certificates = @($Fingerprint | ForEach-Object {
                [pscustomobject]@{ fingerprints = [pscustomobject]@{ '2.16.840.1.101.3.4.2.1' = $_ }; subject = 'CN=NuGet.org Repository by Microsoft' }
            })
        $resource = [pscustomobject]@{ allRepositorySigned = $true; signingCertificates = $certificates }
        Mock Invoke-RestMethod -ParameterFilter { $Uri -eq $serviceIndex } -MockWith { $index }.GetNewClosure()
        Mock Invoke-RestMethod -ParameterFilter { $Uri -eq $signatures } -MockWith { $resource }.GetNewClosure()
        Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/4.7.0/*' } -MockWith { throw 'the 4.7.0 resource is older than 5.0.0' }
    }
}

Describe 'Test-NuGetTrustedSigners' {
    It 'passes when nuget.config trusts exactly the certificates the service index announces, in any case' {
        Set-AnnouncedCertificate -Fingerprint $old, $current
        $config = New-NuGetConfig -Fingerprint $current.ToUpperInvariant(), $old

        Invoke-TrustedSignerCheck -ConfigPath $config 6>$null | Should -Be 0
    }

    It 'fails on <Case>, naming the fingerprint and the command that fixes it' -ForEach @(
        @{ Case = 'a certificate announced that nuget.config does not trust'; Announced = 'current,next'; Trusted = 'current'; Named = 'next'; Message = 'announces' }
        @{ Case = 'a trusted certificate the service index no longer announces'; Announced = 'current'; Trusted = 'old,current'; Named = 'old'; Message = 'no longer announces' }
    ) {
        $byName = @{ old = $old; current = $current; next = $next }
        Set-AnnouncedCertificate -Fingerprint @($Announced.Split(',') | ForEach-Object { $byName[$_] })
        $config = New-NuGetConfig -Fingerprint @($Trusted.Split(',') | ForEach-Object { $byName[$_] })

        $exitCode = Invoke-TrustedSignerCheck -ConfigPath $config -InformationVariable messages 6>$null

        $exitCode | Should -Be 1
        ($messages -join "`n") | Should -Match "$($byName[$Named]).*$Message"
        ($messages -join "`n") | Should -Match 'dotnet nuget trust sync nuget\.org'
    }

    It 'fails on <Case>' -ForEach @(
        @{ Case = 'a nuget.config that trusts no repository named nuget.org'; Name = 'contoso'; Type = @('RepositorySignatures/5.0.0'); Message = "no trusted repository named 'nuget\.org'" }
        @{ Case = 'a service index that announces no repository signatures'; Name = 'nuget.org'; Type = @(); Message = 'RepositorySignatures' }
    ) {
        Set-AnnouncedCertificate -Fingerprint $current -Type $Type
        $config = New-NuGetConfig -Fingerprint $current -Name $Name

        $exitCode = Invoke-TrustedSignerCheck -ConfigPath $config -InformationVariable messages 6>$null

        $exitCode | Should -Be 1
        ($messages -join "`n") | Should -Match $Message
    }
}

# The scheduled check (GAP-038): kit only, since every app gets nuget.config from the kit (Export-KitApp, the kit sync).
Describe 'nuget-trust.yml' {
    BeforeAll {
        Import-Module powershell-yaml
        $path = Join-Path $PSScriptRoot '..' '..' '.github' 'workflows' 'nuget-trust.yml'
        $script:text = if (Test-Path -LiteralPath $path) { Get-Content -Raw -LiteralPath $path } else { '' }
        $script:workflow = if ($text) { ConvertFrom-Yaml $text } else { @{} }
        $script:jobs = if ($workflow.ContainsKey('jobs')) { $workflow['jobs'] } else { @{} }
        $script:check = if ($jobs.ContainsKey('check')) { $jobs['check'] } else { @{} }
        $script:report = if ($jobs.ContainsKey('report')) { $jobs['report'] } else { @{} }
        # powershell-yaml reads YAML 1.1, where a bare "on" key can be the boolean true.
        $script:on = if ($workflow.ContainsKey('on')) { $workflow['on'] } elseif ($workflow.ContainsKey($true)) { $workflow[$true] } else { @{} }
    }

    It 'runs on a schedule, by hand, and on pull requests that change the check or nuget.config' {
        $on.ContainsKey('workflow_dispatch') | Should -BeTrue
        @($on['schedule']).Count | Should -Be 1
        @($on['pull_request']['paths']) | Should -Be @('.github/workflows/nuget-trust.yml', 'tools/Test-NuGetTrustedSigners.ps1', 'nuget.config')
    }

    It 'gives the workflow no permissions, the check read access only, and the report only issue writes' {
        $workflow.ContainsKey('permissions') | Should -BeTrue
        $workflow['permissions'].Count | Should -Be 0
        @($check['permissions'].Keys) | Should -Be @('contents')
        $check['permissions']['contents'] | Should -Be 'read'
        @($report['permissions'].Keys) | Should -Be @('issues')
        $report['permissions']['issues'] | Should -Be 'write'
    }

    It 'runs the kit script against nuget.config, and says whether it differs' {
        $text | Should -Match '\./tools/Test-NuGetTrustedSigners\.ps1 -ConfigPath nuget\.config'
        $check['outputs']['differs'] | Should -Not -BeNullOrEmpty
    }

    It 'opens one issue when they differ, never from a pull request, and not when one is already open' {
        @($report['needs']) | Should -Be @('check')
        "$($report['if'])" | Should -Match "needs\.check\.outputs\.differs == 'true'"
        "$($report['if'])" | Should -Match "github\.event_name != 'pull_request'"
        $text | Should -Match 'gh issue list'
        $text | Should -Match 'gh issue create'
    }

    It 'pins every action to a full commit SHA (SUP-008)' {
        $uses = @($jobs.Values | ForEach-Object { @($_['steps']) } | Where-Object { $_.ContainsKey('uses') } | ForEach-Object { $_['uses'] })
        $uses | Should -Not -BeNullOrEmpty
        $uses | Should -Match '@[0-9a-f]{40}$'
    }
}
