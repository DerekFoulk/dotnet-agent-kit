#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when an EF Core migration's Up method makes a change the version of the app still running can't work
    with (DAT-003, ADR-0050).

.DESCRIPTION
    Reads every C# file under -Path (bin, obj and .git left out) that overrides Up(MigrationBuilder), as an EF Core
    migration does, and reports each call in Up to an operation in $UnsafeOperations. Exit code: 0 when every
    migration passes, otherwise 1.

.EXAMPLE
    ./.kit/tools/Test-SafeMigrations.ps1 -Path .
#>
[CmdletBinding()]
param(
    [string] $Path = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# MigrationBuilder operations that remove or change what the running version reads or writes.
$script:UnsafeOperations = @('DropColumn')

# Folders that hold build output or git's own files, never a migration to check.
$script:SkippedFolders = @('bin', 'obj', '.git')

function New-Problem {
    param([string] $Message)
    [pscustomobject]@{ Message = $Message }
}

# Every .cs file under the folder, outside the skipped folders.
function Get-CSharpFile {
    param([Parameter(Mandatory)] [string] $Folder)

    foreach ($item in Get-ChildItem -LiteralPath $Folder -Force) {
        if ($item.PSIsContainer) {
            if ($item.Name -notin $script:SkippedFolders) { Get-CSharpFile -Folder $item.FullName }
        }
        elseif ($item.Extension -eq '.cs') {
            $item
        }
    }
}

function Get-MigrationProblem {
    param([Parameter(Mandatory)] [string] $Path)

    foreach ($file in Get-CSharpFile -Folder $Path) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        $up = [regex]::Match($text, 'override\s+void\s+Up\s*\(\s*MigrationBuilder\s+(?<builder>\w+)\s*\)')
        if (-not $up.Success) { continue }

        # Up's body runs to the next method override, Down in a scaffolded migration.
        $next = [regex]::Match($text.Substring($up.Index + $up.Length), 'override\s+\w+\s+\w+\s*\(')
        $end = if ($next.Success) { $up.Index + $up.Length + $next.Index } else { $text.Length }
        $body = $text.Substring(0, $end)

        $relative = [IO.Path]::GetRelativePath($Path, $file.FullName) -replace '\\', '/'
        $call = "\b$([regex]::Escape($up.Groups['builder'].Value))\s*\.\s*(?<op>\w+)\s*(?:<[^>]*>)?\s*\("
        foreach ($match in [regex]::Matches($body, $call)) {
            if ($match.Index -lt $up.Index) { continue }
            $operation = $match.Groups['op'].Value
            if ($operation -cnotin $script:UnsafeOperations) { continue }
            $line = $text.Substring(0, $match.Index).Split("`n").Count
            New-Problem -Message "${relative}:${line}: Up calls $operation, which the version still running may need (DAT-003)"
        }
    }
}
