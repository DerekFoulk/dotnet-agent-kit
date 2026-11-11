#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when a project in the solution holds no code of its own (ARC-009, ADR-0049).

.EXAMPLE
    ./tools/Test-EmptyProjects.ps1 -Solution dotnet-agent-kit.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Problem {
    param([string] $Message)
    [pscustomobject]@{ Message = $Message }
}

function Get-EmptyProjectProblem {
    param([Parameter(Mandatory)] [string] $Solution)

    $solutionFolder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).Path
    foreach ($project in ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project')) {
        $relative = $project.GetAttribute('Path')
        $projectFolder = Split-Path -Parent (Join-Path $solutionFolder $relative)
        $sources = @(Get-ChildItem -LiteralPath $projectFolder -Recurse -File -Filter '*.cs')
        if (-not $sources) {
            New-Problem -Message "$relative has no source files of its own"
        }
    }
}
