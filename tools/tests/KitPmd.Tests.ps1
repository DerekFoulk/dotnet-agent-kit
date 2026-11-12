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
}
