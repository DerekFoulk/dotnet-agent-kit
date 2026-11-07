#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# New-KitApp creates an app repo on GitHub from Export-KitApp's files (PR D2b, ADR-0033). The repo settings
# and the "main protection" ruleset are data in templates/github, so the sync job (PR D3) can apply them again.

Describe 'New-KitApp settings' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $rulesetPath = Join-Path $root 'templates' 'github' 'main-protection.json'
    }

    It 'requires exactly the checks the app''s CI workflows report' {
        # A check's name is "<caller job id> / <shared workflow job name>". Deriving it from the workflows means
        # renaming a job fails here, instead of leaving every app PR waiting for a check that never reports.
        $expected = foreach ($caller in Get-ChildItem -LiteralPath (Join-Path $root 'templates' 'app' '.github' 'workflows') -Filter *.yml) {
            # {{Name}} placeholders aren't YAML; ${{ }} expressions are plain strings.
            $yaml = ConvertFrom-Yaml ((Get-Content -Raw -LiteralPath $caller.FullName) -replace '\{\{[A-Za-z]+\}\}', 'X')
            foreach ($jobId in $yaml['jobs'].Keys) {
                $uses = $yaml['jobs'][$jobId]['uses']
                if ($uses -notmatch '^DerekFoulk/dotnet-agent-kit/\.github/workflows/([^@]+)@') { continue }
                $shared = ConvertFrom-Yaml (Get-Content -Raw -LiteralPath (Join-Path $root '.github' 'workflows' $Matches[1]))
                foreach ($job in $shared['jobs'].Values) { "$jobId / $($job['name'])" }
            }
        }
        @($expected).Count | Should -Be 3

        Test-Path -LiteralPath $rulesetPath | Should -BeTrue -Because 'the app ruleset is data in templates/github'
        $ruleset = Get-Content -Raw -LiteralPath $rulesetPath | ConvertFrom-Json
        $checks = ($ruleset.rules | Where-Object type -EQ 'required_status_checks').parameters.required_status_checks
        @($checks.context | Sort-Object) | Should -Be @($expected | Sort-Object)
        # 15368 is the GitHub Actions app: only a check that Actions reports satisfies the rule.
        @($checks.integration_id | Select-Object -Unique) | Should -Be @(15368)
    }
}
