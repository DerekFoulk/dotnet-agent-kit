#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The new-app intake (ADR-0058): templates/app-intake.json holds the question cards and the test tools, and
# tools/KitIntake.psm1 checks a set of answers against it and writes the app's docs/app-profile.md.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $intakePath = Join-Path $root 'templates' 'app-intake.json'
    $intake = if (Test-Path -LiteralPath $intakePath) { Get-Content -Raw -LiteralPath $intakePath | ConvertFrom-Json -AsHashtable }
}

Describe 'the intake data' {
    It 'exists as templates/app-intake.json' {
        Test-Path -LiteralPath $intakePath | Should -BeTrue
    }

    # The agent shows each card with AskUserQuestion: a header of at most 12 characters, a question, and 2 to 4
    # options, the recommended one first (COM-001). A card that depends on another shows only the options that
    # fit that card's answer, so each such subset has to fit too, with at least one option.
    It 'has cards that AskUserQuestion can show, each with its recommended option first' {
        $intake | Should -Not -BeNullOrEmpty -Because 'templates/app-intake.json holds the cards'
        @($intake['cards'].id) | Should -Be @('appType', 'data', 'database', 'signIn', 'hosting')
        foreach ($card in $intake['cards']) {
            $card['header'].Length | Should -BeLessOrEqual 12 -Because "card $($card['id'])'s header is a chip of 12 characters at most"
            $card['question'] | Should -Match '\?$' -Because "card $($card['id']) asks a question"
            $ids = @($card['options'].id)
            $ids | Should -Be @($ids | Select-Object -Unique) -Because "card $($card['id'])'s option ids are unique"
            foreach ($option in $card['options']) {
                $option['label'] | Should -Not -BeNullOrEmpty
                $option['label'].Length | Should -BeLessOrEqual 40 -Because "option $($option['id']) is a short label"
                $option['description'] | Should -Not -BeNullOrEmpty
            }
            if ($card.Contains('dependsOn')) {
                $parent = $intake['cards'] | Where-Object id -EQ $card['dependsOn']
                foreach ($parentOption in $parent['options']) {
                    $fitting = @($card['options'] | Where-Object { $parentOption['id'] -in $_['fits'] })
                    $fitting.Count | Should -BeIn 1..4 -Because "$($card['id']) offers 1 to 4 options for $($card['dependsOn']) = $($parentOption['id'])"
                }
            }
            else {
                $ids.Count | Should -BeIn 2..4 -Because "card $($card['id']) has 2 to 4 options"
            }
        }
    }
}
