#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a PR title or a commit subject isn't a Conventional Commit (GIT-004, ADR-0006, ADR-0022).

.EXAMPLE
    ./tools/Test-ConventionalTitle.ps1 -Title 'feat: add tags'

.EXAMPLE
    ./tools/Test-ConventionalTitle.ps1 -Range origin/main..HEAD
    Checks every non-merge commit on the branch.
#>
[CmdletBinding()]
param(
    [string] $Title,
    [string] $RepoPath = '.',
    [string] $Range
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The Conventional Commits types release-please understands. feat and fix change the version; ! or a
# BREAKING CHANGE footer makes a major change.
$script:Types = 'feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'build', 'ci', 'chore', 'revert'
$script:TitlePattern = "^($($script:Types -join '|'))(\([a-z0-9][a-z0-9-]*\))?!?: \S"

# Returns why the title isn't a Conventional Commit, or $null when it is. Case-sensitive: types are lower case.
function Get-TitleProblem {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Title)

    if ($Title -cmatch $script:TitlePattern) {
        return $null
    }
    # git revert writes 'Revert "<original subject>"' and never runs the commit-msg hook. Conventional
    # Commits parsers recognize that form, so it's valid when the reverted subject was.
    if ($Title -cmatch '^Revert "(.+)"$' -and -not (Get-TitleProblem -Title $Matches[1])) {
        return $null
    }
    "'$Title' isn't a Conventional Commit: '<type>(<optional scope>)!: <description>', where type is one of $($script:Types -join ', ')"
}

# Checks a PR title (-Title) and/or every non-merge commit subject in a git range (-Range, such as
# origin/main..HEAD). Prints each problem and returns 0 when all are Conventional Commits, otherwise 1.
function Invoke-ConventionalTitleCheck {
    param([string] $Title, [string] $RepoPath = '.', [string] $Range)

    $problems = [System.Collections.Generic.List[string]]::new()
    $checked = 0

    if ($PSBoundParameters.ContainsKey('Title')) {
        $checked++
        $problem = Get-TitleProblem -Title $Title
        if ($problem) { $problems.Add("PR title: $problem") }
    }

    if ($Range) {
        # Merge commits carry the PR title once the repo's merge settings apply (ADR-0022); older ones
        # read "Merge pull request ...", so they're skipped here and the PR title is checked instead.
        $log = @(git -C $RepoPath log --no-merges --format='%h%x09%s' $Range)
        if ($LASTEXITCODE -ne 0) { throw "git log failed for range '$Range' in $RepoPath." }
        foreach ($line in $log) {
            $hash, $subject = $line -split "`t", 2
            $checked++
            $problem = Get-TitleProblem -Title $subject
            if ($problem) { $problems.Add("commit ${hash}: $problem") }
        }
    }

    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }
    if ($problems.Count -gt 0) {
        Write-Host "`n$($problems.Count) of $checked title(s) aren't Conventional Commits." -ForegroundColor Red
        return 1
    }
    Write-Host "$checked title(s), all Conventional Commits." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    # Checking nothing must not look like a pass (a CI step with a missing value, for example).
    if (-not $PSBoundParameters.ContainsKey('Title') -and -not $Range) {
        Write-Host 'Nothing to check: pass -Title, -Range, or both.' -ForegroundColor Red
        exit 1
    }
    $arguments = @{ RepoPath = $RepoPath }
    if ($PSBoundParameters.ContainsKey('Title')) { $arguments['Title'] = $Title }
    if ($Range) { $arguments['Range'] = $Range }
    exit (Invoke-ConventionalTitleCheck @arguments)
}
