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
                    $fitting.Count | Should -BeIn @(1, 2, 3, 4) -Because "$($card['id']) offers 1 to 4 options for $($card['dependsOn']) = $($parentOption['id'])"
                }
            }
            else {
                $ids.Count | Should -BeIn @(2, 3, 4) -Because "card $($card['id']) has 2 to 4 options"
            }
        }
    }

    # One list of test tools (TST-007, CRF-003): the testing standard and ADR-0003 name tools, and each one they
    # name has to be in this list, so the two can't drift apart.
    It 'lists every kind of test TST-003 names, and every tool TST-005 and ADR-0003 name' {
        Import-Module powershell-yaml
        Import-Module (Join-Path $root 'tools' 'KitFrontMatter.psm1') -Force
        $rules = (Read-FrontMatter -Path (Join-Path $root 'docs' 'standards' 'testing.md'))['rules']
        $kinds = @($intake['testKinds'])
        $kinds | Should -Not -BeNullOrEmpty -Because 'templates/app-intake.json lists the test kinds'
        $tools = @($kinds | ForEach-Object { $_['tools'] })

        $matrix = [regex]::Match(($rules | Where-Object id -EQ 'TST-003')['statement'], '\(([^)]+)\)').Groups[1].Value
        foreach ($kind in $matrix -split ',\s*') {
            @($kinds.id) | Should -Contain $kind.ToLowerInvariant() -Because "TST-003's matrix has $kind tests"
        }

        $named = [regex]::Match(($rules | Where-Object id -EQ 'TST-005')['statement'], '\(([^)]+)\)').Groups[1].Value -replace '\s+and the ADR-0003 additions$', ''
        foreach ($name in $named -split ',\s*') {
            @($tools | Where-Object { $_['name'] -like "$name*" }) | Should -Not -BeNullOrEmpty -Because "TST-005 names $name"
        }

        # ADR-0003's "Added:" line names each tool by its package, in backticks, or by its name.
        $added = [regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $root 'docs' 'adr' '0003-test-toolset.md')), '(?m)^- Added: (.+)$').Groups[1].Value
        $added | Should -Not -BeNullOrEmpty
        foreach ($item in $added.TrimEnd().TrimEnd('.') -split ',\s*') {
            $names = if ($item -match '`') { [regex]::Matches($item, '`([^`]+)`').ForEach({ $_.Groups[1].Value }) } else { @($item.Trim()) }
            foreach ($name in $names) {
                @($tools | Where-Object { $_['name'] -eq $name -or $_['package'] -eq $name }) | Should -Not -BeNullOrEmpty -Because "ADR-0003 adds $name"
            }
        }
    }

    # The owner, 2026-11-11: every option says what it costs, paid ones stay on the list, and the defaults are free.
    It 'labels every tool and priced option Free, Free tier or Paid, with a price, source and date unless Free, and makes every default Free' {
        # A card is priced when its choice itself costs something (sign-in, hosting); the database card's prices are in
        # its guide (prices), and the app type and data cards cost nothing in themselves.
        $pricedCards = @($intake['cards'] | Where-Object { $_['priced'] })
        @($pricedCards.id) | Should -Be @('signIn', 'hosting')
        $priced = @($pricedCards | ForEach-Object { $_['options'] }) +
            @($intake['testKinds'] | ForEach-Object { $_['tools'] })
        foreach ($entry in $priced) {
            $cost = $entry['cost']
            $cost | Should -Not -BeNullOrEmpty -Because "$($entry['id']) says what it costs"
            $cost['label'] | Should -BeIn @('Free', 'Free tier', 'Paid') -Because "$($entry['id']) has a cost label"
            if ($cost['label'] -ne 'Free') {
                $cost['price'] | Should -Not -BeNullOrEmpty -Because "$($entry['id']) isn't free, so it gives a price or says 'not verified'"
                $cost['source'] | Should -Match 'https://' -Because "$($entry['id'])'s price has a source"
                $cost['checked'] | Should -Match '^\d{4}-\d{2}-\d{2}$' -Because "$($entry['id'])'s price has the date it was checked"
            }
            if ($cost['label'] -eq 'Free tier') { $cost['free'] | Should -Not -BeNullOrEmpty -Because "$($entry['id']) says what's free" }
        }
        foreach ($card in $pricedCards) {
            $card['options'][0]['cost']['label'] | Should -BeIn @('Free', 'Free tier') -Because "card $($card['id'])'s recommendation costs nothing up to its free amount"
        }
        foreach ($kind in $intake['testKinds']) {
            $kind['tools'] | ForEach-Object { $_['license'] | Should -Not -BeNullOrEmpty -Because "$($_['id']) names its license" }
            $defaults = @($kind['tools'] | Where-Object { $_['default'] })
            $defaults | Should -Not -BeNullOrEmpty -Because "the $($kind['id']) kind has a default"
            $defaults | ForEach-Object { $_['cost']['label'] | Should -Be 'Free' -Because "$($_['id']) is a default" }
        }
    }

    # ADR-0057, the owner's decision of 2026-11-11.
    It 'offers load testing as the owner decided: Locust by default, JMeter beside it, Azure Load Testing and NBomber as Paid' {
        $load = @($intake['testKinds'] | Where-Object id -EQ 'load')[0]['tools']
        @($load | Where-Object { $_['default'] }).id | Should -Be @('locust')
        $byId = @{}; $load | ForEach-Object { $byId[$_['id']] = $_ }
        $byId['locust']['license'] | Should -Be 'MIT'
        $byId['jmeter']['license'] | Should -Be 'Apache-2.0'
        $byId['jmeter']['cost']['label'] | Should -Be 'Free'
        $byId['azure-load-testing']['cost']['label'] | Should -Be 'Paid'
        $byId['azure-load-testing']['cost']['price'] | Should -Match 'virtual user hour'
        $byId['azure-load-testing']['cost']['price'] | Should -Match 'limit' -Because 'a monthly cap is available'
        $byId['nbomber']['cost']['label'] | Should -Be 'Paid'
        $byId['nbomber']['cost']['price'] | Should -Match 'organization'
    }
}

Describe 'Resolve-KitIntakeAnswer' {
    BeforeAll {
        Import-Module (Join-Path $root 'tools' 'KitIntake.psm1') -Force
        # The skill's example answers: the first option of each card, and the database that fits relational data.
        function New-Answer {
            [ordered]@{ appType = 'web-api-blazor'; data = 'relational'; database = 'azure-sql-free'; signIn = 'entra-external-id'; hosting = 'none' }
        }
    }

    It 'resolves each card to its option, and each kind of test to its default tools' {
        $resolved = Resolve-KitIntakeAnswer -Intake $intake -Answers (New-Answer)

        @($resolved.Cards.Id) | Should -Be @('appType', 'data', 'database', 'signIn', 'hosting')
        ($resolved.Cards | Where-Object Id -EQ 'database').Option['label'] | Should -Be 'Azure SQL Database, free offer'
        ($resolved.Cards | Where-Object Id -EQ 'hosting').Option['id'] | Should -Be 'none'
        @($resolved.TestKinds.Kind | ForEach-Object { $_['id'] }) | Should -Be @($intake['testKinds'].id)
        @(($resolved.TestKinds | Where-Object { $_.Kind['id'] -eq 'load' }).Tools | ForEach-Object { $_['id'] }) | Should -Be @('locust')
        @(($resolved.TestKinds | Where-Object { $_.Kind['id'] -eq 'unit' }).Tools | ForEach-Object { $_['id'] }) | Should -Not -Contain 'awesomeassertions'
    }

    # Checked before New-KitApp changes anything, so a wrong answer leaves nothing behind.
    It 'refuses <Case>, naming the card and what it accepts' -ForEach @(
        @{ Case = 'a missing card'; Change = { param($a) $a.Remove('hosting') }; Message = "*no answer for 'hosting'*none, container-apps, app-service*" }
        @{ Case = 'an answer that isn''t text'; Change = { param($a) $a['hosting'] = @('none') }; Message = "*no answer for 'hosting'*" }
        @{ Case = 'an unknown card'; Change = { param($a) $a['colour'] = 'blue' }; Message = "*'colour', which isn't an intake card*appType, data, database, signIn, hosting, testTools*" }
        @{ Case = 'an unknown option'; Change = { param($a) $a['signIn'] = 'okta' }; Message = "*'okta' isn't an option of the 'signIn' card*entra-external-id, entra-id, none*Other: <text>*" }
        @{ Case = 'an option in the wrong case'; Change = { param($a) $a['hosting'] = 'NONE' }; Message = "*'NONE' isn't an option of the 'hosting' card*" }
    ) {
        $answers = New-Answer
        & $Change $answers
        { Resolve-KitIntakeAnswer -Intake $intake -Answers $answers } | Should -Throw $Message
    }
}