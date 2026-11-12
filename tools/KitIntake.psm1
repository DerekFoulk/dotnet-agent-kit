#Requires -Version 7.6
# The new-app intake (ADR-0058): reads templates/app-intake.json, checks a set of answers against it, and writes
# the app's docs/app-profile.md. New-KitApp uses it; the new-app skill writes the answers.

Set-StrictMode -Version Latest

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
    $kinds = foreach ($kind in $Intake['testKinds']) {
        [pscustomobject]@{ Kind = $kind; Tools = @($kind['tools'] | Where-Object { $_['default'] }) }
    }
    [pscustomobject]@{ Cards = @($cards); TestKinds = @($kinds) }
}

Export-ModuleMember -Function Resolve-KitIntakeAnswer
