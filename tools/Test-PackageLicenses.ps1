#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when a package the solution's lock files resolve has a license the license policy doesn't allow (SEC-005,
    ADR-0004, ADR-0079).

.DESCRIPTION
    Reads the packages.lock.json beside every project the .slnx lists, takes every package it resolves (transitive
    ones too, not project references), and reads each one's license from its .nuspec in the global packages folder,
    so the solution must be restored first. A license is one of:
      expression <SPDX expression>       allowed when the expression is satisfied by the policy's licenses: OR needs
                                         one side, AND both, WITH keeps its license's verdict; ids match in any case
      file <name> sha256:<hash>          the license file in the package, allowed only by a package entry pinning it
      url <url>                          a package with only the deprecated licenseUrl, allowed only by an entry
    A package entry ({ id, license, reason }) allows that package under exactly that license, so a package that
    changes its license fails until someone reads the new one. An entry with "commercialUse": false allows it only in
    a repo not marked commercial, and names its "swap" otherwise.

    The policy is the kit's (tools/package-licenses.json, .kit/tools/ in an app) plus the repo's own
    .config/package-licenses.json, beside the solution, if it has one: its "licenses" and "packages" add to the kit's,
    and "commercial": true marks the repo commercial (ADR-0004).

.EXAMPLE
    ./tools/Test-PackageLicenses.ps1 -Solution dotnet-agent-kit.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution,
    [string] $Policy = (Join-Path $PSScriptRoot 'package-licenses.json'),
    [string] $PackagesFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'KitSolution.psm1') -Force

# SPDX license expressions (SPDX 2.3, Annex D): OR binds loosest, then AND, then WITH. Operators are uppercase. Each
# reader takes tokens off the queue and returns whether its part is allowed; a malformed expression throws a
# FormatException, which Test-LicenseExpression turns into "not allowed".
function Read-OrExpression([Collections.Generic.Queue[string]] $Tokens, [string[]] $Allowed) {
    $value = Read-AndExpression $Tokens $Allowed
    while ($Tokens.Count -gt 0 -and $Tokens.Peek() -ceq 'OR') {
        [void] $Tokens.Dequeue()
        $right = Read-AndExpression $Tokens $Allowed
        $value = $value -or $right
    }
    $value
}

function Read-AndExpression([Collections.Generic.Queue[string]] $Tokens, [string[]] $Allowed) {
    $value = Read-WithExpression $Tokens $Allowed
    while ($Tokens.Count -gt 0 -and $Tokens.Peek() -ceq 'AND') {
        [void] $Tokens.Dequeue()
        $right = Read-WithExpression $Tokens $Allowed
        $value = $value -and $right
    }
    $value
}

# An exception (Apache-2.0 WITH LLVM-exception) only adds permissions, so the license alone decides.
function Read-WithExpression([Collections.Generic.Queue[string]] $Tokens, [string[]] $Allowed) {
    $value = Read-License $Tokens $Allowed
    if ($Tokens.Count -gt 0 -and $Tokens.Peek() -ceq 'WITH') {
        [void] $Tokens.Dequeue()
        if ($Tokens.Count -eq 0 -or $Tokens.Dequeue() -cin '(', ')', 'AND', 'OR', 'WITH') { throw [FormatException]::new('WITH needs an exception id.') }
    }
    $value
}

# A license id, or a parenthesized expression. "<id>+" means that version or later, so the version named is allowed
# when <id> is.
function Read-License([Collections.Generic.Queue[string]] $Tokens, [string[]] $Allowed) {
    if ($Tokens.Count -eq 0) { throw [FormatException]::new('The expression ends early.') }
    $token = $Tokens.Dequeue()
    if ($token -eq '(') {
        $value = Read-OrExpression $Tokens $Allowed
        if ($Tokens.Count -eq 0 -or $Tokens.Dequeue() -ne ')') { throw [FormatException]::new('A ( is never closed.') }
        return $value
    }
    if ($token -cin ')', 'AND', 'OR', 'WITH') { throw [FormatException]::new("'$token' where a license id should be.") }
    $id = $token -replace '\+\z', ''
    @($Allowed | Where-Object { $_ -eq $id }).Count -gt 0
}

function Test-LicenseExpression([string] $Expression, [string[]] $Allowed) {
    $tokens = [Collections.Generic.Queue[string]]::new()
    foreach ($match in [regex]::Matches($Expression, '\(|\)|[^\s()]+')) { $tokens.Enqueue($match.Value) }
    try {
        $value = Read-OrExpression $tokens $Allowed
        $value -and $tokens.Count -eq 0
    }
    catch [FormatException] {
        $false
    }
}

# A package's license as the policy names it, from its .nuspec in the global packages folder (NuGet keeps each
# package in <id>/<version>/, lowercase); nothing when the package isn't there.
function Get-PackageLicense([string] $PackagesFolder, [string] $Id, [string] $Version) {
    $folder = Join-Path $PackagesFolder $Id.ToLowerInvariant() $Version.ToLowerInvariant()
    $nuspec = Join-Path $folder "$($Id.ToLowerInvariant()).nuspec"
    if (-not (Test-Path -LiteralPath $nuspec -PathType Leaf)) { return }
    [xml] $xml = Get-Content -Raw -LiteralPath $nuspec
    $metadata = $xml.DocumentElement.SelectSingleNode("*[local-name()='metadata']")
    $license = $metadata.SelectSingleNode("*[local-name()='license']")
    $url = $metadata.SelectSingleNode("*[local-name()='licenseUrl']")
    if ($license -and $license.GetAttribute('type') -eq 'expression') {
        return [pscustomobject]@{ Identity = "expression $($license.InnerText.Trim())"; Expression = $license.InnerText.Trim() }
    }
    if ($license -and $license.GetAttribute('type') -eq 'file') {
        $name = $license.InnerText.Trim().Replace('\', '/')
        $file = [IO.Path]::GetFullPath((Join-Path $folder $name))
        $inside = $file.StartsWith([IO.Path]::GetFullPath($folder) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)
        $hash = if ($inside -and (Test-Path -LiteralPath $file -PathType Leaf)) { (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() } else { 'missing' }
        return [pscustomobject]@{ Identity = "file $name sha256:$hash"; Expression = $null }
    }
    $identity = if ($license) { "$($license.GetAttribute('type')) $($license.InnerText.Trim())" } elseif ($url) { "url $($url.InnerText.Trim())" } else { 'none' }
    [pscustomobject]@{ Identity = $identity; Expression = $null }
}

# The kit's policy and the repo's own .config/package-licenses.json, if it has one, as one policy.
function Get-LicensePolicy([string] $Policy, [string] $RepoRoot) {
    $files = @($Policy, (Join-Path $RepoRoot '.config' 'package-licenses.json')) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    $merged = [pscustomobject]@{ Licenses = @(); Packages = @(); Commercial = $false }
    foreach ($file in $files) {
        $data = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json -AsHashtable
        $merged.Licenses += @($data['licenses'] | Where-Object { $_ })
        foreach ($entry in @($data['packages'] | Where-Object { $_ })) {
            if (-not ($entry['id'] -and $entry['license'] -and $entry['reason'])) { throw "$file`: every package entry needs an id, a license and a reason." }
            $merged.Packages += $entry
        }
        # Only the repo says whether it's commercial (ADR-0004).
        if ($file -ne $Policy -and $data['commercial'] -eq $true) { $merged.Commercial = $true }
    }
    $merged
}

# Why the package's license isn't allowed, or nothing when it is.
function Get-LicenseProblem([object] $Package, [object] $Policy, [string] $PackagesFolder) {
    $name = "$($Package.Id) $($Package.Version)"
    $license = Get-PackageLicense -PackagesFolder $PackagesFolder -Id $Package.Id -Version $Package.Version
    if (-not $license) { return "$name isn't in the global packages folder ($PackagesFolder); restore the solution first." }
    $entries = @($Policy.Packages | Where-Object { $_['id'] -eq $Package.Id })
    $swap = @($entries | Where-Object { $_['swap'] } | ForEach-Object { $_['swap'] }) | Select-Object -First 1
    $matched = @($entries | Where-Object { $_['license'] -ceq $license.Identity })
    $commercialUse = @($matched | Where-Object { -not $_.ContainsKey('commercialUse') -or $_['commercialUse'] })
    if ($matched.Count -gt 0 -and ($commercialUse.Count -gt 0 -or -not $Policy.Commercial)) { return }
    if ($matched.Count -gt 0) {
        $replace = if ($swap) { "use $swap instead" } else { 'replace it with a package free for commercial use' }
        return "$name`: $($license.Identity) is free only for non-commercial use ($($matched[0]['reason'])), and this repo is marked commercial in .config/package-licenses.json; $replace (ADR-0004)."
    }
    if ($license.Expression -and (Test-LicenseExpression -Expression $license.Expression -Allowed $Policy.Licenses)) { return }
    $changed = if ($entries.Count -gt 0) { "; the policy pins $(($entries | ForEach-Object { $_['license'] }) -join ' or ') for it, so its license changed: read the new one before you pin it" } else { '' }
    $instead = if ($swap) { ", or use $swap instead" } else { '' }
    "$name`: $($license.Identity) isn't allowed$changed. If it's free for commercial use, add it to .config/package-licenses.json with the reason (SEC-005)$instead."
}

# NuGet's global packages folder, as `dotnet nuget locals` reports it from the solution's folder (its nuget.config
# and NUGET_PACKAGES count).
function Get-GlobalPackagesFolder([string] $RepoRoot) {
    Push-Location -LiteralPath $RepoRoot
    try { $output = @(dotnet nuget locals global-packages --list) }
    finally { Pop-Location }
    $line = @($output | Where-Object { $_ -match '\Aglobal-packages: (?<path>.+)\z' })
    if ($line.Count -ne 1) { throw "dotnet nuget locals didn't name the global packages folder: $($output -join ' ')" }
    $Matches['path'].Trim()
}

# Prints each problem and returns 0 when every package's license is allowed, 1 otherwise.
function Invoke-PackageLicenseCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [string] $Policy = (Join-Path $PSScriptRoot 'package-licenses.json'),
        [string] $PackagesFolder
    )

    $repoRoot = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).ProviderPath
    if (-not $PackagesFolder) { $PackagesFolder = Get-GlobalPackagesFolder $repoRoot }
    $licensePolicy = Get-LicensePolicy -Policy $Policy -RepoRoot $repoRoot
    $problems = [System.Collections.Generic.List[string]]::new()
    $packages = [ordered]@{}
    $lockFiles = 0
    foreach ($project in Get-SolutionProject -Solution $Solution) {
        $lockFile = Join-Path (Split-Path -Parent $project.FullPath) 'packages.lock.json'
        if (-not (Test-Path -LiteralPath $lockFile -PathType Leaf)) {
            $problems.Add("$($project.Path) has no packages.lock.json beside it; restore with lock files on (SUP-001).")
            continue
        }
        $lockFiles++
        $lock = Get-Content -Raw -LiteralPath $lockFile | ConvertFrom-Json -AsHashtable
        foreach ($framework in $lock['dependencies'].Values) {
            foreach ($id in $framework.Keys | Where-Object { $framework[$_]['type'] -ne 'Project' }) {
                $packages["$id/$($framework[$id]['resolved'])"] = [pscustomobject]@{ Id = $id; Version = $framework[$id]['resolved'] }
            }
        }
    }
    foreach ($package in $packages.Values) {
        $problem = Get-LicenseProblem -Package $package -Policy $licensePolicy -PackagesFolder $PackagesFolder
        if ($problem) { $problems.Add($problem) }
    }

    foreach ($problem in $problems) { Write-Host "  $problem" -ForegroundColor Red }
    if ($problems.Count -gt 0) {
        Write-Host "`n$($problems.Count) license problem(s). Every package needs a license free for commercial use, or a reasoned entry in .config/package-licenses.json (SEC-005, ADR-0079)." -ForegroundColor Red
        return 1
    }
    Write-Host "$($packages.Count) package(s) in $lockFiles lock file(s): every license is allowed." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Pass -Solution, the .slnx whose projects to check.' }
    exit (Invoke-PackageLicenseCheck -Solution $Solution -Policy $Policy -PackagesFolder $PackagesFolder)
}
