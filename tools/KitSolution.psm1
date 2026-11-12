#Requires -Version 7.6
# How the kit's scripts read a .NET solution (CRF-003): the projects a .slnx lists, and the framework MSBuild must
# evaluate a multi-target project through. Every kit script and shared workflow that reads a solution comes here.

Set-StrictMode -Version Latest

# The projects a .slnx solution lists, in its order, inside solution folders too. Path is as the solution writes it;
# FullPath is the file's full path with this OS's separators. A listed project needn't exist: each caller decides
# what a missing one means.
function Get-SolutionProject {
    param([Parameter(Mandatory)] [string] $Solution)

    $folder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).ProviderPath
    foreach ($node in ([xml] (Get-Content -LiteralPath $Solution -Raw)).SelectNodes('//Project')) {
        $path = $node.GetAttribute('Path')
        [pscustomobject]@{ Path = $path; FullPath = [IO.Path]::GetFullPath((Join-Path $folder $path)) }
    }
}

Export-ModuleMember -Function Get-SolutionProject
