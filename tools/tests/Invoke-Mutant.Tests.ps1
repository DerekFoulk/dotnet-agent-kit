#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Invoke-Mutant.ps1 changes one exact piece of a file, runs the tests that should notice, and restores the file
# byte for byte: the "break it on purpose" check reviewers ran by hand on every round (owner, 2026-11-10).

Describe 'Invoke-Mutant.ps1' {
    BeforeAll {
        $script = Join-Path $PSScriptRoot '..' 'Invoke-Mutant.ps1'

        # A tiny function and the test that pins it, in a folder of their own.
        function New-Fixture {
            $folder = Join-Path $TestDrive "fixture-$(New-Guid)"
            New-Item -ItemType Directory -Path $folder | Out-Null
            $source = Join-Path $folder 'Add.ps1'
            [IO.File]::WriteAllText($source, "function Add([int] `$a, [int] `$b) { `$a + `$b }`n")
            $tests = Join-Path $folder 'Add.Tests.ps1'
            [IO.File]::WriteAllText($tests, @'
Describe 'Add' {
    BeforeAll { . (Join-Path $PSScriptRoot 'Add.ps1') }
    It 'adds' { Add 1 2 | Should -Be 3 }
}
'@)
            [pscustomobject]@{ Source = $source; Tests = $tests }
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

}
