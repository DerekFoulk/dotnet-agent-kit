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
        # {{Name}} placeholders aren't YAML; read the template with them replaced.
        $appText = if (Test-Path (Join-Path $root 'templates/app/.github/workflows/mutation.yml')) {
            Get-Content -Raw (Join-Path $root 'templates/app/.github/workflows/mutation.yml')
        } else { '' }
        $app = if ($appText) { ConvertFrom-Yaml ($appText -replace '\{\{[A-Za-z]+\}\}', 'X') } else { @{} }
    }

    Context 'an app''s mutation.yml (templates/app)' {
        It 'runs nightly and on demand, never on pull requests, calling the shared workflow pinned to the kit release' {
            $appText | Should -Not -BeNullOrEmpty -Because 'every new app gets the nightly mutation run'
            @($app['on']['schedule']).Count | Should -BeGreaterThan 0
            $app['on'].ContainsKey('workflow_dispatch') | Should -BeTrue
            $app['on'].ContainsKey('pull_request') | Should -BeFalse -Because 'it is too slow for every pull request, and so not a required check'
            $appText | Should -Match 'uses: DerekFoulk/dotnet-agent-kit/\.github/workflows/mutation\.reusable\.yml@\{\{KitCommit\}\} # \{\{KitVersion\}\}'
            $appText | Should -Match 'solution: \{\{Name\}\}\.slnx'
            $app['permissions']['contents'] | Should -Be 'read'
        }
    }

    Context 'the kit''s mutation.yml' {
        It 'runs nightly, on demand, and on a pull request that changes the mutation setup' {
            $on = $kit.Yaml['on']

            $on | Should -Not -BeNullOrEmpty
            @($on['schedule']).Count | Should -BeGreaterThan 0
            $on.ContainsKey('workflow_dispatch') | Should -BeTrue
            @($on['pull_request']['paths']) | Should -Contain '.github/workflows/mutation.reusable.yml'
            @($on['pull_request']['paths']) | Should -Contain '.github/workflows/mutation.yml'
            # A pull request that changes the sample proves its mutation score before it merges.
            @($on['pull_request']['paths']) | Should -Contain 'sample/**'
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

        It 'runs every test against every mutant, and skips ConfigureAwait, through a config file it writes' {
            # Per-test coverage misses code that runs inside an in-memory API host (the first CI run on PR 23 scored
            # the API 0% with every mutant "not covered"), and ConfigureAwait(true) can't change behaviour without a
            # synchronization context, so those mutants could never be killed.
            $run = (Get-Steps $reusable.Yaml | ForEach-Object { "$($_['run'])" }) -join "`n"

            $run | Should -Match '"coverage-analysis":\s*"off"'
            $run | Should -Match '"ignore-methods":\s*\[\s*"ConfigureAwait"\s*\]'
            $run | Should -Match '--config-file "\$RUNNER_TEMP/stryker-config\.json"'
        }

        It 'skips Stryker while the solution has no projects, as a new app''s does' {
            $steps = @(Get-Steps $reusable.Yaml)
            $count = @($steps | Where-Object { $_['id'] -eq 'projects' })
            $stryker = @($steps | Where-Object { "$($_['run'])" -match 'dotnet-stryker' })

            $count.Count | Should -Be 1
            $stryker.Count | Should -BeGreaterThan 0
            $stryker | ForEach-Object { $_['if'] | Should -Be "steps.projects.outputs.count != '0'" }
        }

        It 'refuses a score that one test inflated, with the kit''s Test-MutationReport.ps1 at its own version' {
            $steps = @(Get-Steps $reusable.Yaml)
            $kitTools = @($steps | Where-Object { "$($_['uses'])" -eq '$/.github/actions/kit-tools' })
            $check = @($steps | Where-Object { "$($_['run'])" -match 'Test-MutationReport\.ps1' })

            $kitTools.Count | Should -Be 1
            $kitTools[0]['id'] | Should -Be 'kit'
            $check.Count | Should -Be 1
            "$($check[0]['run'])" | Should -Match '\$env:KIT/tools/Test-MutationReport\.ps1'
            "$($check[0]['run'])" | Should -Match 'stryker-output/reports/mutation-report\.json'
            $check[0]['if'] | Should -Match 'always\(\)'
            $check[0]['if'] | Should -Match "steps\.projects\.outputs\.count != '0'"
        }

        It 'uploads the HTML and JSON report, even when the score fails, so the surviving mutants can be read' {
            # The YAML parser drops the "# vX" comment, so the version is read from the text.
            $upload = @(Get-Steps $reusable.Yaml | Where-Object { "$($_['uses'])" -match '^actions/upload-artifact@[0-9a-f]{40}$' })

            $upload.Count | Should -Be 1
            $reusable.Text | Should -Match 'actions/upload-artifact@[0-9a-f]{40} # v\d'
            $upload[0]['if'] | Should -Match 'always\(\)'
            "$($upload[0]['with']['path'])" | Should -Match 'stryker-output/reports'
        }
    }
}
