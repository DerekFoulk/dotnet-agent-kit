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

            @($sections.Name) | Should -Be $script:RequiredSections
            ($sections | Where-Object Name -EQ 'How to deploy a release').Body | Should -Match '## not a heading'
        }

        # Review 1 (mutants that survived): a fence closes only on the same character, at least as long, and may be
        # indented up to three spaces (CommonMark).
        It 'keeps a fence open across <Case>' -ForEach @(
            @{ Case = 'a shorter fence of the same character'; Open = '````'; Inner = '```'; Close = '````' }
            @{ Case = 'a fence of the other character'; Open = '```'; Inner = '~~~'; Close = '```' }
            @{ Case = 'an indented fence'; Open = '   ```'; Inner = 'echo indented'; Close = '   ```' }
        ) {
            $body = "1. Run:`n`n$Open`n$Inner`n## not a heading`n$Close"
            $text = New-RunbookText -Body @{ 'How to deploy a release' = $body }

            $sections = Get-RunbookSection -Lines ($text -split "`n")

            @($sections.Name) | Should -Be $script:RequiredSections
        }

        It 'keeps a fence open across a fence line with an info string, which can''t close one' {
            $fence = '```'
            $text = New-RunbookText -Body @{ 'How to deploy a release' = "1. Run:`n`n$fence`n${fence}text`n## not a heading`n$fence" }

            $sections = Get-RunbookSection -Lines ($text -split "`n")

            @($sections.Name) | Should -Be $script:RequiredSections
        }

        It 'reads a heading with closing hashes' {
            $text = (New-RunbookText) -replace '(?m)^## Where it runs$', '## Where it runs ##'

            @((Get-RunbookSection -Lines ($text -split "`n")).Name) | Should -Contain 'Where it runs'
        }

        It 'reports a section that appears twice' {
            $text = (New-RunbookText) + "`n## How to restore its data`n`n1. Again.`n"
            Set-Content -Path $script:runbook -Value $text

            Get-Message | Should -Be "section 'How to restore its data' appears more than once"
        }

        It 'counts a section that holds only an HTML comment as empty' {
            New-Runbook -Body @{ 'How to restore its data' = '<!-- TODO -->' }

            Get-Message | Should -Be "section 'How to restore its data' is empty"
        }

        # Review 2 (mutants that survived): a comment may span lines, and one comment ends at its own -->.
        It 'counts a section that holds only a comment over several lines as empty' {
            New-Runbook -Body @{ 'How to restore its data' = "<!--`n  TODO: the restore steps`n-->" }

            Get-Message | Should -Be "section 'How to restore its data' is empty"
        }

        It 'counts a step between two comments' {
            New-Runbook -Body @{ 'How to restore its data' = '<!-- a --> 1. Restore it. <!-- b -->' }

            Get-Message | Should -BeNullOrEmpty
        }

        It 'reads a heading with trailing spaces' {
            $text = (New-RunbookText) -replace '(?m)^## Where it runs$', '## Where it runs   '

            @((Get-RunbookSection -Lines ($text -split "`n")).Name) | Should -Contain 'Where it runs'
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

        It 'reports a status in the wrong case' {
            New-Runbook -Status 'in use'

            Get-Message | Should -Be "status 'in use' must be 'Draft' or 'In use'"
        }

        It 'reads a status with trailing spaces' {
            New-Runbook -Status 'In use   '

            Get-Message | Should -BeNullOrEmpty
        }

        It 'reports a missing review date line' {
            New-Runbook -Omit 'Last reviewed'

            Get-Message | Should -Be "the '- **Last reviewed:** ' line is missing"
        }
    }

    Context 'placeholders' {
        It 'lets a Draft keep its placeholders, the review date''s too' {
            New-Runbook -Status 'Draft' -Reviewed '[fill in: YYYY-MM-DD]' -Body @{ 'Where it runs' = '- Production: [fill in: the production URL]' }

            Get-Message | Should -BeNullOrEmpty
        }

        It 'reports each placeholder left in a runbook that''s In use, with its line' {
            New-Runbook -Status 'In use' -Body @{ 'Where it runs' = '- Production: [fill in: the production URL]' }
            $line = (Select-String -LiteralPath $script:runbook -SimpleMatch '[fill in:').LineNumber

            Get-Message | Should -Be "line ${line}: '[fill in: the production URL]' must be filled in before the runbook is In use"
        }

        It 'reports a review date ''<Date>'', which isn''t YYYY-MM-DD, in a runbook that''s In use' -ForEach @(
            @{ Date = '11/11/2026' }, @{ Date = '2026-11-1' }, @{ Date = '2026-13-01' }
        ) {
            New-Runbook -Status 'In use' -Reviewed $Date

            Get-Message | Should -Be "review date '$Date' must be YYYY-MM-DD"
        }
    }

    Context 'the app template''s runbook' {
        It 'passes, as a Draft whose steps the app fills in' {
            $template = Join-Path $PSScriptRoot '..' '..' 'templates' 'app' 'docs' 'runbook.md'

            @(Get-RunbookProblem -Path $template) | ForEach-Object Message | Should -BeNullOrEmpty
            Get-RunbookField -Lines (Get-Content -LiteralPath $template) -Name 'Status' | Should -Be 'Draft'
            Get-Content -Raw -LiteralPath $template | Should -Match $script:PlaceholderPattern
        }

        # Review 2: the template's own guidance named the placeholder form, so a filled-in runbook still failed.
        It 'passes once an app fills in every step and sets it In use' {
            $template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..' '..' 'templates' 'app' 'docs' 'runbook.md')) -replace "`r`n", "`n"
            $firstSection = $template.IndexOf("`n## ")
            $header = $template.Substring(0, $firstSection) -replace '(?m)^- \*\*Status:\*\* .*$', '- **Status:** In use' -replace '(?m)^- \*\*Last reviewed:\*\* .*$', '- **Last reviewed:** 2026-11-11'
            $steps = [regex]::Replace($template.Substring($firstSection), $script:PlaceholderPattern, 'the app''s own step')
            Set-Content -Path $script:runbook -Value ($header + $steps)

            Get-Message | Should -BeNullOrEmpty
        }
    }

    Context 'runner' {
        BeforeEach {
            Mock Write-Host {}
        }

        It 'reports a runbook that isn''t there' {
            Get-Message | Should -Be "there's no runbook at '$script:runbook'"
        }

        It 'returns 0 and says so when the runbook is complete' {
            New-Runbook

            Invoke-RunbookCheck -Path $script:runbook | Should -Be 0
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*runbook*complete*' }
        }

        It 'returns 1 and prints each problem' {
            New-Runbook -Omit 'How to restore its data'

            Invoke-RunbookCheck -Path $script:runbook | Should -Be 1
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like "*'How to restore its data' is missing*" }
        }

        It 'exits 1 when run as a script against an incomplete runbook' {
            New-Runbook -Omit 'How to roll back a release'
            $script = Join-Path $PSScriptRoot '..' 'Test-Runbook.ps1'

            $output = pwsh -NoProfile -File $script -Path $script:runbook 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'How to roll back a release'
        }
    }
}
