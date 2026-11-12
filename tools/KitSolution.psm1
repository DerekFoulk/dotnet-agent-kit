#Requires -Version 7.6
# How the kit's scripts read a .NET solution (CRF-003): the projects a .slnx lists, and the framework MSBuild must
# evaluate a multi-target project through. Every kit script and shared workflow that reads a solution comes here.

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
        # A hand-written solution may use Windows separators, which .NET on Linux reads as part of a name.
        [pscustomobject]@{ Path = $path; FullPath = [IO.Path]::GetFullPath((Join-Path $folder ($path -replace '\\', '/'))) }
    }
}

# The framework to evaluate a project through, from MSBuild's evaluated properties (-getProperty:TargetFramework
# -getProperty:TargetFrameworks): a multi-target project's first, or nothing for a project MSBuild already evaluated
# for one framework. MSBuild's outer evaluation of a multi-target project has no Compile items or output folder.
function Get-FirstTargetFramework {
    param([Parameter(Mandatory)] [object] $Properties)

    if (-not $Properties.TargetFramework -and $Properties.TargetFrameworks) {
        $Properties.TargetFrameworks -split ';' | Where-Object { $_ } | Select-Object -First 1
    }
}

Export-ModuleMember -Function Get-SolutionProject, Get-FirstTargetFramework
