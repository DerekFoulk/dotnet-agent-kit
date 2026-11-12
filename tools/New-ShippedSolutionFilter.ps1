#Requires -Version 7.6
<#
.SYNOPSIS
    Writes a solution filter (.slnf) of the projects a .slnx solution ships, leaving out its test projects.

.DESCRIPTION
    The shared .NET CI writes an SBOM of what a build ships (SUP-009, ADR-0055). CycloneDX's own
    --exclude-test-projects reads only each project file's XML, so it misses a test project marked by a
    Directory.Build.props, as the kit's sample and every app's tests are. This asks MSBuild instead: a project
    whose evaluated IsTestProject is true is left out. The filter is named after the solution, so the SBOM is too,
    and it names the solution relative to itself, as a solution filter does. It writes the filter's path.

.EXAMPLE
    ./tools/New-ShippedSolutionFilter.ps1 -Solution Contoso.Orders.slnx -Destination $env:RUNNER_TEMP/sbom-input
#>
[CmdletBinding()]
param(
    [string] $Solution,
    [string] $Destination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-ShippedSolutionFilter {
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [Parameter(Mandatory)] [string] $Destination
    )

    if (-not (Test-Path -LiteralPath $Solution -PathType Leaf)) { throw "No solution file at '$Solution'." }
    $solutionPath = (Resolve-Path -LiteralPath $Solution).Path
    $solutionFolder = Split-Path -Parent $solutionPath

    $shipped = foreach ($node in ([xml] (Get-Content -LiteralPath $solutionPath -Raw)).SelectNodes('//Project')) {
        $relative = $node.GetAttribute('Path')
        # CycloneDX reads only these project types (its Utils.IsSupportedProjectType); MSBuild may not evaluate the
        # rest, such as a shared project (.shproj), on Linux.
        if ([IO.Path]::GetExtension($relative) -notin '.csproj', '.fsproj', '.vbproj') { continue }
        $output = @(& dotnet msbuild (Join-Path $solutionFolder $relative) -nologo -getProperty:IsTestProject 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "MSBuild couldn't read $relative, so it's unknown whether it ships:`n$($output -join "`n")" }
        # The value is MSBuild's last line; an evaluation warning comes before it. Anything else is a surprise.
        $value = if ($output.Count) { "$($output[-1])".Trim() } else { '' }
        if ($value -notin 'true', 'false', '') { throw "MSBuild gave '$value' as $relative's IsTestProject:`n$($output -join "`n")" }
        if ($value -ne 'true') { $relative }
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $folder = (Resolve-Path -LiteralPath $Destination).Path
    $filter = Join-Path $folder ([IO.Path]::ChangeExtension((Split-Path -Leaf $solutionPath), '.slnf'))
    $json = [ordered]@{
        solution = [ordered]@{
            path = [IO.Path]::GetRelativePath($folder, $solutionPath) -replace '\\', '/'
            projects = @($shipped)
        }
    }
    $json | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $filter
    $filter
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution -or -not $Destination) { throw 'Give the solution with -Solution, and the folder for the filter with -Destination.' }
    New-ShippedSolutionFilter -Solution $Solution -Destination $Destination
}
