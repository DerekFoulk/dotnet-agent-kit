#Requires -Version 7.0
<#
.SYNOPSIS
    The commit-msg hook: rejects a commit whose subject isn't a Conventional Commit (GIT-004, ADR-0027).

.DESCRIPTION
    Uses the same rule as CI (Get-TitleProblem in tools/Test-ConventionalTitle.ps1). A bad subject that
    reaches CI can only be fixed by rewriting history, so the hook stops it before the commit exists.
    Subjects git writes itself (merges, reverts, fixup!/squash!/amend!) are skipped.
#>
param([Parameter(Mandatory)] [string] $MessageFile)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..' 'tools' 'Test-ConventionalTitle.ps1')

# git's editor template adds comment lines (#) and may leave blank lines before the subject.
$subject = Get-Content -Path $MessageFile |
    Where-Object { $_.Trim() -and -not $_.StartsWith('#') } |
    Select-Object -First 1

if (-not $subject -or $subject -match '^(Merge |Revert "|fixup! |squash! |amend! )') {
    exit 0
}

$problem = Get-TitleProblem -Title $subject
if ($problem) {
    Write-Host "commit-msg hook: $problem" -ForegroundColor Red
    Write-Host 'Example: feat: add tags   (see docs/standards/git.md)' -ForegroundColor Red
    exit 1
}
exit 0
