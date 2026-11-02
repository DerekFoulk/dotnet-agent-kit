#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Test-AdrSections.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-AdrSections.ps1')

        function New-Option([string] $Name, [string[]] $Skip = @()) {
            $lines = @("### $Name", '')
            if ('Trade-offs' -notin $Skip) { $lines += '- **Trade-offs:** Simple, but slower.' }
            if ('Reversibility' -notin $Skip) { $lines += '- **Reversibility:** Easy; one config change.' }
            if ('Risk' -notin $Skip) { $lines += '- **Risk:** Low.' }
            $lines -join "`n"
        }

        function New-AdrText {
            param(
                [string] $Number = '0007',
                [string] $Status = 'Accepted',
                [string] $Date = '2026-11-01',
                [string[]] $Omit = @(),
                [hashtable] $Body = @{},
                [string] $Options = ((New-Option 'Option 1: Merge commits') + "`n`n" + (New-Option 'Option 2: Squash merges'))
            )

            $sections = [ordered]@{
                'Context'         = 'Squash merges hide the red and green commits.'
                'Options'         = $Options
                'Recommendation'  = 'Option 1, because history shows each TDD step.'
                'Decision'        = 'Option 1.'
                'Consequences'    = 'Longer history.'
                'Pillars affected' = 'Operational excellence.'
                'Sources'         = '- owner, 2026-10-26'
            }
            foreach ($key in $Body.Keys) { $sections[$key] = $Body[$key] }

            $lines = @("# ADR-${Number}: GitHub Flow with merge commits only", '')
            if ('Status' -notin $Omit) { $lines += "- **Status:** $Status" }
            if ('Date' -notin $Omit) { $lines += "- **Date:** $Date" }
            foreach ($name in $sections.Keys) {
                if ($name -notin $Omit) { $lines += '', "## $name", '', $sections[$name] }
            }
            ($lines -join "`n") + "`n"
        }

        function New-Adr([string] $FileName = '0007-github-flow.md') {
            $text = New-AdrText @args
            Set-Content -Path (Join-Path $script:adr $FileName) -Value $text
        }

        function Get-Problem {
            @(Get-AdrSectionProblem -AdrPath $script:adr)
        }

        function Get-Message {
            Get-Problem | ForEach-Object Message
        }
    }

    BeforeEach {
        $script:adr = Join-Path $TestDrive "adr-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:adr | Out-Null
    }

    Context 'sections' {
        It 'finds no problems in a complete ADR' {
            New-Adr

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports a missing <Section> section' -ForEach @(
            @{ Section = 'Context' }, @{ Section = 'Options' }, @{ Section = 'Recommendation' }, @{ Section = 'Decision' },
            @{ Section = 'Consequences' }, @{ Section = 'Pillars affected' }, @{ Section = 'Sources' }
        ) {
            New-Adr -Omit $Section

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].File | Should -Be '0007-github-flow.md'
            $problems[0].Message | Should -BeLike "*'$Section'*missing*"
        }

        It 'reports an empty <Section> section' -ForEach @(
            @{ Section = 'Recommendation' }, @{ Section = 'Consequences' }
        ) {
            New-Adr -Body @{ $Section = '   ' }

            Get-Message | Should -BeLike "*'$Section'*empty*"
        }

        It 'skips the template' {
            Set-Content -Path (Join-Path $script:adr '0000-template.md') -Value '# ADR-NNNN: Title'

            Get-Problem | Should -BeNullOrEmpty
        }
    }

    Context 'header' {
        It 'accepts status <Status>' -ForEach @(
            @{ Status = 'Proposed' }, @{ Status = 'Accepted' }, @{ Status = 'Rejected' },
            @{ Status = 'Deprecated' }, @{ Status = 'Superseded by ADR-0012' }
        ) {
            New-Adr -Status $Status

            Get-Problem | Should -BeNullOrEmpty
        }

        It 'reports <Case>' -ForEach @(
            @{ Case = 'a status outside the allowed list'; Arguments = @{ Status = 'Done' }; Expected = "*status 'Done'*" }
            @{ Case = 'a date that is not YYYY-MM-DD'; Arguments = @{ Date = '2026-13-01' }; Expected = "*date '2026-13-01'*" }
            @{ Case = 'a missing Status line'; Arguments = @{ Omit = 'Status' }; Expected = '*Status*missing*' }
            @{ Case = 'a missing Date line'; Arguments = @{ Omit = 'Date' }; Expected = '*Date*missing*' }
            @{ Case = 'a title number that differs from the file name'; Arguments = @{ Number = '0008' }; Expected = '*title*ADR-0007*' }
        ) {
            New-Adr @Arguments

            $problems = @(Get-Problem)

            $problems.Count | Should -Be 1
            $problems[0].Message | Should -BeLike $Expected
        }

        It 'reports a file name that is not NNNN-title.md' {
            New-Adr -FileName 'github-flow.md'

            Get-Message | Should -BeLike '*file name*NNNN-*'
        }
    }
}
