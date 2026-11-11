#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when an app's runbook is missing a required part, or is In use with a step left to fill in (OPS-004,
    ADR-0046).

.DESCRIPTION
    Checks one runbook, docs/runbook.md by default: a "- **Status:** " line that reads Draft or In use; a
    "- **Last reviewed:** " line; and a non-empty "## " section for each task in $RequiredSections, each a
    how-to guide. A "## " line inside a fenced code block is code, not a heading. A Draft may keep the
    template's "[fill in: ...]" placeholders. An In use runbook, the status from the app's first production
    deployment on, may not, and its review date must be YYYY-MM-DD. Exit code: 0 when the runbook passes,
    otherwise 1.

.EXAMPLE
    ./.kit/tools/Test-Runbook.ps1 -Path ./docs/runbook.md
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

# Splits a runbook into its "## " sections, in order: one Name and Body (trimmed text) each, a repeated heading
# included. It reads them as Markdown (CommonMark) does: a "## " line inside a fenced code block is code, such as
# a shell comment, not a heading; a fence closes only on a line of the same character, at least as long, with
# nothing after it; and a heading's closing hashes aren't part of its name.
function Get-RunbookSection {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $sections = [System.Collections.Generic.List[object]]::new()
    $body = $null
    $fence = $null
    foreach ($line in $Lines) {
        if ($null -eq $fence -and $line -match '^ {0,3}(?<marker>`{3,}|~{3,})') {
            $fence = $Matches['marker']
        }
        elseif ($null -ne $fence -and $line -match '^ {0,3}(?<marker>`{3,}|~{3,})\s*$' -and
            $Matches['marker'][0] -eq $fence[0] -and $Matches['marker'].Length -ge $fence.Length) {
            $fence = $null
        }
        elseif ($null -eq $fence -and $line -match '^## (?<name>.+?)(?:\s+#+)?\s*$') {
            $body = [System.Collections.Generic.List[string]]::new()
            $sections.Add([pscustomobject]@{ Name = $Matches['name']; Lines = $body })
            continue
        }
        if ($null -ne $body) { $body.Add($line) }
    }
    foreach ($section in $sections) {
        [pscustomobject]@{ Name = $section.Name; Body = ($section.Lines -join "`n").Trim() }
    }
}

function Get-RunbookProblem {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        New-Problem -Message "there's no runbook at '$Path'"
        return
    }
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
        $found = @($sections | Where-Object Name -EQ $name)
        if (-not $found) {
            New-Problem -Message "section '$name' is missing"
        }
        elseif ($found.Count -gt 1) {
            New-Problem -Message "section '$name' appears more than once"
        }
        # An HTML comment doesn't show when the runbook is read, so it doesn't count as a step.
        elseif (-not ($found[0].Body -replace '(?s)<!--.*?-->', '').Trim()) {
            New-Problem -Message "section '$name' is empty"
        }
    }
}

# Prints every problem and returns 0 when the runbook passes, otherwise 1.
function Invoke-RunbookCheck {
    param([Parameter(Mandatory)] [string] $Path)

    $problems = @(Get-RunbookProblem -Path $Path)
    foreach ($problem in $problems) {
        Write-Host "  $($problem.Message)" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) runbook problem(s) in $Path." -ForegroundColor Red
        return 1
    }

    Write-Host "The runbook at $Path is complete." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-RunbookCheck -Path $Path)
}
