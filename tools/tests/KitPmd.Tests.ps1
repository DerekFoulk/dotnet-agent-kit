#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# PMD's pin (ADR-0060): the version sits in .config/pmd/pom.xml, where Dependabot's maven updater moves it, and the
# release zip's SHA-256 in pmd-dist-bin.zip.sha256 beside it, in sha256sum's format. The shared .NET CI reads both
# through Get-PmdPin; on Dependabot's PMD PRs, dependabot-lockfiles.yml writes the new hash with Set-PmdPin.

# GAP-029: the pin job checks the zip's signature with gpg, on a Linux runner. Off CI, a Windows machine skips the tests
# that run gpg (Git for Windows' gpg can't read Windows paths), as does a machine without gpg; CI never skips them.
BeforeDiscovery {
    $script:skipGpg = ($IsWindows -or -not (Get-Command -Name gpg -ErrorAction SilentlyContinue)) -and -not $env:CI
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'KitPmd.psm1') -Force

    $script:hash = 'd27177c185b837fa57f097e482d1253468aa035379c5eb2671fa0a279109b179'

    # A stand-in for a PMD zip, signed with a test key made for these tests, whose public key and primary fingerprint
    # New-PinFolder pins. Like PMD's key, it signs with a subkey, so only a check of the primary key in gpg's VALIDSIG
    # line passes it. signed-by-another-key.asc is the same zip signed with a second test key (key B), and
    # two-signatures.asc holds both signatures.
    $script:signed = Join-Path $PSScriptRoot 'fixtures' 'PmdSignature'
    $script:zip = Join-Path $signed 'pmd-dist-7.30.0-bin.zip'
    $script:signature = Join-Path $signed 'pmd-dist-7.30.0-bin.zip.asc'
    $script:zipHash = 'c20c20e6c9be6dcd78a4293bc77d27a599cf6e3c3d8ecb711f9357b65b2c584b'

    # A pin folder like .config/pmd, with the pom's version and the pin file's text given.
    function New-PinFolder([string] $Version, [string] $Pin) {
        $folder = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $folder | Out-Null
        $pom = @"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>example</groupId>
  <artifactId>pmd-pin</artifactId>
  <version>1</version>
  <packaging>pom</packaging>
  <dependencies>
    <dependency>
      <groupId>net.sourceforge.pmd</groupId>
      <artifactId>pmd-dist</artifactId>
      <version>$Version</version>
    </dependency>
  </dependencies>
</project>
"@
        Set-Content -LiteralPath (Join-Path $folder 'pom.xml') -Value $pom -NoNewline
        if ($null -ne $Pin) {
            [IO.File]::WriteAllText((Join-Path $folder 'pmd-dist-bin.zip.sha256'), $Pin)
        }
        foreach ($file in 'pmd-release-key.asc', 'pmd-release-key.fingerprint') {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures' 'PmdSignature' $file) -Destination $folder
        }
        $folder
    }
}

Describe 'Get-PmdVersion' {
    # The workflow that pins a new zip asks GitHub for the release of this version.
    It "gives the pom's version" {
        $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"

        Get-Command -Module KitPmd -Name Get-PmdVersion -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-PmdVersion -Path $folder | Should -Be '7.30.0'
    }
}

# The pin job downloads the zip and its signature before it pins anything, while the pin file still names the old zip.
Describe 'Get-PmdDownload' {
    It "gives the GitHub release URLs of the pom's version's zip and its signature" {
        $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"

        Get-Command -Module KitPmd -Name Get-PmdDownload -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $download = Get-PmdDownload -Path $folder

        $download.Version | Should -Be '7.30.0'
        $download.FileName | Should -Be 'pmd-dist-7.30.0-bin.zip'
        $download.Url | Should -Be 'https://github.com/pmd/pmd/releases/download/pmd_releases%2F7.30.0/pmd-dist-7.30.0-bin.zip'
        $download.SignatureUrl | Should -Be 'https://github.com/pmd/pmd/releases/download/pmd_releases%2F7.30.0/pmd-dist-7.30.0-bin.zip.asc'
    }
}

Describe 'Get-PmdPin' {
    It "takes the version from the pom and the zip's SHA-256 from the pin file" {
        $folder = New-PinFolder -Version '7.29.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"

        $pin = Get-PmdPin -Path $folder

        $pin.Version | Should -Be '7.29.0'
        $pin.Sha256 | Should -Be $hash
        $pin.FileName | Should -Be 'pmd-dist-7.29.0-bin.zip'
        $pin.Url | Should -Be 'https://github.com/pmd/pmd/releases/download/pmd_releases%2F7.29.0/pmd-dist-7.29.0-bin.zip'
        $pin.PinFile | Should -Be (Join-Path $folder 'pmd-dist-bin.zip.sha256')
    }

    # Dependabot moves the pom alone; until the hash for the new zip is pinned, CI must stop, saying why.
    It 'refuses a pin for another version than the pom names, naming both' {
        $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"

        { Get-PmdPin -Path $folder } | Should -Throw '*7.30.0*7.29.0*'
    }

    # The version ends up in a URL and a file name, and sha256sum --check opens the file the pin names, so both must be
    # plain: a release version, and one line of 64 lowercase hex digits, two spaces and the zip's name.
    It 'refuses <Case>' -ForEach @(
        @{ Case = 'a hash that is too short'; Message = '*one line*'; Version = '7.29.0'; Pin = "d27177c1  pmd-dist-7.29.0-bin.zip`n" }
        @{ Case = 'an uppercase hash'; Message = '*one line*'; Version = '7.29.0'; Pin = "{HASH}  pmd-dist-7.29.0-bin.zip`n" }
        @{ Case = 'a second line'; Message = '*one line*'; Version = '7.29.0'; Pin = "{hash}  pmd-dist-7.29.0-bin.zip`n{hash}  other.zip`n" }
        @{ Case = 'a CR in the line'; Message = '*one line*'; Version = '7.29.0'; Pin = "{hash}  pmd-dist-7.29.0-bin.zip`r`n" }
        @{ Case = 'one space, not two'; Message = '*one line*'; Version = '7.29.0'; Pin = "{hash} pmd-dist-7.29.0-bin.zip`n" }
        @{ Case = 'a version that is not x.y.z'; Message = '*release version*'; Version = '7.29.0/../x'; Pin = "{hash}  pmd-dist-7.29.0/../x-bin.zip`n" }
        @{ Case = 'a snapshot version'; Message = '*release version*'; Version = '7.30.0-SNAPSHOT'; Pin = "{hash}  pmd-dist-7.30.0-SNAPSHOT-bin.zip`n" }
    ) {
        # The hash is filled in here: discovery, which expands the cases, can't see BeforeAll's variables.
        $folder = New-PinFolder -Version $Version -Pin $Pin.Replace('{hash}', $hash).Replace('{HASH}', $hash.ToUpperInvariant())

        { Get-PmdPin -Path $folder } | Should -Throw $Message
    }

    It 'refuses a pom without a pmd-dist dependency' {
        $folder = New-PinFolder -Version '7.29.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"
        $pom = Join-Path $folder 'pom.xml'
        (Get-Content -Raw -LiteralPath $pom) -replace 'pmd-dist', 'pmd-core' | Set-Content -LiteralPath $pom -NoNewline

        { Get-PmdPin -Path $folder } | Should -Throw '*pmd-dist*'
    }
}

# On Dependabot's PMD PRs the workflow passes the release as `gh api repos/pmd/pmd/releases/tags/...` returns it, with
# the zip and its .asc signature, downloaded from the release.
Describe 'Set-PmdPin' {
    BeforeAll {
        $script:now = [datetimeoffset]'2026-11-20T00:00:00Z'

        # The fields of GitHub's release JSON that Set-PmdPin reads.
        function New-Release([string] $Tag = 'pmd_releases/7.30.0', [string] $Asset = 'pmd-dist-7.30.0-bin.zip',
            [AllowNull()] [string] $Digest = "sha256:$zipHash", [string] $UpdatedAt = '2026-11-12T09:31:00Z') {
            [pscustomobject]@{
                tag_name = $Tag
                assets   = @(
                    [pscustomobject]@{ name = 'pmd-dist-7.30.0-src.zip'; digest = "sha256:$('bb' * 32)"; updated_at = $UpdatedAt }
                    [pscustomobject]@{ name = $Asset; digest = $(if ($Digest) { $Digest } else { $null }); updated_at = $UpdatedAt }
                )
            }
        }

        # The release, zip and signature for one way a signature check must fail, changing the pin folder as it needs.
        function Get-SignatureCase([string] $Setup, [string] $Folder) {
            $case = [pscustomobject]@{ Release = (New-Release); Zip = $zip; Signature = $signature }
            $otherSignature = Join-Path $signed 'signed-by-another-key.asc'
            switch ($Setup) {
                'OtherSignature' { $case.Signature = $otherSignature }
                'OtherKeyInFile' {
                    $case.Signature = $otherSignature
                    Get-Content -Raw -LiteralPath (Join-Path $signed 'another-key.asc') | Add-Content -LiteralPath (Join-Path $Folder 'pmd-release-key.asc')
                }
                'ChangedZip' {
                    # One bit changed, and GitHub's digest made to match the changed zip, so only the signature can tell.
                    $case.Zip = Join-Path $Folder 'pmd-dist-7.30.0-bin.zip'
                    $bytes = [IO.File]::ReadAllBytes($zip)
                    $bytes[10] = $bytes[10] -bxor 1
                    [IO.File]::WriteAllBytes($case.Zip, $bytes)
                    $case.Release = New-Release -Digest "sha256:$((Get-FileHash -LiteralPath $case.Zip -Algorithm SHA256).Hash.ToLowerInvariant())"
                }
                'TwoSignatures' {
                    # Both good, from two keys in the key file: one of them is the pinned key, but only one may sign.
                    $case.Signature = Join-Path $signed 'two-signatures.asc'
                    Get-Content -Raw -LiteralPath (Join-Path $signed 'another-key.asc') | Add-Content -LiteralPath (Join-Path $Folder 'pmd-release-key.asc')
                }
                'OtherDigest' { $case.Release = New-Release -Digest "sha256:$('aa' * 32)" }
                'BadFingerprint' { [IO.File]::WriteAllText((Join-Path $Folder 'pmd-release-key.fingerprint'), "7db3 1375`n") }
            }
            $case
        }
    }

    It 'refuses <Case>, leaving the pin as it was' -ForEach @(
        @{ Case = 'the release of another version'; Release = @{ Tag = 'pmd_releases/7.29.0' }; Message = '*pmd_releases/7.30.0*' }
        @{ Case = 'a release without the zip'; Release = @{ Asset = 'pmd-dist-7.30.0-bin.tar.gz' }; Message = '*pmd-dist-7.30.0-bin.zip*' }
        @{ Case = 'a zip GitHub gives no digest for'; Release = @{ Digest = $null }; Message = '*digest*' }
        @{ Case = 'a digest that is not SHA-256'; Release = @{ Digest = "sha512:$('aa' * 64)" }; Message = '*digest*' }
        # Review 1 of GAP-023: one second short of 7 days, so a shorter wait fails this case.
        @{ Case = 'a zip uploaded or changed under 7 days ago'; Release = @{ UpdatedAt = '2026-11-13T00:00:01Z' }; Message = '*7 days*' }
    ) {
        $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"
        $pinFile = Join-Path $folder 'pmd-dist-bin.zip.sha256'

        { Set-PmdPin -Path $folder -Release (New-Release @Release) -Zip $zip -Signature $signature -Now $now } | Should -Throw $Message

        [IO.File]::ReadAllText($pinFile) | Should -Be "$hash  pmd-dist-7.29.0-bin.zip`n"
    }

    # GAP-029: GitHub's digest comes from the server the zip comes from, so a zip replaced there before the pin, or bad from
    # its first upload, would match it. The signature, checked against the key the kit pins, catches that.
    Context 'with gpg' -Skip:$skipGpg {
        It "pins the zip's SHA-256 once its signature verifies against the pinned key, in sha256sum's format: LF, no BOM" {
            $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"
            (Get-Command -Name Set-PmdPin).Parameters.Keys | Should -Contain 'Signature'

            Set-PmdPin -Path $folder -Release (New-Release) -Zip $zip -Signature $signature -Now $now

            $bytes = [IO.File]::ReadAllBytes((Join-Path $folder 'pmd-dist-bin.zip.sha256'))
            $bytes | Should -Be ([Text.Encoding]::ASCII.GetBytes("$zipHash  pmd-dist-7.30.0-bin.zip`n"))
            (Get-PmdPin -Path $folder).Sha256 | Should -Be $zipHash
        }

        It 'pins a zip exactly 7 days old: the wait matches Dependabot''s cooldown, no longer' {
            $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"

            Set-PmdPin -Path $folder -Release (New-Release -UpdatedAt '2026-11-13T00:00:00Z') -Zip $zip -Signature $signature -Now $now

            (Get-PmdPin -Path $folder).Sha256 | Should -Be $zipHash
        }

        It 'refuses <Case>, leaving the pin as it was' -ForEach @(
            # Key B isn't in the keyring at all, so gpg can't check the signature.
            @{ Case = 'a signature by a key the kit does not pin'; Setup = 'OtherSignature'; Message = '*886F1C32C2FA876051F9EB0B28171CA6BD473A64*' }
            # Key B is in the key file and its signature is good, but it isn't the pinned key.
            @{ Case = 'a good signature by another key in the key file'; Setup = 'OtherKeyInFile'; Message = '*886F1C32C2FA876051F9EB0B28171CA6BD473A64*' }
            @{ Case = 'a zip changed after it was signed'; Setup = 'ChangedZip'; Message = '*886F1C32C2FA876051F9EB0B28171CA6BD473A64*' }
            @{ Case = 'a signature file with a second signature'; Setup = 'TwoSignatures'; Message = '*886F1C32C2FA876051F9EB0B28171CA6BD473A64*' }
            @{ Case = 'a signed zip whose SHA-256 is not GitHub''s digest'; Setup = 'OtherDigest'; Message = "*GitHub's digest*" }
            @{ Case = 'a fingerprint file that is not 40 uppercase hex digits'; Setup = 'BadFingerprint'; Message = '*pmd-release-key.fingerprint*' }
        ) {
            $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"
            $pinFile = Join-Path $folder 'pmd-dist-bin.zip.sha256'
            $case = Get-SignatureCase -Setup $Setup -Folder $folder

            { Set-PmdPin -Path $folder -Release $case.Release -Zip $case.Zip -Signature $case.Signature -Now $now } | Should -Throw $Message

            [IO.File]::ReadAllText($pinFile) | Should -Be "$hash  pmd-dist-7.29.0-bin.zip`n"
        }
    }
}

# The key itself (ADR-0060, GAP-029): PMD's "PMD Release Signing Key <releases@pmd-code.org>", whose fingerprint PMD
# publishes on https://docs.pmd-code.org/latest/pmd_userdocs_signed_releases.html. A key change is a reviewed PR that
# replaces both files.
Describe "The kit's PMD release key" -Skip:$skipGpg {
    BeforeAll {
        $script:config = Join-Path $PSScriptRoot '..' '..' '.config' 'pmd'
    }

    It 'pins the primary key fingerprint PMD publishes' {
        [IO.File]::ReadAllText((Join-Path $config 'pmd-release-key.fingerprint')).TrimEnd() | Should -Be '2EFA55D0785C31F956F2F87EA0B5CA1A4E086838'
    }

    It 'holds that one key and nothing else' {
        $lines = @(gpg --batch --show-keys --with-colons (Join-Path $config 'pmd-release-key.asc'))
        $primary = @($lines | Where-Object { $_ -like 'pub:*' })
        $firstFingerprint = @($lines | Where-Object { $_ -like 'fpr:*' })[0]

        $primary | Should -HaveCount 1
        $firstFingerprint.Split(':')[9] | Should -Be '2EFA55D0785C31F956F2F87EA0B5CA1A4E086838'
    }
}
