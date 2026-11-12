#Requires -Version 7.6
# PMD's pin (ADR-0060): the version Dependabot moves in .config/pmd/pom.xml, and the release zip's SHA-256 beside it.

Set-StrictMode -Version Latest

function Get-PmdPin {
    param([Parameter(Mandatory)] [string] $Path)

    [pscustomobject]@{ Version = $null; Sha256 = $null; FileName = $null; Url = $null; PinFile = $null }
}

Export-ModuleMember -Function Get-PmdPin
