#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Invoke-KitTests.ps1 is the kit's one way to run its script tests locally (ADR-0092): always in a child pwsh, so
# nothing Pester does reaches the caller's session. Twice, a run in Claude Code's shared PowerShell session left a
# path variable pointing into Pester's own module folder, and a later "restore" overwrote a Pester file.

Describe 'Invoke-KitTests.ps1' {
    BeforeAll {
        $launcher = Join-Path $PSScriptRoot '..' 'Invoke-KitTests.ps1'

        # A test file in a folder of its own, holding the given Pester body.
        function New-TestFile([string] $Body, [string] $Folder = "fixture-$(New-Guid)", [string] $Name = 'Fixture.Tests.ps1') {
            $folderPath = Join-Path $TestDrive $Folder
            New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
            $path = Join-Path $folderPath $Name
            [IO.File]::WriteAllText($path, $Body)
            $path
        }

        # A copy of the launcher in a repo of its own, so a run with no -Path runs that repo's tools/tests, not
        # this one's, which holds this file and would run it again without end.
        function New-FakeRepo([hashtable] $TestFiles) {
            $root = Join-Path $TestDrive "repo-$(New-Guid)"
            New-Item -ItemType Directory -Path (Join-Path $root 'tools' 'tests') -Force | Out-Null
            Copy-Item -LiteralPath $launcher -Destination (Join-Path $root 'tools' 'Invoke-KitTests.ps1')
            foreach ($name in $TestFiles.Keys) { [IO.File]::WriteAllText((Join-Path $root 'tools' 'tests' $name), $TestFiles[$name]) }
            $root
        }

        $passing = @'
Describe 'Fixture' {
    It 'one' { 1 | Should -Be 1 }
    It 'two' { 2 | Should -Be 2 }
}
'@
    }

    It 'runs a passing test file and returns its counts with exit code 0' {
        $path = New-TestFile -Body $passing

        $result = & $launcher -Path $path -Output None

        $result.Total | Should -Be 2
        $result.Passed | Should -Be 2
        $result.Failed | Should -Be 0
        $result.ExitCode | Should -Be 0
        $LASTEXITCODE | Should -Be 0
    }

    It 'runs only the tests -FullNameFilter names' {
        $path = New-TestFile -Body $passing

        $result = & $launcher -Path $path -FullNameFilter 'Fixture.two' -Output None

        $result.Passed | Should -Be 1
        $result.NotRun | Should -Be 1
    }

    # Pester calls a run with nothing in it "Passed", and its TotalCount counts tests it didn't run. A run that
    # ran no test proves nothing, so it fails.
    It 'exits 1 when <Case>' -ForEach @(
        @{ Case = 'the filter matches no test'; Filter = @('nothing matches this*') }
        @{ Case = 'every test it runs is skipped'; Filter = @('Fixture.skipped') }
    ) {
        $path = New-TestFile -Body @'
Describe 'Fixture' {
    It 'runs' { 1 | Should -Be 1 }
    It 'skipped' -Skip { 1 | Should -Be 1 }
}
'@

        $result = & $launcher -Path $path -FullNameFilter $Filter -Output None

        $result.Passed + $result.Failed | Should -Be 0
        $result.ExitCode | Should -Be 1
        $LASTEXITCODE | Should -Be 1
    }

    # CI's pwsh steps run with 'Stop' (GitHub prepends it), so a local run must too, or a non-terminating error
    # passes here and fails there.
    It 'runs the tests with $ErrorActionPreference set to Stop, as CI does' {
        $path = New-TestFile -Body @'
Describe 'Fixture' {
    It 'stops on errors' { $ErrorActionPreference | Should -Be 'Stop' }
}
'@

        $result = & $launcher -Path $path -Output None

        $result.Passed | Should -Be 1
    }

    It 'runs every test file under its repo''s tools/tests when no -Path is given' {
        $root = New-FakeRepo @{ 'One.Tests.ps1' = $passing; 'Two.Tests.ps1' = $passing }

        $result = & (Join-Path $root 'tools' 'Invoke-KitTests.ps1') -Output None

        $result.Passed | Should -Be 4
    }

    # The caller never stands in the fake repo, so the tests see its root only if the launcher moves there.
    It 'runs the tests from its repo''s root, wherever the caller stands' {
        $root = New-FakeRepo @{ 'Where.Tests.ps1' = @'
Describe 'Fixture' {
    It 'is at the root' { (Get-Location).Path | Should -Be (Split-Path (Split-Path $PSScriptRoot)) }
}
'@ }

        $result = & (Join-Path $root 'tools' 'Invoke-KitTests.ps1') -Output None

        $result.Passed | Should -Be 1
    }

    # Pester reads a path as a wildcard pattern, where "[1]" matches "1": unescaped, "a [1]" would run "a 1".
    It 'takes a path with wildcard characters literally' {
        $guid = New-Guid
        $literal = New-TestFile -Body "Describe 'Fixture' { It 'one' { 1 | Should -Be 1 } }" -Folder "a [1] $guid"
        $null = New-TestFile -Body $passing -Folder "a 1 $guid"

        $result = & $launcher -Path (Split-Path $literal) -Output None

        $result.Passed | Should -Be 1
    }
}
