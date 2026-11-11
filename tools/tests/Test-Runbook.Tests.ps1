#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Test-Runbook.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-Runbook.ps1')

        function New-RunbookText {
            param(
                [string] $Status = 'Draft',
                [string] $Reviewed = '2026-11-11',
                [string[]] $Omit = @(),
                [hashtable] $Body = @{}
            )

            $sections = [ordered]@{}
            foreach ($name in $script:RequiredSections) { $sections[$name] = "1. Do the $name step." }
            foreach ($key in $Body.Keys) { $sections[$key] = $Body[$key] }

            $lines = @('# Contoso.Orders runbook', '')
            if ('Status' -notin $Omit) { $lines += "- **Status:** $Status" }
            if ('Last reviewed' -notin $Omit) { $lines += "- **Last reviewed:** $Reviewed" }
            foreach ($name in $sections.Keys) {
                if ($name -notin $Omit) { $lines += '', "## $name", '', $sections[$name] }
            }
            ($lines -join "`n") + "`n"
        }

        function New-Runbook {
            Set-Content -Path $script:runbook -Value (New-RunbookText @args)
        }

        function Get-Message {
            @(Get-RunbookProblem -Path $script:runbook) | ForEach-Object Message
        }
    }

    BeforeEach {
        $script:runbook = Join-Path $TestDrive "runbook-$(New-Guid).md"
    }

    Context 'sections' {
        It 'finds no problems in a complete runbook' {
            New-Runbook

            Get-Message | Should -BeNullOrEmpty
        }

        It 'reports a missing ''<Section>'' section' -ForEach @(
            @{ Section = 'Where it runs' }, @{ Section = 'How to deploy a release' },
            @{ Section = 'How to roll back a release' }, @{ Section = 'How to check its health' },
            @{ Section = 'How to read its telemetry' }, @{ Section = 'How to restore its data' },
            @{ Section = 'How to respond to an incident' }
        ) {
            New-Runbook -Omit $Section

            Get-Message | Should -Be "section '$Section' is missing"
        }

        It 'reports an empty section' {
            New-Runbook -Body @{ 'How to restore its data' = '' }

            Get-Message | Should -Be "section 'How to restore its data' is empty"
        }

        It 'reads a "## " line inside a fenced code block as code, not as a heading' {
            $fence = '```'
            $text = New-RunbookText -Body @{ 'How to deploy a release' = "1. Run:`n`n${fence}bash`n## not a heading`ngh workflow run deploy.yml`n${fence}" }

            $sections = Get-RunbookSection -Lines ($text -split "`n")

            @($sections.Keys) | Should -Be $script:RequiredSections
            $sections['How to deploy a release'] | Should -Match '## not a heading'
        }
    }

    Context 'status and review date' {
        It 'accepts the status ''<Status>''' -ForEach @(@{ Status = 'Draft' }, @{ Status = 'In use' }) {
            New-Runbook -Status $Status

            Get-Message | Should -BeNullOrEmpty
        }

        It 'reports a missing status line' {
            New-Runbook -Omit 'Status'

            Get-Message | Should -Be "the '- **Status:** ' line is missing"
        }

        It 'reports a status other than Draft or In use' {
            New-Runbook -Status 'Live'

            Get-Message | Should -Be "status 'Live' must be 'Draft' or 'In use'"
        }

        It 'reports a missing review date line' {
            New-Runbook -Omit 'Last reviewed'

            Get-Message | Should -Be "the '- **Last reviewed:** ' line is missing"
        }
    }
}
