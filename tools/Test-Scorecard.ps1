#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when the quality scorecard (docs/quality/scorecard.md) doesn't match the kit's rules (ADR-0034).

.DESCRIPTION
    The scorecard maps each quality area of a .NET app to the kit's rules and lists what's missing. Its YAML
    front matter holds the areas. This check fails when an area names a rule that doesn't exist, when a rule
    in force has no area, or when the table of counts in the file is out of date.
    Exit code: 0 when the scorecard is consistent, otherwise 1.

.EXAMPLE
    ./tools/Test-Scorecard.ps1

.EXAMPLE
    ./tools/Test-Scorecard.ps1 -Update   # rewrite the table after changing a rule or the scorecard
#>
[CmdletBinding()]
param(
    [string] $ScorecardPath,
    [string] $StandardsPath,
    [string] $AdrPath,
    [switch] $Update
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Not '#Requires -Modules': a module loaded that way turns the script's 'exit 1' into 0 when run with -File
# (see Test-RuleSources.ps1).
Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'
Import-Module -Name (Join-Path $PSScriptRoot 'KitFrontMatter.psm1') -Force

# What every area needs: what "perfect" means for it, and where that comes from.
$script:RequiredAreaFields = 'id', 'name', 'perfect', 'sources'
# A gap is what's missing for an area to be "perfect"; closing one is its own PR.
$script:RequiredGapFields = 'id', 'gap', 'status'
$script:GapStatuses = 'proposed', 'planned', 'closed'
# -Update writes the table of counts between these lines.
$script:TableStart = '<!-- scorecard-table:start -->'
$script:TableEnd = '<!-- scorecard-table:end -->'

function New-Problem {
    param([string] $Area, [string] $Message)
    [pscustomobject]@{ Area = $Area; Message = $Message }
}

# Every rule in docs/standards, keyed by id: its status and whether a tool enforces it.
function Get-KitRule {
    param([Parameter(Mandatory)] [string] $StandardsPath)

    $rules = [ordered]@{}
    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File | Sort-Object Name) {
        $frontMatter = Read-FrontMatter -Path $file.FullName
        if ($null -eq $frontMatter -or -not $frontMatter.Contains('rules')) { continue }
        foreach ($rule in @($frontMatter['rules'])) {
            $rules["$($rule['id'])"] = [pscustomobject]@{
                Id       = "$($rule['id'])"
                Status   = "$($rule['status'])"
                Advisory = "$($rule['enforcement'])" -match '^advisory\b'
            }
        }
    }
    $rules
}

# One row per area, counted from the standards, so the scores can't drift from the rules. A rule whose
# enforcement starts with "advisory" is advisory; any other kind (build, ci, ruleset, hook, settings) is checked
# by a tool. Proposed rules aren't in force, so they're counted apart. Unknown rule ids are skipped here;
# Get-ScorecardProblem reports them.
function Get-ScorecardRow {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath
    )

    $rules = Get-KitRule -StandardsPath $StandardsPath
    foreach ($area in @((Read-FrontMatter -Path $ScorecardPath)['areas'])) {
        $areaRules = @(@($(if ($area.Contains('rules')) { $area['rules'] })) | Where-Object { $_ -and $rules.Contains("$_") } |
                ForEach-Object { $rules["$_"] })
        $inForce = @($areaRules | Where-Object Status -EQ 'accepted')
        $gaps = @($(if ($area.Contains('gaps')) { $area['gaps'] }) | Where-Object { $_ })
        [pscustomobject]@{
            Area          = "$($area['name'])"
            InForce       = $inForce.Count
            CheckedByTool = @($inForce | Where-Object { -not $_.Advisory }).Count
            Advisory      = @($inForce | Where-Object Advisory).Count
            Proposed      = @($areaRules | Where-Object Status -EQ 'proposed').Count
            OpenGaps      = @($gaps | Where-Object { "$($_['status'])" -ne 'closed' }).Count
        }
    }
}

# The table and summary line that go between the markers in the scorecard file.
function Format-ScorecardTable {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath
    )

    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('| Area | Rules in force | Checked by a tool | Advisory | Proposed rules | Open gaps |')
    $lines.Add('|---|---|---|---|---|---|')
    foreach ($row in Get-ScorecardRow -ScorecardPath $ScorecardPath -StandardsPath $StandardsPath) {
        $lines.Add("| $($row.Area) | $($row.InForce) | $($row.CheckedByTool) | $($row.Advisory) | $($row.Proposed) | $($row.OpenGaps) |")
    }

    # The summary counts each rule once, however many areas name it.
    $rules = @((Get-KitRule -StandardsPath $StandardsPath).Values)
    $inForce = @($rules | Where-Object Status -EQ 'accepted')
    $advisory = @($inForce | Where-Object Advisory).Count
    $proposed = @($rules | Where-Object Status -EQ 'proposed').Count
    $openGaps = 0
    foreach ($area in @((Read-FrontMatter -Path $ScorecardPath)['areas'])) {
        $gaps = @($(if ($area.Contains('gaps')) { $area['gaps'] }) | Where-Object { $_ })
        $openGaps += @($gaps | Where-Object { "$($_['status'])" -ne 'closed' }).Count
    }
    $ruleNoun = if ($inForce.Count -eq 1) { 'rule' } else { 'rules' }
    $gapNoun = if ($openGaps -eq 1) { 'gap' } else { 'gaps' }
    $lines.Add('')
    $lines.Add("**Overall:** $($inForce.Count) $ruleNoun in force, $($inForce.Count - $advisory) checked by a tool and $advisory advisory; $proposed proposed; $openGaps open $gapNoun.")
    $lines -join "`n"
}

# The text between the table markers, or $null when the file has no markers.
function Get-ScorecardTableText {
    param([Parameter(Mandatory)] [string] $Text)
    $pattern = "(?s)$([regex]::Escape($script:TableStart))\r?\n?(.*?)\r?\n?$([regex]::Escape($script:TableEnd))"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { $match.Groups[1].Value } else { $null }
}

function Get-ScorecardTableProblem {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath
    )

    $current = Get-ScorecardTableText -Text (Get-Content -Raw -LiteralPath $ScorecardPath)
    if ($null -eq $current) {
        return New-Problem -Message "has no table: add the lines $script:TableStart and $script:TableEnd, then run ./tools/Test-Scorecard.ps1 -Update"
    }
    $expected = Format-ScorecardTable -ScorecardPath $ScorecardPath -StandardsPath $StandardsPath
    if (($current -replace "`r`n", "`n").Trim() -ne $expected.Trim()) {
        New-Problem -Message 'table is out of date with the rules: run ./tools/Test-Scorecard.ps1 -Update and commit the result'
    }
}

# Rewrites the table between the markers; the rest of the file stays as it is.
function Update-ScorecardTable {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath
    )

    $text = Get-Content -Raw -LiteralPath $ScorecardPath
    if ($null -eq (Get-ScorecardTableText -Text $text)) {
        throw "$ScorecardPath has no table markers ($script:TableStart, $script:TableEnd)."
    }
    $table = Format-ScorecardTable -ScorecardPath $ScorecardPath -StandardsPath $StandardsPath
    $pattern = "(?s)$([regex]::Escape($script:TableStart)).*?$([regex]::Escape($script:TableEnd))"
    $updated = [regex]::Replace($text, $pattern, { param($m) "$script:TableStart`n$table`n$script:TableEnd" })
    Set-Content -LiteralPath $ScorecardPath -Value $updated -NoNewline
}

function Get-ScorecardProblem {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    $rules = Get-KitRule -StandardsPath $StandardsPath
    $scorecard = Read-FrontMatter -Path $ScorecardPath
    $named = @{}
    $gapsSeen = @{}
    foreach ($area in @($scorecard['areas'])) {
        $areaId = "$($area['id'])"
        foreach ($field in $script:RequiredAreaFields) {
            if (-not $area.Contains($field) -or -not (Test-Present $area[$field])) {
                New-Problem -Area $areaId -Message "is missing '$field'"
            }
        }
        $areaRules = @($(if ($area.Contains('rules')) { $area['rules'] }) | Where-Object { $_ })
        $areaGaps = @($(if ($area.Contains('gaps')) { $area['gaps'] }) | Where-Object { $_ })
        if (-not $areaRules -and -not $areaGaps) {
            New-Problem -Area $areaId -Message 'has no rules and no gaps: list the rules that cover it, or what is missing'
        }
        foreach ($gap in $areaGaps) {
            $gapId = if ($gap.Contains('id')) { "$($gap['id'])" } else { '' }
            foreach ($field in $script:RequiredGapFields) {
                if (-not $gap.Contains($field) -or -not (Test-Present $gap[$field])) {
                    New-Problem -Area $areaId -Message "has a gap $gapId missing '$field'"
                }
            }
            if ($gap.Contains('status') -and (Test-Present $gap['status']) -and "$($gap['status'])" -notin $script:GapStatuses) {
                New-Problem -Area $areaId -Message "gap $gapId has status '$($gap['status'])'; it must be one of: $($script:GapStatuses -join ', ')"
            }
            if ($gapId) {
                if ($gapsSeen.ContainsKey($gapId)) {
                    New-Problem -Area $areaId -Message "gap id $gapId is already used in area $($gapsSeen[$gapId])"
                }
                else { $gapsSeen[$gapId] = $areaId }
            }
        }
        foreach ($source in @(if ($area.Contains('sources')) { $area['sources'] })) {
            $message = Get-SourceProblem -Source "$source" -AdrPath $AdrPath
            if ($message) { New-Problem -Area $areaId -Message $message }
        }
        foreach ($ruleId in $areaRules) {
            $named["$ruleId"] = $true
            if (-not $rules.Contains("$ruleId")) {
                New-Problem -Area $areaId -Message "names rule $ruleId, which no standard in $StandardsPath has"
            }
            elseif ($rules["$ruleId"].Status -eq 'retired') {
                New-Problem -Area $areaId -Message "names rule $ruleId, which is retired"
            }
        }
    }
    foreach ($rule in $rules.Values) {
        if ($rule.Status -eq 'accepted' -and -not $named.ContainsKey($rule.Id)) {
            New-Problem -Message "rule $($rule.Id) is in force but no area names it"
        }
    }
}

# Prints every problem and returns 0 when the scorecard matches the rules, otherwise 1. With -Update, the table
# is rewritten first, so only the other problems remain.
function Invoke-ScorecardCheck {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath,
        [switch] $Update
    )

    if ($Update) { Update-ScorecardTable -ScorecardPath $ScorecardPath -StandardsPath $StandardsPath }
    $problems = @(Get-ScorecardProblem -ScorecardPath $ScorecardPath -StandardsPath $StandardsPath -AdrPath $AdrPath) +
        @(Get-ScorecardTableProblem -ScorecardPath $ScorecardPath -StandardsPath $StandardsPath)
    $problems = @($problems | Where-Object { $_ })
    foreach ($problem in $problems) {
        $where = if ($problem.Area) { "$($problem.Area): " } else { '' }
        Write-Host "  $where$($problem.Message)" -ForegroundColor Red
    }
    if ($problems) {
        Write-Host "`n$($problems.Count) scorecard problem(s) in $ScorecardPath." -ForegroundColor Red
        return 1
    }

    $areas = @((Read-FrontMatter -Path $ScorecardPath)['areas']).Count
    $noun = if ($areas -eq 1) { 'area' } else { 'areas' }
    Write-Host "$areas $noun, consistent with the rules." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    if (-not $ScorecardPath) { $ScorecardPath = Join-Path $repoRoot 'docs' 'quality' 'scorecard.md' }
    if (-not $StandardsPath) { $StandardsPath = Join-Path $repoRoot 'docs' 'standards' }
    if (-not $AdrPath) { $AdrPath = Join-Path $repoRoot 'docs' 'adr' }
    exit (Invoke-ScorecardCheck -ScorecardPath $ScorecardPath -StandardsPath $StandardsPath -AdrPath $AdrPath -Update:$Update)
}
