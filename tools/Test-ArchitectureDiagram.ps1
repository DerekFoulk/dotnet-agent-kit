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

# Every problem with the page, one Message each; nothing when it passes.
function Get-ArchitectureDiagramProblem {
    param([Parameter(Mandatory)] [string] $Path)
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
