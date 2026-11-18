#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when any kit rule lacks a traceable source or an enforcement entry (brief §7, checkpoint §2).

.DESCRIPTION
    Reads the YAML front matter of every docs/standards/*.md file. Each rule needs id, statement, layer,
    basis, status, sources and enforcement. Each source is "owner, YYYY-MM-DD", "ADR-NNNN" (an existing file
    in docs/adr) or "<URL>, retrieved YYYY-MM-DD". Basis 'authority' needs a URL source and 'preference' an
    owner or ADR source. Enforcement is a list of parts, each with kind (gate or advisory), in (kit, app or
    both) and how (ADR-0063). Ids are unique.
    ADR-0082: an authority rule cites pages only (URLs), has layer outside or floor, and stores quotes: for each
    cited page, the page's own words with that source's URL and retrieval date, one contiguous passage each. An
    accepted authority rule names who accepted it in ratified. A preference has layer owner or floor. Every rule in
    force names its scope: core, or app types from app-types.yml in the same folder (never every one; ADR-0084).
    Exit code: 0 when every rule is traceable, otherwise 1.

.EXAMPLE
    ./tools/Test-RuleSources.ps1
#>
[CmdletBinding()]
param(
    [string] $StandardsPath,
    [string] $AdrPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Not '#Requires -Modules': in PowerShell 7.6.9, a module loaded that way turns the script's 'exit 1' into 0
# when run with -File, which would make this check pass in CI no matter what it finds.
Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'
Import-Module -Name (Join-Path $PSScriptRoot 'KitFrontMatter.psm1') -Force

$script:RequiredFields = 'id', 'statement', 'layer', 'basis', 'status', 'sources', 'enforcement'
$script:AllowedValues = [ordered]@{
    layer  = 'floor', 'owner', 'outside'
    basis  = 'authority', 'preference'
    status = 'proposed', 'accepted', 'retired'
}
# ADR-0063: each enforcement part is a gate (a tool fails the change) or advisory (a person or code review
# checks it), and says where it applies: in the kit, in apps, or both.
$script:PartKinds = 'gate', 'advisory'
$script:PartPlaces = 'kit', 'app'

# The problems with a rule's enforcement: it must be a list of parts, each with a known kind, at least one known
# place, and a non-empty 'how' (for an advisory part, the reason no tool checks it).
function Get-EnforcementProblem {
    param([Parameter(Mandatory)] [AllowNull()] [object] $Enforcement)

    # A dictionary is enumerable too, so a single part written without its list must be caught first.
    if ($Enforcement -is [string] -or $Enforcement -is [System.Collections.IDictionary] -or
        $Enforcement -isnot [System.Collections.IEnumerable]) {
        return "enforcement must be a list of parts, each with kind, in and how (ADR-0063)"
    }
    foreach ($part in @($Enforcement)) {
        if ($part -isnot [System.Collections.IDictionary]) {
            "enforcement part '$part' must have kind, in and how"
            continue
        }
        if (-not $part.Contains('kind') -or -not (Test-Present $part['kind'])) {
            "an enforcement part has no kind"
        }
        elseif ("$($part['kind'])" -notin $script:PartKinds) {
            "enforcement part kind '$($part['kind'])' must be one of: $($script:PartKinds -join ', ')"
        }
        $places = @()
        if ($part.Contains('in') -and $part['in'] -is [string]) {
            "enforcement part in '$($part['in'])' must be a list, such as [kit] or [kit, app]"
        }
        else {
            if ($part.Contains('in')) { $places = @($part['in'] | Where-Object { Test-Present $_ }) }
            if (-not $places) { "an enforcement part has no 'in' (kit, app or both)" }
        }
        foreach ($place in $places) {
            if ("$place" -notin $script:PartPlaces) {
                "enforcement part in '$place' must be one of: $($script:PartPlaces -join ', ')"
            }
        }
        if (-not $part.Contains('how') -or "$($part['how'])" -notmatch '\S') {
            "an enforcement part has no 'how'"
        }
    }
}

# ADR-0063: an authority's rule cites the authority by URL; a preference cites the owner or the ADR he accepted.
function Get-BasisProblem {
    param([string] $Basis, [object[]] $Sources)

    $sources = @($Sources | ForEach-Object { "$_" })
    if ($Basis -eq 'authority' -and -not ($sources -match '^https?://')) {
        return "basis 'authority' needs a URL source for the authority"
    }
    # ADR-0082: an authority rule says only what its pages say. An owner's decision or an ADR among its sources means
    # part of it is the kit's, which is a preference rule of its own; the owner accepting the rule is 'ratified'.
    if ($Basis -eq 'authority') {
        foreach ($source in @($sources | Where-Object { $_ -match '^(owner, |ADR-\d{4}$)' })) {
            "basis 'authority' cites pages only, not '$source': split what the owner or ADR adds into a preference rule, or move the owner's acceptance to ratified (ADR-0082)"
        }
    }
    if ($Basis -eq 'preference' -and -not ($sources -match '^(owner, |ADR-\d{4}$)')) {
        return "basis 'preference' needs an 'owner, YYYY-MM-DD' or ADR source"
    }
}

# ADR-0082: layer says whose rule it is. An authority's rule is the outside layer and a preference is the owner's;
# a floor rule (law, safety, security, privacy, licenses) can be either.
$script:LayersForBasis = @{ authority = @('outside', 'floor'); preference = @('owner', 'floor') }

function Get-RatifiedProblem {
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Rule)

    $hasRatified = $Rule.Contains('ratified') -and "$($Rule['ratified'])" -match '\S'
    if ("$($Rule['basis'])" -ne 'authority') {
        if ($hasRatified) { "ratified is for an authority rule; a preference's sources already name the owner or the ADR" }
        return
    }
    if (-not $hasRatified) {
        if ("$($Rule['status'])" -eq 'accepted') {
            "an accepted authority rule needs ratified: 'owner, YYYY-MM-DD' or 'ADR-NNNN', who accepted it"
        }
        return
    }
    $ratified = "$($Rule['ratified'])"
    if ($ratified -notmatch '^(owner, |ADR-\d{4}$)') {
        return "ratified '$ratified' must read 'owner, YYYY-MM-DD' or 'ADR-NNNN'"
    }
}

# ADR-0082: a quote is the page's own words, with the page and the day they were read, so the rule can be compared
# with them. Returns the date as text, whether YAML read it as a string or a date.
function ConvertTo-DateText {
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture) }
    "$Value"
}

function Get-QuoteProblem {
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Rule)

    # Not "$quotes = if (...)": an if statement's output is enumerated, so a one-quote list would become the quote.
    $quotes = $null
    if ($Rule.Contains('quotes')) { $quotes = $Rule['quotes'] }
    $isAuthority = "$($Rule['basis'])" -eq 'authority' -and "$($Rule['status'])" -ne 'retired'
    if (-not (Test-Present $quotes)) {
        if ($isAuthority) { "basis 'authority' needs quotes: the sentence on each cited page that says what the rule says (ADR-0082)" }
        return
    }
    if ($quotes -is [string] -or $quotes -is [System.Collections.IDictionary]) {
        return "quotes must be a list, each quote with source, retrieved and text"
    }
    # The rule's URL sources, each with its retrieval date: a quote names one of them and the same date, so the
    # page and the day live in sources and the quote is checked against them (CRF-003).
    $cited = [ordered]@{}
    foreach ($source in @($(if ($Rule.Contains('sources')) { $Rule['sources'] }))) {
        if ("$source" -match '^(https?://\S+), retrieved (\S+)$') { $cited[$Matches[1]] = $Matches[2] }
    }
    $quoted = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($quote in @($quotes)) {
        if ($quote -isnot [System.Collections.IDictionary]) {
            "quote '$quote' must have source, retrieved and text"
            continue
        }
        foreach ($field in 'source', 'retrieved', 'text') {
            if (-not $quote.Contains($field) -or "$($quote[$field])" -notmatch '\S') {
                "a quote has no '$field'"
            }
        }
        $retrieved = if ($quote.Contains('retrieved')) { ConvertTo-DateText $quote['retrieved'] } else { '' }
        if ($retrieved -match '\S' -and -not (Test-IsoDate $retrieved)) {
            "quote retrieved '$retrieved' must be a date, YYYY-MM-DD"
        }
        $page = if ($quote.Contains('source')) { "$($quote['source'])" } else { '' }
        if ($page -match '\S') {
            if (-not $cited.Contains($page)) {
                "a quote's source '$page' is not one of the rule's sources (write it as the source is written, without ', retrieved')"
            }
            else {
                [void] $quoted.Add($page)
                if ((Test-IsoDate $retrieved) -and $retrieved -ne $cited[$page]) {
                    "a quote of $page says retrieved $retrieved, but its source says $($cited[$page])"
                }
            }
        }
        # One contiguous passage, so the scheduled re-read (ADR-0083) can find it on the page as written. An ellipsis that
        # stands for left-out words stands alone or in brackets; dots inside the page's code, as in Task.Run(...), stay.
        if ($quote.Contains('text') -and "$($quote['text'])" -match '\[(\.\.\.|…)\]|(^|\s)(\.\.\.|…)(\s|$)') {
            "a quote of $page has an ellipsis: store one contiguous passage, and another quote for another passage"
        }
    }
    if ($isAuthority) {
        foreach ($page in $cited.Keys) {
            if (-not $quoted.Contains($page)) { "the rule cites $page but has no quote from it" }
        }
    }
}

# ADR-0084: the app types a rule's scope can name, from docs/standards/app-types.yml, the one list of them. Returns
# the ids, and the file's problems as messages.
function Read-AppType {
    param([Parameter(Mandatory)] [string] $StandardsPath)

    $path = Join-Path $StandardsPath 'app-types.yml'
    $result = [pscustomobject]@{ Ids = [System.Collections.Generic.List[string]]::new(); Problems = [System.Collections.Generic.List[string]]::new() }
    if (-not (Test-Path -LiteralPath $path)) {
        $result.Problems.Add("app-types.yml is missing from $StandardsPath; it lists the app types a rule's scope names (ADR-0084)")
        return $result
    }
    $yaml = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
    $types = $null
    if ($yaml -is [System.Collections.IDictionary] -and $yaml.Contains('types')) { $types = $yaml['types'] }
    foreach ($type in @($types)) {
        if ($type -isnot [System.Collections.IDictionary] -or "$($type['id'])" -notmatch '^[a-z0-9-]+$') {
            $result.Problems.Add("app-types.yml has an entry with no id in lower-case-with-dashes: '$type'")
            continue
        }
        $id = "$($type['id'])"
        if ($id -eq 'core') { $result.Problems.Add("app-types.yml names a type 'core', which is reserved for rules that fit every app type") }
        elseif ($result.Ids.Contains($id)) { $result.Problems.Add("app-types.yml lists '$id' more than once") }
        else { $result.Ids.Add($id) }
        if ("$($type['name'])" -notmatch '\S') { $result.Problems.Add("app-types.yml type '$id' has no name") }
        if ("$($type['docs'])" -notmatch '^https://\S+$') { $result.Problems.Add("app-types.yml type '$id' needs docs, the URL of Microsoft's page for it") }
    }
    if ($result.Ids.Count -eq 0 -and $result.Problems.Count -eq 0) { $result.Problems.Add("app-types.yml lists no types") }
    $result
}

# ADR-0084: scope is 'core' (every app type) or a list of the app types in app-types.yml, never all of them: a type
# added later would be left out of a rule that lists every type today, so such a rule says core.
function Get-ScopeProblem {
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Rule, [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Known)

    if ($Rule.Contains('projectTypes')) { "projectTypes is retired: write scope, core or the app types it applies to (ADR-0084)" }
    if ("$($Rule['status'])" -eq 'retired') { return }
    $scope = $null
    if ($Rule.Contains('scope')) { $scope = $Rule['scope'] }
    if ($scope -is [string]) {
        if ($scope -eq 'core') { return }
        if ($scope -match '\S') { return "scope '$scope' must be core, or a list of app types such as [web-api, blazor]" }
    }
    $types = @(@($scope) | Where-Object { "$_" -match '\S' } | ForEach-Object { "$_" })
    if (-not $types) { return "is missing 'scope': core, or the app types in app-types.yml it applies to" }
    if ('core' -in $types) { return "scope: core stands alone, written as core, not in a list" }
    foreach ($type in $types) {
        if ($type -notin $Known) { "app type '$type' isn't one of app-types.yml's: $($Known -join ', ')" }
    }
    if ($Known.Count -gt 0 -and @($Known | Where-Object { $_ -notin $types }).Count -eq 0) {
        "scope lists every app type: write core, so a type added later is covered too"
    }
}

function New-Problem {
    param([string] $File, [string] $RuleId, [string] $Message)
    [pscustomobject]@{ File = $File; RuleId = $RuleId; Message = $Message }
}

function Get-RuleSourceProblem {
    param(
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    $appTypes = Read-AppType -StandardsPath $StandardsPath
    foreach ($message in $appTypes.Problems) { New-Problem -File 'app-types.yml' -Message $message }
    $seen = @{}
    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File | Sort-Object Name) {
        $frontMatter = Read-FrontMatter -Path $file.FullName
        if ($null -eq $frontMatter) {
            New-Problem -File $file.Name -Message 'has no YAML front matter'
            continue
        }
        if (-not $frontMatter.Contains('rules') -or -not (Test-Present $frontMatter['rules'])) {
            New-Problem -File $file.Name -Message 'front matter has no rules'
            continue
        }

        foreach ($rule in $frontMatter['rules']) {
            $ruleId = if ($rule.Contains('id')) { "$($rule['id'])" } else { $null }
            foreach ($field in $script:RequiredFields) {
                if (-not $rule.Contains($field) -or -not (Test-Present $rule[$field])) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message "is missing '$field'"
                }
            }
            if ($ruleId) {
                if ($seen.ContainsKey($ruleId)) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message "id '$ruleId' is already used in $($seen[$ruleId])"
                }
                else {
                    $seen[$ruleId] = $file.Name
                }
            }
            foreach ($field in $script:AllowedValues.Keys) {
                if ($rule.Contains($field) -and (Test-Present $rule[$field]) -and "$($rule[$field])" -notin $script:AllowedValues[$field]) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message "$field '$($rule[$field])' must be one of: $($script:AllowedValues[$field] -join ', ')"
                }
            }
            if ($rule.Contains('enforcement') -and (Test-Present $rule['enforcement'])) {
                foreach ($message in @(Get-EnforcementProblem -Enforcement $rule['enforcement'])) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message $message
                }
            }
            # Only sources that are valid count toward the basis; a rule with none already has a problem above.
            $validSources = @(@($(if ($rule.Contains('sources')) { $rule['sources'] })) | Where-Object {
                    (Test-Present $_) -and -not (Get-SourceProblem -Source "$_" -AdrPath $AdrPath)
                })
            if ($rule.Contains('basis') -and $validSources -and "$($rule['basis'])" -in $script:AllowedValues['basis']) {
                foreach ($message in @(Get-BasisProblem -Basis "$($rule['basis'])" -Sources $validSources)) {
                    New-Problem -File $file.Name -RuleId $ruleId -Message $message
                }
            }
            $basis = "$($rule['basis'])"
            if ($script:LayersForBasis.ContainsKey($basis) -and "$($rule['layer'])" -in $script:AllowedValues['layer'] -and
                "$($rule['layer'])" -notin $script:LayersForBasis[$basis]) {
                New-Problem -File $file.Name -RuleId $ruleId -Message "basis '$basis' can't have layer '$($rule['layer'])': use $($script:LayersForBasis[$basis] -join ' or ') (ADR-0082)"
            }
            foreach ($message in @(Get-ScopeProblem -Rule $rule -Known $appTypes.Ids)) {
                New-Problem -File $file.Name -RuleId $ruleId -Message $message
            }
            foreach ($message in @(Get-RatifiedProblem -Rule $rule)) {
                New-Problem -File $file.Name -RuleId $ruleId -Message $message
            }
            foreach ($message in @(Get-QuoteProblem -Rule $rule)) {
                New-Problem -File $file.Name -RuleId $ruleId -Message $message
            }
            if ($rule.Contains('sources')) {
                foreach ($source in @($rule['sources'])) {
                    $message = Get-SourceProblem -Source "$source" -AdrPath $AdrPath
                    if ($message) {
                        New-Problem -File $file.Name -RuleId $ruleId -Message $message
                    }
                }
            }
        }
    }
}

# Prints every problem and returns 0 when every rule is traceable, otherwise 1.
function Invoke-RuleSourceCheck {
    param(
        [Parameter(Mandatory)] [string] $StandardsPath,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    $problems = @(Get-RuleSourceProblem -StandardsPath $StandardsPath -AdrPath $AdrPath)
    foreach ($problem in $problems) {
        $where = if ($problem.RuleId) { "$($problem.File) $($problem.RuleId)" } else { $problem.File }
        Write-Host "  $where`: $($problem.Message)" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) rule problem(s) in $StandardsPath." -ForegroundColor Red
        return 1
    }

    $ruleCount = 0
    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File) {
        $ruleCount += @((Read-FrontMatter -Path $file.FullName)['rules']).Count
    }
    $noun = if ($ruleCount -eq 1) { 'rule' } else { 'rules' }
    Write-Host "$ruleCount $noun, all traceable to a source and an enforcement." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    if (-not $StandardsPath) { $StandardsPath = Join-Path $repoRoot 'docs' 'standards' }
    if (-not $AdrPath) { $AdrPath = Join-Path $repoRoot 'docs' 'adr' }
    exit (Invoke-RuleSourceCheck -StandardsPath $StandardsPath -AdrPath $AdrPath)
}
