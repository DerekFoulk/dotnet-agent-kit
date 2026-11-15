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
