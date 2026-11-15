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
    $blocks = [regex]::Matches($text, '(?ms)^ {0,3}```mermaid[ \t]*\r?\n(?<body>.*?)^ {0,3}```[ \t]*$')
    if ($blocks.Count -eq 0) {
        return New-Problem -Message 'no ```mermaid code block'
    }

    if (-not ($blocks | Where-Object { $_.Groups['body'].Value.Trim() })) {
        New-Problem -Message 'the ```mermaid code block is empty'
    }
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
