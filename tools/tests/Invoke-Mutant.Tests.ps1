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

    # The launcher next to it judges every mutant, so a mutant of the launcher would judge itself: one that
    # over-reports a broken block would read as Killed while no test failed (review round 1 of ADR-0092's PR).
    It 'refuses to mutate the launcher it judges with, and leaves it unchanged' {
        $launcher = Join-Path (Split-Path $script) 'Invoke-KitTests.ps1'
        $fixture = New-Fixture
        $before = [IO.File]::ReadAllBytes($launcher)

        { & $script -Path $launcher -TestPath $fixture.Tests -Mutant @{ Name = 'none'; Find = 'text that is not there'; Replace = 'x' } } |
            Should -Throw '*another clone*'
        [Convert]::ToHexString([IO.File]::ReadAllBytes($launcher)) | Should -Be ([Convert]::ToHexString($before))
    }

    # A killed mutant is the run going as planned; the launcher's exit code for its failing tests isn't the caller's.
    It 'leaves $LASTEXITCODE at 0 after a run whose mutant is killed' {
        $fixture = New-Fixture

        $null = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $LASTEXITCODE | Should -Be 0
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

    # Pester's TotalCount counts skipped tests too, so "ran" means passed or failed: a run that only skipped proves
    # nothing (review round 1 of ADR-0092's PR).
    It 'reports every mutant as an error when every test on the unchanged file is skipped' {
        $fixture = New-Fixture -Tests "Describe 'Add' { It 'adds' -Skip { 1 | Should -Be 1 } }`n"

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match 'ran no tests on the unchanged file'
    }

    It 'reports a mutant as an error when, with it in place, every test is skipped' {
        $fixture = New-Fixture -Tests @'
$skip = -not (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Add.ps1') -Raw).Contains('+')
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' -Skip:$skip { Add 1 2 | Should -Be 3 }
}
'@

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match 'No tests ran with the mutant in place'
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

    It 'reports every mutant as an error with Pester''s reason when the test path is a folder with no test files' {
        # Invoke-Pester doesn't throw here: it prints why on stdout and returns nothing.
        $fixture = New-Fixture
        $empty = Join-Path $TestDrive "empty-$(New-Guid)"
        New-Item -ItemType Directory -Path $empty | Out-Null

        $result = & $script -Path $fixture.Source -TestPath $empty -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match 'No test files were found'
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

    It 'reports a test file that breaks during discovery on the unchanged file as already failing' {
        # Pester counts no test then, but the reason is a broken file, not an empty one.
        $fixture = New-Fixture -Tests "Describe 'Add' {`n"

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

    It 'reports a mutant that fails only an AfterAll as killed' {
        $fixture = New-Fixture -Tests @'
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'runs' { $true | Should -BeTrue }
    AfterAll { Add 1 2 | Should -Be 3 }
}
'@

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Killed'
    }

    It 'reports every mutant as an error when an AfterAll already fails on the unchanged file' {
        $fixture = New-Fixture -Tests @'
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 3 }
    AfterAll { throw 'teardown broke' }
}
'@

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match 'already fail'
    }

    It 'reports a mutant as an error when, with it in place, <Case>' -ForEach @(
        @{ Case = 'no tests run'; Message = 'No tests ran with the mutant in place.*mutant broke'; Tests = @'
if ((Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Add.ps1') -Raw).Contains('+')) {
    Describe 'Add' {
        BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
        It 'adds' { Add 1 2 | Should -Be 3 }
    }
}
else { [Console]::Error.WriteLine('mutant broke') }
'@ }
        @{ Case = 'Pester returns no result'; Message = 'returned no result with the mutant in place.*mutant broke'; Tests = @'
if (-not (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Add.ps1') -Raw).Contains('+')) {
    [Console]::Error.WriteLine('mutant broke')
    [Environment]::Exit(3)
}
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 3 }
}
'@ }
    ) {
        # The baseline passes, so only the mutant's own run can say nothing was tested. The fixture prints only
        # then, so the message must carry the mutant run's own output.
        $fixture = New-Fixture -Tests $Tests

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Error'
        $result.Message | Should -Match $Message
        $result.Message | Should -Not -Match 'Invoke-Mutant result' -Because 'the result line is data, not something the tests printed'
    }

    It 'runs the tests on the unchanged file once, however many mutants there are' {
        $fixture = New-Fixture -Tests @'
Add-Content -LiteralPath (Join-Path $PSScriptRoot 'runs.log') -Value 'run'
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 3 }
}
'@

        $null = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @(
            @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }
            @{ Name = 'rename'; Find = '[int] $a,'; Replace = '[int] $x,' }
        )

        # One baseline run, then one run per mutant.
        @(Get-Content -LiteralPath (Join-Path (Split-Path $fixture.Tests) 'runs.log')).Count | Should -Be 3
    }

    # Dot-sourced, $file, $original and the rest would land in the caller's session: the generic variables both
    # Pester incidents restored through (ADR-0092). It refuses before it changes anything.
    It 'refuses to run dot-sourced, leaving the file, the caller''s variables and its preferences alone' {
        $fixture = New-Fixture
        $before = [IO.File]::ReadAllBytes($fixture.Source)
        $probe = @"
`$file = 'mine'
try { . '$($script -replace "'", "''")' -Path '$($fixture.Source -replace "'", "''")' -TestPath '$($fixture.Tests -replace "'", "''")' -Mutant @{ Name = 'subtract'; Find = '`$a + `$b'; Replace = '`$a - `$b' } } catch { 'refused' }
"file=`$file eap=`$ErrorActionPreference"
"@

        $printed = @(& pwsh -NoProfile -NonInteractive -Command $probe 2>&1 | ForEach-Object { "$_" })

        $printed | Should -Contain 'refused'
        $printed | Should -Contain 'file=mine eap=Continue'
        [Convert]::ToHexString([IO.File]::ReadAllBytes($fixture.Source)) | Should -Be ([Convert]::ToHexString($before))
    }

    # Its test runs go through Invoke-KitTests.ps1, so they run as the kit's other local runs and CI's do.
    It 'runs the tests with $ErrorActionPreference set to Stop, as CI does' {
        $fixture = New-Fixture -Tests @'
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 3 }
    It 'stops on errors' { $ErrorActionPreference | Should -Be 'Stop' }
}
'@

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Killed'
    }

    It 'runs tests in a folder whose name has a quote and wildcard brackets' {
        $fixture = New-Fixture -Folder "it's here [x]"

        $result = & $script -Path $fixture.Source -TestPath $fixture.Tests -Mutant @{ Name = 'subtract'; Find = '$a + $b'; Replace = '$a - $b' }

        $result.Result | Should -Be 'Killed'
        $result.Total | Should -Be 1
    }
}
