#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when C# code breaks a CRF-008 limit that no analyzer checks: nesting, statements per member, file length
    or LCOM4 (ADR-0050).

.DESCRIPTION
    Lists the solution's projects with `dotnet sln list` and skips any that isn't C#. For each, it asks MSBuild for
    the project's Compile items and DefineConstants (`dotnet msbuild -getItem -getProperty`, which evaluates the
    project without building it), so the check reads exactly the files the compiler would. It then runs the kit's
    Kit.CodeShape tool over them, built from the kit's own source with analyzers off (the app's SDK may carry newer
    analyzers than the kit's tool was written against) and without MinVer (the kit's download isn't a git checkout). Run it from the repo root, so the repo's global.json picks the
    SDK. Each finding prints in MSBuild's error format, which setup-dotnet's problem matcher turns into an annotation
    on the PR. A "// CRF-008 exception: <reason>" comment exempts one member, type or file (craft.md, "Exceptions").
    Exit code: 0 when every limit holds, otherwise 1.

.EXAMPLE
    ./tools/Test-CodeShape.ps1 -Solution dotnet-agent-kit.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The C# projects in a solution, each with its preprocessor symbols and source files, as Kit.CodeShape's manifest
# lists them.
function Get-CodeShapeProject {
    param([Parameter(Mandatory)] [string] $Solution)

    $folder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).Path
    $listed = @(dotnet sln $Solution list)
    if ($LASTEXITCODE -ne 0) { throw "dotnet sln list failed for '$Solution': $($listed -join "`n")" }

    # The listing's two header lines end at the dashes; every line after them is a project path.
    $paths = $listed | Select-Object -Skip ([array]::FindIndex([string[]] $listed, [Predicate[string]] { $args[0] -match '^-+$' }) + 1)
    foreach ($path in $paths | Where-Object { $_ -like '*.csproj' }) {
        $project = Join-Path $folder $path
        $json = dotnet msbuild $project -getItem:Compile -getProperty:DefineConstants
        if ($LASTEXITCODE -ne 0) { throw "dotnet msbuild couldn't evaluate '$project': $($json -join "`n")" }

        $evaluated = ($json -join "`n") | ConvertFrom-Json
        [pscustomobject]@{
            name    = $project
            defines = @($evaluated.Properties.DefineConstants -split ';' | Where-Object { $_ })
            files   = @($evaluated.Items.Compile | ForEach-Object FullPath)
        }
    }
}

# Runs Kit.CodeShape over the solution's C# projects and returns its exit code and output.
function Invoke-CodeShapeCheck {
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [Parameter(Mandatory)] [string] $KitRoot
    )

    $manifest = Join-Path ([IO.Path]::GetTempPath()) "codeshape-$(New-Guid).json"
    try {
        ConvertTo-Json -InputObject @(Get-CodeShapeProject -Solution $Solution) -Depth 4 | Set-Content -LiteralPath $manifest
        $tool = Join-Path $KitRoot 'tools/CodeShape/src/Kit.CodeShape/Kit.CodeShape.csproj'
        # In CI the kit is a download of its commit, not a git checkout, so MinVer can't read a version there; the
        # tool needs none.
        $output = @(dotnet run --project $tool --configuration Release -p:RunAnalyzers=false -p:MinVerSkip=true -- $manifest)
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output -join "`n" }
    }
    finally {
        Remove-Item -LiteralPath $manifest -ErrorAction Ignore
    }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution to check, with -Solution.' }
    $result = Invoke-CodeShapeCheck -Solution $Solution -KitRoot (Join-Path $PSScriptRoot '..')
    $result.Output
    exit $result.ExitCode
}
