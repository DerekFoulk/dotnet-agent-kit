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
        $kit = Read-Yaml '.github/workflows/mutation.yml'
    }

    Context 'the kit''s mutation.yml' {
        It 'runs nightly, on demand, and on a pull request that changes the mutation setup' {
            $on = $kit.Yaml['on']

            $on | Should -Not -BeNullOrEmpty
            @($on['schedule']).Count | Should -BeGreaterThan 0
            $on.ContainsKey('workflow_dispatch') | Should -BeTrue
            @($on['pull_request']['paths']) | Should -Contain '.github/workflows/mutation.reusable.yml'
            @($on['pull_request']['paths']) | Should -Contain '.github/workflows/mutation.yml'
        }

        It 'calls the shared workflow for the kit''s solution, with a read-only token' {
            $kit.Yaml.ContainsKey('jobs') | Should -BeTrue
            $job = @($kit.Yaml['jobs'].Values)[0]

            $job['uses'] | Should -Be './.github/workflows/mutation.reusable.yml'
            $job['with']['solution'] | Should -Be 'dotnet-agent-kit.slnx'
            $kit.Yaml['permissions']['contents'] | Should -Be 'read'
        }
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
