#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# KitRuleStatus.psm1 tells a check whether the rule it enforces is in force (ADR-0089): a proposed rule's findings are
# warnings, an accepted rule's fail. The statuses come from tools/rule-status.json, which Build-AgentRules.ps1 writes
# from docs/standards; these tests use a file of their own, so they don't depend on any real rule's status.

Describe 'KitRuleStatus.psm1' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..' 'KitRuleStatus.psm1') -Force
        $script:statusFile = Join-Path $TestDrive 'rule-status.json'
        Set-Content -LiteralPath $script:statusFile -Value '{ "ARC-009": "proposed", "STY-005": "accepted", "OLD-001": "retired" }'
    }

    Context 'Get-RuleStatus' {
        It 'returns <Id>''s status from the file: <Status>' -ForEach @(
            @{ Id = 'ARC-009'; Status = 'proposed' }
            @{ Id = 'STY-005'; Status = 'accepted' }
            @{ Id = 'OLD-001'; Status = 'retired' }
        ) {
            Get-RuleStatus -Id $Id -Path $script:statusFile | Should -BeExactly $Status
        }

        It 'throws for an id the file doesn''t list, so a typo can''t switch a gate off' {
            { Get-RuleStatus -Id 'ARC-099' -Path $script:statusFile } | Should -Throw '*ARC-099*'
        }

        It 'throws for a status that isn''t proposed, accepted or retired' {
            $odd = Join-Path $TestDrive 'odd-status.json'
            Set-Content -LiteralPath $odd -Value '{ "ARC-009": "maybe" }'

            { Get-RuleStatus -Id 'ARC-009' -Path $odd } | Should -Throw '*ARC-009*maybe*'
        }

        It 'reads the rule-status.json beside the module when no path is given' {
            $real = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '..' 'rule-status.json') | ConvertFrom-Json
            $first = @($real.PSObject.Properties)[0]

            Get-RuleStatus -Id $first.Name | Should -BeExactly $first.Value
        }
    }
}
