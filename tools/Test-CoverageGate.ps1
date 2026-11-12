#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when line coverage is below the TST-004 minimums: 100% for *.Domain, 95% for *.Application,
    90% overall.

.DESCRIPTION
    Reads every Cobertura report under -Path (one per test project, from
    `dotnet test --coverage --coverage-output-format cobertura --results-directory <Path>`) and merges them:
    a line counts as covered if any report covers it. Test assemblies (names ending in "Tests"), benchmarks
    assemblies (names ending in ".Benchmarks", ADR-0062) and generated files (*.g.cs, *.generated.cs, anything
    under obj/) are left out. No report at all is a failure, so a run that collected nothing can't pass.

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

# A benchmarks project (ADR-0062): its name ends in ".Benchmarks", in the case tests/Directory.Build.props matches.
function Test-BenchmarksAssembly([string] $Name) {
    $Name -clike '*.Benchmarks'
}

# Test-side code, never counted: test projects (names ending in "Tests") and benchmarks projects, which measure
# production code and ship nothing.
function Test-TestSideAssembly([string] $Name) {
    $Name -like '*Tests' -or (Test-BenchmarksAssembly $Name)
}

function Test-GeneratedFile {
    param([Parameter(Mandatory)] [string] $FileName)
    $FileName -match '\.(g|generated)\.cs$' -or $FileName -match '(^|[\\/])obj[\\/]'
}

# Every Cobertura report under the path, parsed: the one place that says which files are reports.
function Get-CoberturaReport {
    param([Parameter(Mandatory)] [string] $Path)

    foreach ($file in Get-ChildItem -Path $Path -Recurse -Filter '*.cobertura.xml' -File) {
        [pscustomobject]@{ Name = $file.Name; Xml = [xml] (Get-Content -LiteralPath $file.FullName -Raw) }
    }
}

# One row per assembly: lines covered, lines counted, and the percentage, merged across reports.
function Get-CoverageSummary {
    param([Parameter(Mandatory)] [string] $Path)

    $lines = @{}
    foreach ($report in Get-CoberturaReport -Path $Path) {
        $xml = $report.Xml
        # XPath at every level, not property access: PowerShell reads an empty element (<packages />, <classes />,
        # <lines />) as a string, which has none of the children's properties.
        foreach ($package in @($xml.SelectNodes('/coverage/packages/package'))) {
            $name = [string] $package.name
            if (Test-TestSideAssembly $name) { continue }
            foreach ($class in @($package.SelectNodes('classes/class'))) {
                $file = [string] $class.filename
                if (Test-GeneratedFile -FileName $file) { continue }
                foreach ($line in @($class.SelectNodes('lines/line'))) {
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
# project in it except UI projects must appear in the reports, and UI projects are left out. Returns 0 when
# all pass, else 1.
function Invoke-CoverageGate {
    param([Parameter(Mandatory)] [string] $Path, [string] $Solution)

    # UI projects are exempt (ARC-010, ADR-0059): they hold only views, platform code and startup wiring, which no
    # plain test project can load; their logic lives in libraries the gate counts.
    $exempt = if ($Solution) { @(& (Join-Path $PSScriptRoot 'Get-UiProject.ps1') -Solution $Solution | ForEach-Object Name) } else { @() }
    foreach ($name in $exempt) { Write-Host ('{0,-32} exempt (UI project, ARC-010)' -f $name) }

    # An empty report is legitimate for a test project that loads nothing the gate counts, but on Windows Microsoft's
    # collector also writes one when the clone's path is too long, and the project it should have counted then fails
    # below as one no test loads. Name each, so that cause is in sight.
    foreach ($report in Get-CoberturaReport -Path $Path) {
        if ($report.Xml.SelectNodes('/coverage/packages/package').Count -eq 0) {
            Write-Host "$($report.Name) lists no assemblies. On Windows that can mean the clone's path is too long for the coverage collector; see docs/standards/testing.md, ""Browser and accessibility tests""."
        }
    }

    $summary = @(Get-CoverageSummary -Path $Path | Where-Object { $exempt -notcontains $_.Package })
    if ($summary.Count -eq 0) {
        Write-Host "No Cobertura coverage report with counted lines under $Path; run dotnet test with --coverage first."
        return 1
    }

    $failed = $false

    # A production project that no test loads isn't in any report, so it would drop out silently.
    if ($Solution) {
        $expected = ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project') |
            ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.GetAttribute('Path')) } |
            Where-Object { $exempt -notcontains $_ }
        foreach ($name in $expected) {
            if (Test-BenchmarksAssembly $name) { Write-Host ('{0,-32} left out (benchmarks project, ADR-0062)' -f $name) }
            if (Test-TestSideAssembly $name) { continue }
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
