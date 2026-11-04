#Requires -Version 7.0
<#
.SYNOPSIS
    Fails when line coverage is below the TST-004 minimums: 100% for *.Domain, 95% for *.Application,
    90% overall.

.DESCRIPTION
    Reads every Cobertura report under -Path (one per test project, from
    `dotnet test --coverage --coverage-output-format cobertura --results-directory <Path>`) and merges them:
    a line counts as covered if any report covers it. Test assemblies (names ending in "Tests") and
    generated files (*.g.cs, *.generated.cs, anything under obj/) are left out. No report at all is a
    failure, so a run that collected nothing can't pass.

.EXAMPLE
    dotnet test --coverage --coverage-output-format cobertura --results-directory TestResults
    ./tools/Test-CoverageGate.ps1 -Path TestResults
#>
[CmdletBinding()]
param(
    [string] $Path = 'TestResults',
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# TST-004. The first matching rule applies; the overall minimum covers every counted assembly.
$script:CoverageRules = @(
    [pscustomobject]@{ Pattern = '*.Domain'; Minimum = 100 }
    [pscustomobject]@{ Pattern = '*.Application'; Minimum = 95 }
)
$script:OverallMinimum = 90

function Test-GeneratedFile {
    param([Parameter(Mandatory)] [string] $FileName)
    $FileName -match '\.(g|generated)\.cs$' -or $FileName -match '(^|[\\/])obj[\\/]'
}

# One row per assembly: lines covered, lines counted, and the percentage, merged across reports.
function Get-CoverageSummary {
    param([Parameter(Mandatory)] [string] $Path)

    $lines = @{}
    foreach ($report in Get-ChildItem -Path $Path -Recurse -Filter '*.cobertura.xml' -File) {
        [xml] $xml = Get-Content -LiteralPath $report.FullName -Raw
        foreach ($package in @($xml.coverage.packages.package)) {
            $name = [string] $package.name
            if ($name -like '*Tests') { continue }
            foreach ($class in @($package.classes.class)) {
                $file = [string] $class.filename
                if (Test-GeneratedFile -FileName $file) { continue }
                foreach ($line in @($class.lines.line)) {
                    if ($null -eq $line) { continue }
                    $key = "$name|$file|$($line.number)"
                    $lines[$key] = ($lines.ContainsKey($key) -and $lines[$key]) -or ([int] $line.hits -gt 0)
                }
            }
        }
    }

    $lines.GetEnumerator() |
        Group-Object { ($_.Key -split '\|', 2)[0] } |
        Sort-Object Name |
        ForEach-Object {
            $covered = @($_.Group | Where-Object Value).Count
            [pscustomobject]@{
                Package = $_.Name
                Covered = $covered
                Total   = $_.Count
                # For display only; Test-CoverageMinimum compares exact counts.
                Percent = [math]::Round(100 * $covered / $_.Count, 2)
            }
        }
}

# Exact check: covered/total is at least minimum%, with no rounding.
function Test-CoverageMinimum {
    param([int] $Covered, [int] $Total, [double] $Minimum)
    $Covered * 100 -ge $Minimum * $Total
}

# Prints each assembly against its minimum, then the overall total. With -Solution, every production
# project in it must appear in the reports. Returns 0 when all pass, else 1.
function Invoke-CoverageGate {
    param([Parameter(Mandatory)] [string] $Path, [string] $Solution)

    $summary = @(Get-CoverageSummary -Path $Path)
    if ($summary.Count -eq 0) {
        Write-Host "No Cobertura coverage report with counted lines under $Path; run dotnet test with --coverage first."
        return 1
    }

    $failed = $false

    # A production project that no test loads isn't in any report, so it would drop out silently.
    if ($Solution) {
        $expected = ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project') |
            ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.GetAttribute('Path')) } |
            Where-Object { $_ -notlike '*Tests' }
        foreach ($name in $expected) {
            if ($summary.Package -notcontains $name) {
                $failed = $true
                Write-Host ('{0,-32} FAIL: no coverage at all; no test loads it' -f $name)
            }
        }
    }

    foreach ($row in $summary) {
        $rule = $script:CoverageRules | Where-Object { $row.Package -like $_.Pattern } | Select-Object -First 1
        $minimum = if ($rule) { $rule.Minimum } else { $null }
        $status = if ($null -eq $minimum) { 'counted in overall' } elseif (Test-CoverageMinimum -Covered $row.Covered -Total $row.Total -Minimum $minimum) { "ok (minimum $minimum%)" } else { $failed = $true; "FAIL: minimum $minimum%" }
        Write-Host ('{0,-32} {1,6}% ({2}/{3} lines)  {4}' -f $row.Package, $row.Percent, $row.Covered, $row.Total, $status)
    }

    $covered = ($summary | Measure-Object Covered -Sum).Sum
    $total = ($summary | Measure-Object Total -Sum).Sum
    $overall = [math]::Round(100 * $covered / $total, 2)
    $overallStatus = if (Test-CoverageMinimum -Covered $covered -Total $total -Minimum $script:OverallMinimum) { "ok (minimum $($script:OverallMinimum)%)" } else { $failed = $true; "FAIL: minimum $($script:OverallMinimum)%" }
    Write-Host ('{0,-32} {1,6}% ({2}/{3} lines)  {4}' -f 'overall', $overall, $covered, $total, $overallStatus)

    if ($failed) { 1 } else { 0 }
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-CoverageGate -Path $Path -Solution $Solution)
}
