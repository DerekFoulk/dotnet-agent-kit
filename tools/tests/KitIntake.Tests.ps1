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
    BeforeAll { Import-Module (Join-Path $root 'tools' 'KitIntake.psm1') -Force }

    # The guide holds the database options' prices and trade-offs (CRF-003); the card names the same options.
    It 'names each database option as docs/database-guide.md does' {
        $guide = Get-Content -Raw -LiteralPath (Join-Path $root 'docs' 'database-guide.md')
        $card = $intake['cards'] | Where-Object { $_['id'] -eq 'database' }
        $card['prices'] | Should -Be 'docs/database-guide.md'
        foreach ($option in $card['options'] | Where-Object { $_['id'] -ne 'none' }) {
            $guide | Should -Match ([regex]::Escape($option['label'])) -Because "the guide lists $($option['label'])"
        }
    }
    # ADR-0070: an app gets the guide but not templates/app-intake.json, so the guide labels its recommendations too,
    # and this keeps them the same as the intake's (CRF-003).
    It 'labels each database recommendation as the intake does: the authority''s page and the agent''s pick' {
        $guide = Get-Content -Raw -LiteralPath (Join-Path $root 'docs' 'database-guide.md')
        $card = @($intake['cards'] | Where-Object { $_['id'] -eq 'database' })[0]
        foreach ($answer in $card['recommendation'].Keys) {
            $recommendation = $card['recommendation'][$answer]
            $label = @($card['options'] | Where-Object { $_['id'] -eq $recommendation['agent']['pick'] })[0]['label']
            $guide | Should -Match ([regex]::Escape($recommendation['authority']['source'])) -Because "the guide links the page Microsoft's recommendation for $answer data comes from"
            $guide | Should -Match "\*\*$([regex]::Escape($label))\*\* \(the agent's recommendation\)" -Because "the guide labels $label as the agent's pick for $answer data"
        }
    }
    It 'exists as templates/app-intake.json' {
        Test-Path -LiteralPath $intakePath | Should -BeTrue
    }

    # ARC-012, the cost rule (owner, 2026-11-12): the intake asks a monthly budget, and it's $0 when unanswered, so
    # the defaults stay free unless the owner sets a budget.
    It 'asks for a monthly budget, $0 first and by default' {
        $budget = @($intake['cards'] | Where-Object id -EQ 'budget')
        $budget.Count | Should -Be 1 -Because 'the intake asks for a budget'
        $budget[0]['options'][0]['id'] | Should -Be 'budget-0' -Because '$0 is the recommendation, listed first'
        $budget[0]['default'] | Should -Be 'budget-0' -Because 'an unanswered budget is $0'
    }

    # The agent shows each card with AskUserQuestion: a header of at most 12 characters, a question, and 2 to 4
    # options, the recommended one first (COM-001). A card that depends on another shows only the options that
    # fit that card's answer, so each such subset has to fit too, with at least one option.
    It 'has cards that AskUserQuestion can show' {
        $intake | Should -Not -BeNullOrEmpty -Because 'templates/app-intake.json holds the cards'
        @($intake['cards'].id) | Should -Be @('appType', 'data', 'database', 'signIn', 'hosting', 'budget')
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

    # One list of test tools (TST-007, CRF-003): TST-005 points to this list and keeps none of its own, and each tool
    # ADR-0003 adds has to be in it, so they can't drift apart (rules audit, D2).
    It 'lists every kind of test TST-003 names, and every tool ADR-0003 adds; TST-005 points here' {
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

        $toolset = ($rules | Where-Object id -EQ 'TST-005')['statement']
        $toolset | Should -Match ([regex]::Escape('templates/app-intake.json')) -Because 'TST-005 points to the one list'
        foreach ($tool in @($tools | ForEach-Object { $_['name'] })) {
            $toolset | Should -Not -Match "\b$([regex]::Escape($tool))\b" -Because "TST-005 keeps no copy of the list, such as $tool"
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
        # its guide (prices). On the other cards an option costs nothing in itself, unless it says otherwise: a MAUI app
        # builds on Windows and macOS runners too, which a private repo pays for (ADR-0059).
        $pricedCards = @($intake['cards'] | Where-Object { $_['priced'] })
        @($pricedCards.id) | Should -Be @('signIn', 'hosting')
        $pricedOptions = @($intake['cards'] | Where-Object { -not $_['priced'] } | ForEach-Object { $_['options'] } | Where-Object { $_.Contains('cost') })
        @($pricedOptions.id) | Should -Be @('maui')
        $maui = $pricedOptions[0]['cost']
        $maui['label'] | Should -Be 'Free tier'
        $maui['free'] | Should -Match 'public'
        $maui['price'] | Should -Match 'macOS'
        $priced = @($pricedCards | ForEach-Object { $_['options'] }) + $pricedOptions +
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
            $card['recommendation'] | Should -Not -BeNullOrEmpty -Because "card $($card['id']) has a recommendation"
            $pick = @($card['options'] | Where-Object id -EQ $card['recommendation']['agent']['pick'])
            $pick[0]['cost']['label'] | Should -BeIn @('Free', 'Free tier') -Because "card $($card['id'])'s agent recommendation costs nothing up to its free amount"
        }
        foreach ($kind in $intake['testKinds']) {
            $kind['tools'] | ForEach-Object { $_['license'] | Should -Not -BeNullOrEmpty -Because "$($_['id']) names its license" }
            # The agent's pick is the default when neither the developer nor the authority has one, so it's free.
            $kind['roles'] | Should -Not -BeNullOrEmpty -Because "the $($kind['id']) kind lists the roles its tools fill"
            foreach ($role in $kind['roles']) {
                $pick = @($kind['tools'] | Where-Object id -EQ $role['recommendation']['agent']['pick'])
                $pick[0]['cost']['label'] | Should -Be 'Free' -Because "$($kind['id'])/$($role['id'])'s agent pick, $($pick[0]['id']), is a default for anyone, so it's free"
            }
        }
    }

    # ADR-0070: every card and every role names the authority's recommendation (or that it has none) and the agent's.
    It 'gives every card and every test tool role both labeled sources' {
        @($intake['testKinds'] | Where-Object { -not $_['roles'] } | ForEach-Object { $_['id'] }) | Should -BeNullOrEmpty -Because 'every kind of test lists its roles'
        @(Test-KitIntakeSource -Intake $intake) | Should -BeNullOrEmpty
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
    It 'offers load testing as the owner decided: Locust as the agent''s pick, JMeter beside it, Azure Load Testing and NBomber as Paid' {
        $kind = @($intake['testKinds'] | Where-Object id -EQ 'load')[0]
        $load = $kind['tools']
        $kind['roles'] | Should -Not -BeNullOrEmpty -Because 'load tests list the role Locust fills'
        @($kind['roles'] | ForEach-Object { $_['recommendation']['agent']['pick'] }) | Should -Be @('locust')
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

    # ADR-0061 (GAP-004): the shared CI runs every browser test on every PR, hosting the app with WebApplicationFactory
    # on Kestrel; Aspire testing is for an app that has an Aspire AppHost, so it isn't a default for every app. The axe
    # package itself is MIT; its axe-core engine (Deque.AxeCore.Commons) is MPL-2.0.
    It 'runs UI tests on every PR, with Playwright, axe and WebApplicationFactory by default, and names axe''s licenses' {
        $ui = @($intake['testKinds'] | Where-Object id -EQ 'ui')[0]
        $ui['runs'] | Should -Be 'Every PR, in the shared .NET CI'
        $ui['roles'] | Should -Not -BeNullOrEmpty -Because 'UI tests list the roles their tools fill'
        @($ui['roles'] | ForEach-Object { $_['recommendation']['agent']['pick'] }) | Should -Be @('playwright', 'axe', 'webapplicationfactory')
        $byId = @{}; $ui['tools'] | ForEach-Object { $byId[$_['id']] = $_ }
        $byId['webapplicationfactory']['package'] | Should -Be 'Microsoft.AspNetCore.Mvc.Testing'
        $byId['webapplicationfactory']['note'] | Should -Match 'Kestrel'
        $byId['aspire-testing']['note'] | Should -Match 'AppHost'
        $byId['axe']['license'] | Should -Be 'MIT'
        $byId['axe']['note'] | Should -Match 'Deque\.AxeCore\.Commons.*MPL-2\.0'
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

        @($resolved.Cards.Id) | Should -Be @('appType', 'data', 'database', 'signIn', 'hosting', 'budget')
        ($resolved.Cards | Where-Object Id -EQ 'database').Option['label'] | Should -Be 'Azure SQL Database, free offer'
        ($resolved.Cards | Where-Object Id -EQ 'hosting').Option['id'] | Should -Be 'none'
        @($resolved.TestKinds.Kind | ForEach-Object { $_['id'] }) | Should -Be @($intake['testKinds'].id)
        @(($resolved.TestKinds | Where-Object { $_.Kind['id'] -eq 'load' }).Tools | ForEach-Object { $_['id'] }) | Should -Be @('locust')
        # One tool for each role; with no developer file, the agent picks AwesomeAssertions, free for any app (ADR-0070).
        @(($resolved.TestKinds | Where-Object { $_.Kind['id'] -eq 'unit' }).Tools | ForEach-Object { $_['id'] }) |
            Should -Be @('xunit', 'moq', 'awesomeassertions', 'bogus', 'fscheck', 'faketimeprovider', 'fakelogger')
    }

    # ARC-012 starts every tool on its free option, so an authority's pick that's Paid is listed but never the
    # default by itself (ADR-0070).
    It 'skips an authority pick that''s Paid, so an unanswered kind of test starts free' {
        $paid = $intake | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        @($paid['testKinds'] | Where-Object { $_['id'] -eq 'load' })[0]['roles'][0]['recommendation']['authority']['pick'] = 'azure-load-testing'

        $resolved = Resolve-KitIntakeAnswer -Intake $paid -Answers (New-Answer)

        @(($resolved.TestKinds | Where-Object { $_.Kind['id'] -eq 'load' }).Tools | ForEach-Object { $_['id'] }) | Should -Be @('locust')
    }

    # Checked before New-KitApp changes anything, so a wrong answer leaves nothing behind.
    It 'refuses <Case>, naming the card and what it accepts' -ForEach @(
        @{ Case = 'a missing card'; Change = { param($a) $a.Remove('hosting') }; Message = "*no answer for 'hosting'*none, container-apps, app-service*" }
        @{ Case = 'an answer that isn''t text'; Change = { param($a) $a['hosting'] = @('none') }; Message = "*no answer for 'hosting'*" }
        @{ Case = 'an unknown card'; Change = { param($a) $a['colour'] = 'blue' }; Message = "*'colour', which isn't an intake card*appType, data, database, signIn, hosting, budget, testTools*" }
        @{ Case = 'an unknown option'; Change = { param($a) $a['signIn'] = 'okta' }; Message = "*'okta' isn't an option of the 'signIn' card*entra-external-id, entra-id, none*Other: <text>*" }
        @{ Case = 'an option in the wrong case'; Change = { param($a) $a['hosting'] = 'NONE' }; Message = "*'NONE' isn't an option of the 'hosting' card*" }
    ) {
        $answers = New-Answer
        & $Change $answers
        { Resolve-KitIntakeAnswer -Intake $intake -Answers $answers } | Should -Throw $Message
    }

    # The skill's example answers leave the budget out: a card with a default takes it when unanswered (ARC-012).
    It 'gives an unanswered budget its default, $0' {
        $resolved = Resolve-KitIntakeAnswer -Intake $intake -Answers (New-Answer)

        $budget = @($resolved.Cards | Where-Object Id -EQ 'budget')
        $budget.Count | Should -Be 1 -Because 'the budget card resolves even when unanswered'
        $budget[0].Option['id'] | Should -Be 'budget-0'
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

    # The database guide (ADR-0053) picks the database from where the data lives and its shape.
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
        @{ Case = 'a tool named twice'; Tools = @{ load = @('locust', 'locust') }; Message = "*names 'locust' twice for load tests*" }
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
        @{ Case = 'another schemaVersion'; Text = '{ "schemaVersion": 1, "cards": [], "testKinds": [] }'; Message = "*schemaVersion 1*reads version 2*same kit version*" }
        @{ Case = 'a schemaVersion written as text'; Text = '{ "schemaVersion": "2", "cards": [], "testKinds": [] }'; Message = "*schemaVersion 2*reads version 2*" }
        @{ Case = 'no schemaVersion'; Text = '{ "cards": [], "testKinds": [] }'; Message = "*schemaVersion none*reads version 2*" }
        @{ Case = 'text that isn''t a JSON object'; Text = '[1, 2]'; Message = "*isn't a JSON object*" }
    ) {
        { Get-KitIntake -Text $Text } | Should -Throw $Message
    }

    # ADR-0070: New-KitApp and the new-app skill both read the intake through Get-KitIntake, so a default with no
    # labeled source never reaches a new app.
    It 'refuses an intake whose defaults have no labeled source, naming each' {
        $text = '{ "schemaVersion": 2, "cards": [ { "id": "hosting", "options": [ { "id": "none" } ] } ], "testKinds": [] }'

        { Get-KitIntake -Text $text } | Should -Throw "*no labeled source*card 'hosting' has no recommendation*ADR-0070*"
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

    # An app doesn't get templates/app-intake.json (Export-KitApp leaves it out), so TST-005, which its agents read,
    # points it to the tools its profile chose (Copilot's review of PR 65).
    It 'lists the app''s test tools under the heading TST-005 points an app to' {
        Import-Module powershell-yaml
        Import-Module (Join-Path $root 'tools' 'KitFrontMatter.psm1') -Force
        $rules = (Read-FrontMatter -Path (Join-Path $root 'docs' 'standards' 'testing.md'))['rules']
        $toolset = ($rules | Where-Object id -EQ 'TST-005')['statement']

        $toolset | Should -Match ([regex]::Escape('docs/app-profile.md'))
        $profileText | Should -Match '(?m)^## Test tools$'
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

    # Copilot's review of PR #70: a budget's Other is an amount, not an unlisted technology, so it needs no ADR.
    It 'keeps an Other budget as the amount given, with no ADR' {
        $custom = [ordered]@{} + $answers
        $custom['budget'] = 'Other: $50 a month'
        $text = ConvertTo-KitAppProfile -Resolved (Resolve-KitIntakeAnswer -Intake $intake -Answers $custom) -Name 'Contoso.Orders' -KitCommit 'abc1234'

        $row = @($text -split "`n" | Where-Object { $_ -like '| How much may this app cost each month?*' })
        $row.Count | Should -Be 1
        $row[0] | Should -Match '\| \$50 a month \|'
        $row[0] | Should -Not -Match 'Needs an ADR'
    }

    # The Other text is the owner's own words, written into a Markdown table: a | or a line break would break the row.
    It 'keeps an Other answer on its own row, escaped, and says it needs an ADR' {
        $other = [ordered]@{} + $answers
        $other['hosting'] = "Other: my own server | a VPS`nin Ohio"
        $text = ConvertTo-KitAppProfile -Resolved (Resolve-KitIntakeAnswer -Intake $intake -Answers $other) -Name 'Contoso.Orders' -KitCommit 'abc1234'

        $text | Should -Match '(?m)^\| Where should it run\? \| Other: my own server \\\| a VPS in Ohio \| Needs an ADR'
    }
}
# ADR-0070 (owner, 2026-11-15): every default the intake gives names its source. The authority's recommendation is
# only what its page says, with the page and the date read (or the search that found no page); the agent's is its
# pick with a reason. A default with neither, or a pick that isn't an option, fails the check.
Describe 'Test-KitIntakeSource' {
    BeforeAll {
        Import-Module (Join-Path $root 'tools' 'KitIntake.psm1') -Force
        # The smallest intake that passes: one card and one kind of test, each with both sources.
        function New-SourcedIntake {
            $authority = @{ by = 'Microsoft'; pick = $null; says = 'No recommendation'; source = 'https://learn.microsoft.com/example'; read = '2026-11-15' }
            @{
                schemaVersion = 2
                cards = @(
                    @{ id = 'hosting'; options = @(@{ id = 'none' }, @{ id = 'app-service' })
                        recommendation = @{ authority = $authority.Clone(); agent = @{ pick = 'none'; reason = 'Nothing to pay or set up yet' } } }
                )
                testKinds = @()
            }
        }
        # The same, with a card that depends on another and a kind of test with a role.
        function New-FullSourcedIntake {
            $intake = New-SourcedIntake
            $sources = { param($pick) @{
                    authority = @{ by = 'Microsoft'; pick = $null; says = 'No recommendation'; searched = 'a query'; read = '2026-11-15' }
                    agent = @{ pick = $pick; reason = 'Free' } } }
            $intake['cards'] += @{ id = 'data'; options = @(@{ id = 'relational' }, @{ id = 'device' }); recommendation = (& $sources 'relational') }
            $intake['cards'] += @{ id = 'database'; dependsOn = 'data'
                options = @(@{ id = 'azure-sql-free'; fits = @('relational') }, @{ id = 'postgresql'; fits = @('relational') }, @{ id = 'sqlite'; fits = @('device') })
                recommendation = @{ relational = (& $sources 'azure-sql-free') } }
            $intake['testKinds'] = @(@{ id = 'load'
                    roles = @(@{ id = 'load'; name = 'Load generator'; recommendation = (& $sources 'locust') })
                    tools = @(@{ id = 'locust'; role = 'load' }, @{ id = 'jmeter'; role = 'load' }) })
            $intake
        }
    }

    It 'finds nothing wrong with a card that has both sources' {
        @(Test-KitIntakeSource -Intake (New-SourcedIntake)) | Should -BeNullOrEmpty
    }

    It 'reports <Case>' -ForEach @(
        @{ Case = 'a card with no recommendation'; Change = { param($c) $c.Remove('recommendation') }; Message = "*card 'hosting' has no recommendation*" }
        @{ Case = 'no authority'; Change = { param($c) $c['recommendation'].Remove('authority') }; Message = "*card 'hosting'*no authority*" }
        @{ Case = 'an authority with no name'; Change = { param($c) $c['recommendation']['authority'].Remove('by') }; Message = "*card 'hosting'*authority*who*" }
        @{ Case = 'an authority with no words'; Change = { param($c) $c['recommendation']['authority']['says'] = ' ' }; Message = "*card 'hosting'*authority*says*" }
        @{ Case = 'an authority with neither a page nor a search'; Change = { param($c) $c['recommendation']['authority'].Remove('source') }; Message = "*card 'hosting'*authority*https:// page*search*" }
        @{ Case = 'an authority page that isn''t a URL'; Change = { param($c) $c['recommendation']['authority']['source'] = 'Microsoft Learn' }; Message = "*card 'hosting'*authority*https:// page*" }
        @{ Case = 'an authority with no date read'; Change = { param($c) $c['recommendation']['authority']['read'] = 'last week' }; Message = "*card 'hosting'*authority*date it was read*" }
        @{ Case = 'an authority pick that isn''t an option'; Change = { param($c) $c['recommendation']['authority']['pick'] = 'aks' }; Message = "*card 'hosting'*authority picks 'aks'*isn't an option*none, app-service*" }
        @{ Case = 'no agent recommendation'; Change = { param($c) $c['recommendation'].Remove('agent') }; Message = "*card 'hosting'*no agent recommendation*" }
        @{ Case = 'an agent pick with no reason'; Change = { param($c) $c['recommendation']['agent'].Remove('reason') }; Message = "*card 'hosting'*agent*reason*" }
        @{ Case = 'an agent that picks nothing'; Change = { param($c) $c['recommendation']['agent']['pick'] = $null }; Message = "*card 'hosting'*agent picks nothing*" }
        @{ Case = 'an agent pick that isn''t an option'; Change = { param($c) $c['recommendation']['agent']['pick'] = 'aks' }; Message = "*card 'hosting'*agent picks 'aks'*isn't an option*" }
    ) {
        $intake = New-SourcedIntake
        & $Change $intake['cards'][0]

        (@(Test-KitIntakeSource -Intake $intake) -join "`n") | Should -BeLike $Message
    }

    # A kind of test fills several roles (a test framework, a mocking library...), each picked on its own. A card that
    # depends on another needs a recommendation for each answer that leaves more than one option, and a card's own
    # default for an unanswered card has to come from a rule.
    It 'reports <Case>' -ForEach @(
        @{ Case = 'a tool in no listed role'; Change = { param($i) $i['testKinds'][0]['tools'][1]['role'] = 'stress' }; Message = "*tool 'jmeter' of load tests has role 'stress', which isn't one of its roles: load*" }
        @{ Case = 'a kind of test with no roles'; Change = { param($i) $i['testKinds'][0].Remove('roles') }; Message = "*load tests list no roles*" }
        @{ Case = 'a role with no tools'; Change = { param($i) $i['testKinds'][0]['roles'] += @{ id = 'soak'; name = 'Soak'; recommendation = @{} } }; Message = "*role 'load/soak' has no tools*" }
        @{ Case = 'a role with no recommendation'; Change = { param($i) $i['testKinds'][0]['roles'][0].Remove('recommendation') }; Message = "*role 'load/load' has no recommendation*" }
        @{ Case = 'a role whose agent picks a tool outside it'; Change = { param($i) $i['testKinds'][0]['roles'][0]['recommendation']['agent']['pick'] = 'k6' }; Message = "*role 'load/load'*agent picks 'k6', which isn't an option: locust, jmeter*" }
        @{ Case = 'an answer that leaves two options with no recommendation'; Change = { param($i) $i['cards'][2]['recommendation'].Remove('relational') }; Message = "*card 'database' for data 'relational' has no recommendation*" }
        @{ Case = 'a recommendation for an answer that isn''t one'; Change = { param($i) $i['cards'][2]['recommendation']['graph'] = @{} }; Message = "*card 'database' has a recommendation for data 'graph', which isn't an option*" }
        @{ Case = 'an agent pick that doesn''t fit the answer'; Change = { param($i) $i['cards'][2]['recommendation']['relational']['agent']['pick'] = 'sqlite' }; Message = "*card 'database' for data 'relational'*agent picks 'sqlite', which isn't an option: azure-sql-free, postgresql*" }
        @{ Case = 'a card default with no rule behind it'; Change = { param($i) $i['cards'][0]['default'] = 'none' }; Message = "*card 'hosting' has a default*no defaultRule*" }
    ) {
        $intake = New-FullSourcedIntake
        & $Change $intake

        (@(Test-KitIntakeSource -Intake $intake) -join "`n") | Should -BeLike $Message
    }

    It 'finds nothing wrong with roles and a dependent card that have both sources' {
        @(Test-KitIntakeSource -Intake (New-FullSourcedIntake)) | Should -BeNullOrEmpty
    }
}

# ADR-0070: a developer's preferences live in their own file, outside every repo, each with their words, the date and
# where they said it. A new kit user has no file, and that's no preferences, not an error.
Describe 'Read-KitPreference' {
    BeforeAll {
        Import-Module (Join-Path $root 'tools' 'KitIntake.psm1') -Force
        # Writes a preferences file with the given entries and returns its path.
        function New-PreferenceFile {
            param([object[]] $Preference, [object] $Version = 1)
            $path = Join-Path $TestDrive "preferences-$([guid]::NewGuid()).json"
            @{ schemaVersion = $Version; preferences = @($Preference) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path
            $path
        }
        $budget = @{ choice = 'budget'; pick = 'budget-0'; stated = 'A $0 budget unless I say otherwise'; date = '2026-11-12'; source = 'ARC-012' }
    }

    It 'lives in the developer''s home folder, outside every repo' {
        Get-KitPreferencePath | Should -Be (Join-Path $HOME '.dotnet-agent-kit' 'preferences.json')
    }

    It 'reads no preferences when the developer has no file' {
        @(Read-KitPreference -Path (Join-Path $TestDrive 'none.json')) | Should -BeNullOrEmpty
    }

    It 'reads each preference with its words, date and source' {
        $general = @{ stated = 'EF Core with code-first migrations'; date = '2026-11-10'; source = 'ADR-0053' }
        $read = @(Read-KitPreference -Path (New-PreferenceFile -Preference $budget, $general))

        $read.Count | Should -Be 2
        $read[0].Choice | Should -Be 'budget'
        $read[0].Pick | Should -Be 'budget-0'
        $read[0].Stated | Should -Be 'A $0 budget unless I say otherwise'
        $read[0].Date | Should -Be '2026-11-12'
        $read[0].Source | Should -Be 'ARC-012'
        $read[1].Choice | Should -BeNullOrEmpty -Because 'a preference with no choice is for plans, not the intake'
    }

    It 'refuses <Case>, naming the file' -ForEach @(
        @{ Case = 'a preference with no words'; Entry = @{ choice = 'budget'; pick = 'budget-0'; date = '2026-11-12'; source = 'ARC-012' }; Message = "*preferences-*.json*preference 1*stated*" }
        @{ Case = 'a preference with no date'; Entry = @{ stated = 'Locust'; source = 'chat' }; Message = "*preference 1*date*yyyy-mm-dd*" }
        @{ Case = 'a date that isn''t a date'; Entry = @{ stated = 'Locust'; date = 'yesterday'; source = 'chat' }; Message = "*preference 1*date*yyyy-mm-dd*" }
        @{ Case = 'a preference with no source'; Entry = @{ stated = 'Locust'; date = '2026-11-12' }; Message = "*preference 1*source*" }
        @{ Case = 'a choice with no pick'; Entry = @{ choice = 'load/load'; stated = 'Locust'; date = '2026-11-12'; source = 'chat' }; Message = "*preference 1*choice 'load/load'*no pick*" }
    ) {
        { Read-KitPreference -Path (New-PreferenceFile -Preference $Entry) } | Should -Throw $Message
    }

    It 'refuses two preferences for the same question' {
        $again = @{ choice = 'budget'; pick = 'budget-20'; stated = 'Up to $20'; date = '2026-11-14'; source = 'chat' }

        { Read-KitPreference -Path (New-PreferenceFile -Preference $budget, $again) } | Should -Throw "*two preferences for 'budget'*keep one*"
    }

    It 'refuses <Case>' -ForEach @(
        @{ Case = 'a file that isn''t JSON'; Text = 'not json'; Message = "*preferences.json*isn't valid JSON*" }
        @{ Case = 'another schemaVersion'; Text = '{ "schemaVersion": 2, "preferences": [] }'; Message = "*schemaVersion 2*reads version 1*" }
    ) {
        $path = Join-Path $TestDrive 'preferences.json'
        Set-Content -LiteralPath $path -Value $Text

        { Read-KitPreference -Path $path } | Should -Throw $Message
    }
}

# ADR-0070: the new-app skill shows, for each question and each test tool role, the default and where it came from,
# with all three sources side by side: the developer's preference first, then the authority's pick, then the agent's.
Describe 'Get-KitIntakeDefault' {
    BeforeAll {
        Import-Module (Join-Path $root 'tools' 'KitIntake.psm1') -Force
        # A preference as Read-KitPreference returns it.
        function New-Preference {
            param([string] $Choice, [string] $Pick, [string] $When)
            [pscustomobject]@{ Choice = $Choice; When = $When; Pick = $Pick; Stated = "I want $Pick"; Date = '2026-11-15'; Source = 'said in chat' }
        }
        # The row for one question, or for one answer of a card that depends on another.
        function Get-Row {
            param([object[]] $Rows, [string] $Choice, [string] $When)
            @($Rows | Where-Object { $_.Choice -eq $Choice -and "$($_.When)" -eq $When })[0]
        }
        $kitDefaults = @(Get-KitIntakeDefault -Intake $intake)
    }

    It 'gives the agent''s pick, labeled, where the authority names none' {
        $row = Get-Row $kitDefaults 'appType'

        $row.Pick | Should -Be 'web-api-blazor'
        $row.From | Should -Be 'agent'
        $row.Agent['reason'] | Should -Not -BeNullOrEmpty
        $row.Authority['pick'] | Should -BeNullOrEmpty -Because 'Microsoft names no app type'
        $row.Developer | Should -BeNullOrEmpty
    }

    It 'gives the authority''s pick where it names one' {
        $row = Get-Row $kitDefaults 'unit/time'

        $row.Pick | Should -Be 'faketimeprovider'
        $row.From | Should -Be 'authority'
        $row.Authority['source'] | Should -Match '^https://learn\.microsoft\.com/'
    }

    It 'gives a row for each data answer, and says when only one database fits' {
        (Get-Row $kitDefaults 'database' 'relational').From | Should -Be 'agent'
        $documents = Get-Row $kitDefaults 'database' 'documents'
        $documents.Pick | Should -Be 'cosmos-free'
        $documents.From | Should -Be 'only option'
    }

    It 'puts the developer''s preference first, with their words and date' {
        $rows = @(Get-KitIntakeDefault -Intake $intake -Preference (New-Preference 'unit/time' 'faketimeprovider'), (New-Preference 'database' 'postgresql' 'relational'))

        $time = Get-Row $rows 'unit/time'
        $time.From | Should -Be 'developer'
        $time.Developer.Stated | Should -Be 'I want faketimeprovider'
        $relational = Get-Row $rows 'database' 'relational'
        $relational.Pick | Should -Be 'postgresql'
        $relational.From | Should -Be 'developer'
    }

    It 'skips a preference that isn''t an option any more, and says so' {
        $row = Get-Row @(Get-KitIntakeDefault -Intake $intake -Preference (New-Preference 'load/load' 'k6')) 'load/load'

        $row.Pick | Should -Be 'locust'
        $row.From | Should -Be 'agent'
        ($row.Notes -join ' ') | Should -Match "'k6'.*isn't an option"
    }

    It 'leaves out a preference that answers no intake question' {
        $plan = [pscustomobject]@{ Choice = $null; When = $null; Pick = $null; Stated = 'EF Core'; Date = '2026-11-10'; Source = 'ADR-0053' }

        @(Get-KitIntakeDefault -Intake $intake -Preference $plan).Count | Should -Be $kitDefaults.Count
    }
}
