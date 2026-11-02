#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when any ADR is missing a required section (brief §5, checkpoint §3).

.DESCRIPTION
    Checks every docs/adr/NNNN-short-title.md except the 0000 template: a "# ADR-NNNN: <title>" line that
    matches the file number; "- **Status:** " (Proposed, Accepted, Rejected, Deprecated or Superseded by
    ADR-NNNN) and "- **Date:** YYYY-MM-DD" lines; non-empty Context, Options, Recommendation, Decision,
    Consequences, Pillars affected and Sources sections; and at least two "### " options, each with
    Trade-offs, Reversibility and Risk. Exit code: 0 when every ADR is complete, otherwise 1.

.EXAMPLE
    ./tools/Test-AdrSections.ps1
#>
[CmdletBinding()]
param(
    [string] $AdrPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredSections = 'Context', 'Options', 'Recommendation', 'Decision', 'Consequences', 'Pillars affected', 'Sources'
$script:OptionFields = 'Trade-offs', 'Reversibility', 'Risk'
$script:StatusPattern = '(Proposed|Accepted|Rejected|Deprecated|Superseded by ADR-\d{4})'

function New-Problem {
    param([string] $File, [string] $Message)
    [pscustomobject]@{ File = $File; Message = $Message }
}

# Splits an ADR into its "## " sections: an ordered map of heading to body text.
function Get-AdrSection {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $sections = [ordered]@{}
    $current = $null
    foreach ($line in $Lines) {
        if ($line -match '^## (.+?)\s*$') {
            $current = $Matches[1]
            $sections[$current] = [System.Collections.Generic.List[string]]::new()
        }
        elseif ($null -ne $current) {
            $sections[$current].Add($line)
        }
    }
    $result = [ordered]@{}
    foreach ($name in $sections.Keys) {
        $result[$name] = ($sections[$name] -join "`n").Trim()
    }
    $result
}

function Get-AdrSectionProblem {
    param([Parameter(Mandatory)] [string] $AdrPath)

    # 0000-template.md holds placeholders by design.
    $files = Get-ChildItem -Path $AdrPath -Filter '*.md' -File | Where-Object Name -NotLike '0000-*' | Sort-Object Name
    foreach ($file in $files) {
        $lines = @(Get-Content -Path $file.FullName)
        $sections = Get-AdrSection -Lines $lines

        if ($file.Name -notmatch '^(\d{4})-[a-z0-9-]+\.md$') {
            New-Problem -File $file.Name -Message "file name must be NNNN-short-title.md"
        }
        else {
            $number = $Matches[1]
            if (-not ($lines | Where-Object { $_ -match "^# ADR-${number}: \S" })) {
                New-Problem -File $file.Name -Message "title must read '# ADR-${number}: <title>'"
            }
        }

        $status = $lines | Where-Object { $_ -match '^- \*\*Status:\*\* ' } | Select-Object -First 1
        if (-not $status) {
            New-Problem -File $file.Name -Message "the '- **Status:** ' line is missing"
        }
        elseif ($status -notmatch "^- \*\*Status:\*\* $script:StatusPattern\s*$") {
            $value = $status -replace '^- \*\*Status:\*\* ', ''
            New-Problem -File $file.Name -Message "status '$value' must be Proposed, Accepted, Rejected, Deprecated or 'Superseded by ADR-NNNN'"
        }

        $date = $lines | Where-Object { $_ -match '^- \*\*Date:\*\* ' } | Select-Object -First 1
        if (-not $date) {
            New-Problem -File $file.Name -Message "the '- **Date:** ' line is missing"
        }
        else {
            $value = ($date -replace '^- \*\*Date:\*\* ', '').Trim()
            $parsed = [datetime]::MinValue
            if (-not [datetime]::TryParseExact($value, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, 'None', [ref] $parsed)) {
                New-Problem -File $file.Name -Message "date '$value' must be YYYY-MM-DD"
            }
        }

        foreach ($name in $script:RequiredSections) {
            if (-not $sections.Contains($name)) {
                New-Problem -File $file.Name -Message "section '$name' is missing"
            }
            elseif (-not $sections[$name]) {
                New-Problem -File $file.Name -Message "section '$name' is empty"
            }
        }

        if ($sections.Contains('Options') -and $sections['Options']) {
            # Each "### " option records its trade-offs, reversibility and risk (WAF, brief §5).
            $options = @($sections['Options'] -split '(?m)^(?=### )' | Where-Object { $_ -match '^### ' })
            if ($options.Count -lt 2) {
                New-Problem -File $file.Name -Message 'Options needs at least two options (### headings), so the rejected one is recorded'
            }
            foreach ($option in $options) {
                $title = (($option -split "`n")[0] -replace '^### ', '').Trim()
                foreach ($field in $script:OptionFields) {
                    if ($option -notmatch "(?m)^- \*\*${field}:\*\* \S") {
                        New-Problem -File $file.Name -Message "option '$title' is missing '- **${field}:** '"
                    }
                }
            }
        }
    }
}

# Prints every problem and returns 0 when every ADR is complete, otherwise 1.
function Invoke-AdrSectionCheck {
    param([Parameter(Mandatory)] [string] $AdrPath)

    $problems = @(Get-AdrSectionProblem -AdrPath $AdrPath)
    foreach ($problem in $problems) {
        Write-Host "  $($problem.File): $($problem.Message)" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) ADR problem(s) in $AdrPath." -ForegroundColor Red
        return 1
    }

    $adrCount = @(Get-ChildItem -Path $AdrPath -Filter '*.md' -File | Where-Object Name -NotLike '0000-*').Count
    $noun = if ($adrCount -eq 1) { 'ADR' } else { 'ADRs' }
    Write-Host "$adrCount $noun, all complete." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $AdrPath) { $AdrPath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'docs' 'adr' }
    exit (Invoke-AdrSectionCheck -AdrPath $AdrPath)
}
