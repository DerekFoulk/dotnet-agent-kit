#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Test-ArchitectureDiagram.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-ArchitectureDiagram.ps1')

        function Get-Message {
            param([Parameter(Mandatory)] [string] $Path)
            @(Get-ArchitectureDiagramProblem -Path $Path) | ForEach-Object Message
        }
    }

    BeforeEach {
        $script:diagram = Join-Path $TestDrive "modules-$(New-Guid).md"
    }

    It 'passes a page with a Mermaid diagram' {
        Set-Content -Path $script:diagram -Value "# Modules`n`n``````mermaid`nflowchart LR`n  Api --> Application`n```````n"

        Get-Message -Path $script:diagram | Should -BeNullOrEmpty
    }

    It 'fails when the page is missing' {
        Get-Message -Path $script:diagram | Should -Be "no architecture diagram at $script:diagram"
    }

    It 'fails when the page has no Mermaid diagram' {
        Set-Content -Path $script:diagram -Value "# Modules`n`nThe API calls the application layer.`n"

        Get-Message -Path $script:diagram | Should -Be 'no ```mermaid code block'
    }

    It 'fails when the Mermaid diagram is empty' {
        Set-Content -Path $script:diagram -Value "# Modules`n`n``````mermaid`n`n```````n"

        Get-Message -Path $script:diagram | Should -Be 'the ```mermaid code block is empty'
    }

    It 'doesn''t count a Mermaid block inside an HTML comment, which a reader doesn''t see' {
        Set-Content -Path $script:diagram -Value "# Modules`n`n<!--`n``````mermaid`nflowchart LR`n  A --> B`n```````n-->`n"

        Get-Message -Path $script:diagram | Should -Be 'no ```mermaid code block'
    }

    # A Windows checkout writes CRLF line endings (.gitattributes leaves .md files to text=auto), review 1.
    It 'passes a page with CRLF line endings' {
        [IO.File]::WriteAllText($script:diagram, "# Modules`r`n`r`n``````mermaid`r`nflowchart LR`r`n  A --> B`r`n```````r`n")

        Get-Message -Path $script:diagram | Should -BeNullOrEmpty
    }

    It 'reads a fence as CommonMark does: <Description>' -ForEach @(
        @{ Description = 'a tilde fence'; Text = "~~~mermaid`nflowchart LR`n  A --> B`n~~~`n" }
        @{ Description = 'a fence longer than three'; Text = "````````mermaid`nflowchart LR`n  A --> B`n`````````n" }
        @{ Description = 'an info string after mermaid'; Text = "``````mermaid title`nflowchart LR`n  A --> B`n```````n" }
        @{ Description = 'a fence indented by up to three spaces'; Text = "   ``````mermaid`n   flowchart LR`n   ```````n" }
    ) {
        Set-Content -Path $script:diagram -Value $Text

        Get-Message -Path $script:diagram | Should -BeNullOrEmpty
    }

    # Each case is one the outcome depends on: a fence read the wrong way gives a different answer (review 2).
    It 'reads <Description>' -ForEach @(
        @{ Description = 'a three-backtick line inside a four-backtick fence as text'; Text = "````````mermaid`n```````nflowchart LR`n`````````n"; Expected = $null }
        @{ Description = 'a tilde line inside a backtick fence as text'; Text = "``````mermaid`n~~~`nflowchart LR`n```````n"; Expected = $null }
        @{ Description = 'a fence line with text after it as text, not a close'; Text = "``````mermaid`n``````  text`nflowchart LR`n```````n"; Expected = $null }
        @{ Description = 'an unclosed Mermaid fence as running to the end of the page'; Text = "``````mermaid`nflowchart LR`n  A --> B`n"; Expected = $null }
        @{ Description = 'Mermaid in capitals as another language'; Text = "``````Mermaid`nflowchart LR`n```````n"; Expected = 'no ```mermaid code block' }
        @{ Description = 'mermaidx as another language'; Text = "``````mermaidx`nflowchart LR`n```````n"; Expected = 'no ```mermaid code block' }
        @{ Description = 'a backtick line with a backtick in its info string as text, not a fence'; Text = "``````mermaid ``x```n flowchart LR`n```````n"; Expected = 'no ```mermaid code block' }
        @{ Description = 'a tilde fence with a backtick in its info string as a fence'; Text = "~~~mermaid ``x```n flowchart LR`n~~~`n"; Expected = $null }
        @{ Description = 'a fence line indented four spaces inside a fence as text, not a close'; Text = "``````mermaid`n    ```````n flowchart LR`n```````n"; Expected = $null }
    ) {
        Set-Content -Path $script:diagram -Value $Text

        Get-Message -Path $script:diagram | Should -Be $Expected
    }

    It 'closes a fence on a CRLF line, so an empty block followed by text is still empty' {
        [IO.File]::WriteAllText($script:diagram, "``````mermaid`r`n`r`n```````r`nThe modules are below.`r`n")

        Get-Message -Path $script:diagram | Should -Be 'the ```mermaid code block is empty'
    }

    It 'doesn''t read a line indented four spaces as a fence: it''s an indented code block' {
        Set-Content -Path $script:diagram -Value "    ``````mermaid`n    flowchart LR`n    ```````n"

        Get-Message -Path $script:diagram | Should -Be 'no ```mermaid code block'
    }

    It 'passes when any Mermaid block has a diagram, not only the first' {
        Set-Content -Path $script:diagram -Value "``````mermaid`n```````n`n``````mermaid`nflowchart LR`n  A --> B`n```````n"

        Get-Message -Path $script:diagram | Should -BeNullOrEmpty
    }

    It 'fails when the path is a folder, not a page' {
        Get-Message -Path $TestDrive | Should -Be "no architecture diagram at $TestDrive"
    }

    It 'returns 0 for a page that passes and 1 for one that fails, as a script' {
        Set-Content -Path $script:diagram -Value "``````mermaid`nflowchart LR`n  A --> B`n```````n"
        $script = Join-Path $PSScriptRoot '..' 'Test-ArchitectureDiagram.ps1'

        & pwsh -NoProfile -File $script -Path $script:diagram *> $null
        $LASTEXITCODE | Should -Be 0
        & pwsh -NoProfile -File $script -Path (Join-Path $TestDrive 'missing.md') *> $null
        $LASTEXITCODE | Should -Be 1
    }
}
