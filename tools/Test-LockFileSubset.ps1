#Requires -Version 7.6
<#
.SYNOPSIS
    Fails unless every NuGet lock file a restore wrote matches the committed one for each target framework it lists.

.DESCRIPTION
    A MAUI project builds fewer target frameworks on macOS than on Windows, where its lock file is made, so NuGet
    refuses a locked restore there (NU1004). The macOS CI job restores without locked mode, and this check then
    gives the same guarantee for the frameworks macOS builds (SUP-001, ADR-0057): each one's packages, versions and
    hashes must be exactly as committed. A framework the committed file lacks, or a lock file nobody committed,
    fails too. Run it in the checkout, after the restore.

.EXAMPLE
    dotnet restore App.slnx -p:RestoreLockedMode=false
    ./tools/Test-LockFileSubset.ps1 -RepoRoot .
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One line per problem; nothing when every lock file is a subset of its committed version.
function Get-LockFileSubsetProblem {
    param([Parameter(Mandatory)] [string] $RepoRoot)

    $untracked = @(git -C $RepoRoot ls-files --others --exclude-standard -- ':(glob)**/packages.lock.json')
    if ($LASTEXITCODE -ne 0) { throw "git couldn't list the files in $RepoRoot." }
    foreach ($path in $untracked) { "$path isn't committed: run a restore on Windows and commit it." }

    foreach ($path in @(git -C $RepoRoot ls-files -- ':(glob)**/packages.lock.json')) {
        $file = Join-Path $RepoRoot $path
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
        $committed = (git -C $RepoRoot show "HEAD:$path") -join "`n" | ConvertFrom-Json -AsHashtable
        $restored = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json -AsHashtable
        foreach ($framework in $restored['dependencies'].Keys) {
            if (-not $committed['dependencies'].ContainsKey($framework)) {
                "${path}: the restore added $framework, which the committed lock file doesn't have."
            }
            elseif ((ConvertTo-Json -Depth 20 -Compress $restored['dependencies'][$framework]) -cne (ConvertTo-Json -Depth 20 -Compress $committed['dependencies'][$framework])) {
                "${path}: $framework resolved different packages than the committed lock file."
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $problems = @(Get-LockFileSubsetProblem -RepoRoot $RepoRoot)
    $problems | ForEach-Object { Write-Host $_ }
    if ($problems) { exit 1 }
    Write-Host 'Every restored lock file matches the committed one for each framework it lists.'
}
