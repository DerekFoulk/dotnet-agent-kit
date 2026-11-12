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
    }

    Context 'running the check' {
        It 'fails a solution that breaks a limit, naming the place in MSBuild error format' {
            $result = Invoke-CodeShapeCheck -Solution (Join-Path $script:fixtures 'Deep.slnx') -KitRoot $script:kitRoot

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match '[\\/]Deep\.cs\(7,74\): error CRF011: Run nests 5 levels deep; the limit is 4 \(CRF-011\)\. \[.*Deep\.csproj\]$'
        }

        It 'passes a solution within every limit' {
            $result = Invoke-CodeShapeCheck -Solution (Join-Path $script:fixtures 'Tidy.slnx') -KitRoot $script:kitRoot

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Be 'Code shape (CRF-011): 1 project, 1 file, no findings.'
        }

        # Review 1 of GAP-019: a tool that doesn't build is a broken check, not a finding in the code.
        It "stops with the build's errors when the kit's tool doesn't build" {
            { Invoke-CodeShapeCheck -Solution (Join-Path $script:fixtures 'Tidy.slnx') -KitRoot (Join-Path $script:fixtures 'BrokenKit') } |
                Should -Throw "*The kit's code shape tool didn't build*The fixture's tool doesn't build*"
        }
    }

    Context "CRF-011's numbers" {
        It 'match the limits the check enforces' {
            $limits = Get-Content -Raw (Join-Path $script:kitRoot 'tools/CodeShape/src/Kit.CodeShape/Limits.cs')
            $craft = Get-Content -Raw (Join-Path $script:kitRoot 'docs/standards/craft.md')
            $statement = [regex]::Match($craft, '(?m)^  - id: CRF-011\r?\n    statement: "(?<s>[^"]+)"').Groups['s'].Value

            $enforced = 'NestingDepth', 'StatementsPerMember', 'LinesPerFile', 'Lcom4' | ForEach-Object {
                [regex]::Match($limits, "const int $_ = (\d+);").Groups[1].Value
            }
            $stated = 'nesting to (\d+) levels', '(\d+) statements per member', '(\d+) lines per file', 'LCOM4 of (\d+)' |
                ForEach-Object { [regex]::Match($statement, $_).Groups[1].Value }

            $stated | Should -Be $enforced
            $enforced | Should -Not -Contain ''
        }

        # Review 2 of GAP-019: until the owner accepts CRF-011, CRF-008 states the same numbers as aims; they stay in step.
        It "match CRF-008's aims, while it states them" {
            $limits = Get-Content -Raw (Join-Path $script:kitRoot 'tools/CodeShape/src/Kit.CodeShape/Limits.cs')
            $craft = Get-Content -Raw (Join-Path $script:kitRoot 'docs/standards/craft.md')
            $statement = [regex]::Match($craft, '(?m)^  - id: CRF-008\r?\n    statement: "(?<s>[^"]+)"').Groups['s'].Value
            $statement | Should -Not -BeNullOrEmpty -Because 'the test must find CRF-008 to check it'
            if ($statement -notmatch 'aim for') { Set-ItResult -Skipped -Because "CRF-008 no longer states CRF-011's numbers" }

            $enforced = 'NestingDepth', 'StatementsPerMember', 'LinesPerFile', 'Lcom4' | ForEach-Object {
                [regex]::Match($limits, "const int $_ = (\d+);").Groups[1].Value
            }
            $stated = 'nesting (\d+) levels deep', 'about (\d+) statements per method', 'about (\d+) lines per file', 'LCOM4 of (\d+)' |
                ForEach-Object { [regex]::Match($statement, $_).Groups[1].Value }

            $stated | Should -Be $enforced
            $enforced | Should -Not -Contain ''
        }
    }
}
