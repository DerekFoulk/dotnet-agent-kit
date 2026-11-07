#Requires -Version 7.0
<#
.SYNOPSIS
    The commit-msg hook: rejects a commit whose subject isn't a Conventional Commit (GIT-004, ADR-0027).

.DESCRIPTION
    Uses the same rule as CI (Get-TitleProblem in Test-ConventionalTitle.ps1), and must never accept a
    subject CI rejects: a bad subject that reaches CI can only be fixed by rewriting history. CI skips only
    real merge commits, so this hook skips only a merge in progress (git sets MERGE_HEAD), never a subject
    that merely looks like one. fixup!/squash!/amend! subjects are rejected. git revert never runs this
    hook; its 'Revert "<subject>"' form is valid in the shared rule when the reverted subject was.
#>
param([Parameter(Mandatory)] [string] $MessageFile)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The kit keeps the check in tools/; an app repo gets it in .kit/tools/ (ADR-0032).
$check = @(
    (Join-Path $PSScriptRoot '..' '.kit' 'tools' 'Test-ConventionalTitle.ps1'),
    (Join-Path $PSScriptRoot '..' 'tools' 'Test-ConventionalTitle.ps1')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $check) {
    Write-Host 'commit-msg hook: Test-ConventionalTitle.ps1 is missing from .kit/tools and tools.' -ForegroundColor Red
    exit 1
}
. $check

# A merge commit in progress: CI skips merge commits (git log --no-merges), so the hook does too.
git rev-parse -q --verify MERGE_HEAD *> $null
if ($LASTEXITCODE -eq 0) {
    exit 0
}

# git's editor template adds comment lines (#) and may leave blank lines before the subject.
$subject = Get-Content -LiteralPath $MessageFile |
    Where-Object { $_.Trim() -and -not $_.StartsWith('#') } |
    Select-Object -First 1

if (-not $subject) {
    exit 0 # git itself aborts a commit with an empty message
}

$problem = Get-TitleProblem -Title $subject
if ($problem) {
    Write-Host "commit-msg hook: $problem" -ForegroundColor Red
    Write-Host 'Example: feat: add tags   (see docs/standards/git.md)' -ForegroundColor Red
    exit 1
}
exit 0
