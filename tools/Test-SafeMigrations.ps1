#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when an EF Core migration's Up method makes a change the version of the app still running can't work
    with (DAT-003, ADR-0053).

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
$script:UnsafeOperations = @(
    'DropTable', 'DropColumn', 'RenameTable', 'RenameColumn', 'AlterColumn', 'DropSchema', 'DropSequence', 'RenameSequence',
    'AlterSequence', 'RestartSequence', 'AlterTable', 'AlterDatabase',
    'DeleteData', 'UpdateData',
    # Raw SQL could do anything, so it's reported too.
    'Sql'
)

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
        # Get-Content returns nothing for an empty file, which has no migration in it.
        if (-not $text) { continue }
        $up = [regex]::Match($text, 'override\s+void\s+Up\s*\(\s*MigrationBuilder\s+(?<builder>\w+)\s*\)')
        if (-not $up.Success) { continue }

        # Up's body runs to the next method override, Down in a scaffolded migration.
        $next = [regex]::Match($text.Substring($up.Index + $up.Length), 'override\s+\w+\s+\w+\s*\(')
        $end = if ($next.Success) { $up.Index + $up.Length + $next.Index } else { $text.Length }
        $body = $text.Substring(0, $end)

        $relative = [IO.Path]::GetRelativePath($Path, $file.FullName) -replace '\\', '/'

        $lines = $text -split '\r?\n'
        $call = "\b$([regex]::Escape($up.Groups['builder'].Value))\s*\.\s*(?<op>\w+)\s*(?:<[^()]*>)?\s*\("
        foreach ($match in [regex]::Matches($body, $call)) {
            if ($match.Index -lt $up.Index) { continue }
            $operation = $match.Groups['op'].Value
            if ($operation -notin $script:UnsafeOperations) { continue }

            $line = Get-LineNumber $text $match.Index
            # A call after // on its line is commented out.
            $start = $text.LastIndexOf("`n", $match.Index) + 1
            if ($text.Substring($start, $match.Index - $start).Contains('//')) { continue }

            # A reviewed contract step has a "// DAT-003: <reason>" comment at the end of its line or directly above
            # it, saying why the running version still works. A comment with no reason approves nothing.
            $comment = Get-Dat003Comment -Lines $lines -Line $line
            if ($comment -and $comment.Reason) { continue }
            if ($comment) {
                New-Problem -Message "${relative}:$($comment.Line): the DAT-003 comment must say why the version still running works after this call"
            }
            New-Problem -Message "${relative}:${line}: Up calls $operation, which the version still running may need (DAT-003)"
        }
    }
}

# The DAT-003 comment for the call on 1-based Line: at the end of that line, or in the comment lines directly above it.
function Get-Dat003Comment {
    param([string[]] $Lines, [int] $Line)

    $pattern = '//[ \t]*DAT-003:(?<reason>.*)$'
    $candidates = @($Line)
    for ($above = $Line - 1; $above -ge 1 -and $Lines[$above - 1] -match '^\s*//'; $above--) { $candidates += $above }

    foreach ($number in $candidates) {
        $found = [regex]::Match($Lines[$number - 1], $pattern)
        if ($found.Success) {
            return [pscustomobject]@{ Line = $number; Reason = $found.Groups['reason'].Value.Trim() }
        }
    }
}

# The 1-based line the character at Index is on.
function Get-LineNumber {
    param([string] $Text, [int] $Index)
    $Text.Substring(0, $Index).Split("`n").Count
}

# Prints every problem and returns 0 when every migration passes, otherwise 1.
function Invoke-SafeMigrationsCheck {
    param([Parameter(Mandatory)] [string] $Path)

    $problems = @(Get-MigrationProblem -Path $Path)
    foreach ($problem in $problems) {
        Write-Host "  $($problem.Message)" -ForegroundColor Red
    }

    if ($problems) {
        Write-Host "`n$($problems.Count) unsafe migration step(s) under $Path. Leave drops and renames to a later release (expand, then contract), and put a '// DAT-003: <reason>' comment directly above each call that's safe, saying why the version still running works (docs/standards/data.md)." -ForegroundColor Red
        return 1
    }

    Write-Host "Every migration under $Path is safe for the version still running." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-SafeMigrationsCheck -Path $Path)
}
