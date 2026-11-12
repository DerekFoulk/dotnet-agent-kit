#Requires -Version 7.6
# How the kit's scripts read a .NET solution (CRF-003): the projects a .slnx lists, the framework MSBuild must
# evaluate a multi-target project through, and which projects are benchmarks projects. Every kit script and shared
# workflow that reads a solution comes here.

Set-StrictMode -Version Latest

# The projects a .slnx solution lists, in its order, inside solution folders too. Path is as the solution writes it;
# FullPath is the file's full path with this OS's separators. A listed project needn't exist: each caller decides
# what a missing one means.
function Get-SolutionProject {
    param([Parameter(Mandatory)] [string] $Solution)

    if (-not (Test-Path -LiteralPath $Solution -PathType Leaf)) { throw "No solution file at '$Solution'." }
    # The kit's solutions are .slnx: New-KitApp writes one, and every shared workflow takes one.
    $extension = [IO.Path]::GetExtension($Solution)
    if ($extension -ne '.slnx') {
        $convert = if ($extension -eq '.sln') { " Convert it with 'dotnet sln $Solution migrate'." } else { '' }
        throw "$Solution isn't a .slnx solution, the only kind the kit's scripts read.$convert"
    }
    # The file system's own path, not a PowerShell drive's (TestDrive:\, a mapped drive), which .NET can't read.
    $folder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).ProviderPath
    foreach ($node in ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project')) {
        $path = $node.GetAttribute('Path')
        # A hand-written solution may use Windows separators. PowerShell's commands, Join-Path among them, accept \ or /
        # on every OS (about_Path_Syntax), so FullPath has this OS's own; the tests, which CI runs on Linux too, pin it.
        [pscustomobject]@{ Path = $path; FullPath = [IO.Path]::GetFullPath((Join-Path $folder $path)) }
    }
}

# The framework to evaluate a project through, from MSBuild's evaluated properties (-getProperty:TargetFramework
# -getProperty:TargetFrameworks): a multi-target project's first, or nothing for a project MSBuild already evaluated
# for one framework. MSBuild's outer evaluation of a multi-target project has no Compile items or output folder.
function Get-FirstTargetFramework {
    param([Parameter(Mandatory)] [object] $Properties)

    # MSBuild gives every property it was asked for, empty or not; a missing one means the caller didn't ask.
    foreach ($name in 'TargetFramework', 'TargetFrameworks') {
        if (-not $Properties.PSObject.Properties[$name]) {
            throw "MSBuild's evaluated properties have no $name; evaluate the project with -getProperty:$name."
        }
    }
    if (-not $Properties.TargetFramework) {
        $Properties.TargetFrameworks -split ';' | Where-Object { $_ } | Select-Object -First 1
    }
}

# Whether a project, by its name (its file name without the extension, which is its assembly name), is a benchmarks
# project (ADR-0062): one whose name ends in ".Benchmarks", in that case. This is the one statement of that rule
# (CRF-003). The coverage gate, the SBOM's solution filter and performance.reusable.yml call it. MSBuild
# (sample/Directory.Build.props, an app's tests/Directory.Build.props) and .editorconfig can't, so KitSolution.Tests.ps1
# checks each of them against it.
function Test-BenchmarksProject {
    param([Parameter(Mandatory)] [string] $Name)

    # Case-sensitive, as MSBuild's String.EndsWith in tests/Directory.Build.props is.
    $Name -clike '*.Benchmarks'
}

Export-ModuleMember -Function Get-SolutionProject, Get-FirstTargetFramework, Test-BenchmarksProject
