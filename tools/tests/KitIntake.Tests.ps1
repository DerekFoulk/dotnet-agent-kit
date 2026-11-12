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
    BeforeDiscovery {
        # docs/database-guide.md (ADR-0052) comes from another branch; this check starts once it's on main.
        $hasGuide = Test-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..' 'docs' 'database-guide.md')
    }

    # The guide holds the database options' prices and trade-offs (CRF-003); the card names the same options.
    It 'names each database option as docs/database-guide.md does' -Skip:(-not $hasGuide) {
        $guide = Get-Content -Raw -LiteralPath (Join-Path $root 'docs' 'database-guide.md')
        $card = $intake['cards'] | Where-Object { $_['id'] -eq 'database' }
        $card['prices'] | Should -Be 'docs/database-guide.md'
        foreach ($option in $card['options'] | Where-Object { $_['id'] -ne 'none' }) {
            $guide | Should -Match ([regex]::Escape($option['label'])) -Because "the guide lists $($option['label'])"
        }
    }
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

    # ADR-0004: FluentAssertions 8 is free only while the app isn't sold or paid for. A commercial app swaps it for
    # AwesomeAssertions, so the card has to say so rather than call it Free.
    It 'labels FluentAssertions 8 free for non-commercial use only, with its commercial price and AwesomeAssertions beside it' {
        $unit = @($intake['testKinds'] | Where-Object id -EQ 'unit')[0]['tools']
        $fluent = @($unit | Where-Object id -EQ 'fluentassertions')[0]
        $fluent['cost']['label'] | Should -Be 'Free tier'
        $fluent['cost']['free'] | Should -BeLike 'Non-commercial use*'
        $fluent['cost']['price'] | Should -Match 'commercial'
        $awesome = @($unit | Where-Object id -EQ 'awesomeassertions')[0]
        $awesome['cost']['label'] | Should -Be 'Free'
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

    # AskUserQuestion always offers "Other". An answer that isn't a kit option is kept in the owner's words, and the
    # profile says it needs an ADR before anything is built on it.
    It 'keeps an Other answer in the owner''s words' {
        $answers = New-Answer
        $answers['database'] = 'Other:  MongoDB Atlas '
        { $script:resolved = Resolve-KitIntakeAnswer -Intake $intake -Answers $answers } | Should -Not -Throw
        $card = $script:resolved.Cards | Where-Object Id -EQ 'database'

        $card.Option | Should -BeNullOrEmpty
        $card.Other | Should -Be 'MongoDB Atlas'
    }

    # The database guide (ADR-0052) picks the database from where the data lives and its shape.
    It 'refuses a database that doesn''t fit the data answer, naming the ones that do' {
        $answers = New-Answer
        $answers['database'] = 'sqlite'
        { Resolve-KitIntakeAnswer -Intake $intake -Answers $answers } | Should -Throw "*'sqlite' doesn't fit data 'relational'*azure-sql-free, postgresql*"
    }

    It 'checks no fit when either answer is Other' {
        $answers = New-Answer
        $answers['data'] = 'Other: a graph of friends'
        { Resolve-KitIntakeAnswer -Intake $intake -Answers $answers } | Should -Not -Throw
    }

    It 'uses exactly the tools named for a kind of test, in place of its defaults' {
        $answers = New-Answer
        $answers['testTools'] = @{ load = @('jmeter', 'azure-load-testing') }
        { $script:resolved = Resolve-KitIntakeAnswer -Intake $intake -Answers $answers } | Should -Not -Throw

        @(($script:resolved.TestKinds | Where-Object { $_.Kind['id'] -eq 'load' }).Tools | ForEach-Object { $_['id'] }) | Should -Be @('jmeter', 'azure-load-testing')
        @(($script:resolved.TestKinds | Where-Object { $_.Kind['id'] -eq 'unit' }).Tools | ForEach-Object { $_['id'] }) | Should -Contain 'xunit'
    }

    # A tool that isn't on the list needs an ADR (TST-005), so it can't come in through the intake.
    It 'refuses test tools for <Case>' -ForEach @(
        @{ Case = 'an unknown kind of test'; Tools = @{ soak = @('locust') }; Message = "*'soak', which isn't a kind of test*unit, integration*" }
        @{ Case = 'an unknown tool'; Tools = @{ load = @('k6') }; Message = "*'k6' isn't on the kit's list for load tests*locust, jmeter, azure-load-testing, nbomber*ADR*" }
        @{ Case = 'an empty list'; Tools = @{ load = @() }; Message = "*no tools for load tests*" }
        @{ Case = 'testTools that isn''t a map'; Tools = 'locust'; Message = "*testTools*map*" }
    ) {
        $answers = New-Answer
        $answers['testTools'] = $Tools
        { Resolve-KitIntakeAnswer -Intake $intake -Answers $answers } | Should -Throw $Message
    }
}

# New-KitApp reads templates/app-intake.json from the kit at -KitRef but runs this module from the current kit, so
# a file laid out for another version of the module is refused rather than misread.
Describe 'Get-KitIntake' {
    BeforeAll { Import-Module (Join-Path $root 'tools' 'KitIntake.psm1') -Force }

    It 'reads the kit''s own intake file' {
        { $script:read = Get-KitIntake -Text (Get-Content -Raw -LiteralPath $intakePath) } | Should -Not -Throw
        $script:read | Should -Not -BeNullOrEmpty
        @($script:read['cards'] | ForEach-Object { $_['id'] }) | Should -Contain 'appType'
    }

    It 'refuses <Case>' -ForEach @(
        @{ Case = 'another schemaVersion'; Text = '{ "schemaVersion": 2, "cards": [], "testKinds": [] }'; Message = "*schemaVersion 2*reads version 1*same kit version*" }
        @{ Case = 'no schemaVersion'; Text = '{ "cards": [], "testKinds": [] }'; Message = "*schemaVersion none*reads version 1*" }
        @{ Case = 'text that isn''t a JSON object'; Text = '[1, 2]'; Message = "*isn't a JSON object*" }
    ) {
        { Get-KitIntake -Text $Text } | Should -Throw $Message
    }
}

Describe 'ConvertTo-KitAppProfile' {
    BeforeAll {
        Import-Module (Join-Path $root 'tools' 'KitIntake.psm1') -Force
        $answers = [ordered]@{ appType = 'web-api-blazor'; data = 'relational'; database = 'azure-sql-free'; signIn = 'entra-external-id'; hosting = 'none'
            testTools = @{ load = @('azure-load-testing') } }
        $resolved = Resolve-KitIntakeAnswer -Intake $intake -Answers $answers
        $profileText = ConvertTo-KitAppProfile -Resolved $resolved -Name 'Contoso.Orders' -KitCommit 'abc1234'
    }

    It 'names the app and the kit commit it was chosen from' {
        $profileText | Should -Match '^# App profile: Contoso\.Orders\r?\n'
        $profileText | Should -Match 'abc1234'
    }

    It 'has a row for every card: its question, the answer, and what it costs' {
        foreach ($card in $resolved.Cards) {
            $profileText | Should -Match "(?m)^\| $([regex]::Escape($card.Card['question'])) \| $([regex]::Escape($card.Option['label'])) \|"
        }
        $profileText | Should -Match '(?m)^\| Who signs in to the app\? \| Customers or the public \| Free tier: The first 50,000 monthly active users'
        $profileText | Should -Match 'https://github\.com/DerekFoulk/dotnet-agent-kit/blob/abc1234/docs/database-guide\.md' -Because 'the database prices are in the guide'
    }

    It 'lists each kind of test with its tools, licenses and labels, and the price of a paid one' {
        foreach ($kind in $resolved.TestKinds) {
            $profileText | Should -Match "(?m)^\| $([regex]::Escape($kind.Kind['name'])) \|"
        }
        $profileText | Should -Match 'xUnit v3 \(Apache-2\.0, Free\)'
        $profileText | Should -Match 'Azure Load Testing \(Microsoft Azure service, Paid: East US: \$10 per resource per month'
        $profileText | Should -Match 'checked 2026-11-11'
    }

    # The Other text is the owner's own words, written into a Markdown table: a | or a line break would break the row.
    It 'keeps an Other answer on its own row, escaped, and says it needs an ADR' {
        $other = [ordered]@{} + $answers
        $other['hosting'] = "Other: my own server | a VPS`nin Ohio"
        $text = ConvertTo-KitAppProfile -Resolved (Resolve-KitIntakeAnswer -Intake $intake -Answers $other) -Name 'Contoso.Orders' -KitCommit 'abc1234'

        $text | Should -Match '(?m)^\| Where should it run\? \| Other: my own server \\\| a VPS in Ohio \| Needs an ADR'
    }
}