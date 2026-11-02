#Requires -Version 7.0
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

Export-ModuleMember -Function Read-FrontMatter, Read-MarkdownBody
