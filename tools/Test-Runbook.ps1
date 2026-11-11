#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when an app's runbook is missing a required section (OPS-004, ADR-0046).
#>
[CmdletBinding()]
param(
    [string] $Path = 'docs/runbook.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredSections = @(
    'Where it runs', 'How to deploy a release', 'How to roll back a release', 'How to check its health',
    'How to read its telemetry', 'How to restore its data', 'How to respond to an incident'
)

# Draft until the app's first production deployment; In use from then on.
$script:Statuses = 'Draft', 'In use'

# What the template marks for the app to fill in, such as "[fill in: the production URL]".
$script:PlaceholderPattern = '\[fill in:[^\]]*\]'

function New-Problem {
    param([string] $Message)
    [pscustomobject]@{ Message = $Message }
}

# The value of the first "- **<Name>:** value" line, trimmed; $null when there's no such line.
function Get-RunbookField {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [string] $Name
    )

    $prefix = "^- \*\*$([regex]::Escape($Name)):\*\* "
    $line = $Lines | Where-Object { $_ -match $prefix } | Select-Object -First 1
    if ($null -eq $line) { return $null }
    ($line -replace $prefix, '').Trim()
}

# Splits a runbook into its "## " sections: an ordered map of heading to body text. A "## " line inside a
# fenced code block is code, such as a shell comment, not a heading.
function Get-RunbookSection {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $sections = [ordered]@{}
    $current = $null
    $fence = $null
    foreach ($line in $Lines) {
        if ($line -match '^ {0,3}(?<marker>`{3,}|~{3,})') {
            $marker = $Matches['marker']
            if ($null -eq $fence) { $fence = $marker }
            elseif ($marker[0] -eq $fence[0] -and $marker.Length -ge $fence.Length) { $fence = $null }
        }
        elseif ($null -eq $fence -and $line -match '^## (.+?)\s*$') {
            $current = $Matches[1]
            $sections[$current] = [System.Collections.Generic.List[string]]::new()
            continue
        }
        if ($null -ne $current) { $sections[$current].Add($line) }
    }
    $result = [ordered]@{}
    foreach ($name in $sections.Keys) {
        $result[$name] = ($sections[$name] -join "`n").Trim()
    }
    $result
}

function Invoke-RunbookCheck {
    param([Parameter(Mandatory)] [string] $Path)
    0
}

function Get-RunbookProblem {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $lines = @(Get-Content -LiteralPath $Path)
    $sections = Get-RunbookSection -Lines $lines

    $status = Get-RunbookField -Lines $lines -Name 'Status'
    if ($null -eq $status) {
        New-Problem -Message "the '- **Status:** ' line is missing"
    }
    elseif ($status -cnotin $script:Statuses) {
        New-Problem -Message "status '$status' must be 'Draft' or 'In use'"
    }

    $reviewed = Get-RunbookField -Lines $lines -Name 'Last reviewed'
    if ($null -eq $reviewed) {
        New-Problem -Message "the '- **Last reviewed:** ' line is missing"
    }

    # A Draft may keep its placeholders; once the app is deployed, the runbook is In use and complete.
    if ($status -ceq 'In use') {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($match in [regex]::Matches($lines[$i], $script:PlaceholderPattern)) {
                New-Problem -Message "line $($i + 1): '$($match.Value)' must be filled in before the runbook is In use"
            }
        }
        $parsed = [datetime]::MinValue
        if ($null -ne $reviewed -and -not [datetime]::TryParseExact($reviewed, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, 'None', [ref] $parsed)) {
            New-Problem -Message "review date '$reviewed' must be YYYY-MM-DD"
        }
    }

    foreach ($name in $script:RequiredSections) {
        if (-not $sections.Contains($name)) {
            New-Problem -Message "section '$name' is missing"
        }
        elseif (-not $sections[$name]) {
            New-Problem -Message "section '$name' is empty"
        }
    }
}
