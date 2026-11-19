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

        # Review of the branch: a missing file reported "Rule X isn't in ..." after a non-terminating error, and an empty
        # one threw about a missing property. Each says what's wrong with the file instead.
        It 'throws, naming the file, when the statuses file <Case>' -ForEach @(
            @{ Case = 'is missing'; Text = $null; Expected = "*no-statuses.json*doesn't exist*Build-AgentRules*" }
            @{ Case = 'is empty'; Text = ''; Expected = '*no-statuses.json*is empty*Build-AgentRules*' }
            @{ Case = 'holds only spaces'; Text = "  `n"; Expected = '*no-statuses.json*is empty*Build-AgentRules*' }
        ) {
            $path = Join-Path $TestDrive "case-$(New-Guid)" 'no-statuses.json'
            New-Item -ItemType Directory -Path (Split-Path $path) | Out-Null
            if ($null -ne $Text) { Set-Content -LiteralPath $path -Value $Text -NoNewline }

            { Get-RuleStatus -Id 'ARC-009' -Path $path } | Should -Throw $Expected
        }

        It 'reads the rule-status.json beside the module when no path is given' {
            $real = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '..' 'rule-status.json') | ConvertFrom-Json
            $first = @($real.PSObject.Properties)[0]

            Get-RuleStatus -Id $first.Name | Should -BeExactly $first.Value
        }
    }

    Context 'Write-RuleFinding' {
        BeforeEach {
            Mock Write-Host {} -ModuleName KitRuleStatus
        }

        It 'writes a proposed rule''s finding as a GitHub warning and doesn''t count it' {
            Write-RuleFinding -Id 'ARC-009' -Message 'src/App.Domain has no source files of its own' -Path $script:statusFile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning::ARC-009: src/App.Domain has no source files of its own' }
        }

        It 'writes an accepted rule''s finding as an error, as it is, and counts it' {
            Write-RuleFinding -Id 'STY-005' -Message 'App.cs(3,1): error STY005: a #nullable directive' -Path $script:statusFile | Should -BeTrue

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter {
                "$Object" -ceq 'App.cs(3,1): error STY005: a #nullable directive' -and $ForegroundColor -eq 'Red'
            }
        }

        # GitHub reads a workflow command to the end of its line, and decodes %25, %0D and %0A in its message.
        It 'keeps a warning on one line, escaping what GitHub would read as the end of the command' {
            Write-RuleFinding -Id 'ARC-009' -Message "100% empty`r`nsecond line" -Path $script:statusFile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning::ARC-009: 100%25 empty%0D%0Asecond line' }
        }

        # Review of the branch: a warning that names its place shows inline on the pull request's diff.
        It 'names the file, line and column in a warning, as GitHub''s warning command takes them' {
            Write-RuleFinding -Id 'ARC-009' -Message 'Run nests 5 levels deep' -File 'src/App/Deep.cs' -Line 7 -Column 74 -Path $script:statusFile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning file=src/App/Deep.cs,line=7,col=74::ARC-009: Run nests 5 levels deep' }
        }

        It 'names only the file when no line is given' {
            Write-RuleFinding -Id 'ARC-009' -Message 'no source' -File 'src/App.Domain/App.Domain.csproj' -Path $script:statusFile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning file=src/App.Domain/App.Domain.csproj::ARC-009: no source' }
        }

        # A property ends at a comma, and its name at a colon, so those are escaped too, as @actions/core does.
        It 'escapes what GitHub would read as the end of a property in the file name' {
            Write-RuleFinding -Id 'ARC-009' -Message 'odd' -File 'src/a,b:c%.cs' -Line 1 -Path $script:statusFile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning file=src/a%2Cb%3Ac%25.cs,line=1::ARC-009: odd' }
        }

        It 'writes an accepted rule''s finding as it is, whatever place it names' {
            Write-RuleFinding -Id 'STY-005' -Message 'App.cs(3,1): error STY005: x' -File 'App.cs' -Line 3 -Column 1 -Path $script:statusFile | Should -BeTrue

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq 'App.cs(3,1): error STY005: x' }
        }

        It 'throws for a retired rule, whose check shouldn''t run any more' {
            { Write-RuleFinding -Id 'OLD-001' -Message 'anything' -Path $script:statusFile } | Should -Throw '*OLD-001*retired*'
        }

        It 'throws for an id the file doesn''t list' {
            { Write-RuleFinding -Id 'ARC-099' -Message 'anything' -Path $script:statusFile } | Should -Throw '*ARC-099*'
        }
    }
}
