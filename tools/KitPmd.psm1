#Requires -Version 7.6
# PMD's pin (ADR-0060): the version Dependabot's maven updater moves in .config/pmd/pom.xml, and the release zip's
# SHA-256 beside it in pmd-dist-bin.zip.sha256, one line in sha256sum's format. The shared .NET CI reads both through
# Get-PmdPin; on Dependabot's PMD PRs, dependabot-lockfiles.yml writes the new hash with Set-PmdPin.

Set-StrictMode -Version Latest

$script:PinFileName = 'pmd-dist-bin.zip.sha256'

# PMD's version, from the pom's one pmd-dist dependency. It ends up in a URL and a file name, so only a release
# version (x.y.z) passes: no path characters, no snapshot.
function Get-PmdVersion {
    param([Parameter(Mandatory)] [string] $Path)

    $pomFile = Join-Path $Path 'pom.xml'
    [xml] $pom = Get-Content -Raw -LiteralPath $pomFile
    $namespace = @{ m = 'http://maven.apache.org/POM/4.0.0' }
    $xpath = "/m:project/m:dependencies/m:dependency[m:groupId='net.sourceforge.pmd' and m:artifactId='pmd-dist']/m:version"
    $nodes = @(Select-Xml -Xml $pom -Namespace $namespace -XPath $xpath)
    if ($nodes.Count -ne 1) {
        throw "$pomFile must name exactly one net.sourceforge.pmd:pmd-dist dependency with a version; it names $($nodes.Count)."
    }
    $version = $nodes[0].Node.InnerText
    if ($version -notmatch '\A\d+\.\d+\.\d+\z') {
        throw "$pomFile names PMD '$version', which isn't a release version (x.y.z)."
    }
    $version
}

function Get-PmdPin {
    param([Parameter(Mandatory)] [string] $Path)

    $version = Get-PmdVersion $Path
    $pinFile = Join-Path $Path $script:PinFileName
    $text = [IO.File]::ReadAllText($pinFile)
    # sha256sum's format, exactly: one line, LF-terminated, of a lowercase SHA-256, two spaces and the zip's name.
    $line = [regex]::Match($text, '\A(?<hash>[0-9a-f]{64})  (?<file>pmd-dist-[0-9A-Za-z.-]+-bin\.zip)\n\z')
    if (-not $line.Success) {
        throw "$pinFile must be one line: a lowercase SHA-256, two spaces and pmd-dist-<version>-bin.zip, ending in LF."
    }
    $fileName = $line.Groups['file'].Value
    $expected = "pmd-dist-$version-bin.zip"
    if ($fileName -cne $expected) {
        throw "The pom names PMD $version, but $pinFile pins '$fileName', not $expected. Pin the new zip's SHA-256 with Set-PmdPin (ADR-0060)."
    }
    [pscustomobject]@{
        Version  = $version
        Sha256   = $line.Groups['hash'].Value
        FileName = $fileName
        Url      = "https://github.com/pmd/pmd/releases/download/pmd_releases%2F$version/$fileName"
        PinFile  = $pinFile
    }
}

# Pins the zip of the pom's version from GitHub's release data (`gh api repos/pmd/pmd/releases/tags/<tag>`): the
# SHA-256 GitHub computed for the asset when it was uploaded. The asset must be at least 7 days old, the same wait
# Dependabot's cooldown gives the version on Maven Central (ADR-0041), so a zip replaced after the release is caught.
function Set-PmdPin {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [object] $Release,
        [datetimeoffset] $Now = [datetimeoffset]::UtcNow
    )

    $version = Get-PmdVersion $Path
    $tag = "pmd_releases/$version"
    if ($Release.tag_name -cne $tag) {
        throw "The pom names PMD $version, so the release must be $tag, not '$($Release.tag_name)'."
    }
    $fileName = "pmd-dist-$version-bin.zip"
    $assets = @($Release.assets | Where-Object { $_.name -ceq $fileName })
    if ($assets.Count -ne 1) {
        throw "Release $tag has no asset named $fileName."
    }
    $asset = $assets[0]
    if ("$($asset.digest)" -notmatch '\Asha256:(?<hash>[0-9a-f]{64})\z') {
        throw "GitHub gives no SHA-256 digest for $fileName in $tag ('$($asset.digest)'); pin it by hand from a verified download."
    }
    $age = $Now - [datetimeoffset] $asset.updated_at
    if ($age -lt [timespan]::FromDays(7)) {
        throw "$fileName in $tag was uploaded or changed at $($asset.updated_at), under 7 days ago; run this again once it's 7 days old."
    }
    $pin = "$($Matches['hash'])  $fileName`n"
    [IO.File]::WriteAllText((Join-Path $Path $script:PinFileName), $pin, [Text.UTF8Encoding]::new($false))
}

Export-ModuleMember -Function Get-PmdVersion, Get-PmdPin, Set-PmdPin
