#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The kit's web UI fixture (fixtures/WebUi, ADR-0061) runs axe with the WCAG tags UI-002 names. The rule is the one
# source for that list (CRF-003): the fixture's Wcag.cs, which apps copy, must run exactly those tags.

Describe 'The web UI fixture''s accessibility check' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        Import-Module (Join-Path $root 'tools' 'KitFrontMatter.psm1') -Force
    }

    It 'runs exactly the WCAG tags UI-002 names' {
        $rules = (Read-FrontMatter -Path (Join-Path $root 'docs' 'standards' 'ui.md'))['rules']
        $statement = @($rules | Where-Object { $_['id'] -eq 'UI-002' })[0]['statement']
        $named = @([regex]::Matches($statement, '\bwcag\w+') | ForEach-Object Value)
        $code = Get-Content -Raw -LiteralPath (Join-Path $root 'fixtures' 'WebUi' 'tests' 'Kit.WebUi.E2E.Tests' 'Wcag.cs')
        $values = [regex]::Match($code, 'Values = \[(?<tags>[^\]]*)\]').Groups['tags'].Value
        $run = @([regex]::Matches($values, '"(?<tag>[^"]+)"') | ForEach-Object { $_.Groups['tag'].Value })

        $named | Should -Not -BeNullOrEmpty -Because 'UI-002 names the tags'
        $run | Should -Be $named -Because 'Wcag.cs runs the tags UI-002 names, in the same order'
        $code | Should -Match 'Type = "tag"' -Because 'the values are tags, not rule ids'
    }
}
