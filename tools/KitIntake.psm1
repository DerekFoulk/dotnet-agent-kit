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
    if ($version -ne $script:SchemaVersion) {
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

Export-ModuleMember -Function Get-KitIntake, Resolve-KitIntakeAnswer
