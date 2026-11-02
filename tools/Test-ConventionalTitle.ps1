#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a PR title or a commit subject isn't a Conventional Commit (GIT-004, ADR-0006, ADR-0022).
#>
[CmdletBinding()]
param()

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
    "'$Title' isn't a Conventional Commit: '<type>(<optional scope>)!: <description>', where type is one of $($script:Types -join ', ')"
}
