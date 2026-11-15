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

    It 'returns 0 for a page that passes and 1 for one that fails, as a script' {
        Set-Content -Path $script:diagram -Value "``````mermaid`nflowchart LR`n  A --> B`n```````n"
        $script = Join-Path $PSScriptRoot '..' 'Test-ArchitectureDiagram.ps1'

        & pwsh -NoProfile -File $script -Path $script:diagram *> $null
        $LASTEXITCODE | Should -Be 0
        & pwsh -NoProfile -File $script -Path (Join-Path $TestDrive 'missing.md') *> $null
        $LASTEXITCODE | Should -Be 1
    }
}
