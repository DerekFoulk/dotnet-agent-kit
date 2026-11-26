#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# KitRuleStatus.psm1 tells a check how the rule it enforces applies (ADR-0090): a must rule's findings fail, a should
# rule's are warnings, and a rule whose scope or when doesn't fit the app is skipped. The strengths come from
# tools/rule-strength.json, which Build-AgentRules.ps1 writes from docs/standards; these tests use a file of their own,
# so they don't depend on any real rule's strength.

Describe 'KitRuleStatus.psm1' {
    BeforeAll {
        $script:modulePath = Join-Path $PSScriptRoot '..' 'KitRuleStatus.psm1'
        Import-Module $script:modulePath -Force
        $script:strengthFile = Join-Path $TestDrive 'rule-strength.json'
        Set-Content -LiteralPath $script:strengthFile -Value @'
{
  "ARC-009": { "strength": "should", "scope": ["core"], "when": [] },
  "STY-005": { "strength": "must", "scope": ["core"], "when": [] },
  "NET-002": { "strength": "consider", "scope": ["core"], "when": [] },
  "OPS-004": { "strength": "must", "scope": ["web-api", "blazor"], "when": [] },
  "DAT-003": { "strength": "should", "scope": ["web-api", "blazor"], "when": ["has-server-database"] },
  "OLD-001": { "strength": "retired", "scope": ["core"], "when": [] }
}
'@
        # No profile: the kit itself, or an app made before app profiles, where every rule applies.
        $script:noProfile = Join-Path $TestDrive 'no-profile' 'app-profile.md'

        function New-Profile {
            param([string[]] $Line)
            $path = Join-Path $TestDrive "profile-$(New-Guid).md"
            Set-Content -LiteralPath $path -Value (@('# App profile: Contoso', '') + $Line)
            $path
        }
    }

    Context 'Get-RuleStrength' {
        It 'returns <Id>''s strength from the file: <Strength>' -ForEach @(
            @{ Id = 'ARC-009'; Strength = 'should' }
            @{ Id = 'STY-005'; Strength = 'must' }
            @{ Id = 'NET-002'; Strength = 'consider' }
            @{ Id = 'OLD-001'; Strength = 'retired' }
        ) {
            Get-RuleStrength -Id $Id -Path $script:strengthFile | Should -BeExactly $Strength
        }

        It 'throws for an id the file doesn''t list, so a typo can''t switch a gate off' {
            { Get-RuleStrength -Id 'ARC-099' -Path $script:strengthFile } | Should -Throw '*ARC-099*'
        }

        It 'throws for a strength the kit doesn''t know' {
            $odd = Join-Path $TestDrive 'odd-strength.json'
            Set-Content -LiteralPath $odd -Value '{ "ARC-009": { "strength": "maybe", "scope": ["core"], "when": [] } }'

            { Get-RuleStrength -Id 'ARC-009' -Path $odd } | Should -Throw '*ARC-009*maybe*'
        }

        It 'throws, naming the file, when the strengths file <Case>' -ForEach @(
            @{ Case = 'is missing'; Text = $null; Expected = "*no-strengths.json*doesn't exist*Build-AgentRules*" }
            @{ Case = 'is empty'; Text = ''; Expected = '*no-strengths.json*is empty*Build-AgentRules*' }
            @{ Case = 'holds only spaces'; Text = "  `n"; Expected = '*no-strengths.json*is empty*Build-AgentRules*' }
        ) {
            $path = Join-Path $TestDrive "case-$(New-Guid)" 'no-strengths.json'
            New-Item -ItemType Directory -Path (Split-Path $path) | Out-Null
            if ($null -ne $Text) { Set-Content -LiteralPath $path -Value $Text -NoNewline }

            { Get-RuleStrength -Id 'ARC-009' -Path $path } | Should -Throw $Expected
        }

        It 'reads the rule-strength.json beside the module when no path is given' {
            $real = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '..' 'rule-strength.json') | ConvertFrom-Json
            $first = @($real.PSObject.Properties)[0]

            Get-RuleStrength -Id $first.Name | Should -BeExactly $first.Value.strength
        }
    }

    Context 'Write-RuleFinding' {
        BeforeEach {
            # A fresh module each test: it reports a skipped rule once per run.
            Import-Module $script:modulePath -Force
            Mock Write-Host {} -ModuleName KitRuleStatus
        }

        It 'writes a should rule''s finding as a GitHub warning and doesn''t count it' {
            Write-RuleFinding -Id 'ARC-009' -Message 'src/App.Domain has no source files of its own' -Path $script:strengthFile -ProfilePath $script:noProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning::ARC-009: src/App.Domain has no source files of its own' }
        }

        It 'writes a must rule''s finding as an error, as it is, and counts it' {
            Write-RuleFinding -Id 'STY-005' -Message 'App.cs(3,1): error STY005: a #nullable directive' -Path $script:strengthFile -ProfilePath $script:noProfile | Should -BeTrue

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter {
                "$Object" -ceq 'App.cs(3,1): error STY005: a #nullable directive' -and $ForegroundColor -eq 'Red'
            }
        }

        # GitHub reads a workflow command to the end of its line, and decodes %25, %0D and %0A in its message.
        It 'keeps a warning on one line, escaping what GitHub would read as the end of the command' {
            Write-RuleFinding -Id 'ARC-009' -Message "100% empty`r`nsecond line" -Path $script:strengthFile -ProfilePath $script:noProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning::ARC-009: 100%25 empty%0D%0Asecond line' }
        }

        It 'names the file, line and column in a warning, as GitHub''s warning command takes them' {
            Write-RuleFinding -Id 'ARC-009' -Message 'Run nests 5 levels deep' -File 'src/App/Deep.cs' -Line 7 -Column 74 -Path $script:strengthFile -ProfilePath $script:noProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning file=src/App/Deep.cs,line=7,col=74::ARC-009: Run nests 5 levels deep' }
        }

        It 'names only the file when no line is given' {
            Write-RuleFinding -Id 'ARC-009' -Message 'no source' -File 'src/App.Domain/App.Domain.csproj' -Path $script:strengthFile -ProfilePath $script:noProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning file=src/App.Domain/App.Domain.csproj::ARC-009: no source' }
        }

        # A property ends at a comma, and its name at a colon, so those are escaped too, as @actions/core does.
        It 'escapes what GitHub would read as the end of a property in the file name' {
            Write-RuleFinding -Id 'ARC-009' -Message 'odd' -File 'src/a,b:c%.cs' -Line 1 -Path $script:strengthFile -ProfilePath $script:noProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning file=src/a%2Cb%3Ac%25.cs,line=1::ARC-009: odd' }
        }

        It 'writes a must rule''s finding as it is, whatever place it names' {
            Write-RuleFinding -Id 'STY-005' -Message 'App.cs(3,1): error STY005: x' -File 'App.cs' -Line 3 -Column 1 -Path $script:strengthFile -ProfilePath $script:noProfile | Should -BeTrue

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq 'App.cs(3,1): error STY005: x' }
        }

        It 'throws for a <Strength> rule, whose check shouldn''t run' -ForEach @(
            @{ Id = 'OLD-001'; Strength = 'retired' }
            @{ Id = 'NET-002'; Strength = 'consider' }
        ) {
            { Write-RuleFinding -Id $Id -Message 'anything' -Path $script:strengthFile -ProfilePath $script:noProfile } | Should -Throw "*$Id*$Strength*"
        }

        It 'throws for an id the file doesn''t list' {
            { Write-RuleFinding -Id 'ARC-099' -Message 'anything' -Path $script:strengthFile -ProfilePath $script:noProfile } | Should -Throw '*ARC-099*'
        }

        # ADR-0090 decision 8: a gate skips, with its reason, where its rule doesn't apply to the app.
        It 'skips a rule whose scope doesn''t name the app''s types, once, with the reason' {
            $appProfile = New-Profile 'App types: maui'

            Write-RuleFinding -Id 'OPS-004' -Message 'first' -Path $script:strengthFile -ProfilePath $appProfile | Should -BeFalse
            Write-RuleFinding -Id 'OPS-004' -Message 'second' -Path $script:strengthFile -ProfilePath $appProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly
            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::notice::OPS-004 skipped: its scope is web-api, blazor, and the app profile names the app types maui' }
        }

        It 'skips a rule whose when the app profile answers no' {
            $appProfile = New-Profile 'App types: web-api', 'Conditions: has-sign-in=yes, has-server-database=no'

            Write-RuleFinding -Id 'DAT-003' -Message 'drops a column' -Path $script:strengthFile -ProfilePath $appProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::notice::DAT-003 skipped: it holds only where has-server-database, and the app profile answers has-server-database=no' }
        }

        It 'applies a rule whose when the app profile answers <Case>' -ForEach @(
            @{ Case = 'yes'; Conditions = 'Conditions: has-server-database=yes' }
            @{ Case = 'unknown'; Conditions = 'Conditions: has-server-database=unknown' }
            @{ Case = 'not at all, as a condition added after the app was made'; Conditions = 'Conditions: has-sign-in=no' }
            @{ Case = 'with no Conditions line'; Conditions = '' }
        ) {
            $appProfile = New-Profile 'App types: web-api', $Conditions

            Write-RuleFinding -Id 'DAT-003' -Message 'drops a column' -Path $script:strengthFile -ProfilePath $appProfile | Should -BeFalse

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq '::warning::DAT-003: drops a column' }
        }

        It 'applies a scoped rule in an app whose profile names <Case>' -ForEach @(
            @{ Case = 'one of its types'; Line = 'App types: blazor' }
            @{ Case = 'no app types'; Line = 'None chosen yet, so the app gets every kit rule.' }
        ) {
            $appProfile = New-Profile $Line

            Write-RuleFinding -Id 'OPS-004' -Message 'no rollback section' -Path $script:strengthFile -ProfilePath $appProfile | Should -BeTrue
        }

        It 'throws for a Conditions answer that isn''t yes, no or unknown' {
            $appProfile = New-Profile 'Conditions: has-server-database=maybe'

            { Write-RuleFinding -Id 'DAT-003' -Message 'x' -Path $script:strengthFile -ProfilePath $appProfile } | Should -Throw '*has-server-database=maybe*yes, no or unknown*'
        }

        # The shared workflows call a check from the app's checkout without naming a profile: it's the one in the
        # workspace GitHub checked the app out to.
        It 'reads docs/app-profile.md in GITHUB_WORKSPACE when no profile path is given' {
            $workspace = Join-Path $TestDrive "workspace-$(New-Guid)"
            New-Item -ItemType Directory -Path (Join-Path $workspace 'docs') | Out-Null
            Set-Content -LiteralPath (Join-Path $workspace 'docs' 'app-profile.md') -Value 'App types: maui'
            $saved = $env:GITHUB_WORKSPACE
            try {
                $env:GITHUB_WORKSPACE = $workspace
                Write-RuleFinding -Id 'OPS-004' -Message 'no rollback section' -Path $script:strengthFile | Should -BeFalse
            }
            finally { $env:GITHUB_WORKSPACE = $saved }

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -like '::notice::OPS-004 skipped:*maui*' }
        }
    }
}
