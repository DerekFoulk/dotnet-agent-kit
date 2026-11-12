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

    $cards = foreach ($card in $Intake['cards']) {
        $value = $Answers[$card['id']]
        [pscustomobject]@{ Id = $card['id']; Card = $card; Option = @($card['options'] | Where-Object { $_['id'] -ceq $value })[0]; Other = $null }
    }
    $kinds = foreach ($kind in $Intake['testKinds']) {
        [pscustomobject]@{ Kind = $kind; Tools = @($kind['tools'] | Where-Object { $_['default'] }) }
    }
    [pscustomobject]@{ Cards = @($cards); TestKinds = @($kinds) }
}

Export-ModuleMember -Function Resolve-KitIntakeAnswer
