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
# Fields written as one line of text; a list or map there would print as "System.Collections.Hashtable".
$script:AreaTextFields = 'id', 'name', 'perfect'
$script:GapTextFields = 'id', 'gap', 'status', 'needs'
$script:GapStatuses = 'proposed', 'planned', 'closed'
# -Update writes the table of counts between these lines.
$script:TableStart = '<!-- scorecard-table:start -->'
$script:TableEnd = '<!-- scorecard-table:end -->'

function New-Problem {
    param([string] $Area, [string] $Message)
    [pscustomobject]@{ Area = $Area; Message = $Message }
}

# The scorecard's areas as written: anything under 'areas', which may not all be maps. Get-ScorecardProblem
# reports what isn't a map; the counting functions skip it, so a malformed file is reported, not a crash.
function Get-ScorecardAreaList {
    param([Parameter(Mandatory)] [string] $ScorecardPath)
    $frontMatter = Read-FrontMatter -Path $ScorecardPath
    if ($frontMatter -isnot [Collections.IDictionary] -or -not $frontMatter.Contains('areas')) { return $null }
    # The comma keeps a list a list: PowerShell would otherwise unroll it, or turn a one-map list into the map.
    , $frontMatter['areas']
}

# Each entry under 'areas', empty ones included (as $null), so they can be reported. A single map written
# where the list should be gives no entries; Get-ScorecardProblem reports it.
function Get-ScorecardEntry {
    param([Parameter(Mandatory)] [string] $ScorecardPath)
    $list = Get-ScorecardAreaList -ScorecardPath $ScorecardPath
    if ($null -eq $list -or $list -is [Collections.IDictionary]) { return @() }
    @($list)
}

# True for a value written as text (or a number or date), not a list or a map.
function Test-Text {
    param($Value)
    $null -ne $Value -and ($Value -is [string] -or $Value -isnot [Collections.IEnumerable])
}

# What's wrong with a field that must be one line of text, or $null when it's fine (or blank: the required
# fields check reports that). A multi-line value would split its row in the table.
function Get-TextFieldProblem {
    param($Value)
    if ($null -eq $Value) { return $null }
    if (-not (Test-Text $Value)) { return "isn't text" }
    if ("$Value".Trim() -match '|
') { return 'is written over several lines' }
    $null
}

function Get-ScorecardArea {
    param([Parameter(Mandatory)] [string] $ScorecardPath)
    @(Get-ScorecardEntry -ScorecardPath $ScorecardPath | Where-Object { $_ -is [Collections.IDictionary] })
}

# An area's gaps that are maps; others are reported by Get-ScorecardProblem.
function Get-AreaGap {
    param([Parameter(Mandatory)] [Collections.IDictionary] $Area)
    @($(if ($Area.Contains('gaps')) { $Area['gaps'] }) | Where-Object { $_ -is [Collections.IDictionary] })
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
# enforcement starts with "advisory" is advisory; any other start (build, ci, ruleset, check, restore, settings)
# counts as checked by a tool, even when the text adds that part is advisory, so it's an upper bound.
# Proposed rules aren't in force, so they're counted apart. Unknown rule ids are skipped here;
# Get-ScorecardProblem reports them.
function Get-ScorecardRow {
    param(
        [Parameter(Mandatory)] [string] $ScorecardPath,
        [Parameter(Mandatory)] [string] $StandardsPath
    )

    $rules = Get-KitRule -StandardsPath $StandardsPath
    foreach ($area in Get-ScorecardArea -ScorecardPath $ScorecardPath) {
        $areaRules = @(@($(if ($area.Contains('rules')) { $area['rules'] })) | Where-Object { $_ -and $rules.Contains("$_") } |
                ForEach-Object { $rules["$_"] })
        $inForce = @($areaRules | Where-Object Status -EQ 'accepted')
        $gaps = Get-AreaGap -Area $area
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
    # Each open gap, so a reader sees what's missing without reading the YAML.
    $gapLines = [Collections.Generic.List[string]]::new()
    foreach ($area in Get-ScorecardArea -ScorecardPath $ScorecardPath) {
        $gaps = Get-AreaGap -Area $area
        foreach ($gap in @($gaps | Where-Object { "$($_['status'])" -ne 'closed' })) {
            $needs = if ($gap.Contains('needs') -and (Test-Present $gap['needs'])) { "; needs $($gap['needs'])" } else { '' }
            $gapLines.Add("- **$($gap['id'])** ($($area['name']), $($gap['status'])$needs): $($gap['gap'])")
        }
    }
    $openGaps = $gapLines.Count
    $ruleNoun = if ($inForce.Count -eq 1) { 'rule' } else { 'rules' }
    $gapNoun = if ($openGaps -eq 1) { 'gap' } else { 'gaps' }
    $lines.Add('')
    $lines.Add("**Overall:** $($inForce.Count) $ruleNoun in force, $($inForce.Count - $advisory) checked by a tool and $advisory advisory; $proposed proposed; $openGaps open $gapNoun.")
    if ($gapLines.Count) {
        $lines.Add('')
        $lines.Add('Open gaps:')
        $lines.Add('')
        $lines.AddRange($gapLines)
    }
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
    $named = @{}
    $gapsSeen = @{}
    $areasSeen = @{}
    $entries = @(Get-ScorecardEntry -ScorecardPath $ScorecardPath)
    if ((Get-ScorecardAreaList -ScorecardPath $ScorecardPath) -is [Collections.IDictionary]) {
        New-Problem -Message "'areas' is one map; it must be a list, with each area starting '- id:'"
    }
    elseif (-not $entries) {
        New-Problem -Message "has no areas: its front matter needs an 'areas' list"
    }
    $position = 0
    foreach ($area in $entries) {
        $position++
        if ($null -eq $area) {
            New-Problem -Message "area $position is empty"
            continue
        }
        if ($area -isnot [Collections.IDictionary]) {
            New-Problem -Message "area $position ('$area') is not a map with id, name, perfect and sources"
            continue
        }
        $areaId = if (Test-Text $area['id']) { "$($area['id'])" } else { "area $position" }
        foreach ($field in $script:AreaTextFields) {
            $problem = if ($area.Contains($field)) { Get-TextFieldProblem $area[$field] }
            if ($problem) { New-Problem -Area $areaId -Message "has a '$field' that $problem`: write it on one line" }
        }
        if ($areaId) {
            if ($areasSeen.ContainsKey($areaId)) { New-Problem -Area $areaId -Message "area id $areaId is already used" }
            else { $areasSeen[$areaId] = $true }
        }
        foreach ($field in $script:RequiredAreaFields) {
            if (-not $area.Contains($field) -or -not (Test-Present $area[$field])) {
                New-Problem -Area $areaId -Message "is missing '$field'"
            }
        }
        $areaRules = @($(if ($area.Contains('rules')) { $area['rules'] }) | Where-Object { $_ })
        foreach ($field in 'rules', 'sources') {
            $items = @($(if ($area.Contains($field)) { $area[$field] }) | Where-Object { $_ })
            if (@($items | Where-Object { -not (Test-Text $_) })) {
                New-Problem -Area $areaId -Message "lists $field that aren't text: write each as one line, such as '- STY-001' or '- owner, 2026-11-07'"
            }
        }
        $areaRules = @($areaRules | Where-Object { Test-Text $_ })
        $areaGaps = @($(if ($area.Contains('gaps')) { $area['gaps'] }) | Where-Object { $_ })
        foreach ($gap in @($areaGaps | Where-Object { $_ -isnot [Collections.IDictionary] })) {
            New-Problem -Area $areaId -Message "has a gap '$gap' that is not a map with id, gap and status"
        }
        $areaGaps = Get-AreaGap -Area $area
        if (-not $areaRules -and -not $areaGaps) {
            New-Problem -Area $areaId -Message 'has no rules and no gaps: list the rules that cover it, or what is missing'
        }
        foreach ($gap in $areaGaps) {
            $gapId = if ($gap.Contains('id') -and (Test-Text $gap['id'])) { "$($gap['id'])" } else { '' }
            foreach ($field in $script:GapTextFields) {
                $problem = if ($gap.Contains($field)) { Get-TextFieldProblem $gap[$field] }
                if ($problem) { New-Problem -Area $areaId -Message "has a gap $gapId whose '$field' $problem`: write it on one line" }
            }
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
        foreach ($source in @(@(if ($area.Contains('sources')) { $area['sources'] }) | Where-Object { Test-Text $_ })) {
            $message = Get-SourceProblem -Source "$source" -AdrPath $AdrPath
            if ($message) { New-Problem -Area $areaId -Message $message }
        }
        foreach ($ruleId in @($areaRules | Group-Object { "$_" } | Where-Object Count -GT 1 | ForEach-Object Name)) {
            New-Problem -Area $areaId -Message "names rule $ruleId twice"
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

    $areas = @(Get-ScorecardArea -ScorecardPath $ScorecardPath).Count
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
