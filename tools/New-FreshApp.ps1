#Requires -Version 7.6
<#
.SYNOPSIS
    Writes a fresh app of one app type from the kit at one commit, with a probe project of that type, for the kit's
    CI to check (GAP-049, ADR-0095). It creates no GitHub repo.

.DESCRIPTION
    Exports the app with Export-KitApp.ps1, as New-KitApp does, with an app profile whose answers are the intake's
    defaults and whose app type is -Type. Kit only: an app never gets this script.

.EXAMPLE
    ./tools/New-FreshApp.ps1 -Type web-api -Destination ../fresh-web-api
#>
[CmdletBinding()]
param(
    [string] $Type,
    [string] $Destination,
    [string] $KitRef = 'HEAD',
    [string] $KitRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'KitIntake.psm1') -Force

# The probe for each app type the job checks: the kit's own reference app of that type (ADR-0095). Name is the app's
# name; From is the kit folder whose src/ and tests/ become the app's.
$script:Probes = [ordered]@{
    'web-api' = @{ Name = 'Fresh.WebApi'; From = 'sample' }
    'blazor'  = @{ Name = 'Fresh.Blazor'; From = 'fixtures/WebUi' }
}

# App types in docs/standards/app-types.yml that have no probe yet, and why (GAP-049 stays open for them).
$script:Waiting = @{
    'maui' = "MAUI's leg needs the Windows and macOS jobs proven first (GAP-028), and the owner put MAUI after the practice run"
}

# Refuses a type with no probe, saying why.
function Assert-FreshAppType {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Type)

    if ($script:Probes.Contains($Type)) { return }
    $reason = if ($script:Waiting.ContainsKey($Type)) { ": $($script:Waiting[$Type])" } else { '' }
    throw "There's no fresh-app probe for the app type '$Type'$reason. Types with a probe: $($script:Probes.Keys -join ', ')."
}

# The intake's answers for a fresh app: the app type's own option, and every other card's default as the new-app skill
# would show it with no developer preferences, so a run on any machine gives the app CI checks.
function Get-FreshAppAnswer {
    param(
        [Parameter(Mandatory)] [Collections.IDictionary] $Intake,
        [Parameter(Mandatory)] [string] $Type
    )

    $defaults = @(Get-KitIntakeDefault -Intake $Intake -Preference @())
    $appType = @($Intake['cards'] | Where-Object { $_['id'] -ceq 'appType' })
    $option = @($appType | ForEach-Object { $_['options'] } | Where-Object { @($_['appTypes']).Count -eq 1 -and @($_['appTypes'])[0] -ceq $Type })
    if ($option.Count -ne 1) { throw "The intake's appType card has no option for the app type '$Type' alone." }

    $answers = [ordered]@{ appType = $option[0]['id'] }
    foreach ($card in $Intake['cards'] | Where-Object { $_['id'] -cne 'appType' }) {
        $id = $card['id']
        $row = if ($card.Contains('dependsOn')) {
            @($defaults | Where-Object { $_.Choice -ceq $id -and $_.When -ceq $answers[$card['dependsOn']] })
        }
        else { @($defaults | Where-Object { $_.Choice -ceq $id -and -not $_.When }) }
        # A card with a default of its own, such as the budget, takes it when the answers leave it out.
        if ($row -and $row[0].Pick) { $answers[$id] = $row[0].Pick }
    }
    $answers
}

function New-FreshApp {
    param(
        [Parameter(Mandatory)] [string] $Type,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $KitRoot
    )

    Assert-FreshAppType -Type $Type
    $probe = $script:Probes[$Type]
    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)
    $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    $commit = (git -C $KitRoot rev-parse --verify --quiet "$KitRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "'$KitRef' isn't a commit or tag in $KitRoot." }

    # The intake at the same commit as the files, as New-KitApp reads it.
    $intakeText = git -C $KitRoot show "${commit}:templates/app-intake.json" 2>$null | Out-String
    if ($LASTEXITCODE -ne 0 -or -not $intakeText.Trim()) { throw "The kit at $commit has no templates/app-intake.json." }
    $intake = Get-KitIntake -Text $intakeText
    $resolved = Resolve-KitIntakeAnswer -Intake $intake -Answers (Get-FreshAppAnswer -Intake $intake -Type $Type)
    $profileText = ConvertTo-KitAppProfile -Resolved $resolved -Name $probe.Name -KitCommit $commit

    & (Join-Path $PSScriptRoot 'Export-KitApp.ps1') -Name $probe.Name -Destination $Destination -KitRef $commit -KitRoot $KitRoot -AppProfile $profileText
    if ($LASTEXITCODE -ne 0) { throw 'Export-KitApp failed.' }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $KitRoot) { $KitRoot = Split-Path -Path $PSScriptRoot -Parent }
    try {
        New-FreshApp -Type $Type -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
