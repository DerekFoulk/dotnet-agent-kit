#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when a branch's TDD commits are out of order: every red must be made green, and every green
    must follow a red (TST-001, GIT-005, ADR-0006, ADR-0018).
#>
[CmdletBinding()]
param(
    [string] $RepoPath = '.',
    [string] $Range
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Midnight Pacific on 2026-11-02. Commits made before it carried "TDD: red|green" in its own paragraph,
# which git doesn't read as a trailer; the first real trailer commit (c779b47) landed at 23:42 on
# 2026-11-01 Pacific, and everything after the fix uses the trailer.
$script:TrailerCutoff = [datetimeoffset]::Parse('2026-11-02T00:00:00-08:00', [cultureinfo]::InvariantCulture)

# Walks the commits oldest first. A red opens a cycle; a green closes every open red (several reds may
# share one green, for example when a second test refines the first before the code exists). A green
# with nothing open, a red still open at the end, and any value other than red or green are problems.
function Get-RedGreenProblem {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Commits)

    $open = [System.Collections.Generic.List[object]]::new()
    foreach ($commit in $Commits) {
        $describe = "commit $($commit.Hash) ($($commit.Subject))"
        switch ("$($commit.Marker)") {
            '' { continue }
            'red' { $open.Add($commit) }
            'green' {
                if ($open.Count -eq 0) { "${describe}: TDD green with no red before it" }
                $open.Clear()
            }
            default { "${describe}: unknown TDD marker '$($commit.Marker)'; use red or green" }
        }
    }
    foreach ($commit in $open) {
        "commit $($commit.Hash) ($($commit.Subject)): TDD red never made green on this branch"
    }
}

# Returns each of the branch's own non-merge commits in the range, oldest first, with its TDD marker: the git trailer, or
# for commits made before 2026-11-02 a "TDD: red|green" line in the body (it sat in its own paragraph,
# so git doesn't read it as a trailer).
function Get-TddCommit {
    param([Parameter(Mandatory)] [string] $RepoPath, [Parameter(Mandatory)] [string] $Range)

    $format = '%h%x1f%s%x1f%cI%x1f%(trailers:key=TDD,valueonly,separator=%x2C)%x1f%b%x1e'
    # --first-parent reads only the branch's own line. Commits merged in from another branch were checked
    # on that branch's pull request, and walking them by date interleaves the two lines, so one branch's
    # green could close another branch's red.
    $log = (git -C $RepoPath log --first-parent --reverse --no-merges "--format=$format" $Range) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "git log failed for range '$Range' in $RepoPath." }

    foreach ($record in $log -split "`u{1e}") {
        if (-not $record.Trim()) { continue }
        $hash, $subject, $committed, $trailer, $body = $record.TrimStart("`n") -split "`u{1f}", 5
        $marker = $trailer.Trim()
        # The body-line fallback is for history only: newer commits must carry a real trailer (GIT-005).
        # [ \t]* keeps "TDD:" and its value on one line.
        $isLegacy = [datetimeoffset]::Parse($committed, [cultureinfo]::InvariantCulture) -lt $script:TrailerCutoff
        if (-not $marker -and $isLegacy -and $body -match '(?m)^TDD:[ \t]*(\S+)[ \t]*$') {
            $marker = $Matches[1]
        }
        [pscustomobject]@{ Hash = $hash; Subject = $subject; Marker = $marker }
    }
}

# Prints each problem and returns 0 when every red is made green, otherwise 1.
function Invoke-RedGreenCheck {
    param([object[]] $Commits, [string] $RepoPath = '.', [string] $Range)

    if (-not $PSBoundParameters.ContainsKey('Commits')) {
        $Commits = @(Get-TddCommit -RepoPath $RepoPath -Range $Range)
    }
    $problems = @(Get-RedGreenProblem -Commits $Commits)
    foreach ($problem in $problems) {
        Write-Host "  $problem" -ForegroundColor Red
    }
    if ($problems.Count -gt 0) {
        Write-Host "`n$($problems.Count) red/green problem(s)." -ForegroundColor Red
        return 1
    }
    $reds = @($Commits | Where-Object Marker -EQ 'red').Count
    $greens = @($Commits | Where-Object Marker -EQ 'green').Count
    Write-Host "$reds red and $greens green commit(s); every red is made green." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Range) { throw 'Pass -Range, for example origin/main..HEAD.' }
    exit (Invoke-RedGreenCheck -RepoPath $RepoPath -Range $Range)
}
