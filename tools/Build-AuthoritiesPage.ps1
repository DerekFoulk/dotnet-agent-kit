#Requires -Version 7.6
<#
.SYNOPSIS
    Fills the generated blocks of docs/authorities.md (every source the rules in docs/standards cite, by publisher)
    and THIRD-PARTY-NOTICES.md (every work the rules quote, with its license).

.DESCRIPTION
    Reads the URL sources of every rule in docs/standards that isn't retired, gives each URL to the entry in
    docs/authorities.yml's 'sources' with the longest matching prefix (an archived web.archive.org copy is matched by
    its original URL), and writes the block between '<!-- sources from docs/standards' and '<!-- end sources -->'
    in docs/authorities.md (ADR-0073).

    Reads the page of every stored quote (ADR-0082), gives each to the entry in 'works' with the longest matching
    prefix, and writes the block between '<!-- quotes from docs/standards' and '<!-- end quotes -->' in
    THIRD-PARTY-NOTICES.md: each work's title, author, source and license, with links, as its license asks of a copy
    (ADR-0094). Apps get that file's text in their own notices, so the attribution travels with the quotes.
    The text outside each block is hand-written and left alone.

    -Check writes nothing and exits 1 when a cited URL matches no entry, an entry matches no cited URL, an entry
    is incomplete, a block's markers are missing, or a block is stale.

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

# What docs/authorities.yml says about each publisher, and its classes (ADR-0073).
$script:EntryFields = 'name', 'publisher', 'class', 'covers', 'match'
$script:Classes = 'authority', 'practitioner', 'project'
# The page lists authorities first, then the tool pages ADR-0063 also counts as authorities, then practitioners.
$script:ClassOrder = [System.Collections.Generic.List[string]] @('authority', 'project', 'practitioner')
$script:ClassHeadings = @{ authority = 'Authorities'; project = 'Tool and project pages'; practitioner = 'Practitioners and references' }
# What docs/authorities.yml says about each quoted work and each license (ADR-0094). A work's 'stated' is the page
# where its license is stated, such as its repo's LICENSE file, read on its 'checked' date.
$script:WorkFields = 'title', 'author', 'source', 'license', 'stated', 'checked', 'match'
$script:LicenseFields = 'id', 'name', 'url'

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

# Every stored quote's page (ADR-0082): one object per quote, with its rule and file. A retired rule's quotes count
# too: its words are still copied in the file.
function Get-QuotedPage {
    param([Parameter(Mandatory)] [string] $StandardsPath)

    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File | Sort-Object Name) {
        $frontMatter = Read-FrontMatter -Path $file.FullName
        if ($null -eq $frontMatter -or -not $frontMatter.Contains('rules')) { continue }
        foreach ($rule in @($frontMatter['rules'])) {
            if ($rule -isnot [System.Collections.IDictionary] -or -not $rule.Contains('quotes')) { continue }
            foreach ($quote in @($rule['quotes'])) {
                # A quote without a source is Test-RuleSources' to report.
                if ($quote -isnot [System.Collections.IDictionary] -or -not (Test-Present $quote['source'])) { continue }
                [pscustomobject]@{ Url = ConvertTo-PageUrl -Url "$($quote['source'])"; RuleId = "$($rule['id'])"; File = $file.Name }
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
            # A prefix is a folder, ending in '/'; the folder's own page, cited without that slash, is in it too.
            $inFolder = $Url.StartsWith("$prefix", [System.StringComparison]::OrdinalIgnoreCase) -or
                "$Url/".Equals("$prefix", [System.StringComparison]::OrdinalIgnoreCase)
            if ($inFolder -and "$prefix".Length -gt $bestLength) {
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
        else { "$($citation.Url) ($($citation.RuleId)) matches no entry in docs/authorities.yml; add its publisher there (ADR-0073)" }
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

# Each work that some quote comes from, with those quotes: keyed by the work's own entry, so a work with a missing or
# repeated title still gets its own quotes.
function Group-QuoteByWork {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Quoted,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Works
    )

    $byWork = [System.Collections.Generic.Dictionary[object, System.Collections.Generic.List[object]]]::new(
        [System.Collections.Generic.ReferenceEqualityComparer]::Instance)
    foreach ($quote in $Quoted) {
        $work = Find-SourceEntry -Url $quote.Url -Entries $Works
        if (-not $work) { continue }
        $key = $work.psobject.BaseObject
        if (-not $byWork.ContainsKey($key)) { $byWork[$key] = [System.Collections.Generic.List[object]]::new() }
        $byWork[$key].Add($quote)
    }
    , $byWork
}

# Every reason the notices can't be built (ADR-0094): a quote no work matches, a work no quote matches, a work or a
# license that's incomplete or malformed, a work naming a license the list doesn't have, a license no work uses.
function Get-NoticesProblem {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Quoted,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Works,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Licenses
    )

    $licenseIds = @($Licenses | Where-Object { $_ -is [System.Collections.IDictionary] -and $_.Contains('id') } | ForEach-Object { "$($_['id'])" })
    foreach ($license in $Licenses) {
        $id = if ($license.Contains('id') -and (Test-Present $license['id'])) { $license['id'] } else { '(no id)' }
        foreach ($field in $script:LicenseFields) {
            if (-not $license.Contains($field) -or -not (Test-Present $license[$field])) { "license '$id' is missing '$field'" }
        }
        if ($license.Contains('url') -and (Test-Present $license['url']) -and "$($license['url'])" -notmatch '^https?://\S+$') {
            "license '$id' url '$($license['url'])' must be an http or https URL"
        }
    }
    foreach ($work in $Works) {
        $title = if ($work.Contains('title') -and (Test-Present $work['title'])) { $work['title'] } else { '(no title)' }
        foreach ($field in $script:WorkFields) {
            if (-not $work.Contains($field) -or -not (Test-Present $work[$field])) { "work '$title' is missing '$field'" }
        }
        if ($work.Contains('license') -and (Test-Present $work['license']) -and "$($work['license'])" -notin $licenseIds) {
            "work '$title' license '$($work['license'])' isn't in docs/authorities.yml's licenses"
        }
        if ($work.Contains('checked') -and (Test-Present $work['checked']) -and -not (Test-IsoDate (ConvertTo-DateText $work['checked']))) {
            "work '$title' checked '$($work['checked'])' must be a date, yyyy-MM-dd"
        }
        foreach ($field in 'source', 'stated') {
            if ($work.Contains($field) -and (Test-Present $work[$field]) -and "$($work[$field])" -notmatch '^https?://\S+$') {
                "work '$title' $field '$($work[$field])' must be an http or https URL"
            }
        }
        foreach ($prefix in @($(if ($work.Contains('match')) { $work['match'] }))) {
            if ("$prefix" -notmatch '^https?://[^/\s]+/(\S*/)?$') { "work '$title' match '$prefix' must be an http or https URL ending in '/'" }
        }
        # The block puts these in table cells, where a '|' ends the cell.
        foreach ($field in 'title', 'author', 'copyright') {
            if ($work.Contains($field) -and "$($work[$field])".Contains('|')) { "work '$title' $field has a '|', which would break the notices table" }
        }
    }
    foreach ($group in $Works | Where-Object { $_.Contains('title') } | Group-Object { "$($_['title'])" } | Where-Object Count -GT 1) {
        "work '$($group.Name)' has the same title as another; give each its own"
    }

    $byWork = Group-QuoteByWork -Quoted $Quoted -Works $Works
    foreach ($quote in $Quoted | Where-Object { -not (Find-SourceEntry -Url $_.Url -Entries $Works) }) {
        "quote from $($quote.Url) ($($quote.RuleId)) matches no work in docs/authorities.yml; add the work and its license (ADR-0094)"
    }
    foreach ($work in $Works | Where-Object { -not $byWork.ContainsKey($_.psobject.BaseObject) }) {
        "work '$($work['title'])' matches no quoted page; remove it"
    }
    $usedLicenses = @($Works | Where-Object { $_.Contains('license') } | ForEach-Object { "$($_['license'])" })
    foreach ($id in $licenseIds | Where-Object { $_ -notin $usedLicenses }) { "license '$id' is used by no work; remove it" }
}

# The generated block of THIRD-PARTY-NOTICES.md: each quoted work with what its license asks a copy to name (title,
# author, source, license, with links; ADR-0094), where the license is stated, how many quotes come from it and the
# standards that hold them.
function ConvertTo-NoticesBlock {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Quoted,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Works,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Licenses
    )

    $byWork = Group-QuoteByWork -Quoted $Quoted -Works $Works
    $licenseById = @{}
    foreach ($license in $Licenses) { $licenseById["$($license['id'])"] = $license }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]] @("The rules quote $($Quoted.Count) passages from $($byWork.Count) works.", ''))
    $lines.AddRange([string[]] @('| Work | Author | License | License stated in | Quotes | Quoted in |', '|---|---|---|---|---|---|'))
    $quotedWorks = @($Works | Where-Object { $byWork.ContainsKey($_.psobject.BaseObject) } | Sort-Object { "$($_['title'])" })
    foreach ($work in $quotedWorks) {
        $quotes = $byWork[$work.psobject.BaseObject]
        $license = $licenseById["$($work['license'])"]
        $licenseText = if ($license) { "[$($license['name'])]($($license['url']))" } else { "$($work['license'])" }
        $author = if ($work.Contains('copyright') -and (Test-Present $work['copyright'])) { "$($work['author']); $($work['copyright'])" } else { "$($work['author'])" }
        $files = @($quotes | ForEach-Object File | Sort-Object -Unique | ForEach-Object { "[$_](docs/standards/$_)" }) -join ', '
        $lines.Add("| [$($work['title'])]($($work['source'])) | $author | $licenseText | <$($work['stated'])>, checked $(ConvertTo-DateText $work['checked']) | $($quotes.Count) | $files |")
    }

    # What a license asks beyond the row (its 'note'), for each license a quoted work uses, in the order the licenses
    # are listed; then each work's own notice, such as the copyright and status lines the W3C's license asks for.
    $usedIds = @($quotedWorks | ForEach-Object { "$($_['license'])" })
    $notes = @(
        $Licenses | Where-Object { "$($_['id'])" -in $usedIds -and $_.Contains('note') -and (Test-Present $_['note']) } |
            ForEach-Object { "- [$($_['name'])]($($_['url'])): $($_['note'])" }
        $quotedWorks | Where-Object { $_.Contains('notice') -and (Test-Present $_['notice']) } |
            ForEach-Object { "- [$($_['title'])]($($_['source'])): $($_['notice'])" }
    )
    if ($notes) { $lines.Add(''); $lines.AddRange([string[]] $notes) }
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
    # The two generated files: what each is called in messages, where it is, the word its block's markers use, and
    # how to make its block once the data is read.
    $targets = @(
        [pscustomobject]@{ Name = 'docs/authorities.md'; Path = Join-Path $RepoRoot 'docs' 'authorities.md'; Marker = 'sources'
            Block = { ConvertTo-AuthoritiesBlock -Cited $cited -Entries $data.Sources }; Current = $null; Expected = $null }
        [pscustomobject]@{ Name = 'THIRD-PARTY-NOTICES.md'; Path = Join-Path $RepoRoot 'THIRD-PARTY-NOTICES.md'; Marker = 'quotes'
            Block = { ConvertTo-NoticesBlock -Quoted $quoted -Works $data.Works -Licenses $data.Licenses }; Current = $null; Expected = $null }
    )
    # Kept across the catch, so a file that can't be filled is reported beside what was found before it.
    $problems = @()
    try {
        $data = Read-AuthoritiesData -Path (Join-Path $RepoRoot 'docs' 'authorities.yml')
        $standardsPath = Join-Path $RepoRoot 'docs' 'standards'
        $cited = @(Get-CitedUrl -StandardsPath $standardsPath)
        $quoted = @(Get-QuotedPage -StandardsPath $standardsPath)
        $problems += @(Get-AuthoritiesProblem -Cited $cited -Entries $data.Sources)
        $problems += @(Get-NoticesProblem -Quoted $quoted -Works $data.Works -Licenses $data.Licenses)
        foreach ($target in $targets) {
            if (-not (Test-Path -LiteralPath $target.Path)) { $problems += "$($target.Name) is missing"; continue }
            $target.Current = (Get-Content -Raw -LiteralPath $target.Path) -replace "`r`n", "`n"
            try { $target.Expected = Update-GeneratedBlock -Text $target.Current -Block (& $target.Block) -Marker $target.Marker -Name $target.Name }
            catch { $problems += $_.Exception.Message }
        }
    }
    catch {
        $problems += $_.Exception.Message
    }

    if ($problems) {
        foreach ($problem in $problems) { Write-Host "  $problem" -ForegroundColor Red }
        Write-Host "`n$($problems.Count) problem(s); docs/authorities.md and THIRD-PARTY-NOTICES.md were not written." -ForegroundColor Red
        return 1
    }
    $stale = @($targets | Where-Object { $_.Current -cne $_.Expected })
    if (-not $stale) {
        Write-Host "docs/authorities.md and THIRD-PARTY-NOTICES.md are current: $($cited.Count) citations from $($data.Sources.Count) sources, $($quoted.Count) quotes from $($data.Works.Count) works." -ForegroundColor Green
        return 0
    }
    if ($Check) {
        foreach ($target in $stale) { Write-StaleDifference -Name $target.Name -Expected $target.Expected -Current $target.Current }
        Write-Host "`nRun ./tools/Build-AuthoritiesPage.ps1 and commit the result." -ForegroundColor Red
        return 1
    }
    foreach ($target in $stale) {
        Set-Content -LiteralPath $target.Path -Value $target.Expected -NoNewline
        Write-Host "updated: $($target.Name)" -ForegroundColor Cyan
    }
    0
}

# Says a generated file is out of date, with the first line that differs, so a failure in CI shows what changed
# without a local run.
function Write-StaleDifference {
    param([Parameter(Mandatory)] [string] $Name, [Parameter(Mandatory)] [string] $Expected, [Parameter(Mandatory)] [string] $Current)

    Write-Host "  out of date: $Name" -ForegroundColor Red
    $want = $Expected -split "`n"
    $have = $Current -split "`n"
    $line = 0
    while ($line -lt $want.Count -and $line -lt $have.Count -and $want[$line] -ceq $have[$line]) { $line++ }
    Write-Host "  first difference, line $($line + 1):" -ForegroundColor Red
    Write-Host "    expected: $(if ($line -lt $want.Count) { $want[$line] } else { '(end of page)' })" -ForegroundColor Red
    Write-Host "    found:    $(if ($line -lt $have.Count) { $have[$line] } else { '(end of page)' })" -ForegroundColor Red
}

# The lists in docs/authorities.yml: Sources (each publisher, ADR-0073), and Works and Licenses (each quoted work and
# its license, ADR-0094; empty when absent, so a quote is then reported as having no work). A missing file, or one
# without a 'sources' list, is a mistake to fix, not "no sources": every cited URL would then be reported, so stop with
# the real reason.
function Read-AuthoritiesData {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw 'docs/authorities.yml is missing; it classes every source the rules cite (ADR-0073).' }
    $data = ConvertFrom-Yaml -Yaml (Get-Content -Raw -LiteralPath $Path)
    $isList = { param($Value) $Value -isnot [string] -and $Value -is [System.Collections.IEnumerable] }
    if ($data -isnot [System.Collections.IDictionary] -or -not $data.Contains('sources') -or -not (& $isList $data['sources'])) {
        throw "docs/authorities.yml has no 'sources' list."
    }
    # A key with no value ('works:' alone) is an empty list; anything else must be a list of mappings, which is what
    # the checks read fields from.
    $lists = @{}
    foreach ($key in 'works', 'licenses') {
        # Assigned, not taken from an 'if' expression, which would unroll a one-entry list into its entry.
        $value = $null
        if ($data.Contains($key)) { $value = $data[$key] }
        if ($null -ne $value -and -not (& $isList $value)) { throw "docs/authorities.yml '$key' isn't a list." }
        $entries = @($(if ($null -ne $value) { $value }))
        # Counted, not tested for truth: an empty, blank or zero entry is itself false.
        if (@($entries | Where-Object { $_ -isnot [System.Collections.IDictionary] }).Count -gt 0) { throw "docs/authorities.yml '$key' has an entry that isn't a mapping." }
        $lists[$key] = $entries
    }
    [pscustomobject]@{
        Sources  = @($data['sources'])
        Works    = $lists['works']
        Licenses = $lists['licenses']
    }
}

# Replaces what's between a generated block's markers, '<!-- <Marker> from docs/standards ... -->' and
# '<!-- end <Marker> -->', each a line of its own; the rest of the file stays the author's.
function Update-GeneratedBlock {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        [Parameter(Mandatory)] [string] $Block,
        [Parameter(Mandatory)] [string] $Marker,
        [Parameter(Mandatory)] [string] $Name
    )

    # One opening line and one closing line, in that order. A second opening line, such as one quoted in an example,
    # would otherwise start the match early and replace the hand-written text after it.
    $opens = [regex]::Matches($Text, "(?m)^<!-- $Marker from docs/standards[^\n]*-->$")
    $pattern = "(?ms)^(?<open><!-- $Marker from docs/standards[^\n]*-->)\n.*?^<!-- end $Marker -->$"
    $found = [regex]::Matches($Text, $pattern)
    if ($opens.Count -ne 1 -or $found.Count -ne 1) {
        throw "$Name needs one block: one '<!-- $Marker from docs/standards ... -->' line, then one '<!-- end $Marker -->' line."
    }
    $Text.Substring(0, $found[0].Index) + $found[0].Groups['open'].Value + "`n" + $Block + "<!-- end $Marker -->" +
        $Text.Substring($found[0].Index + $found[0].Length)
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $RepoRoot) { $RepoRoot = Split-Path -Path $PSScriptRoot -Parent }
    exit (Invoke-AuthoritiesPageBuild -RepoRoot $RepoRoot -Check:$Check)
}
