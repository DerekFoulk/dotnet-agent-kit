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

# What docs/authorities.yml says about each publisher, and its classes (ADR-0070).
$script:EntryFields = 'name', 'publisher', 'class', 'covers', 'match'
$script:Classes = 'authority', 'practitioner', 'project'
# The page lists authorities first, then the tool pages ADR-0063 also counts as authorities, then practitioners.
$script:ClassOrder = [System.Collections.Generic.List[string]] @('authority', 'project', 'practitioner')
$script:ClassHeadings = @{ authority = 'Authorities'; project = 'Tool and project pages'; practitioner = 'Practitioners and references' }

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

# Every reason the page can't be built: an entry that's incomplete, a cited URL no entry matches, an entry no
# cited URL matches.
function Get-AuthoritiesProblem {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Cited,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Entries
    )

    foreach ($entry in $Entries) {
        $name = if ($entry.Contains('name') -and (Test-Present $entry['name'])) { $entry['name'] } else { '(no name)' }
        foreach ($field in $script:EntryFields) {
            if (-not $entry.Contains($field) -or -not (Test-Present $entry[$field])) { "entry '$name' is missing '$field'" }
        }
        if ($entry.Contains('class') -and (Test-Present $entry['class']) -and "$($entry['class'])" -notin $script:Classes) {
            "entry '$name' class '$($entry['class'])' must be one of: $($script:Classes -join ', ')"
        }
        # A folder URL, so 'https://github.com/dotnet/' can't also claim 'https://github.com/dotnetfoo'.
        foreach ($prefix in @($(if ($entry.Contains('match')) { $entry['match'] }))) {
            if ("$prefix" -notmatch '^https?://[^/\s]+/(\S*/)?$') {
                "entry '$name' match '$prefix' must be an http or https URL ending in '/'"
            }
        }
        # The page puts these in table cells, where a '|' ends the cell.
        foreach ($field in 'name', 'publisher', 'covers') {
            if ($entry.Contains($field) -and "$($entry[$field])".Contains('|')) { "entry '$name' $field has a '|', which would break the page's table" }
        }
    }
    # Each name is a heading, an anchor and the key the page groups citations by.
    foreach ($group in $Entries | Where-Object { $_.Contains('name') } | Group-Object { "$($_['name'])" } | Where-Object Count -GT 1) {
        "entry '$($group.Name)' has the same name as another; each name is a heading and an anchor, so give each its own"
    }

    $used = [System.Collections.Generic.HashSet[object]]::new()
    foreach ($citation in $Cited) {
        $entry = Find-SourceEntry -Url $citation.Url -Entries $Entries
        if ($entry) { [void] $used.Add($entry) }
        else { "$($citation.Url) ($($citation.RuleId)) matches no entry in docs/authorities.yml; add its publisher there (ADR-0070)" }
    }
    foreach ($entry in $Entries) {
        if (-not $used.Contains($entry)) { "entry '$($entry['name'])' matches no URL the rules cite; remove it" }
    }

    # ADR-0063: a rule resting on practitioners alone is a preference. A URL with no entry, or an entry with no valid
    # class, is reported above, so its rule isn't judged until that's fixed.
    foreach ($rule in $Cited | Where-Object Basis -EQ 'authority' | Group-Object RuleId) {
        $classes = @($rule.Group | ForEach-Object {
                $entry = Find-SourceEntry -Url $_.Url -Entries $Entries
                if ($entry -and $entry.Contains('class') -and "$($entry['class'])" -in $script:Classes) { "$($entry['class'])" } else { 'unknown' }
            })
        if ($classes -notcontains 'unknown' -and $classes -notcontains 'authority' -and $classes -notcontains 'project') {
            "$($rule.Name) has basis 'authority' but cites no page classed authority or project; cite one, or make it a preference (ADR-0063)"
        }
    }
}

# The generated block's Markdown, between its markers: a table per class, then each source's pages.
function ConvertTo-AuthoritiesBlock {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Cited,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Entries
    )

    $bySource = [ordered]@{}
    foreach ($entry in $Entries) { $bySource[$entry['name']] = [System.Collections.Generic.List[object]]::new() }
    foreach ($citation in $Cited) {
        $entry = Find-SourceEntry -Url $citation.Url -Entries $Entries
        if ($entry) { $bySource[$entry['name']].Add($citation) }
    }

    $pageCount = @($Cited | ForEach-Object Url | Sort-Object -Unique).Count
    $ruleCount = @($Cited | ForEach-Object RuleId | Sort-Object -Unique).Count
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("The rules cite $pageCount pages from $($Entries.Count) sources; $ruleCount rules cite them.")
    foreach ($class in $script:ClassOrder) {
        $lines.AddRange([string[]] @('', "### $($script:ClassHeadings[$class])", '', '| Source | Publisher | Covers | Cited by |', '|---|---|---|---|'))
        foreach ($entry in $Entries | Where-Object { $_['class'] -eq $class } | Sort-Object { $_['name'] }) {
            $name = $entry['name']
            $lines.Add("| [$name](#$(ConvertTo-HeadingAnchor $name)) | $($entry['publisher']) | $($entry['covers']) | $(ConvertTo-RuleLinks $bySource[$name]) |")
        }
    }
    $lines.AddRange([string[]] @('', '### Pages cited'))
    foreach ($class in $script:ClassOrder) {
        foreach ($entry in $Entries | Where-Object { $_['class'] -eq $class } | Sort-Object { $_['name'] }) {
            $lines.AddRange([string[]] @('', "#### $($entry['name'])", '', '| Page | Cited by |', '|---|---|'))
            foreach ($page in $bySource[$entry['name']] | Group-Object Url | Sort-Object Name) {
                $lines.Add("| <$($page.Name)> | $(ConvertTo-RuleLinks $page.Group) |")
            }
        }
    }
    ($lines -join "`n") + "`n"
}

# Each citing rule once, sorted, linked to its standard, with a proposed rule marked: it isn't in force yet.
function ConvertTo-RuleLinks {
    param([AllowEmptyCollection()] [object[]] $Citations)

    $rules = @($Citations | Sort-Object RuleId -Unique | ForEach-Object {
            $mark = if ($_.Status -eq 'proposed') { ' (proposed)' } else { '' }
            "[$($_.RuleId)](standards/$($_.File))$mark"
        })
    $rules -join ', '
}

# The anchor GitHub gives a heading: lower case, punctuation dropped, spaces as hyphens.
function ConvertTo-HeadingAnchor {
    param([Parameter(Mandatory)] [string] $Heading)
    (($Heading.ToLowerInvariant() -replace '[^\p{L}\p{N}\s-]', '') -replace '\s', '-')
}

# Fills the block in docs/authorities.md, or with -Check only compares it. Returns 0, or 1 after printing each problem;
# nothing is written unless every source is classed and the page has its block.
function Invoke-AuthoritiesPageBuild {
    param(
        [Parameter(Mandatory)] [string] $RepoRoot,
        [switch] $Check
    )

    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
    $pagePath = Join-Path $RepoRoot 'docs' 'authorities.md'
    # Kept across the catch, so a page that can't be filled is reported beside what was found before it.
    $problems = @()
    try {
        $entries = @(Read-SourceEntry -Path (Join-Path $RepoRoot 'docs' 'authorities.yml'))
        $cited = @(Get-CitedUrl -StandardsPath (Join-Path $RepoRoot 'docs' 'standards'))
        $problems += @(Get-AuthoritiesProblem -Cited $cited -Entries $entries)
        if (-not (Test-Path -LiteralPath $pagePath)) { $problems += 'docs/authorities.md is missing' }
        else {
            $current = (Get-Content -Raw -LiteralPath $pagePath) -replace "`r`n", "`n"
            $expected = Update-SourcesBlock -Text $current -Block (ConvertTo-AuthoritiesBlock -Cited $cited -Entries $entries)
        }
    }
    catch {
        $problems += $_.Exception.Message
    }

    if ($problems) {
        foreach ($problem in $problems) { Write-Host "  $problem" -ForegroundColor Red }
        Write-Host "`n$($problems.Count) problem(s); docs/authorities.md was not written." -ForegroundColor Red
        return 1
    }
    if ($current -ceq $expected) {
        Write-Host "docs/authorities.md is current: $($cited.Count) citations from $($entries.Count) sources." -ForegroundColor Green
        return 0
    }
    if ($Check) {
        Write-Host '  out of date: docs/authorities.md' -ForegroundColor Red
        Write-Host "`nRun ./tools/Build-AuthoritiesPage.ps1 and commit the result." -ForegroundColor Red
        return 1
    }
    Set-Content -LiteralPath $pagePath -Value $expected -NoNewline
    Write-Host 'updated: docs/authorities.md' -ForegroundColor Cyan
    0
}

# The entries of docs/authorities.yml. A missing file, or one without a 'sources' list, is a mistake to fix, not
# "no sources": every cited URL would then be reported, so stop with the real reason.
function Read-SourceEntry {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw 'docs/authorities.yml is missing; it classes every source the rules cite (ADR-0070).' }
    $data = ConvertFrom-Yaml -Yaml (Get-Content -Raw -LiteralPath $Path)
    if ($data -isnot [System.Collections.IDictionary] -or -not $data.Contains('sources') -or
        $data['sources'] -is [string] -or $data['sources'] -isnot [System.Collections.IEnumerable]) {
        throw "docs/authorities.yml has no 'sources' list."
    }
    @($data['sources'])
}

# Replaces what's between the block's markers, which must each be a line of their own; the rest stays the author's.
function Update-SourcesBlock {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        [Parameter(Mandatory)] [string] $Block
    )

    # One opening line and one closing line, in that order. A second opening line, such as one quoted in an example,
    # would otherwise start the match early and replace the hand-written text after it.
    $opens = [regex]::Matches($Text, '(?m)^<!-- sources from docs/standards[^\n]*-->$')
    $pattern = '(?ms)^(?<open><!-- sources from docs/standards[^\n]*-->)\n.*?^<!-- end sources -->$'
    $found = [regex]::Matches($Text, $pattern)
    if ($opens.Count -ne 1 -or $found.Count -ne 1) {
        throw "docs/authorities.md needs one block: one '<!-- sources from docs/standards ... -->' line, then one '<!-- end sources -->' line."
    }
    $Text.Substring(0, $found[0].Index) + $found[0].Groups['open'].Value + "`n" + $Block + '<!-- end sources -->' +
        $Text.Substring($found[0].Index + $found[0].Length)
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $RepoRoot) { $RepoRoot = Split-Path -Path $PSScriptRoot -Parent }
    exit (Invoke-AuthoritiesPageBuild -RepoRoot $RepoRoot -Check:$Check)
}
