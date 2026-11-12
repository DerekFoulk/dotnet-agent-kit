#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# PMD's pin (ADR-0060): the version sits in .config/pmd/pom.xml, where Dependabot's maven updater moves it, and the
# release zip's SHA-256 in pmd-dist-bin.zip.sha256 beside it, in sha256sum's format. The shared .NET CI reads both
# through Get-PmdPin; on Dependabot's PMD PRs, dependabot-lockfiles.yml writes the new hash with Set-PmdPin.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'KitPmd.psm1') -Force

    $script:hash = 'd27177c185b837fa57f097e482d1253468aa035379c5eb2671fa0a279109b179'

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

# On Dependabot's PMD PRs the workflow passes the release as `gh api repos/pmd/pmd/releases/tags/...` returns it.
Describe 'Set-PmdPin' {
    BeforeAll {
        $script:now = [datetimeoffset]'2026-11-20T00:00:00Z'
        $script:newHash = 'aa' * 32

        # The fields of GitHub's release JSON that Set-PmdPin reads.
        function New-Release([string] $Tag = 'pmd_releases/7.30.0', [string] $Asset = 'pmd-dist-7.30.0-bin.zip',
            [AllowNull()] [string] $Digest = "sha256:$newHash", [string] $UpdatedAt = '2026-11-12T09:31:00Z') {
            [pscustomobject]@{
                tag_name = $Tag
                assets   = @(
                    [pscustomobject]@{ name = 'pmd-dist-7.30.0-src.zip'; digest = "sha256:$('bb' * 32)"; updated_at = $UpdatedAt }
                    [pscustomobject]@{ name = $Asset; digest = $(if ($Digest) { $Digest } else { $null }); updated_at = $UpdatedAt }
                )
            }
        }
    }

    It "pins the pom's version with GitHub's digest for the zip, in sha256sum's format: LF, no BOM" {
        $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"

        Set-PmdPin -Path $folder -Release (New-Release) -Now $now

        $bytes = [IO.File]::ReadAllBytes((Join-Path $folder 'pmd-dist-bin.zip.sha256'))
        $bytes | Should -Be ([Text.Encoding]::ASCII.GetBytes("$newHash  pmd-dist-7.30.0-bin.zip`n"))
        (Get-PmdPin -Path $folder).Sha256 | Should -Be $newHash
    }

    It 'refuses <Case>, leaving the pin as it was' -ForEach @(
        @{ Case = 'the release of another version'; Release = @{ Tag = 'pmd_releases/7.29.0' }; Message = '*pmd_releases/7.30.0*' }
        @{ Case = 'a release without the zip'; Release = @{ Asset = 'pmd-dist-7.30.0-bin.tar.gz' }; Message = '*pmd-dist-7.30.0-bin.zip*' }
        @{ Case = 'a zip GitHub gives no digest for'; Release = @{ Digest = $null }; Message = '*digest*' }
        @{ Case = 'a digest that is not SHA-256'; Release = @{ Digest = "sha512:$('aa' * 64)" }; Message = '*digest*' }
        @{ Case = 'a zip uploaded or changed under 7 days ago'; Release = @{ UpdatedAt = '2026-11-14T00:00:01Z' }; Message = '*7 days*' }
    ) {
        $folder = New-PinFolder -Version '7.30.0' -Pin "$hash  pmd-dist-7.29.0-bin.zip`n"
        $pinFile = Join-Path $folder 'pmd-dist-bin.zip.sha256'

        { Set-PmdPin -Path $folder -Release (New-Release @Release) -Now $now } | Should -Throw $Message

        [IO.File]::ReadAllText($pinFile) | Should -Be "$hash  pmd-dist-7.29.0-bin.zip`n"
    }
}
