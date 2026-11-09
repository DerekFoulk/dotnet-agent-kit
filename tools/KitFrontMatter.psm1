#Requires -Version 7.6
# Shared by the kit's scripts that read YAML front matter from Markdown files (docs/standards, skills).

Set-StrictMode -Version Latest

# Returns the YAML front matter of a Markdown file (between the opening and closing --- lines), or $null.
function Read-FrontMatter {
    param([Parameter(Mandatory)] [string] $Path)

    $lines = @(Get-Content -Path $Path)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        return $null
    }
    $end = [array]::IndexOf($lines, '---', 1)
    if ($end -lt 0) {
        return $null
    }
    # An empty block is still front matter (an empty map), not "no front matter". Guard the range too:
    # $lines[1..0] would count down and read the delimiters themselves.
    $yaml = if ($end -gt 1) { $lines[1..($end - 1)] -join "`n" } else { '' }
    $frontMatter = ConvertFrom-Yaml -Yaml $yaml
    if ($null -eq $frontMatter) { [ordered]@{} } else { $frontMatter }
}

# Returns the text after the front matter (the part written for people).
function Read-MarkdownBody {
    param([Parameter(Mandatory)] [string] $Path)

    $lines = @(Get-Content -Path $Path)
    if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
        $end = [array]::IndexOf($lines, '---', 1)
        if ($end -ge 0) {
            # A file that ends at the closing delimiter has no body; the range would count down past the end.
            if ($end -eq $lines.Count - 1) { return '' }
            return ($lines[($end + 1)..($lines.Count - 1)] -join "`n")
        }
    }
    $lines -join "`n"
}

# True when a front matter value is there and not blank: a non-empty string or list, or any other value.
function Test-Present {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return -not [string]::IsNullOrWhiteSpace($Value) }
    if ($Value -is [System.Collections.ICollection]) { return $Value.Count -gt 0 }
    $true
}

function Test-IsoDate {
    param([string] $Text)
    $parsed = [datetime]::MinValue
    [datetime]::TryParseExact($Text, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, 'None', [ref] $parsed)
}

# A source is one of: "owner, YYYY-MM-DD", "ADR-NNNN" (an existing ADR file), or "<URL>, retrieved YYYY-MM-DD".
# Returns the problem message, or $null when the source is valid. Shared by the rule-source and scorecard checks.
function Get-SourceProblem {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $AdrPath
    )

    if ($Source -match '^owner\b') {
        if ($Source -match '^owner, (\S+)$' -and (Test-IsoDate $Matches[1])) { return $null }
        return "source '$Source' must read 'owner, YYYY-MM-DD'"
    }
    if ($Source -match '^ADR-(\d{4})$') {
        if (Get-ChildItem -Path $AdrPath -Filter "$($Matches[1])-*.md" -File) { return $null }
        return "source '$Source' not found in $AdrPath"
    }
    if ($Source -match '^https?://') {
        if ($Source -notmatch '^(https?://\S+), retrieved (\S+)$' -or -not (Test-IsoDate $Matches[2])) {
            return "outside source '$Source' needs ', retrieved YYYY-MM-DD'"
        }
        $uri = $null
        if (-not [uri]::TryCreate($Matches[1], [UriKind]::Absolute, [ref] $uri) -or
            $uri.Scheme -notin 'http', 'https' -or
            [string]::IsNullOrEmpty($uri.Host) -or
            [uri]::CheckHostName($uri.Host) -eq [UriHostNameType]::Unknown) {
            return "outside source '$Source' is not a valid http(s) URL"
        }
        return $null
    }
    "source '$Source' is not a recognized source (owner, ADR or URL)"
}

Export-ModuleMember -Function Read-FrontMatter, Read-MarkdownBody, Test-Present, Get-SourceProblem
