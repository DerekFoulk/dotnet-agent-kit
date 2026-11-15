#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when a repo has no architecture diagram (ARC-013).

.DESCRIPTION
    Checks one page, docs/architecture/modules.md by default, for a Mermaid diagram: a ```mermaid code block with
    something in it. Exit code: 0 when the diagram is there, otherwise 1.

.EXAMPLE
    ./.kit/tools/Test-ArchitectureDiagram.ps1 -Path ./docs/architecture/modules.md
#>
[CmdletBinding()]
param(
    [string] $Path = 'docs/architecture/modules.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Problem {
    param([string] $Message)
    [pscustomobject]@{ Message = $Message }
}

# Every problem with the page, one Message each; nothing when it passes. A ```mermaid block inside an HTML comment
# isn't shown to a reader, so it doesn't count.
function Get-ArchitectureDiagramProblem {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return New-Problem -Message "no architecture diagram at $Path"
    }

    $text = (Get-Content -LiteralPath $Path -Raw) -replace '(?s)<!--.*?-->', ''
    $blocks = @(Get-MermaidBlock -Lines ($text -split '\r?\n'))
    if ($blocks.Count -eq 0) {
        return New-Problem -Message 'no ```mermaid code block'
    }

    if (-not ($blocks | Where-Object { $_ })) {
        New-Problem -Message 'the ```mermaid code block is empty'
    }
}

# Each mermaid fenced code block's text, trimmed, read as CommonMark reads a fence: three or more backticks or tildes,
# indented up to three spaces, with the info string's first word naming the language; it closes on a line of the same
# character, at least as long, with nothing after it, or at the end of the page.
function Get-MermaidBlock {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $fence = $null
    $isMermaid = $false
    $body = [System.Text.StringBuilder]::new()
    foreach ($line in $Lines) {
        if ($null -eq $fence) {
            if ($line -match '^ {0,3}(?<fence>`{3,}|~{3,})[ \t]*(?<info>.*)$' -and
                ($Matches['fence'][0] -eq '~' -or -not $Matches['info'].Contains('`'))) {
                $fence = $Matches['fence']
                $isMermaid = ($Matches['info'].Trim() -split '\s+')[0] -ceq 'mermaid'
                [void] $body.Clear()
            }
        }
        elseif ($line -match '^ {0,3}(?<fence>`{3,}|~{3,})[ \t]*$' -and
            $Matches['fence'][0] -eq $fence[0] -and $Matches['fence'].Length -ge $fence.Length) {
            if ($isMermaid) { $body.ToString().Trim() }
            $fence = $null
        }
        else {
            [void] $body.AppendLine($line)
        }
    }

    if ($null -ne $fence -and $isMermaid) { $body.ToString().Trim() }
}

# Prints every problem and returns 0 when the page passes, otherwise 1.
function Invoke-ArchitectureDiagramCheck {
    param([Parameter(Mandatory)] [string] $Path)

    $problems = @(Get-ArchitectureDiagramProblem -Path $Path)
    foreach ($problem in $problems) {
        Write-Host "  $($problem.Message)" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`nThe architecture diagram at $Path is missing or empty (ARC-013)." -ForegroundColor Red
        return 1
    }

    Write-Host "The architecture diagram at $Path is there." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-ArchitectureDiagramCheck -Path $Path)
}
