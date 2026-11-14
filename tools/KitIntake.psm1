#Requires -Version 7.6
# The new-app intake (ADR-0058): reads templates/app-intake.json, checks a set of answers against it, and writes
# the app's docs/app-profile.md. New-KitApp uses it; the new-app skill writes the answers.

Set-StrictMode -Version Latest

# The layout of templates/app-intake.json this module reads. Raise it when a change to the file's layout would make
# an older module misread it.
$script:SchemaVersion = 1

# Reads templates/app-intake.json.
function Get-KitIntake {
    param([Parameter(Mandatory)] [string] $Text)

    $intake = $Text | ConvertFrom-Json -AsHashtable
    if ($intake -isnot [Collections.IDictionary]) { throw "templates/app-intake.json isn't a JSON object." }
    $version = if ($intake.Contains('schemaVersion')) { $intake['schemaVersion'] } else { 'none' }
    # A number, compared exactly: "1" as text would pass a loose -ne.
    if ($version -isnot [long] -or $version -ne $script:SchemaVersion) {
        throw "templates/app-intake.json has schemaVersion $version, and this New-KitApp reads version $($script:SchemaVersion). Run the New-KitApp from the same kit version as -KitRef."
    }
    $intake
}

# Checks the answers against the intake and returns each card's answer and each kind of test's tools.
function Resolve-KitIntakeAnswer {
    param(
        [Parameter(Mandatory)] [Collections.IDictionary] $Intake,
        [Parameter(Mandatory)] [Collections.IDictionary] $Answers
    )

    $known = @($Intake['cards'] | ForEach-Object { $_['id'] }) + 'testTools'
    foreach ($key in $Answers.Keys) {
        if ($key -cnotin $known) { throw "The answers have '$key', which isn't an intake card. The cards are: $($known -join ', ')." }
    }

    $cards = foreach ($card in $Intake['cards']) {
        $id = $card['id']
        $ids = @($card['options'] | ForEach-Object { $_['id'] })
        $accepts = "$($ids -join ', '), or 'Other: <text>'"
        $value = $Answers[$id]
        # A card with a default, such as the budget ($0, ARC-012), takes it when the answers leave the card out.
        if (-not $Answers.Contains($id) -and $card.Contains('default')) { $value = $card['default'] }
        if ($value -isnot [string] -or -not $value.Trim()) { throw "The answers have no answer for '$id'. It takes one of: $accepts." }
        # AskUserQuestion always offers Other: the owner's own answer, which the profile says needs an ADR.
        if ($value -match '(?s)^Other:\s*(?<text>\S.*)$') {
            [pscustomobject]@{ Id = $id; Card = $card; Option = $null; Other = $Matches['text'].Trim() }
            continue
        }
        $option = @($card['options'] | Where-Object { $_['id'] -ceq $value })
        if (-not $option) { throw "'$value' isn't an option of the '$id' card. It takes one of: $accepts." }
        [pscustomobject]@{ Id = $id; Card = $card; Option = $option[0]; Other = $null }
    }
    # A card that depends on another (the database on the data) takes only the options that fit that answer.
    foreach ($answer in $cards | Where-Object { $_.Option -and $_.Card.Contains('dependsOn') }) {
        $parent = $cards | Where-Object Id -CEQ $answer.Card['dependsOn']
        if (-not $parent.Option) { continue }
        $parentId = $parent.Option['id']
        if ($parentId -cnotin @($answer.Option['fits'])) {
            $fitting = @($answer.Card['options'] | Where-Object { $parentId -cin @($_['fits']) } | ForEach-Object { $_['id'] })
            throw "'$($answer.Option['id'])' doesn't fit $($parent.Id) '$parentId'. For that answer, '$($answer.Id)' takes one of: $($fitting -join ', '), or 'Other: <text>'."
        }
    }
    # Each kind of test uses its default tools, unless testTools names that kind's tools instead. A tool that isn't
    # on the list needs an ADR (TST-005), so the intake takes only listed ones.
    $chosen = if ($Answers.Contains('testTools')) { $Answers['testTools'] } else { @{} }
    if ($chosen -isnot [Collections.IDictionary]) { throw "The answers' testTools isn't a map from a kind of test to its tool ids." }
    $kindIds = @($Intake['testKinds'] | ForEach-Object { $_['id'] })
    foreach ($key in $chosen.Keys) {
        if ($key -cnotin $kindIds) { throw "testTools has '$key', which isn't a kind of test. The kinds are: $($kindIds -join ', ')." }
    }
    $kinds = foreach ($kind in $Intake['testKinds']) {
        $id = $kind['id']
        if (-not $chosen.Contains($id)) {
            [pscustomobject]@{ Kind = $kind; Tools = @($kind['tools'] | Where-Object { $_['default'] }) }
            continue
        }
        $names = @($chosen[$id] | Where-Object { $_ })
        if (-not $names) { throw "testTools names no tools for $id tests. Leave $id out to use its defaults." }
        $twice = @($names | Group-Object -CaseSensitive | Where-Object Count -GT 1)
        if ($twice) { throw "testTools names '$($twice[0].Name)' twice for $id tests." }
        $tools = foreach ($name in $names) {
            $tool = @($kind['tools'] | Where-Object { $_['id'] -ceq $name })
            if (-not $tool) {
                throw "'$name' isn't on the kit's list for $id tests: $(($kind['tools'] | ForEach-Object { $_['id'] }) -join ', '). A tool that isn't listed needs an ADR (TST-005) before it's added to templates/app-intake.json."
            }
            $tool[0]
        }
        [pscustomobject]@{ Kind = $kind; Tools = @($tools) }
    }
    [pscustomobject]@{ Cards = @($cards); TestKinds = @($kinds) }
}

# Writes the app's docs/app-profile.md from the resolved answers.
function ConvertTo-KitAppProfile {
    param(
        [Parameter(Mandatory)] [object] $Resolved,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $KitCommit
    )

    $cardRows = foreach ($answer in $Resolved.Cards) {
        $card = $answer.Card
        # A card whose Other is an amount, such as the budget, keeps the owner's amount as the answer: it isn't an
        # unlisted technology, so it needs no ADR (ARC-012).
        if ($answer.Other -and $card.Contains('otherIsAmount') -and $card['otherIsAmount']) {
            $value = $answer.Other
            $cost = 'No cost of its own'
        }
        elseif ($answer.Other) {
            $value = "Other: $($answer.Other)"
            $cost = "Needs an ADR: it isn't a kit option, so its cost isn't known yet"
        }
        else {
            $value = $answer.Option['label']
            $cost = if ($card.Contains('prices')) { "See the kit's [$($card['prices'])](https://github.com/DerekFoulk/dotnet-agent-kit/blob/$KitCommit/$($card['prices']))" }
            elseif ($answer.Option.Contains('cost')) { Format-KitCost -Cost $answer.Option['cost'] }
            else { 'No cost of its own' }
        }
        "| $(Format-KitCell $card['question']) | $(Format-KitCell $value) | $(Format-KitCell $cost) |"
    }
    $kindRows = foreach ($answer in $Resolved.TestKinds) {
        $kind = $answer.Kind
        $tools = foreach ($tool in $answer.Tools) {
            $text = "$($tool['name']) ($($tool['license']), $(Format-KitCost -Cost $tool['cost']))"
            if ($tool.Contains('note')) { $text += ": $($tool['note'])" }
            Format-KitCell $text
        }
        "| $(Format-KitCell $kind['name']) | $(Format-KitCell $kind['checks']) | $(Format-KitCell $kind['runs']) | $($tools -join '<br>') |"
    }

    $lines = @(
        "# App profile: $Name"
        ''
        "What this app is, as the owner chose it at the new-app intake (kit ADR-0058), from dotnet-agent-kit commit ``$KitCommit``. Plans start from it. To change an answer, write an ADR in ``docs/adr/`` that says why, and update this file in the same PR. An answer marked ""Needs an ADR"" isn't a kit option: write its ADR before building on it."
        ''
        'Prices are as checked on the date shown, and they change: check again before relying on one.'
        ''
        '## Choices'
        ''
        '| Question | Answer | Cost |'
        '|---|---|---|'
        $cardRows
        ''
        '## Test tools'
        ''
        "The tools each kind of test uses (kit TST-003, TST-005). A tool that isn't listed here needs an ADR."
        ''
        '| Kind | What it checks | Runs | Tools |'
        '|---|---|---|---|'
        $kindRows
    )
    ($lines -join "`n") + "`n"
}

# A cost as the profile shows it: the label, with what's free and the price, its source and date unless Free.
function Format-KitCost {
    param([Parameter(Mandatory)] [Collections.IDictionary] $Cost)

    $checked = if ($Cost.Contains('checked')) { " (checked $($Cost['checked']), $($Cost['source']))" } else { '' }
    switch ($Cost['label']) {
        'Free tier' { "Free tier: $($Cost['free']). Past it: $($Cost['price'])$checked" }
        'Paid' { "Paid: $($Cost['price'])$checked" }
        default { $Cost['label'] }
    }
}

# Text for one Markdown table cell: a | would end the cell and a line break the row, and the Other answers are the
# owner's own words.
function Format-KitCell {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)

    ($Text -replace '\|', '\|' -replace '\s*\r?\n\s*', ' ').Trim()
}

Export-ModuleMember -Function Get-KitIntake, Resolve-KitIntakeAnswer, ConvertTo-KitAppProfile
