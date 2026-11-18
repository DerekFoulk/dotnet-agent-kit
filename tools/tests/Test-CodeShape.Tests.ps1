#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Test-CodeShape.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-CodeShape.ps1')
        $script:fixtures = Join-Path $PSScriptRoot 'fixtures' 'CodeShape'
        $script:kitRoot = Join-Path $PSScriptRoot '..' '..'
    }

    Context 'reading the projects' {
        BeforeAll {
            $script:projects = @(Get-CodeShapeProject -Solution (Join-Path $script:fixtures 'Deep.slnx'))
        }

        It 'lists each C# project, and skips one in another language' {
            $script:projects | ForEach-Object { Split-Path $_.name -Leaf } | Should -Be 'Deep.csproj'
        }

        It "takes the project's source files from MSBuild's Compile items" {
            $script:projects[0].files | ForEach-Object { Split-Path $_ -Leaf } | Should -Be 'Deep.cs'
        }

        It "takes the project's preprocessor symbols from its DefineConstants" {
            $script:projects[0].defines | Should -Contain 'KIT_FIXTURE'
        }

        # Review 1 of GAP-019: with TargetFrameworks, the outer evaluation has no Compile items.
        It 'reads a project with several target frameworks through its first one' {
            $multi = @(Get-CodeShapeProject -Solution (Join-Path $script:fixtures 'Multi.slnx'))

            $multi[0].files | ForEach-Object { Split-Path $_ -Leaf } | Should -Be 'Multi.cs'
        }

        # The kit's solutions are .slnx, and the check reads them as every kit script does (KitSolution.psm1).
        It 'refuses a .sln, saying how to convert it' {
            $solution = Join-Path $TestDrive 'Old.sln'
            Push-Location $TestDrive
            try { dotnet new sln -n Old --format sln *> $null } finally { Pop-Location }

            { Get-CodeShapeProject -Solution $solution } | Should -Throw "*Old.sln isn't a .slnx solution*migrate*"
        }
    }

    Context 'running the check' {
        It 'fails a solution that breaks a limit, naming the place in MSBuild error format' {
            $result = Invoke-CodeShapeCheck -Solution (Join-Path $script:fixtures 'Deep.slnx') -KitRoot $script:kitRoot

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match '[\\/]Deep\.cs\(7,74\): error CRF011: Run nests 5 levels deep; the limit is 3 \(CRF-011\)\. \[.*Deep\.csproj\]$'
        }

        It 'passes a solution within every limit' {
            $result = Invoke-CodeShapeCheck -Solution (Join-Path $script:fixtures 'Tidy.slnx') -KitRoot $script:kitRoot

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Be 'Code shape (CRF-011, STY-005): 1 project, 1 file, no findings.'
        }

        # Review 1 of GAP-019: a tool that doesn't build is a broken check, not a finding in the code.
        It "stops with the build's errors when the kit's tool doesn't build" {
            { Invoke-CodeShapeCheck -Solution (Join-Path $script:fixtures 'Tidy.slnx') -KitRoot (Join-Path $script:fixtures 'BrokenKit') } |
                Should -Throw "*The kit's code shape tool didn't build*The fixture's tool doesn't build*"
        }
    }

    # ADR-0089: a proposed rule's findings are warnings that don't fail the check; an accepted rule's fail it. Each
    # finding's rule is its error code (CRF011 is CRF-011). The statuses come from a fixture, not the real rules.
    Context 'a finding of a proposed rule' {
        BeforeAll {
            function New-StatusFile([string] $Crf011) {
                $path = Join-Path $TestDrive "rule-status-$(New-Guid).json"
                Set-Content -LiteralPath $path -Value "{ ""CRF-011"": ""$Crf011"", ""STY-005"": ""accepted"" }"
                $path
            }
            $script:shapeLine = 'C:\app\Deep.cs(7,74): error CRF011: Run nests 5 levels deep; the limit is 3 (CRF-011). [C:\app\Deep.csproj]'
            $script:nullableLine = 'C:\app\Deep.cs(1,1): error STY005: The #nullable directive is not allowed (STY-005). [C:\app\Deep.csproj]'
        }

        BeforeEach {
            Mock Write-Host {}
            Mock Write-Host {} -ModuleName KitRuleStatus
        }

        It 'warns, and passes, on a CRF-011 breach while CRF-011 is proposed' {
            Write-CodeShapeResult -ExitCode 1 -Output $script:shapeLine -RuleStatusPath (New-StatusFile 'proposed') | Should -Be 0

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq "::warning::CRF-011: $script:shapeLine" }
            Should -Invoke Write-Host -ParameterFilter { "$Object" -match '1 code shape finding.*warning.*proposed' }
        }

        It 'fails on the same breach once CRF-011 is accepted' {
            Write-CodeShapeResult -ExitCode 1 -Output $script:shapeLine -RuleStatusPath (New-StatusFile 'accepted') | Should -Be 1

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq $script:shapeLine -and $ForegroundColor -eq 'Red' }
        }

        It 'still fails on a STY-005 breach, whose rule is accepted, beside a CRF-011 warning' {
            Write-CodeShapeResult -ExitCode 1 -Output "$script:shapeLine`n$script:nullableLine" -RuleStatusPath (New-StatusFile 'proposed') | Should -Be 1

            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq $script:nullableLine -and $ForegroundColor -eq 'Red' }
            Should -Invoke Write-Host -ModuleName KitRuleStatus -Times 1 -Exactly -ParameterFilter { "$Object" -ceq "::warning::CRF-011: $script:shapeLine" }
            Should -Invoke Write-Host -ParameterFilter { "$Object" -match '1 code shape finding.*fail.*1 more.*warning' }
        }

        It 'throws for a finding whose rule the statuses don''t list, so a new code can''t pass unseen' {
            $unknown = 'C:\app\Deep.cs(1,1): error XYZ001: Something new. [C:\app\Deep.csproj]'

            { Write-CodeShapeResult -ExitCode 1 -Output $unknown -RuleStatusPath (New-StatusFile 'proposed') } | Should -Throw '*XYZ-001*'
        }

        It 'passes through a clean run, and keeps any other exit code the tool gives' {
            Write-CodeShapeResult -ExitCode 0 -Output 'Code shape (CRF-011, STY-005): 1 project, 1 file, no findings.' -RuleStatusPath (New-StatusFile 'proposed') | Should -Be 0
            Should -Invoke Write-Host -ParameterFilter { "$Object" -ceq 'Code shape (CRF-011, STY-005): 1 project, 1 file, no findings.' }

            Write-CodeShapeResult -ExitCode 2 -Output 'Usage: Kit.CodeShape [--files] <manifest.json>' -RuleStatusPath (New-StatusFile 'proposed') | Should -Be 2
        }

        # Errs toward failing: a run that failed with no finding to judge is a broken check.
        It 'fails a run that exited 1 with no finding it can read' {
            Write-CodeShapeResult -ExitCode 1 -Output 'Unhandled exception.' -RuleStatusPath (New-StatusFile 'proposed') | Should -Be 1
        }

        It 'reads a finding''s rule from its error code: <Code> is <Rule>' -ForEach @(
            @{ Code = 'CRF011'; Rule = 'CRF-011' }
            @{ Code = 'STY005'; Rule = 'STY-005' }
            @{ Code = 'ABC123'; Rule = 'ABC-123' }
        ) {
            ConvertTo-CodeShapeRuleId -Code $Code | Should -BeExactly $Rule
        }

        # Review of the branch: a new error code in Kit.CodeShape needs a rule the statuses list, or the check throws.
        It 'maps every error code Kit.CodeShape prints to a rule in the kit''s rule-status.json' {
            $codes = Get-Content -Raw -LiteralPath (Join-Path $script:kitRoot 'tools/CodeShape/src/Kit.CodeShape/RuleCodes.cs')
            $listed = @([regex]::Matches($codes, 'const string \w+ = "(?<code>[A-Z]+\d+)";') | ForEach-Object { $_.Groups['code'].Value })
            $statuses = Get-Content -Raw -LiteralPath (Join-Path $script:kitRoot 'tools/rule-status.json') | ConvertFrom-Json

            $listed.Count | Should -BeGreaterThan 1
            foreach ($code in $listed) {
                $statuses.PSObject.Properties.Name | Should -Contain (ConvertTo-CodeShapeRuleId -Code $code) -Because "Kit.CodeShape prints $code"
            }
        }

        # Review of the branch: a mutant that always exits 0 survived this file. The script's exit code is the gate.
        It 'exits 1 as a script on a CRF-011 breach once CRF-011 is accepted' {
            $script = Join-Path $PSScriptRoot '..' 'Test-CodeShape.ps1'

            $output = pwsh -NoProfile -File $script -Solution (Join-Path $script:fixtures 'Deep.slnx') -RuleStatusPath (New-StatusFile 'accepted') 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match '(?m)^.*Deep\.cs\(7,74\): error CRF011: Run nests 5 levels deep'
            $output | Should -Not -Match '::warning'
        }

        It 'exits 0 as a script, with the warning annotation, on a CRF-011 breach while CRF-011 is proposed' {
            $script = Join-Path $PSScriptRoot '..' 'Test-CodeShape.ps1'

            $output = pwsh -NoProfile -File $script -Solution (Join-Path $script:fixtures 'Deep.slnx') -RuleStatusPath (New-StatusFile 'proposed') 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 0 -Because $output
            $output | Should -Match '(?m)^::warning::CRF-011: .*Deep\.cs\(7,74\): error CRF011: Run nests 5 levels deep'
        }
    }

    Context "CRF-011's numbers" {
        It 'match the limits the check enforces' {
            $limits = Get-Content -Raw (Join-Path $script:kitRoot 'tools/CodeShape/src/Kit.CodeShape/Limits.cs')
            $craft = Get-Content -Raw (Join-Path $script:kitRoot 'docs/standards/craft.md')
            $statement = [regex]::Match($craft, '(?m)^  - id: CRF-011\r?\n    statement: "(?<s>[^"]+)"').Groups['s'].Value

            $enforced = 'NestingDepth', 'StatementsPerMember', 'LinesPerFile', 'MembersPerType', 'PublicTypesPerFile', 'Lcom4' |
                ForEach-Object { [regex]::Match($limits, "const int $_ = (\d+);").Groups[1].Value }
            # The statement spells out one, as prose does; any other number is in digits.
            $stated = 'nesting to (\d+) levels', '(\d+) statements per member', '(\d+) lines per file', '(\d+) members per type',
                '(\w+) public types? per file', 'LCOM4 of (\d+)' |
                ForEach-Object { [regex]::Match($statement, $_).Groups[1].Value } |
                ForEach-Object { $_ -eq 'one' ? '1' : $_ }

            $stated | Should -Be $enforced
            $enforced | Should -Not -Contain ''
        }

        # CRF-008 stated these numbers as aims until the rules audit (D-items, 2026-11-13) left them to CRF-011 alone
        # (CRF-003: one source); a copy in CRF-008 would drift again.
        It "aren't restated in CRF-008" {
            $craft = Get-Content -Raw (Join-Path $script:kitRoot 'docs/standards/craft.md')
            $statement = [regex]::Match($craft, '(?m)^  - id: CRF-008\r?\n    statement: "(?<s>[^"]+)"').Groups['s'].Value
            $statement | Should -Not -BeNullOrEmpty -Because 'the test must find CRF-008 to check it'

            $statement | Should -Not -Match 'nesting|statements per|lines per file|LCOM4'
        }
    }
}
