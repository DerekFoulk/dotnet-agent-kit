#Requires -Version 7.6
# PMD's pin (ADR-0060): the version Dependabot's maven updater moves in .config/pmd/pom.xml, and the release zip's
# SHA-256 beside it in pmd-dist-bin.zip.sha256, one line in sha256sum's format. The shared .NET CI reads both through
# Get-PmdPin; on Dependabot's PMD PRs, dependabot-lockfiles.yml writes the new hash with Set-PmdPin, which first checks
# the zip's signature against PMD's release key, pinned in the same folder (GAP-029).

Set-StrictMode -Version Latest

$script:PinFileName = 'pmd-dist-bin.zip.sha256'
$script:KeyFileName = 'pmd-release-key.asc'
$script:FingerprintFileName = 'pmd-release-key.fingerprint'

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

# Where the pom's version's zip and its signature are on GitHub's release page. The pin job downloads both before the
# pin file names the new zip, so this reads only the pom.
function Get-PmdDownload {
    param([Parameter(Mandatory)] [string] $Path)

    $version = Get-PmdVersion $Path
    $fileName = "pmd-dist-$version-bin.zip"
    $url = "https://github.com/pmd/pmd/releases/download/pmd_releases%2F$version/$fileName"
    [pscustomobject]@{
        Version      = $version
        FileName     = $fileName
        Url          = $url
        SignatureUrl = "$url.asc"
    }
}

function Get-PmdPin {
    param([Parameter(Mandatory)] [string] $Path)

    $download = Get-PmdDownload $Path
    $version = $download.Version
    $pinFile = Join-Path $Path $script:PinFileName
    $text = [IO.File]::ReadAllText($pinFile)
    # sha256sum's format, exactly: one line, LF-terminated, of a lowercase SHA-256, two spaces and the zip's name.
    $line = [regex]::Match($text, '\A(?<hash>[0-9a-f]{64})  (?<file>pmd-dist-[0-9A-Za-z.-]+-bin\.zip)\n\z')
    if (-not $line.Success) {
        throw "$pinFile must be one line: a lowercase SHA-256, two spaces and pmd-dist-<version>-bin.zip, ending in LF."
    }
    $fileName = $line.Groups['file'].Value
    if ($fileName -cne $download.FileName) {
        throw "The pom names PMD $version, but $pinFile pins '$fileName', not $($download.FileName). Pin the new zip's SHA-256 with Set-PmdPin (ADR-0060)."
    }
    [pscustomobject]@{
        Version  = $version
        Sha256   = $line.Groups['hash'].Value
        FileName = $fileName
        Url      = $download.Url
        PinFile  = $pinFile
    }
}

# The primary key fingerprint of PMD's release key, as the kit pins it beside the key (GAP-029): 40 uppercase hex
# digits on one line, as gpg prints it in its status lines.
function Get-PmdReleaseKeyFingerprint {
    param([Parameter(Mandatory)] [string] $Path)

    $file = Join-Path $Path $script:FingerprintFileName
    $line = [regex]::Match([IO.File]::ReadAllText($file), '\A(?<fingerprint>[0-9A-F]{40})\r?\n\z')
    if (-not $line.Success) {
        throw "$file must be one line: the 40 uppercase hex digits of PMD's release key's primary fingerprint (ADR-0060)."
    }
    $line.Groups['fingerprint'].Value
}

# Checks the zip's detached signature with gpg, in a keyring of its own that holds only the key file beside the pin.
# gpg exits 0 for a good signature by any key in that keyring, so the status lines decide: exactly one signature
# result, a good one (GOODSIG: not bad, expired or revoked), whose VALIDSIG names the pinned key as its primary key.
function Assert-PmdSignature {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Zip,
        [Parameter(Mandatory)] [string] $Signature
    )

    $fingerprint = Get-PmdReleaseKeyFingerprint $Path
    # gpg's exit code is read below, with its status lines; the pin job's own setting would throw before that.
    $PSNativeCommandUseErrorActionPreference = $false
    $keyring = Join-Path ([IO.Path]::GetTempPath()) "kit-pmd-gpg-$([guid]::NewGuid().ToString('n'))"
    New-Item -ItemType Directory -Path $keyring | Out-Null
    try {
        $import = gpg --batch --homedir $keyring --import (Join-Path $Path $script:KeyFileName) 2>&1
        if ($LASTEXITCODE -ne 0) { throw "gpg couldn't import $(Join-Path $Path $script:KeyFileName): $($import -join ' ')" }
        $status = @(gpg --batch --homedir $keyring --status-fd 1 --verify $Signature $Zip 2>$null)
        $verified = $LASTEXITCODE -eq 0
    }
    finally {
        # gpg 2.4 can start an agent or keyboxd for the keyring; stop them, or the folder can't be removed.
        gpgconf --homedir $keyring --kill all 2>$null
        Remove-Item -LiteralPath $keyring -Recurse -Force -ErrorAction SilentlyContinue
    }
    $results = @($status | Where-Object { $_ -match '\A\[GNUPG:\] (GOODSIG|EXPSIG|EXPKEYSIG|REVKEYSIG|BADSIG|ERRSIG) ' })
    $valid = @($status | Where-Object { $_ -like '`[GNUPG:`] VALIDSIG *' })
    $primary = if ($valid.Count -eq 1) { @($valid[0] -split ' ')[11] } else { $null }
    if (-not $verified -or $results.Count -ne 1 -or $results[0] -notlike '`[GNUPG:`] GOODSIG *' -or $primary -cne $fingerprint) {
        $said = @($status | Where-Object { $_ -match '\A\[GNUPG:\] (GOODSIG|EXPSIG|EXPKEYSIG|REVKEYSIG|BADSIG|ERRSIG|NO_PUBKEY|VALIDSIG) ' }) -join '; '
        throw "$Zip isn't signed by PMD's release key $fingerprint, as $Signature should show (gpg: $said). If PMD changed its key, follow ADR-0060's key change steps."
    }
}

# Pins the zip of the pom's version, downloaded from its GitHub release with its .asc signature. The signature must
# verify against the PMD release key the kit pins (GAP-029), and the zip's SHA-256 must equal the one GitHub computed
# for the asset when it was uploaded (`gh api repos/pmd/pmd/releases/tags/<tag>`). The asset must be at least 7 days
# old, the same wait Dependabot's cooldown gives the version on Maven Central (ADR-0041).
function Set-PmdPin {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [object] $Release,
        [Parameter(Mandatory)] [string] $Zip,
        [Parameter(Mandatory)] [string] $Signature,
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
    $digest = $Matches['hash']
    Assert-PmdSignature -Path $Path -Zip $Zip -Signature $Signature
    $actual = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $digest) {
        throw "The signed zip's SHA-256 is $actual, but GitHub's digest for $fileName in $tag is $digest; download it again, and if they still differ, don't pin it."
    }
    $pin = "$actual  $fileName`n"
    [IO.File]::WriteAllText((Join-Path $Path $script:PinFileName), $pin, [Text.UTF8Encoding]::new($false))
}

Export-ModuleMember -Function Get-PmdVersion, Get-PmdDownload, Get-PmdPin, Set-PmdPin
