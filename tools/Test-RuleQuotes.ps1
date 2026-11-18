#Requires -Version 7.6
<#
.SYNOPSIS
    Re-reads every page a rule quotes and reports each stored quote the page no longer says (ADR-0083).

.DESCRIPTION
    An authority rule in docs/standards stores the sentence on each cited page that says what the rule says
    (ADR-0082). Pages change. This script reads each quoted page once, turns its HTML into text, and looks for each
    quote in it. Both sides are compared as the words a reader sees: tags, scripts and styles removed, entities
    decoded, curly quotes and dashes made plain, emoji and whitespace dropped, case ignored.
    Each quote ends Found, Missing (the page loaded and no longer says it) or Unreachable (the page didn't load).
    A page that failed to load is never reported as a missing quote.
    Exit code: 0 when every quote was found, 1 when any is missing, 2 when none is missing but a page didn't load.
    rule-quotes.yml runs it weekly and opens an issue; it also runs, not required, on a pull request that changes
    docs/standards. To fix a missing quote, read the page, update the quote and the rule to what the page says now,
    and re-date both (the recheck-sources skill).

.EXAMPLE
    ./tools/Test-RuleQuotes.ps1
#>
[CmdletBinding()]
param([string] $StandardsPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import-Module, not '#Requires -Modules', which breaks exit codes under -File (see tools/Test-RuleSources.ps1).
Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'
Import-Module -Name (Join-Path $PSScriptRoot 'KitFrontMatter.psm1') -Force

# Every stored quote, with its rule, file, page and text.
function Get-RuleQuote {
    param([Parameter(Mandatory)] [string] $StandardsPath)

    foreach ($file in Get-ChildItem -Path $StandardsPath -Filter '*.md' -File | Sort-Object Name) {
        $frontMatter = Read-FrontMatter -Path $file.FullName
        if ($null -eq $frontMatter -or -not $frontMatter.Contains('rules')) { continue }
        foreach ($rule in @($frontMatter['rules'])) {
            if ($rule -isnot [System.Collections.IDictionary] -or -not $rule.Contains('quotes')) { continue }
            foreach ($quote in @($rule['quotes'])) {
                if ($quote -isnot [System.Collections.IDictionary]) { continue }
                [pscustomobject]@{ RuleId = "$($rule['id'])"; File = $file.Name; Source = "$($quote['source'])"; Text = "$($quote['text'])" }
            }
        }
    }
}

# The words a reader sees, made comparable: Learn renders a sentence with inline markup, curly quotes, non-breaking
# spaces and emoji that a stored quote, written as plain text, leaves out.
function ConvertTo-ComparableText {
    param([AllowEmptyString()] [string] $Text)

    $t = $Text.Normalize([Text.NormalizationForm]::FormKC)
    $t = $t -replace "[‘’‚‛′]", "'" -replace '[“”„‟″]', '"'
    $t = $t -replace '[‐-―−]', '-'
    # Emoji, variation selectors and zero-width characters, which no stored quote carries.
    $t = $t -replace '[☀-➿️​-‍⁠]|\p{Cs}', ''
    ($t -replace '\s+', '').ToLowerInvariant()
}

# A page's visible text: scripts, styles and tags removed, entities decoded.
function ConvertFrom-Html {
    param([AllowEmptyString()] [string] $Html)

    $text = $Html -replace '(?is)<(script|style|noscript|template)\b.*?</\1\s*>', ' ' -replace '(?s)<!--.*?-->', ' '
    $text = $text -replace '<[^>]+>', ' '
    [System.Net.WebUtility]::HtmlDecode($text)
}

# The page as HTML, in English, the way a reader's browser asks for it. Learn redirects to its /en-us/ copy.
function Get-PageHtml {
    param([Parameter(Mandatory)] [string] $Url)

    $headers = @{ 'Accept-Language' = 'en-US,en;q=0.9'; 'Accept' = 'text/html' }
    (Invoke-WebRequest -Uri $Url -Headers $headers -UserAgent 'dotnet-agent-kit rule-quote check' -TimeoutSec 60 -MaximumRedirection 5).Content
}

# Looks for each quote on its page, reading each page once. -GetPage takes a URL and returns its HTML, or throws.
function Test-RuleQuote {
    param(
        [Parameter(Mandatory)] [object[]] $Quote,
        [scriptblock] $GetPage = { param($Url) Get-PageHtml -Url $Url }
    )

    $pages = @{}
    foreach ($q in $Quote) {
        if (-not $pages.ContainsKey($q.Source)) {
            try {
                $pages[$q.Source] = [pscustomobject]@{ Text = ConvertTo-ComparableText (ConvertFrom-Html (& $GetPage $q.Source)); Error = $null }
            }
            catch {
                $pages[$q.Source] = [pscustomobject]@{ Text = $null; Error = $_.Exception.Message }
            }
        }
        $page = $pages[$q.Source]
        $state, $detail = if ($null -ne $page.Error) { 'Unreachable', $page.Error }
        elseif ($page.Text.Contains((ConvertTo-ComparableText $q.Text), [StringComparison]::Ordinal)) { 'Found', '' }
        else { 'Missing', 'the page no longer has this text' }
        [pscustomobject]@{ RuleId = $q.RuleId; File = $q.File; Source = $q.Source; Text = $q.Text; State = $state; Detail = $detail }
    }
}

# Prints each quote that wasn't found, and returns 0 (all found), 1 (one missing) or 2 (a page didn't load).
function Invoke-RuleQuoteCheck {
    param(
        [Parameter(Mandatory)] [string] $StandardsPath,
        [scriptblock] $GetPage = { param($Url) Get-PageHtml -Url $Url }
    )

    $quotes = @(Get-RuleQuote -StandardsPath $StandardsPath)
    $results = @(if ($quotes) { Test-RuleQuote -Quote $quotes -GetPage $GetPage })
    $missing = @($results | Where-Object State -eq 'Missing')
    $unreachable = @($results | Where-Object State -eq 'Unreachable')
    foreach ($r in $missing) {
        Write-Host "  Missing: $($r.File) $($r.RuleId), $($r.Source): `"$($r.Text)`"" -ForegroundColor Red
    }
    foreach ($source in @($unreachable | Group-Object Source)) {
        Write-Host "  Unreachable: $($source.Name) ($($source.Group[0].Detail)); its $($source.Count) quote(s) weren't checked" -ForegroundColor Yellow
    }
    $pageCount = @($quotes | Select-Object -ExpandProperty Source -Unique).Count
    $summary = "$($quotes.Count) quote(s) on $pageCount page(s): $(@($results | Where-Object State -eq 'Found').Count) found, $($missing.Count) missing, $($unreachable.Count) not checked."
    if ($missing) {
        Write-Host "`n$summary Update each rule to what its page says now (the recheck-sources skill)." -ForegroundColor Red
        return 1
    }
    if ($unreachable) {
        Write-Host "`n$summary Run it again later; a page that didn't load isn't a missing quote." -ForegroundColor Yellow
        return 2
    }
    Write-Host $summary -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $StandardsPath) { $StandardsPath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'docs' 'standards' }
    exit (Invoke-RuleQuoteCheck -StandardsPath $StandardsPath)
}
