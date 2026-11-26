#Requires -Version 7.6
# Tells a check how the rule it enforces applies (ADR-0090): a must rule's findings fail the check; a should rule's are
# warnings, shown on the pull request as GitHub annotations, and don't fail it; and a rule whose scope or when doesn't
# fit the app is skipped, with its reason. The strengths come from rule-strength.json beside this module, which
# Build-AgentRules.ps1 writes from docs/standards. JSON, since the shared CI that runs the checks has no YAML module. In
# an app's CI the kit's own copy is read, so the kit version the app pins decides each rule's strength. What fits the
# app comes from its docs/app-profile.md: its "App types:" line, and its "Conditions:" line, which answers each
# condition yes, no or unknown; a rule is skipped only where the line says no, so a condition the profile doesn't
# answer, as one the kit adds after the app was made, holds.

Set-StrictMode -Version Latest

# Generated beside the module: tools/ in the kit, .kit/tools/ in an app.
$script:DefaultPath = Join-Path $PSScriptRoot 'rule-strength.json'

$script:Strengths = 'must', 'should', 'consider', 'retired'
$script:Answers = 'yes', 'no', 'unknown'

# The rules this run has already said it skips, so a check with many findings says it once.
$script:Skipped = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

# A rule's entry: its strength, scope and when. An id the file doesn't list throws, so a typo in a check can't turn its
# gate into warnings, and so does a strength the kit doesn't know.
function Get-RuleEntry {
    param([Parameter(Mandatory)] [string] $Id, [string] $Path)

    if (-not $Path) { $Path = $script:DefaultPath }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "The rule strengths file $Path doesn't exist, so no check can tell how its rule applies. Run Build-AgentRules.ps1."
    }
    $text = Get-Content -Raw -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "The rule strengths file $Path is empty, so no check can tell how its rule applies. Run Build-AgentRules.ps1."
    }
    $entries = $text | ConvertFrom-Json
    $entry = $entries.PSObject.Properties | Where-Object { $_.Name -ceq $Id }
    if (-not $entry) {
        throw "Rule $Id isn't in $Path, so its check can't tell how it applies. Check the id, or run Build-AgentRules.ps1."
    }
    $strength = "$($entry.Value.strength)"
    if ($strength -cnotin $script:Strengths) {
        throw "Rule $Id has the strength '$strength' in $Path, which isn't one of $($script:Strengths -join ', ')."
    }
    [pscustomobject]@{ Strength = $strength; Scope = @($entry.Value.scope | ForEach-Object { "$_" }); When = @($entry.Value.when | ForEach-Object { "$_" }) }
}

# A rule's strength: must, should, consider or retired.
function Get-RuleStrength {
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Id, [string] $Path)

    (Get-RuleEntry -Id $Id -Path $Path).Strength
}

# An app's types and condition answers, from its docs/app-profile.md, which the new-app intake writes; nothing when the
# repo has none (the kit, or an app made before profiles), and then every rule applies. Build-AgentRules reads the
# same lines through this function.
function Read-AppProfile {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $lines = @(Get-Content -LiteralPath $Path)
    $types = @()
    $typeLine = $lines | Where-Object { $_ -match '^App types:' } | Select-Object -First 1
    if ($typeLine) { $types = @(($typeLine -replace '^App types:', '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $conditions = @{}
    $conditionLine = $lines | Where-Object { $_ -match '^Conditions:' } | Select-Object -First 1
    if ($conditionLine) {
        foreach ($pair in @(($conditionLine -replace '^Conditions:', '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            $id, $answer = $pair -split '=', 2
            if ($null -eq $answer -or $answer.Trim() -cnotin $script:Answers) {
                throw "docs/app-profile.md's Conditions line has '$pair'; each condition is answered yes, no or unknown, as in has-sign-in=yes."
            }
            $conditions[$id.Trim()] = $answer.Trim()
        }
    }
    [pscustomobject]@{ AppTypes = $types; Conditions = $conditions }
}

# Why a rule doesn't apply to the app the profile describes, or nothing when it does.
function Get-RuleSkipReason {
    param([Parameter(Mandatory)] [object] $Entry, [AllowNull()] [object] $AppProfile)

    if (-not $AppProfile) { return }
    if ($AppProfile.AppTypes -and 'core' -cnotin $Entry.Scope -and -not @($Entry.Scope | Where-Object { $_ -cin $AppProfile.AppTypes }).Count) {
        return "its scope is $($Entry.Scope -join ', '), and the app profile names the app types $($AppProfile.AppTypes -join ', ')"
    }
    foreach ($condition in $Entry.When) {
        if ($AppProfile.Conditions.ContainsKey($condition) -and $AppProfile.Conditions[$condition] -ceq 'no') {
            return "it holds only where $condition, and the app profile answers $condition=no"
        }
    }
}

# The app's profile when a check names none: the shared workflows run a check in the workspace GitHub checked the app
# out to, so its docs/app-profile.md is there; run by hand, it's the one where you stand.
function Get-DefaultProfilePath {
    $root = if ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { (Get-Location).ProviderPath }
    Join-Path $root 'docs' 'app-profile.md'
}

# Why rule Id doesn't apply to the app whose profile is at -ProfilePath (by default the one Get-DefaultProfilePath finds),
# or nothing when it does: a check asks once, to sum up its findings truly.
function Get-RuleSkip {
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Id, [string] $Path, [string] $ProfilePath)

    if (-not $ProfilePath) { $ProfilePath = Get-DefaultProfilePath }
    Get-RuleSkipReason -Entry (Get-RuleEntry -Id $Id -Path $Path) -AppProfile (Read-AppProfile -Path $ProfilePath)
}

# Writes one finding of rule Id and returns whether it counts toward the check's failure; the rule's strength alone
# decides. A rule that doesn't apply to the app (its scope doesn't name the app's types, or the profile answers one of
# its when conditions no) is skipped: a GitHub notice says why, once per rule, and nothing counts. A should rule's
# finding is a GitHub warning annotation ("::warning::<id>: <message>", or "::warning file=<file>,line=<line>,col=
# <column>::<id>: <message>" when its place is given), which the pull request shows without failing, and doesn't
# count. A must rule's finding is written as it is, in red, as the checks wrote their errors before, and counts: an
# MSBuild-format line stays readable by setup-dotnet's problem matcher. A consider rule is advice and a retired rule
# isn't in force, so no check should report either, and a finding for one throws. -File, -Line and -Column name the
# finding's place in the warning, so the pull request shows it on that line of the diff; GitHub's warning command takes
# them as file, line and col:
#   https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands  retrieved 2026-11-18
function Write-RuleFinding {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Id, [Parameter(Mandatory)] [string] $Message, [string] $Path, [string] $ProfilePath,
        [string] $File, [int] $Line, [int] $Column
    )

    $entry = Get-RuleEntry -Id $Id -Path $Path
    if ($entry.Strength -cin 'consider', 'retired') {
        $why = if ($entry.Strength -ceq 'retired') { "isn't in force" } else { 'is advice' }
        throw "Rule $Id is $($entry.Strength), so it $why and no check should report it; take its check out."
    }
    if (-not $ProfilePath) { $ProfilePath = Get-DefaultProfilePath }
    $reason = Get-RuleSkipReason -Entry $entry -AppProfile (Read-AppProfile -Path $ProfilePath)
    if ($reason) {
        if ($script:Skipped.Add($Id)) { Write-Host "::notice::$Id skipped: $reason" }
        return $false
    }
    if ($entry.Strength -ceq 'should') {
        # GitHub ends a workflow command at the line's end, and decodes these three in its message; a property also
        # ends at a comma, and its name at a colon, so those are escaped in one too, as @actions/core does.
        $data = $Message.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
        $place = @(
            if ($File) { 'file=' + $File.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A').Replace(':', '%3A').Replace(',', '%2C') }
            if ($Line -gt 0) { "line=$Line" }
            if ($Column -gt 0) { "col=$Column" }
        )
        $properties = if ($place) { ' ' + ($place -join ',') } else { '' }
        Write-Host "::warning${properties}::${Id}: $data"
        return $false
    }
    Write-Host $Message -ForegroundColor Red
    $true
}

Export-ModuleMember -Function Get-RuleStrength, Get-RuleSkip, Read-AppProfile, Write-RuleFinding
