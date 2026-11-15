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
