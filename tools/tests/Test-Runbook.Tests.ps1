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

        # Review 2: CommonMark allows these heading forms; the section names must match exactly, as the status does.
        It 'reads a heading written as ''<Heading>''' -ForEach @(
            @{ Heading = '   ## Where it runs' }, @{ Heading = "##`tWhere it runs" }, @{ Heading = '##   Where it runs' }
        ) {
            $text = (New-RunbookText) -replace '(?m)^## Where it runs$', $Heading

            @((Get-RunbookSection -Lines ($text -split "`n")).Name) | Should -Contain 'Where it runs'
        }

        It 'reports a section whose heading is in the wrong case as missing' {
            Set-Content -Path $script:runbook -Value ((New-RunbookText) -replace '(?m)^## Where it runs$', '## where it runs')

            Get-Message | Should -Be "section 'Where it runs' is missing"
        }

        # Review 3 (mutants that survived): the limits of each form. Four spaces of indent make a code line, two
        # backticks aren't a fence, and a heading's closing hashes need a space before them.
        It 'reads ''<Line>'' inside a section as text, not as <What>' -ForEach @(
            @{ Line = '    ## Where it runs'; What = 'a heading' }
            @{ Line = '    ```'; What = 'a fence' }
            @{ Line = '``'; What = 'a fence' }
        ) {
            $text = New-RunbookText -Body @{ 'How to deploy a release' = "1. Run it.`n$Line`n## How to roll back a release`n`n1. Undo it." } -Omit 'How to roll back a release'

            @((Get-RunbookSection -Lines ($text -split "`n")).Name) | Should -Be $script:RequiredSections
        }

        It 'keeps a hash at the end of a heading''s name that has no space before it' {
            $text = (New-RunbookText) -replace '(?m)^## Where it runs$', '## Where it runs#'

            @((Get-RunbookSection -Lines ($text -split "`n")).Name) | Should -Contain 'Where it runs#'
        }

        It 'reads the first status line, as a reader does' {
            $text = (New-RunbookText -Status 'In use') -replace '(?m)^(- \*\*Last reviewed:\*\* .*)$', "`$1`n- **Status:** Draft"
            Set-Content -Path $script:runbook -Value ($text + "`n[fill in: a step]`n")

            Get-Message | Should -Match '^line \d+: '
        }

        It 'reads a code span made of a run of backticks with text after it as text, not a fence' {
            $body = "1. Run this, then wait:`n`n``````echo hi`````` then wait.`n`n## How to roll back a release`n`n1. Undo it."
            $text = New-RunbookText -Body @{ 'How to deploy a release' = $body } -Omit 'How to roll back a release'

            @((Get-RunbookSection -Lines ($text -split "`n")).Name) | Should -Be $script:RequiredSections
        }

        It 'reads a "## " line inside an HTML comment as part of the comment, not a heading' {
            $body = "1. Deploy it.`n<!--`n## How to roll back a release`n-->"
            New-Runbook -Body @{ 'How to deploy a release' = $body }

            Get-Message | Should -BeNullOrEmpty
        }

        # Review 4 (mutants that survived): a comment block runs over every line to the one holding "-->", wherever
        # it sits on that line; it opens only with up to three spaces of indent; and the fence limits hold for the
        # closing line and for a tilde fence's info string.
        It 'reads every line of an HTML comment block, to the one that holds -->, as the comment' {
            $body = "1. Deploy it.`n<!--`nOld steps:`n## How to roll back a release`nend of the old steps -->"
            New-Runbook -Body @{ 'How to deploy a release' = $body }

            Get-Message | Should -BeNullOrEmpty
        }

        It 'reads ''<Open>'' as <What>, so the "## " line after it <Reads>' -ForEach @(
            @{ Open = '    <!--'; Close = '-->'; What = 'code, not a comment'; Reads = 'is a heading'; Expected = 'appears more than once' }
            @{ Open = '~~~ `a` b'; Close = '~~~'; What = 'a tilde fence, though its info string holds a backtick'; Reads = 'is code'; Expected = $null }
        ) {
            $body = "1. Deploy it.`n$Open`n## How to roll back a release`n$Close"
            New-Runbook -Body @{ 'How to deploy a release' = $body }

            if ($Expected) { Get-Message | Should -Match $Expected } else { Get-Message | Should -BeNullOrEmpty }
        }

        It 'keeps a fence open across a closing line indented four spaces' {
            $fence = '```'
            $text = New-RunbookText -Body @{ 'How to deploy a release' = "$fence`n    $fence`n## not a heading`n$fence" }

            @((Get-RunbookSection -Lines ($text -split "`n")).Name) | Should -Be $script:RequiredSections
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

        It 'reports a status in the wrong case, and nothing an In use runbook would add' {
            New-Runbook -Status 'in use' -Reviewed 'soon' -Body @{ 'Where it runs' = '[fill in: the URL]' }

            Get-Message | Should -Be "status 'in use' must be 'Draft' or 'In use'"
        }

        It 'reports only the missing review date line in a runbook that''s In use' {
            New-Runbook -Status 'In use' -Omit 'Last reviewed'

            Get-Message | Should -Be "the '- **Last reviewed:** ' line is missing"
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

        # Review 4: an editor that wraps long lines can split a placeholder over two.
        It 'reports a placeholder split over two lines, at the line it starts on' {
            New-Runbook -Status 'In use' -Body @{ 'Where it runs' = "- Telemetry: [fill in: the OpenTelemetry backend,`n  and how to open it]" }
            $line = (Select-String -LiteralPath $script:runbook -SimpleMatch '[fill in:').LineNumber

            Get-Message | Should -Be "line ${line}: '[fill in: the OpenTelemetry backend, and how to open it]' must be filled in before the runbook is In use"
        }

        # Review 5: the wrap can fall anywhere inside the marker too.
        It 'reports a placeholder split inside its "[fill in:" marker' {
            New-Runbook -Status 'In use' -Body @{ 'Where it runs' = "- Probes: [fill`n  in: where they're set up]" }
            $line = (Select-String -LiteralPath $script:runbook -SimpleMatch '[fill').LineNumber

            Get-Message | Should -Be "line ${line}: '[fill in: where they're set up]' must be filled in before the runbook is In use"
        }

        It 'reports a placeholder whatever its case, as ''<Placeholder>''' -ForEach @(@{ Placeholder = '[Fill in: the URL]' }, @{ Placeholder = '[FILL IN: the URL]' }) {
            New-Runbook -Status 'In use' -Body @{ 'Where it runs' = "- Production: $Placeholder" }

            Get-Message | Should -Match ([regex]::Escape("'$Placeholder' must be filled in"))
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
