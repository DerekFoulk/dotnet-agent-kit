#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when C# code breaks a CRF-008 limit that no analyzer checks: nesting, statements per member, file length
    or LCOM4 (ADR-0050).

.DESCRIPTION
    Lists the solution's projects with `dotnet sln list` and skips any that isn't C#. For each, it asks MSBuild for
    the project's Compile items and DefineConstants (`dotnet msbuild -getItem -getProperty`, which evaluates the
    project without building it; a multi-target project, through its first framework), so the check reads the files
    the compiler would. The SDK's implicit symbols, such as NET10_0_OR_GREATER, come from a build target, not the
    evaluation, so code under an #if on one of them is read as if the symbol weren't defined. It then runs the kit's
    Kit.CodeShape tool over the files, built from the kit's own source with the safety nets Invoke-KitCodeShape lists.
    Run it from the repo root, so the repo's global.json picks the SDK. Each finding prints in MSBuild's error format,
    which setup-dotnet's problem matcher turns into an annotation on the PR. A "// CRF-008 exception: <reason>"
    comment exempts one member, type or file (craft.md, "Exceptions"). Exit code: 0 when every limit holds, otherwise
    1; a tool that doesn't build stops the check with its errors.

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
        $evaluated = Read-MSBuildProject -Project $project
        # With TargetFrameworks, the outer evaluation has no Compile items: read the project through its first one.
        if (-not $evaluated.Properties.TargetFramework -and $evaluated.Properties.TargetFrameworks) {
            $first = ($evaluated.Properties.TargetFrameworks -split ';' | Where-Object { $_ })[0]
            $evaluated = Read-MSBuildProject -Project $project -TargetFramework $first
        }

        [pscustomobject]@{
            name    = $project
            defines = @($evaluated.Properties.DefineConstants -split ';' | Where-Object { $_ })
            files   = @($evaluated.Items.Compile | ForEach-Object FullPath)
        }
    }
}

# MSBuild's evaluation of a project, without a build: its Compile items, preprocessor symbols and target frameworks.
function Read-MSBuildProject {
    param(
        [Parameter(Mandatory)] [string] $Project,
        [string] $TargetFramework
    )

    $framework = @(if ($TargetFramework) { "-p:TargetFramework=$TargetFramework" })
    $json = dotnet msbuild $Project -getItem:Compile -getProperty:DefineConstants -getProperty:TargetFramework -getProperty:TargetFrameworks @framework
    if ($LASTEXITCODE -ne 0) { throw "dotnet msbuild couldn't evaluate '$Project': $($json -join "`n")" }
    ($json -join "`n") | ConvertFrom-Json
}

# Builds the kit's Kit.CodeShape tool, then runs it, leaving its exit code in $LASTEXITCODE. A tool that doesn't build
# stops the check with the build's errors, so a broken check never reads as a finding in the code.
function Invoke-KitCodeShape {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string[]] $Argument
    )

    $tool = Join-Path $KitRoot 'tools/CodeShape/src/Kit.CodeShape/Kit.CodeShape.csproj'
    # Safety nets for a build in an app's CI, which can't change the kit's code (CRF-001): analyzers and
    # warnings-as-errors are off, since the app's SDK may be newer than the one the kit's tool was written for, and so
    # is NuGet's audit, which the kit's own CI runs on these packages. MinVer is skipped, since the kit there is a
    # download of its commit, not a git checkout, and the tool needs no version.
    $settings = '-p:RunAnalyzers=false', '-p:TreatWarningsAsErrors=false', '-p:MSBuildTreatWarningsAsErrors=false', '-p:NuGetAudit=false', '-p:MinVerSkip=true'
    $build = @(dotnet build $tool --configuration Release -nologo -verbosity:quiet @settings 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "The kit's code shape tool didn't build:`n$($build -join "`n")" }
    dotnet run --project $tool --configuration Release --no-build -- @Argument
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
        $output = @(Invoke-KitCodeShape -KitRoot $KitRoot -Argument $manifest)
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
