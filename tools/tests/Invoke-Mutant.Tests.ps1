#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Invoke-Mutant.ps1 changes one exact piece of a file, runs the tests that should notice, and restores the file
# byte for byte: the "break it on purpose" check reviewers ran by hand on every round (owner, 2026-11-10).

Describe 'Invoke-Mutant.ps1' {
    BeforeAll {
        $script = Join-Path $PSScriptRoot '..' 'Invoke-Mutant.ps1'

        # A tiny function and the test that pins it, in a folder of their own.
        function New-Fixture([string] $Folder = "fixture-$(New-Guid)", [string] $Tests = @'
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 3 }
}
'@) {
            $folderPath = Join-Path $TestDrive $Folder
            New-Item -ItemType Directory -Path $folderPath | Out-Null
            $source = Join-Path $folderPath 'Add.ps1'
            [IO.File]::WriteAllText($source, "function Add([int] `$a, [int] `$b) { `$a + `$b }`n")
            $testsPath = Join-Path $folderPath 'Add.Tests.ps1'
            [IO.File]::WriteAllText($testsPath, $Tests)
            [pscustomobject]@{ Source = $source; Tests = $testsPath }
        }
    }

    It 'reports a mutant the tests catch as killed' {
        Test-Path -LiteralPath $script | Should -BeTrue -Because 'Invoke-Mutant.ps1 runs the mutants'
        $fixture = New-Fixture

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Name | Should -Be 'subtract'
        $result.Result | Should -Be 'Killed'
        $result.Failed | Should -BeGreaterThan 0
    }

    It 'reports a mutant the tests miss as survived, and restores the file byte for byte after every mutant' {
        $fixture = New-Fixture
        $before = [IO.File]::ReadAllBytes($fixture.Source)

        # Renaming a parameter changes nothing the test can see.
        $results = @(& $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @(
                @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }
                @{ Name = 'rename'; Find = '[int] $b) { $a + $b }'; Replace = '[int] $c) { $a + $c }' }
            ))

        @($results.Result) | Should -Be @('Killed', 'Survived')
        $results[1].Failed | Should -Be 0
        [Convert]::ToHexString([IO.File]::ReadAllBytes($fixture.Source)) | Should -Be ([Convert]::ToHexString($before))
    }

    It 'reports text that isn''t in the file exactly once as <Expected>, and runs no tests for it' -ForEach @(
        @{ Expected = 'NotFound'; Find = '$a * $b' }
        @{ Expected = 'Ambiguous'; Find = '$a' }
    ) {
        # A mutant that changes nothing would "survive", which looks like a missing test when it's a typo; one
        # matching several places would change more than the reviewer meant.
        $fixture = New-Fixture

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'typo'; Find = $Find; Replace = '0' }

        $result.Result | Should -Be $Expected
        $result.Total | Should -Be 0
    }

    It 'reports every mutant as an error, and changes nothing, when the tests run none on the unchanged file' {
        # "Survived" claims a test is missing. A test path that runs nothing proves nothing either way.
        $fixture = New-Fixture -Tests "Describe 'Add' { }`n"
        $before = [IO.File]::ReadAllBytes($fixture.Source)

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match 'ran no tests on the unchanged file'
        [Convert]::ToHexString([IO.File]::ReadAllBytes($fixture.Source)) | Should -Be ([Convert]::ToHexString($before))
    }

    It 'reports every mutant as an error with what Pester wrote to stderr, when <Case>' -ForEach @(
        @{ Case = 'they run no tests'; Tests = "[Console]::Error.WriteLine('setup broke')`nDescribe 'Add' { }`n"; Message = 'ran no tests.*setup broke' }
        @{ Case = 'they end the process'; Tests = "[Console]::Error.WriteLine('setup broke')`n[Environment]::Exit(3)`n"; Message = 'returned no result.*setup broke' }
    ) {
        # Without the reason, an error is a dead end: the reviewer can't tell a typo in the path from a crash.
        $fixture = New-Fixture -Tests $Tests

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match $Message
    }

    It 'reports every mutant as an error when the tests already fail on the unchanged file' {
        $fixture = New-Fixture -Tests @'
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 4 }
}
'@

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match 'already fail'
    }

    It 'reports a mutant that breaks the test file''s discovery as killed' {
        # Loading the source outside BeforeAll runs it during discovery, so a syntax error fails the whole file
        # before any test runs: Pester counts no failed test, only a failed container. (Discovery's copy is gone
        # by the time tests run, so BeforeAll loads it again.)
        $fixture = New-Fixture -Tests @'
. (Join-Path $PSScriptRoot 'Add.ps1')
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 3 }
}
'@

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'syntax'; Find = '$a + $b }'; Replace = '$a + $b' }

        $result.Result | Should -Be 'Killed'
    }

    It 'runs tests in a folder whose name has a quote and wildcard brackets' {
        $fixture = New-Fixture -Folder "it's here [x]"

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Killed'
        $result.Total | Should -Be 1
    }
}
