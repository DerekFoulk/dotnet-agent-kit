#Requires -Version 7.6
# PMD's pin (ADR-0060): the version Dependabot's maven updater moves in .config/pmd/pom.xml, and the release zip's
# SHA-256 beside it in pmd-dist-bin.zip.sha256, one line in sha256sum's format. The shared .NET CI reads both through
# Get-PmdPin; on Dependabot's PMD PRs, dependabot-lockfiles.yml writes the new hash with Set-PmdPin.

Set-StrictMode -Version Latest

$script:PinFileName = 'pmd-dist-bin.zip.sha256'

# PMD's version, from the pom's one pmd-dist dependency.
function Get-PmdVersion([string] $Path) {
    [xml] $pom = Get-Content -Raw -LiteralPath (Join-Path $Path 'pom.xml')
    $namespace = @{ m = 'http://maven.apache.org/POM/4.0.0' }
    $nodes = @(Select-Xml -Xml $pom -Namespace $namespace -XPath "/m:project/m:dependencies/m:dependency[m:groupId='net.sourceforge.pmd' and m:artifactId='pmd-dist']/m:version")
    $nodes[0].Node.InnerText.Trim()
}

function Get-PmdPin {
    param([Parameter(Mandatory)] [string] $Path)

    $version = Get-PmdVersion $Path
    $pinFile = Join-Path $Path $script:PinFileName
    $hash, $fileName = (Get-Content -Raw -LiteralPath $pinFile).Trim() -split '  ', 2
    [pscustomobject]@{
        Version  = $version
        Sha256   = $hash
        FileName = $fileName
        Url      = "https://github.com/pmd/pmd/releases/download/pmd_releases%2F$version/$fileName"
        PinFile  = $pinFile
    }
}

Export-ModuleMember -Function Get-PmdPin
