#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# GAP-049, ADR-0095: every WebApplicationFactory in the kit's reference apps (the sample and fixtures/WebUi, which
# New-FreshApp exports as each fresh app's probe) sets its content root with the kit's ProjectFolder
# (tools/AppTests/Hosting), the one lookup that holds both in the kit, whose sample is under sample/, and in an app, whose
# projects are at its root. ProjectFolderTests.cs proves the lookup; this proves the factories use it. A factory that went
# back to a path that fits the kit's layout only would pass every other required check in the kit: only the fresh-app
# jobs, which aren't required, would fail.
BeforeDiscovery {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $sources = foreach ($folder in 'sample', 'fixtures') {
        Get-ChildItem -LiteralPath (Join-Path $root $folder) -Recurse -File -Filter '*.cs' |
            Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
            ForEach-Object {
                # Comments may name the factory or ProjectFolder; only code counts.
                $code = (Get-Content -Raw -LiteralPath $_.FullName) -replace '(?m)^\s*//.*$', ''
                @{ Name = [System.IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/'; Code = $code }
            }
    }
    $factories = @($sources | Where-Object { $_.Code -match ':\s*WebApplicationFactory<' })
}

Describe 'Test host factories in the reference apps' {
    It 'finds the factory of each reference app, so the scan below covers them' -ForEach @{ Names = @($factories.Name) } {
        $Names | Should -Contain 'sample/tests/Bookmarks.FunctionalTests/ApiFactory.cs'
        $Names | Should -Contain 'fixtures/WebUi/tests/Kit.WebUi.E2E.Tests/AppFactory.cs'
    }

    It '<Name> sets its content root with ProjectFolder.Find' -ForEach $factories {
        $Code | Should -Match 'UseContentRoot\(\s*ProjectFolder\.Find\('
    }

    # A plain WebApplicationFactory<T> uses the factory's own content-root lookup, which Stryker.NET breaks (ADR-0039).
    It 'makes no plain WebApplicationFactory, only the subclasses above' -ForEach @{ Sources = $sources } {
        $plain = @($Sources | Where-Object { $_.Code -match 'new\s+WebApplicationFactory<|WebApplicationFactory<[^>]+>\s+\w+\s*=\s*new\s*\(' })

        $plain.Name | Should -BeNullOrEmpty -Because 'each test should use its reference app''s own factory'
    }
}
