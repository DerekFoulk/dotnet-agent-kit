#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Mutation testing (GAP-003, TST-004's 85% score, ADR-0039). A shared workflow runs Stryker.NET over a solution
# and fails when the mutation score is below 85%. The kit runs it nightly; apps get the same nightly caller.

Describe 'Mutation testing in CI' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Read-Yaml([string] $RelativePath) {
            $path = Join-Path $root $RelativePath
            $text = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
            [pscustomobject]@{ Text = $text; Yaml = if ($text) { ConvertFrom-Yaml $text } else { @{} } }
        }

        function Get-Steps($Yaml) {
            if (-not $Yaml.ContainsKey('jobs')) { return @() }
            @($Yaml['jobs'].Values | ForEach-Object { @($_['steps']) })
        }

        $reusable = Read-Yaml '.github/workflows/mutation.reusable.yml'
    }

    Context 'mutation.reusable.yml' {
        It 'runs Stryker.NET at a pinned version, with the Microsoft Testing Platform runner, failing below 85%' {
            $run = (Get-Steps $reusable.Yaml | ForEach-Object { "$($_['run'])" }) -join "`n"

            $run | Should -Match 'dotnet tool install dotnet-stryker --version \d+\.\d+\.\d+ '
            $run | Should -Match '--test-runner mtp'
            $run | Should -Match '--break-at 85\b'
            $run | Should -Match '--solution "\$SOLUTION"'
        }
    }
}
