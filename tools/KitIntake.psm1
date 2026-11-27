#Requires -Version 7.6
# The new-app intake (ADR-0058): reads templates/app-intake.json, checks a set of answers against it, and writes
# the app's docs/app-profile.md. New-KitApp uses it; the new-app skill writes the answers.

Set-StrictMode -Version Latest

# The layout of templates/app-intake.json this module reads. Raise it when a change to the file's layout would make
# an older module misread it.
$script:SchemaVersion = 2

# The layout of a developer's preferences file (docs/preferences.md, ADR-0074).
$script:PreferenceSchemaVersion = 1

# Reads templates/app-intake.json, and refuses one whose defaults don't name their source (ADR-0074).
function Get-KitIntake {
    param([Parameter(Mandatory)] [string] $Text)

    $intake = $Text | ConvertFrom-Json -AsHashtable
    if ($intake -isnot [Collections.IDictionary]) { throw "templates/app-intake.json isn't a JSON object." }
    $version = if ($intake.Contains('schemaVersion')) { $intake['schemaVersion'] } else { 'none' }
    # A number, compared exactly: "1" as text would pass a loose -ne.
    if ($version -isnot [long] -or $version -ne $script:SchemaVersion) {
        throw "templates/app-intake.json has schemaVersion $version, and this New-KitApp reads version $($script:SchemaVersion). Run the New-KitApp from the same kit version as -KitRef."
    }
    $problems = @(Test-KitIntakeSource -Intake $intake)
    if ($problems) {
        throw "templates/app-intake.json has defaults with no labeled source:`n- $($problems -join "`n- ")`nEach card and test tool role needs the authority's recommendation and the agent's (ADR-0074)."
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
            [pscustomobject]@{ Kind = $kind; Tools = @(Get-KitDefaultTool -Kind $kind) }
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

# The kit's default tools for a kind of test: one for each role, the authority's pick or else the agent's (ADR-0074).
# A developer's preferences aren't read here, so New-KitApp gives the same app on every machine; the new-app skill
# writes the developer's picks into the answers.
function Get-KitDefaultTool {
    param([Parameter(Mandatory)] [Collections.IDictionary] $Kind)

    foreach ($role in $Kind['roles']) {
        $tools = @($Kind['tools'] | Where-Object { $_['role'] -ceq $role['id'] })
        $pick = (Select-KitPick -Recommendation $role['recommendation'] -Option $tools).Pick
        @($tools | Where-Object { $_['id'] -ceq $pick })[0]
    }
}

# Picks a default from a recommendation (ADR-0074): the developer's preference, then the authority's pick unless it's
# Paid (ARC-012 starts every tool on its free option), then the agent's. Returns the pick, where it came from, and a
# note for each source it passed over.
function Select-KitPick {
    param(
        [Parameter(Mandatory)] [Collections.IDictionary] $Recommendation,
        [Parameter(Mandatory)] [Collections.IDictionary[]] $Option,
        [object] $Preference
    )

    $notes = [Collections.Generic.List[string]]::new()
    $ids = @($Option | ForEach-Object { $_['id'] })
    if ($Preference) {
        if ($Preference.Pick -cin $ids) { return [pscustomobject]@{ Pick = $Preference.Pick; From = 'developer'; Notes = @($notes) } }
        $notes.Add("Your preference of $($Preference.Date), '$($Preference.Pick)', isn't an option here any more, so it's skipped.")
    }
    $authority = $Recommendation['authority']
    if ($null -ne $authority['pick']) {
        $chosen = @($Option | Where-Object { $_['id'] -ceq $authority['pick'] })[0]
        if ($chosen.Contains('cost') -and $chosen['cost']['label'] -eq 'Paid') {
            $notes.Add("$($authority['by'])'s pick, '$($authority['pick'])', is Paid, so it isn't the default: every tool starts on its free option (ARC-012).")
        }
        else { return [pscustomobject]@{ Pick = $authority['pick']; From = 'authority'; Notes = @($notes) } }
    }
    [pscustomobject]@{ Pick = $Recommendation['agent']['pick']; From = 'agent'; Notes = @($notes) }
}

# The conditions a rule's when names (ADR-0090), from docs/standards/conditions.yml at the kit commit an app is made
# from, for ConvertTo-KitAppProfile's -Conditions; New-KitApp and New-FreshApp both read them here. A kit from before
# conditions.yml has none, and its profile no Conditions line.
function Get-KitCondition {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $Commit
    )

    # Into this module's own scope, so ConvertFrom-Yaml resolves whoever calls this.
    Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'
    $text = git -C $KitRoot show "${Commit}:docs/standards/conditions.yml" 2>$null | Out-String
    if ($LASTEXITCODE -ne 0 -or -not $text.Trim()) { return , @() }
    , @((ConvertFrom-Yaml -Yaml $text)['conditions'])
}

# Writes the app's docs/app-profile.md from the resolved answers. -Conditions is the kit's docs/standards/conditions.yml,
# parsed: with it, the profile answers each condition yes, no or unknown (ADR-0090).
function ConvertTo-KitAppProfile {
    param(
        [Parameter(Mandatory)] [object] $Resolved,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $KitCommit,
        [object[]] $Conditions
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

    # ADR-0084: the app's app types, on the line Build-AgentRules reads to give the app only the core ruleset and those
    # types' rulesets. An Other app type has none until an ADR names them, so the app gets every rule.
    $appType = @($Resolved.Cards | Where-Object { $_.Card['id'] -eq 'appType' }) | Select-Object -First 1
    $types = @(if ($appType -and -not $appType.Other -and $appType.Option.Contains('appTypes')) { $appType.Option['appTypes'] })
    $typeLines = if ($types) {
        "The kit's rulesets this app gets (kit ADR-0084): the core ruleset, and one for each app type. The kit's ``Build-AgentRules.ps1`` reads the next line; change it only with an ADR."
        ''
        "App types: $($types -join ', ')"
    }
    else {
        "None chosen yet, so the app gets every kit rule. Name its app types from the kit's ``docs/standards/app-types.yml`` in an ADR, then add a line here that reads ``App types: <id>, <id>`` (kit ADR-0084)."
    }

    # ADR-0090 decision 8: each condition a rule's when can name, answered from the card conditions.yml maps it to: yes
    # or no by the option chosen, unknown for an Other answer, an option it doesn't list, or a condition the intake
    # doesn't ask. A gate skips a rule only on no, so unknown never drops one.
    $conditionLines = @()
    if ($Conditions) {
        $pairs = foreach ($condition in $Conditions) {
            $answer = 'unknown'
            if ($condition.Contains('intake') -and $condition['intake']) {
                $card = @($Resolved.Cards | Where-Object { $_.Card['id'] -eq $condition['intake']['card'] }) | Select-Object -First 1
                if ($card -and -not $card.Other) {
                    $option = "$($card.Option['id'])"
                    if ($option -in @($condition['intake']['yes'])) { $answer = 'yes' }
                    elseif ($option -in @($condition['intake']['no'])) { $answer = 'no' }
                }
            }
            "$($condition['id'])=$answer"
        }
        $conditionLines = @(
            ''
            "Each condition a kit rule's ``when`` can name (kit ``docs/standards/conditions.yml``, ADR-0090), answered from the choices above: a check skips a rule only where its condition is ``no``, and ``unknown`` holds. ``Build-AgentRules.ps1`` and the checks read the next line; change it only with an ADR."
            ''
            "Conditions: $($pairs -join ', ')"
        )
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
        '## App types'
        ''
        $typeLines
        $conditionLines
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

# Checks that every default the intake gives names its source (ADR-0074), and returns what's missing.
function Test-KitIntakeSource {
    param([Parameter(Mandatory)] [Collections.IDictionary] $Intake)

    foreach ($card in $Intake['cards']) {
        $label = "card '$($card['id'])'"
        # An unanswered card's own default, such as the $0 budget, is a rule's, not a recommendation's.
        if ($card.Contains('default') -and -not (Test-KitText $card['defaultRule'])) {
            "$label has a default for an unanswered card but no defaultRule naming the rule that sets it."
        }
        if ($card['recommendation'] -isnot [Collections.IDictionary]) { "$label has no recommendation."; continue }
        if (-not $card.Contains('dependsOn')) {
            Test-KitRecommendation -Label $label -Recommendation $card['recommendation'] -OptionId @($card['options'] | ForEach-Object { $_['id'] })
            continue
        }
        # One recommendation for each answer of the other card that leaves more than one option.
        $parentId = $card['dependsOn']
        $parent = @($Intake['cards'] | Where-Object { $_['id'] -ceq $parentId })
        $parentOptions = @($parent | ForEach-Object { $_['options'] } | ForEach-Object { $_['id'] })
        foreach ($answer in $card['recommendation'].Keys) {
            if ($answer -cnotin $parentOptions) { "$label has a recommendation for $parentId '$answer', which isn't an option of that card." }
        }
        foreach ($answer in $parentOptions) {
            $fitting = @($card['options'] | Where-Object { $answer -cin @($_['fits']) } | ForEach-Object { $_['id'] })
            if ($fitting.Count -lt 2) { continue }
            $forAnswer = "$label for $parentId '$answer'"
            if ($card['recommendation'][$answer] -isnot [Collections.IDictionary]) { "$forAnswer has no recommendation."; continue }
            Test-KitRecommendation -Label $forAnswer -Recommendation $card['recommendation'][$answer] -OptionId $fitting
        }
    }
    foreach ($kind in $Intake['testKinds']) {
        if (-not $kind['roles']) { "$($kind['id']) tests list no roles: each tool fills one, such as the test framework."; continue }
        $roleIds = @($kind['roles'] | ForEach-Object { $_['id'] })
        foreach ($tool in $kind['tools']) {
            if ($tool['role'] -cnotin $roleIds) {
                "tool '$($tool['id'])' of $($kind['id']) tests has role '$($tool['role'])', which isn't one of its roles: $($roleIds -join ', ')."
            }
        }
        foreach ($role in $kind['roles']) {
            $label = "role '$($kind['id'])/$($role['id'])'"
            $toolIds = @($kind['tools'] | Where-Object { $_['role'] -ceq $role['id'] } | ForEach-Object { $_['id'] })
            if (-not $toolIds) { "$label has no tools."; continue }
            if ($role['recommendation'] -isnot [Collections.IDictionary]) { "$label has no recommendation."; continue }
            Test-KitRecommendation -Label $label -Recommendation $role['recommendation'] -OptionId $toolIds
        }
    }
}

# What's missing from one recommendation: the authority's (who, what its page says, the page or the search that
# found none, the date read, and a pick that's an option or none) and the agent's (an option, with a reason).
function Test-KitRecommendation {
    param(
        [Parameter(Mandatory)] [string] $Label,
        [Parameter(Mandatory)] [Collections.IDictionary] $Recommendation,
        [Parameter(Mandatory)] [string[]] $OptionId
    )

    $options = $OptionId -join ', '
    $authority = $Recommendation['authority']
    if ($authority -isnot [Collections.IDictionary]) { "$label has no authority recommendation: what the authority's page says, or that it names no pick." }
    else {
        if (-not (Test-KitText $authority['by'])) { "$label's authority recommendation doesn't say who the authority is (by)." }
        if (-not (Test-KitText $authority['says'])) { "$label's authority recommendation doesn't say what the page says (says)." }
        $page = $authority['source'] -is [string] -and $authority['source'] -match '^https://\S+$'
        if (-not $page -and -not (Test-KitText $authority['searched'])) {
            "$label's authority recommendation needs the https:// page it comes from (source), or the search that found no page (searched)."
        }
        if ("$($authority['read'])" -notmatch '^\d{4}-\d{2}-\d{2}$') { "$label's authority recommendation needs the date it was read (read: yyyy-mm-dd)." }
        $pick = $authority['pick']
        if ($null -ne $pick -and $pick -cnotin $OptionId) { "$label's authority picks '$pick', which isn't an option: $options." }
        # The bar for a pick (ADR-0074): the page recommends it, says it should be used, or gives it a guideline level.
        # "You can use", an example or a tool a page only uses is no pick, and neither is one whose words say so.
        elseif ($null -ne $pick -and "$($authority['says'])" -cmatch '(?i)^\s*no (pick|recommendation)\b|without recommending|doesn''t recommend') {
            "$label's authority picks '$pick', but its says reads as no pick: record pick null, or quote the page's recommendation."
        }
        elseif ($null -ne $pick -and "$($authority['says'])" -cnotmatch '(?i:\brecommend)|\bshould\b|\b(DO|CONSIDER)\b') {
            "$label's authority picks '$pick', but its says doesn't quote the page saying it recommends it, should use it, or a DO or CONSIDER."
        }
    }
    $agent = $Recommendation['agent']
    if ($agent -isnot [Collections.IDictionary]) { "$label has no agent recommendation: the agent's pick, with its reason."; return }
    $pick = $agent['pick']
    if ($null -eq $pick) { "$label's agent picks nothing: the agent always picks an option, as the last default." }
    elseif ($pick -cnotin $OptionId) { "$label's agent picks '$pick', which isn't an option: $options." }
    if (-not (Test-KitText $agent['reason'])) { "$label's agent recommendation gives no reason." }
}

# Whether a value is text with something in it.
function Test-KitText {
    param([AllowNull()] [object] $Value)

    $Value -is [string] -and [bool]$Value.Trim()
}

# Where a developer's preferences file lives: their home folder, outside every repo (ADR-0074).
function Get-KitPreferencePath {
    Join-Path $HOME '.dotnet-agent-kit' 'preferences.json'
}

# Reads a developer's preferences file and checks each preference: their words, the date, where they said it, and
# a pick for a preference that answers an intake question. A missing file is no preferences: a new kit user has none.
function Read-KitPreference {
    param([string] $Path = (Get-KitPreferencePath))

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    try { $file = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable }
    catch { throw "The preferences file $Path isn't valid JSON: $($_.Exception.Message)" }
    if ($file -isnot [Collections.IDictionary]) { throw "The preferences file $Path isn't a JSON object." }
    $version = if ($file.Contains('schemaVersion')) { $file['schemaVersion'] } else { 'none' }
    if ($version -isnot [long] -or $version -ne $script:PreferenceSchemaVersion) {
        throw "The preferences file $Path has schemaVersion $version, and this kit reads version $($script:PreferenceSchemaVersion) (docs/preferences.md)."
    }
    $seen = @{}
    $number = 0
    foreach ($entry in @(if ($file.Contains('preferences')) { $file['preferences'] })) {
        $number++
        $at = "The preferences file $Path, preference $number"
        if ($entry -isnot [Collections.IDictionary]) { throw "$at, isn't a JSON object." }
        if (-not (Test-KitText $entry['stated'])) { throw "$at, has no stated: what you said, in your words." }
        if ("$($entry['date'])" -notmatch '^\d{4}-\d{2}-\d{2}$') { throw "$at, needs the date you said it (date: yyyy-mm-dd)." }
        if (-not (Test-KitText $entry['source'])) { throw "$at, has no source: where you said it, such as 'said in chat'." }
        $choice = $entry['choice']
        if (Test-KitText $choice) {
            if (-not (Test-KitText $entry['pick'])) { throw "$at, answers choice '$choice' but has no pick." }
            $key = "$choice|$($entry['when'])"
            if ($seen.Contains($key)) { throw "The preferences file $Path has two preferences for '$choice' ($($seen[$key]) and $number): keep one." }
            $seen[$key] = $number
        }
        [pscustomobject]@{
            Choice = $choice; When = $entry['when']; Pick = $entry['pick']
            Stated = $entry['stated']; Date = $entry['date']; Source = $entry['source']
        }
    }
}

# The default for each intake question and each test tool role, with where it came from and all three sources side
# by side (ADR-0074), for the new-app skill to show.
function Get-KitIntakeDefault {
    param(
        [Parameter(Mandatory)] [Collections.IDictionary] $Intake,
        [object[]] $Preference = @()
    )

    foreach ($card in $Intake['cards']) {
        if (-not $card.Contains('dependsOn')) {
            New-KitDefaultRow -Choice $card['id'] -Recommendation $card['recommendation'] -Option $card['options'] -Preference $Preference
            continue
        }
        # A card that depends on another has a default for each of that card's answers.
        $parent = $Intake['cards'] | Where-Object { $_['id'] -ceq $card['dependsOn'] } | Select-Object -First 1
        foreach ($answer in @($parent['options'] | ForEach-Object { $_['id'] })) {
            $fitting = @($card['options'] | Where-Object { $answer -cin @($_['fits']) })
            if ($fitting.Count -eq 1) {
                [pscustomobject]@{ Choice = $card['id']; When = $answer; Pick = $fitting[0]['id']; From = 'only option'
                    Developer = $null; Authority = $null; Agent = $null; Notes = @() }
                continue
            }
            New-KitDefaultRow -Choice $card['id'] -When $answer -Recommendation $card['recommendation'][$answer] -Option $fitting -Preference $Preference
        }
    }
    foreach ($kind in $Intake['testKinds']) {
        foreach ($role in $kind['roles']) {
            $tools = @($kind['tools'] | Where-Object { $_['role'] -ceq $role['id'] })
            New-KitDefaultRow -Choice "$($kind['id'])/$($role['id'])" -Recommendation $role['recommendation'] -Option $tools -Preference $Preference
        }
    }
    # A preference that answers none of these is reported, never dropped in silence.
    $asked = @($Intake['cards'] | ForEach-Object {
            $card = $_
            if (-not $card.Contains('dependsOn')) { "$($card['id'])|" }
            else { @($Intake['cards'] | Where-Object { $_['id'] -ceq $card['dependsOn'] } | ForEach-Object { $_['options'] }) | ForEach-Object { "$($card['id'])|$($_['id'])" } }
        }) + @($Intake['testKinds'] | ForEach-Object { $kind = $_; $kind['roles'] | ForEach-Object { "$($kind['id'])/$($_['id'])|" } })
    $dependent = @($Intake['cards'] | Where-Object { $_.Contains('dependsOn') } | ForEach-Object { $_['id'] })
    foreach ($unused in @($Preference | Where-Object { (Test-KitText $_.Choice) -and "$($_.Choice)|$($_.When)" -cnotin $asked })) {
        $why = if ($unused.Choice -cin $dependent -and -not (Test-KitText $unused.When)) {
            "Your preference for '$($unused.Choice)' names no answer of the card it depends on (when), so it's unused: add when, such as 'relational'."
        }
        else { "Your preference for '$($unused.Choice)' isn't an intake question, so it's unused: check its choice against docs/preferences.md." }
        [pscustomobject]@{ Choice = $unused.Choice; When = $unused.When; Pick = $null; From = 'unused preference'
            Developer = $unused; Authority = $null; Agent = $null; Notes = @($why) }
    }
}

# One question's default: the developer's preference for it, if any, picked against the recommendation.
function New-KitDefaultRow {
    param(
        [Parameter(Mandatory)] [string] $Choice,
        [string] $When,
        [Parameter(Mandatory)] [Collections.IDictionary] $Recommendation,
        [Parameter(Mandatory)] [Collections.IDictionary[]] $Option,
        [object[]] $Preference = @()
    )

    $mine = $Preference | Where-Object { $_.Choice -ceq $Choice -and "$($_.When)" -ceq $When } | Select-Object -First 1
    $picked = Select-KitPick -Recommendation $Recommendation -Option $Option -Preference $mine
    [pscustomobject]@{
        Choice = $Choice; When = if ($When) { $When } else { $null }; Pick = $picked.Pick; From = $picked.From
        Developer = $mine; Authority = $Recommendation['authority']; Agent = $Recommendation['agent']; Notes = $picked.Notes
    }
}

# The answers' testTools from the defaults the new-app skill showed: each kind of test with its roles' picks.
function Get-KitTestToolAnswer {
    param([Parameter(Mandatory)] [object[]] $Default)

    $answer = [ordered]@{}
    # An unused preference (a typo, a removed role) is a note for the developer, not an answer for New-KitApp.
    foreach ($row in $Default | Where-Object { $_.Choice -like '*/*' -and $_.From -ne 'unused preference' }) {
        $kind = $row.Choice.Split('/')[0]
        if (-not $answer.Contains($kind)) { $answer[$kind] = [Collections.Generic.List[string]]::new() }
        $answer[$kind].Add($row.Pick)
    }
    foreach ($kind in @($answer.Keys)) { $answer[$kind] = @($answer[$kind]) }
    $answer
}

Export-ModuleMember -Function Get-KitIntake, Resolve-KitIntakeAnswer, Get-KitCondition, ConvertTo-KitAppProfile, Test-KitIntakeSource, Get-KitPreferencePath, Read-KitPreference, Get-KitIntakeDefault, Get-KitTestToolAnswer
