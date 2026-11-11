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

# Where the build writes output and generated C# by default (BaseOutputPath and BaseIntermediateOutputPath): not the
# project's own source.
$script:BuildFolders = 'bin', 'obj'

function New-Problem {
    param([string] $Message)
    [pscustomobject]@{ Message = $Message }
}

# True for the file `dotnet new classlib` writes, Class1.cs with an empty class Class1, in either namespace style.
function Test-PlaceholderFile {
    param([Parameter(Mandatory)] [IO.FileInfo] $File)

    $File.Name -eq 'Class1.cs' -and (Get-Content -LiteralPath $File.FullName -Raw) -match '\bclass\s+Class1\s*\{\s*\}'
}

function Get-EmptyProjectProblem {
    param([Parameter(Mandatory)] [string] $Solution)

    $solutionFolder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).Path
    foreach ($project in ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project')) {
        $relative = $project.GetAttribute('Path')
        $projectFolder = Split-Path -Parent (Join-Path $solutionFolder $relative)
        $files = @(Get-ChildItem -LiteralPath $projectFolder -Recurse -File -Filter '*.cs' |
            Where-Object { [IO.Path]::GetRelativePath($projectFolder, $_.FullName).Split([IO.Path]::DirectorySeparatorChar)[0] -notin $script:BuildFolders })
        $placeholders = @($files | Where-Object { Test-PlaceholderFile -File $_ })
        if ($files.Count -eq $placeholders.Count) {
            New-Problem -Message "$relative has no source files of its own"
            continue
        }
        foreach ($placeholder in $placeholders) {
            $path = [IO.Path]::GetRelativePath($solutionFolder, $placeholder.FullName).Replace('\', '/')
            New-Problem -Message "$path is the class library template's empty placeholder"
        }
    }
}
