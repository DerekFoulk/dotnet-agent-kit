#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# GAP-040 (SEC-005, ADR-0004): every package a solution's lock files resolve, transitive ones included, has a license
# the policy allows. The license comes from the package's .nuspec in the global packages folder: an SPDX expression,
# checked against the policy's licenses, or a license file or URL, which only a package entry pinning it allows. The
# kit's policy is tools/package-licenses.json; a repo adds to it, or declares itself commercial, in
# .config/package-licenses.json.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Test-PackageLicenses.ps1')

    $script:licenseText = "Permission is granted to use this for anything.`n"
    $script:licenseHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($licenseText))).ToLowerInvariant()

    # A repo with App.slnx, one project whose lock file resolves each package (and a project reference, which isn't a
    # package), a packages folder holding each package's .nuspec, and the kit's policy. Each package is a hashtable:
    # Id, Version, and one of Expression, File (with the license text above) or Url.
    function New-LicenseRepo([hashtable[]] $Package, [hashtable] $Policy = @{ licenses = @('MIT', 'Apache-2.0') },
        [hashtable] $RepoPolicy, [switch] $NoLockFile, [string[]] $NotRestored = @()) {
        $repo = Join-Path $TestDrive ([guid]::NewGuid())
        $project = Join-Path $repo 'src' 'App'
        $packages = Join-Path $repo 'packages'
        New-Item -ItemType Directory -Path $project, $packages, (Join-Path $repo '.config') | Out-Null
        Set-Content -LiteralPath (Join-Path $repo 'App.slnx') -Value '<Solution><Project Path="src/App/App.csproj" /></Solution>'
        Set-Content -LiteralPath (Join-Path $project 'App.csproj') -Value '<Project Sdk="Microsoft.NET.Sdk" />'
        $dependencies = [ordered]@{ 'App.Domain' = @{ type = 'Project' } }
        foreach ($p in $Package) {
            $dependencies[$p.Id] = @{ type = 'Transitive'; resolved = $p.Version; contentHash = 'x' }
            if ($p.Id -in $NotRestored) { continue }
            $folder = Join-Path $packages $p.Id.ToLowerInvariant() $p.Version.ToLowerInvariant()
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            $license = if ($p.ContainsKey('Expression')) { "<license type=""expression"">$($p.Expression)</license>" }
            elseif ($p.ContainsKey('File')) { "<license type=""file"">$($p.File)</license>" }
            else { '' }
            $url = if ($p.ContainsKey('Url')) { "<licenseUrl>$($p.Url)</licenseUrl>" } else { '<licenseUrl>https://aka.ms/deprecateLicenseUrl</licenseUrl>' }
            if ($p.ContainsKey('File')) { [IO.File]::WriteAllText((Join-Path $folder $p.File), $(if ($p.ContainsKey('Text')) { $p.Text } else { $licenseText })) }
            Set-Content -LiteralPath (Join-Path $folder "$($p.Id.ToLowerInvariant()).nuspec") -Value @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>$($p.Id)</id>
    <version>$($p.Version)</version>
    $license
    $url
  </metadata>
</package>
"@
        }
        if (-not $NoLockFile) {
            @{ version = 1; dependencies = @{ 'net10.0' = $dependencies } } | ConvertTo-Json -Depth 5 |
                Set-Content -LiteralPath (Join-Path $project 'packages.lock.json')
        }
        $Policy | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $repo 'kit-policy.json')
        if ($RepoPolicy) { $RepoPolicy | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $repo '.config' 'package-licenses.json') }
        [pscustomobject]@{ Solution = (Join-Path $repo 'App.slnx'); Policy = (Join-Path $repo 'kit-policy.json'); Packages = $packages }
    }

    function Invoke-Check($Repo) {
        $exitCode = Invoke-PackageLicenseCheck -Solution $Repo.Solution -Policy $Repo.Policy -PackagesFolder $Repo.Packages -InformationVariable messages 6>$null
        [pscustomobject]@{ ExitCode = $exitCode; Text = ($messages -join "`n") }
    }
}

Describe 'Test-PackageLicenses' {
    It 'passes when every package the lock files resolve has a license expression on the list' {
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Core'; Version = '1.2.0'; Expression = 'MIT' }, @{ Id = 'Contoso.Http'; Version = '2.0.0-Beta'; Expression = 'Apache-2.0' }

        $result = Invoke-Check $repo

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match '2 package'
    }

    It 'fails a package whose expression is not on the list, naming it, its version and its license' {
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Core'; Version = '1.2.0'; Expression = 'MIT' }, @{ Id = 'Contoso.Gpl'; Version = '3.1.0'; Expression = 'GPL-3.0-only' }

        $result = Invoke-Check $repo

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Contoso\.Gpl 3\.1\.0: expression GPL-3\.0-only'
        $result.Text | Should -Not -Match 'Contoso\.Core'
    }

    # SPDX license expressions: OR needs one side allowed, AND both, WITH adds an exception to its license, which only
    # widens it; a license id matches in any case, and "+" (this version or later) allows the version named.
    It 'reads the expression <Expression> as <Verdict>' -ForEach @(
        @{ Expression = 'MIT OR GPL-3.0-only'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = 'GPL-3.0-only OR MIT'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = 'MIT AND GPL-3.0-only'; Verdict = 'not allowed'; ExitCode = 1 }
        @{ Expression = 'MIT AND Apache-2.0'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = '(MIT AND GPL-3.0-only) OR Apache-2.0'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = 'MIT AND (GPL-3.0-only OR Apache-2.0)'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = 'MIT AND (GPL-3.0-only OR LGPL-2.1-only)'; Verdict = 'not allowed'; ExitCode = 1 }
        @{ Expression = 'Apache-2.0 WITH LLVM-exception'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = 'GPL-2.0-only WITH Classpath-exception-2.0'; Verdict = 'not allowed'; ExitCode = 1 }
        @{ Expression = 'mit'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = 'Apache-2.0+'; Verdict = 'allowed'; ExitCode = 0 }
        @{ Expression = 'LicenseRef-Contoso'; Verdict = 'not allowed'; ExitCode = 1 }
        @{ Expression = 'MIT OR'; Verdict = 'not allowed, being malformed'; ExitCode = 1 }
        @{ Expression = '(MIT'; Verdict = 'not allowed, being malformed'; ExitCode = 1 }
        @{ Expression = 'MIT Apache-2.0'; Verdict = 'not allowed, being malformed'; ExitCode = 1 }
        @{ Expression = 'MIT or Apache-2.0'; Verdict = 'not allowed, as SPDX operators are uppercase'; ExitCode = 1 }
    ) {
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Core'; Version = '1.0.0'; Expression = $Expression }

        (Invoke-Check $repo).ExitCode | Should -Be $ExitCode
    }

    It 'allows a license file only through a package entry that pins its SHA-256' {
        $pinned = @{ licenses = @('MIT'); packages = @(@{ id = 'Contoso.Tools'; license = "file LICENSE.txt sha256:$licenseHash"; reason = 'MIT, in a file' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Tools'; Version = '1.0.0'; File = 'LICENSE.txt' } -Policy $pinned
        $unpinned = New-LicenseRepo -Package @{ Id = 'Contoso.Tools'; Version = '1.0.0'; File = 'LICENSE.txt' }

        (Invoke-Check $repo).ExitCode | Should -Be 0
        (Invoke-Check $unpinned).Text | Should -Match "Contoso\.Tools 1\.0\.0: file LICENSE\.txt sha256:$licenseHash"
    }

    # A package can change its license between versions, as FluentAssertions did in version 8; the entry pins the
    # license, not just the package, so a new one is read before it's allowed.
    It 'fails a package whose license is no longer the one its entry pins, naming both' {
        $pinned = @{ licenses = @('MIT'); packages = @(@{ id = 'Contoso.Tools'; license = "file LICENSE.txt sha256:$licenseHash"; reason = 'MIT, in a file' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Tools'; Version = '2.0.0'; File = 'LICENSE.txt'; Text = "Free for non-commercial use only.`n" } -Policy $pinned

        $result = Invoke-Check $repo

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "Contoso\.Tools 2\.0\.0: file LICENSE\.txt sha256:[0-9a-f]{64}.*sha256:$licenseHash"
    }

    It 'allows a package with only a license URL through a package entry that names the URL' {
        $pinned = @{ licenses = @('MIT'); packages = @(@{ id = 'Contoso.Legacy'; license = 'url https://contoso.example/license'; reason = 'free for any use' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Legacy'; Version = '1.0.0'; Url = 'https://contoso.example/license' } -Policy $pinned
        $unpinned = New-LicenseRepo -Package @{ Id = 'Contoso.Legacy'; Version = '1.0.0'; Url = 'https://contoso.example/license' }

        (Invoke-Check $repo).ExitCode | Should -Be 0
        (Invoke-Check $unpinned).Text | Should -Match 'Contoso\.Legacy 1\.0\.0: url https://contoso\.example/license'
    }

    # ADR-0004: a package free only for non-commercial use is allowed until the repo declares itself commercial, and
    # then fails, naming its free swap.
    It 'allows a non-commercial package in a repo that is <Case>' -ForEach @(
        @{ Case = 'not marked commercial'; RepoPolicy = $null; ExitCode = 0 }
        @{ Case = 'marked commercial false'; RepoPolicy = @{ commercial = $false }; ExitCode = 0 }
    ) {
        $policy = @{ licenses = @('MIT'); packages = @(@{ id = 'Contoso.Asserts'; license = "file LICENSE sha256:$licenseHash"; commercialUse = $false; swap = 'Fabrikam.Asserts'; reason = 'free for non-commercial use' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Asserts'; Version = '8.0.0'; File = 'LICENSE' } -Policy $policy -RepoPolicy $RepoPolicy

        (Invoke-Check $repo).ExitCode | Should -Be $ExitCode
    }

    It 'fails a non-commercial package in a repo marked commercial, naming its swap' {
        $policy = @{ licenses = @('MIT'); packages = @(@{ id = 'Contoso.Asserts'; license = "file LICENSE sha256:$licenseHash"; commercialUse = $false; swap = 'Fabrikam.Asserts'; reason = 'free for non-commercial use' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Asserts'; Version = '8.0.0'; File = 'LICENSE' } -Policy $policy -RepoPolicy @{ commercial = $true }

        $result = Invoke-Check $repo

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Contoso\.Asserts 8\.0\.0.*commercial.*Fabrikam\.Asserts'
    }

    It 'fails a non-commercial package with no swap in a repo marked commercial, without naming an empty swap' {
        $policy = @{ licenses = @('MIT'); packages = @(@{ id = 'Contoso.Asserts'; license = "file LICENSE sha256:$licenseHash"; commercialUse = $false; reason = 'free for non-commercial use' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Asserts'; Version = '8.0.0'; File = 'LICENSE' } -Policy $policy -RepoPolicy @{ commercial = $true }

        $result = Invoke-Check $repo

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Not -Match 'use\s+instead'
        $result.Text | Should -Match 'Contoso\.Asserts 8\.0\.0.*commercial'
    }

    # Review 1: only the repo's own file says whether it's commercial (ADR-0004); the kit's policy can't.
    It "ignores commercial in the kit's policy" {
        $policy = @{ licenses = @('MIT'); commercial = $true; packages = @(@{ id = 'Contoso.Asserts'; license = "file LICENSE sha256:$licenseHash"; commercialUse = $false; swap = 'Fabrikam.Asserts'; reason = 'free for non-commercial use' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Asserts'; Version = '8.0.0'; File = 'LICENSE' } -Policy $policy

        (Invoke-Check $repo).ExitCode | Should -Be 0
    }

    # Review 1: a license file outside the package's own folder isn't the package's license, whatever its hash.
    It 'fails a license file whose path leaves the package folder, even when an entry pins its hash' {
        $policy = @{ licenses = @('MIT'); packages = @(@{ id = 'Contoso.Tools'; license = "file ../LICENSE sha256:$licenseHash"; reason = 'MIT, in a file' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Tools'; Version = '1.0.0'; File = '../LICENSE' } -Policy $policy

        $result = Invoke-Check $repo

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Contoso\.Tools 1\.0\.0: file \.\./LICENSE sha256:missing'
    }

    It "adds the repo's own licenses and package entries to the kit's" {
        $repoPolicy = @{ licenses = @('LGPL-2.1-only'); packages = @(@{ id = 'Contoso.Legacy'; license = 'url https://contoso.example/license'; reason = 'free for any use' }) }
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Lgpl'; Version = '1.0.0'; Expression = 'LGPL-2.1-only' }, @{ Id = 'Contoso.Legacy'; Version = '1.0.0'; Url = 'https://contoso.example/license' } -RepoPolicy $repoPolicy

        (Invoke-Check $repo).ExitCode | Should -Be 0
    }

    It 'fails on <Case>, saying what to do' -ForEach @(
        @{ Case = 'a package that is not in the packages folder'; NotRestored = @('Contoso.Core'); NoLockFile = $false; Message = 'Contoso\.Core 1\.0\.0.*restore' }
        @{ Case = 'a project without a lock file'; NotRestored = @(); NoLockFile = $true; Message = 'App\.csproj.*packages\.lock\.json' }
    ) {
        $repo = New-LicenseRepo -Package @{ Id = 'Contoso.Core'; Version = '1.0.0'; Expression = 'MIT' } -NotRestored $NotRestored -NoLockFile:$NoLockFile

        $result = Invoke-Check $repo

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Message
    }
}

# The kit's policy, which every app gets with the kit's tools (.kit/tools/package-licenses.json).
Describe 'package-licenses.json' {
    BeforeAll {
        $path = Join-Path $PSScriptRoot '..' 'package-licenses.json'
        $script:kitPolicy = if (Test-Path -LiteralPath $path) { Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable } else { @{} }
    }

    It 'allows only licenses free for commercial use, by their SPDX ids' {
        @($kitPolicy['licenses']) | Should -Be @('0BSD', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'BSL-1.0', 'ISC', 'MIT', 'MIT-0', 'MPL-2.0', 'MS-PL', 'PostgreSQL', 'Unlicense', 'Zlib')
    }

    It 'gives every package entry its license, pinned, and the reason it is allowed' {
        @($kitPolicy['packages']) | Should -Not -BeNullOrEmpty
        foreach ($entry in $kitPolicy['packages']) {
            $entry['id'] | Should -Not -BeNullOrEmpty
            $entry['license'] | Should -Match '\A(expression .+|file \S+ sha256:[0-9a-f]{64}|url https://\S+)\z'
            $entry['reason'] | Should -Not -BeNullOrEmpty
        }
    }

    # GAP-025: EF Core's SQL Server provider needs Microsoft.Data.SqlClient's native SNI library, under Microsoft's own
    # terms: distributable code an app may ship, so every app on SQL Server or Azure SQL Database (the database guide's
    # default) can use it.
    It 'allows Microsoft.Data.SqlClient''s SNI library under its distributable-code terms, pinned' {
        $sni = @($kitPolicy['packages'] | Where-Object { $_['id'] -eq 'Microsoft.Data.SqlClient.SNI.runtime' })

        $sni | Should -HaveCount 1
        $sni[0]['license'] | Should -Be 'file LICENSE.txt sha256:9335e8bad875dd7be4eebd55d2335eb6433d1cea61aadb3817af7807bef8932a'
    }

    # GAP-025: Microsoft.Data.SqlClient brings MSAL's broker interop too, under terms that allow use but not distribution.
    # A server app only uses it, and every web app on the database guide's default database gets it, so the kit allows it.
    It 'allows MSAL''s broker interop under its use-only terms, pinned' {
        $interop = @($kitPolicy['packages'] | Where-Object { $_['id'] -eq 'Microsoft.Identity.Client.NativeInterop' })

        $interop | Should -HaveCount 1
        $interop[0]['license'] | Should -Be 'file LICENSE sha256:0fe665c2ada5962fd01190ab5b2947b9a9d2c625a9f8225577441eb3256e14e3'
    }

    It 'allows FluentAssertions 8 only outside a commercial repo, naming AwesomeAssertions (ADR-0004)' {
        $kitPolicy.ContainsKey('packages') | Should -BeTrue
        $fluent = @($kitPolicy['packages'] | Where-Object { $_['id'] -eq 'FluentAssertions' })

        $fluent | Should -HaveCount 1
        $fluent[0]['commercialUse'] | Should -BeFalse
        $fluent[0]['swap'] | Should -Be 'AwesomeAssertions'
    }
}
