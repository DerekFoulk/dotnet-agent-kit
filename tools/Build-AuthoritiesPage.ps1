#Requires -Version 7.6
<#
.SYNOPSIS
    Fills the generated block of docs/authorities.md: every source the rules in docs/standards cite, by publisher.

.DESCRIPTION
    Reads the URL sources of every rule in docs/standards that isn't retired, gives each URL to the entry in
    docs/authorities.yml with the longest matching prefix (an archived web.archive.org copy is matched by its
    original URL), and writes the block between '<!-- sources from docs/standards' and '<!-- end sources -->'
    in docs/authorities.md. The text outside the block is hand-written and left alone (ADR-0070).

    -Check writes nothing and exits 1 when a cited URL matches no entry, an entry matches no cited URL, an entry
    is incomplete, the block's markers are missing, or the block is stale.

.EXAMPLE
    ./tools/Build-AuthoritiesPage.ps1
    Regenerate after a rule's sources or docs/authorities.yml change, then commit the page.

.EXAMPLE
    ./tools/Build-AuthoritiesPage.ps1 -Check
    Fails if the page doesn't match the rules' sources (CI runs this in kit-checks).
#>
[CmdletBinding()]
param(
    [string] $RepoRoot,
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import-Module, not '#Requires -Modules', which breaks exit codes under -File (see tools/Test-RuleSources.ps1).
Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'
Import-Module -Name (Join-Path $PSScriptRoot 'KitFrontMatter.psm1') -Force

# Every URL source of the rules in docs/standards that aren't retired: one object per rule and URL, with the
# rule's id, status and basis.
function Get-CitedUrl {
    param([Parameter(Mandatory)] [string] $StandardsPath)

    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File | Sort-Object Name) {
        $frontMatter = Read-FrontMatter -Path $file.FullName
        if ($null -eq $frontMatter -or -not $frontMatter.Contains('rules')) { continue }
        foreach ($rule in @($frontMatter['rules'] | Where-Object { $_['status'] -ne 'retired' })) {
            foreach ($source in @($(if ($rule.Contains('sources')) { $rule['sources'] }))) {
                # The outside-source form Get-SourceProblem accepts (KitFrontMatter.psm1); Test-RuleSources reports
                # any source that doesn't have it, so a malformed one is left to that check.
                if ("$source" -notmatch '^(?<url>https?://\S+), retrieved \S+$') { continue }
                [pscustomobject]@{
                    Url    = ConvertTo-PageUrl -Url $Matches['url']
                    RuleId = "$($rule['id'])"
                    Status = "$($rule['status'])"
                    Basis  = "$($rule['basis'])"
                    File   = $file.Name
                }
            }
        }
    }
}

# One page cited two ways is one page: Microsoft Learn serves /en-us/x and /x alike, and a #fragment points
# into the same page.
function ConvertTo-PageUrl {
    param([Parameter(Mandatory)] [string] $Url)

    $page = $Url -replace '#.*$', ''
    $page -replace '^(https://learn\.microsoft\.com)/[a-z]{2}-[a-z]{2}/', '$1/'
}

# The entry in docs/authorities.yml whose 'match' prefixes include the longest one the URL starts with, or $null.
function Find-SourceEntry {
    param(
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Entries
    )

    # An archived copy is the original author's page, so it's matched by the URL it archives.
    if ($Url -match '^https?://web\.archive\.org/web/[^/]+/(?<original>https?://.+)$') { $Url = $Matches['original'] }
    $best = $null
    $bestLength = -1
    foreach ($entry in $Entries) {
        foreach ($prefix in @($entry['match'])) {
            if ($Url.StartsWith("$prefix", [System.StringComparison]::OrdinalIgnoreCase) -and "$prefix".Length -gt $bestLength) {
                $best = $entry
                $bestLength = "$prefix".Length
            }
        }
    }
    $best
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $RepoRoot) { $RepoRoot = Split-Path -Path $PSScriptRoot -Parent }
    exit 1
}
