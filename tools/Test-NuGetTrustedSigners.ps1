#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when nuget.config's trusted certificates for nuget.org differ from the ones nuget.org's service index
    announces (SUP-012, ADR-0066, GAP-038).

.DESCRIPTION
    nuget.config requires every package to carry nuget.org's repository signature, by one of the certificates it lists.
    Those are the certificates nuget.org's service index announced when `dotnet nuget trust sync nuget.org` last wrote
    them. When nuget.org rotates its certificate, a package signed with the new one fails NU3004 in the kit and every
    app until someone syncs. This script reads the service index the config names, takes the SHA-256 fingerprints of
    the certificates its newest RepositorySignatures resource lists, and compares them with the config's, as sets,
    ignoring case. It reads only nuget.org's public API and changes nothing. nuget-trust.yml runs it daily.

.EXAMPLE
    ./tools/Test-NuGetTrustedSigners.ps1 -ConfigPath nuget.config
#>
[CmdletBinding()]
param([string] $ConfigPath = 'nuget.config')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Source = 'nuget.org'
# The object identifier of SHA-256, under which the RepositorySignatures resource gives each certificate's fingerprint.
$script:Sha256Oid = '2.16.840.1.101.3.4.2.1'

# The trusted repository's service index and certificate fingerprints, as nuget.config's trustedSigners section lists
# them, lowercase; nothing when the config trusts no repository by that name.
function Get-TrustedCertificate {
    param([Parameter(Mandatory)] [string] $ConfigPath)

    [xml] $config = Get-Content -Raw -LiteralPath $ConfigPath
    $repository = @($config.SelectNodes("/configuration/trustedSigners/repository[@name='$script:Source']"))
    if ($repository.Count -ne 1) { return }
    [pscustomobject]@{
        ServiceIndex = $repository[0].GetAttribute('serviceIndex')
        Fingerprints = @($repository[0].SelectNodes('certificate') | ForEach-Object { $_.GetAttribute('fingerprint').ToLowerInvariant() })
    }
}

# The SHA-256 fingerprints, lowercase, of the certificates the service index's newest RepositorySignatures resource
# announces; nothing when it has no such resource.
function Get-AnnouncedCertificate {
    param([Parameter(Mandatory)] [string] $ServiceIndex)

    $index = Invoke-RestMethod -Uri $ServiceIndex
    $resource = @($index.resources | Where-Object { "$($_.'@type')" -match '\ARepositorySignatures/(\d+\.\d+\.\d+)\z' } |
            Sort-Object { [version] ("$($_.'@type')".Split('/')[1]) } -Descending)
    if ($resource.Count -eq 0) { return }
    $signatures = Invoke-RestMethod -Uri $resource[0].'@id'
    @($signatures.signingCertificates | ForEach-Object { "$($_.fingerprints.$script:Sha256Oid)".ToLowerInvariant() })
}

# Prints each difference and returns 0 when the two sets match, 1 otherwise.
function Invoke-TrustedSignerCheck {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $ConfigPath)

    $problems = [System.Collections.Generic.List[string]]::new()
    $trusted = Get-TrustedCertificate -ConfigPath $ConfigPath
    $announced = @(if ($trusted) { Get-AnnouncedCertificate -ServiceIndex $trusted.ServiceIndex })
    if (-not $trusted) {
        $problems.Add("$ConfigPath has no trusted repository named '$script:Source' in its trustedSigners section (SUP-012).")
    }
    elseif ($announced.Count -eq 0) {
        $problems.Add("$($trusted.ServiceIndex) announces no RepositorySignatures resource with certificates, so nothing could be compared.")
    }
    else {
        foreach ($fingerprint in $announced | Where-Object { $_ -notin $trusted.Fingerprints }) {
            $problems.Add("$fingerprint`: $($trusted.ServiceIndex) announces this certificate, but $ConfigPath doesn't trust it.")
        }
        foreach ($fingerprint in $trusted.Fingerprints | Where-Object { $_ -notin $announced }) {
            $problems.Add("$fingerprint`: $ConfigPath trusts this certificate, but $($trusted.ServiceIndex) no longer announces it.")
        }
    }

    foreach ($problem in $problems) { Write-Host "  $problem" -ForegroundColor Red }
    if ($problems.Count -gt 0) {
        Write-Host "`nnuget.org's repository certificates changed. Run 'dotnet nuget trust sync nuget.org --configfile $ConfigPath', check the new certificate against nuget.org's announcement, and commit it (ADR-0066)." -ForegroundColor Red
        return 1
    }
    Write-Host "$ConfigPath trusts the $($announced.Count) certificate(s) $($trusted.ServiceIndex) announces." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-TrustedSignerCheck -ConfigPath $ConfigPath)
}
