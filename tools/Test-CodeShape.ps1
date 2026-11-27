#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when C# code breaks a CRF-011 limit that no analyzer checks: nesting, statements per member, file length,
    members per type, public types per file or LCOM4 (ADR-0050, ADR-0071); or breaks STY-005's nullable rules: a
    #nullable directive, a null-forgiving operator (!) with no "// CRF-001 safety net: <reason>" comment on its line or
    the line above, or a file marked as generated code outside an EF Core Migrations folder (a .resx file's designer
    excepted). Code under an #if the evaluation doesn't define, such as NET10_0_OR_GREATER, isn't read, so a ! there
    isn't checked.

.DESCRIPTION
    Lists the .slnx solution's projects (KitSolution.psm1) and skips any that isn't C#. For each, it asks MSBuild for
    the project's Compile items and DefineConstants (`dotnet msbuild -getItem -getProperty`, which evaluates the
    project without building it; a multi-target project, through its first framework), so the check reads the files
    the compiler would. The SDK's implicit symbols, such as NET10_0_OR_GREATER, come from a build target, not the
    evaluation, so code under an #if on one of them is read as if the symbol weren't defined. It then runs the kit's
    Kit.CodeShape tool over the files, built from the kit's own source with the safety nets Invoke-KitCodeShape lists.
    Run it from the repo root, so the repo's global.json picks the SDK. Each finding prints in MSBuild's error format,
    which setup-dotnet's problem matcher turns into an annotation on the PR. A "// CRF-011 exception: <reason>"
    comment exempts one member, type or file (craft.md, "Exceptions"). A finding of a should rule,
    such as CRF-011, is a GitHub warning annotation instead, and doesn't fail the check unless the rule is a must
    (ADR-0089); -RuleStrengthPath names another rule-strength.json than the one beside this script. Exit code: 0 when no
    finding of a must rule is left, otherwise 1; a tool that doesn't build stops the check with its errors.

.EXAMPLE
    ./tools/Test-CodeShape.ps1 -Solution dotnet-agent-kit.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution,
    [string] $RuleStrengthPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'KitSolution.psm1') -Force
Import-Module -Name (Join-Path $PSScriptRoot 'KitRuleStrength.psm1') -Force

# The C# projects in a solution, each with its preprocessor symbols and source files, as Kit.CodeShape's manifest
# lists them.
function Get-CodeShapeProject {
    param([Parameter(Mandatory)] [string] $Solution)

    foreach ($project in Get-SolutionProject -Solution $Solution | ForEach-Object FullPath | Where-Object { $_ -like '*.csproj' }) {
        $evaluated = Read-MSBuildProject -Project $project
        # With TargetFrameworks, the outer evaluation has no Compile items: read the project through its first one.
        $first = Get-FirstTargetFramework -Properties $evaluated.Properties
        if ($first) { $evaluated = Read-MSBuildProject -Project $project -TargetFramework $first }

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

# The rule a Kit.CodeShape error code names: CRF011 is CRF-011 (tools/CodeShape/src/Kit.CodeShape/RuleCodes.cs).
function ConvertTo-CodeShapeRuleId {
    param([Parameter(Mandatory)] [string] $Code)

    if ($Code -cnotmatch '^(?<letters>[A-Z]+)(?<number>\d+)$') { throw "'$Code' isn't a Kit.CodeShape error code, such as CRF011." }
    "$($Matches['letters'])-$($Matches['number'])"
}

# A finding's file as a warning names it: relative to the folder the check runs in, which is the repo root (GitHub's
# own example names a file in the repo, file=app.js), with / between folders. A path outside that folder, or one that
# isn't a full path on this system, is kept as the tool printed it, with / between folders.
function Get-CodeShapeFindingFile {
    param([Parameter(Mandatory)] [string] $Path)

    $root = (Get-Location).ProviderPath.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::IsPathRooted($Path) -and $Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $Path = $Path.Substring($root.Length)
    }
    $Path.Replace('\', '/')
}

# Prints Kit.CodeShape's output and returns the check's exit code (ADR-0089). Each finding names its rule in its error
# code, CRF011 for CRF-011: a should rule's finding is a warning that doesn't fail the check, a must rule's is
# printed as it is, in MSBuild's error format, and fails it (KitRuleStrength.psm1). Any other exit code than 1 is the
# tool's own, kept; a run that exited 1 with no finding to read fails, since the check is broken.
function Write-CodeShapeResult {
    param([int] $ExitCode, [AllowEmptyString()] [string] $Output, [string] $RuleStrengthPath)

    $counted = 0
    $warned = 0
    $skipped = 0
    foreach ($line in $Output -split '\r?\n' | Where-Object { $_ }) {
        $finding = [regex]::Match($line, '^(?<file>.+)\((?<line>\d+),(?<column>\d+)\): error (?<code>[A-Z]+\d+): ')
        if (-not $finding.Success) {
            Write-Host $line
            continue
        }
        $rule = ConvertTo-CodeShapeRuleId -Code $finding.Groups['code'].Value
        $place = @{
            File   = Get-CodeShapeFindingFile -Path $finding.Groups['file'].Value
            Line   = [int] $finding.Groups['line'].Value
            Column = [int] $finding.Groups['column'].Value
        }
        if (Write-RuleFinding -Id $rule -Message $line -Path $RuleStrengthPath @place) { $counted++ }
        elseif (Get-RuleSkip -Id $rule -Path $RuleStrengthPath) { $skipped++ }
        else { $warned++ }
    }

    if ($ExitCode -ne 1) { return $ExitCode }
    if ($counted + $warned + $skipped -eq 0) { return 1 }
    $notJudged = if ($skipped) { "; $skipped more not judged, because their rule doesn't apply to this app" } else { '' }
    if ($counted) {
        $more = if ($warned) { "; $warned more were warnings, because their rule is a should rule" } else { '' }
        $more += $notJudged
        Write-Host "`n$counted code shape finding(s) fail the check$more." -ForegroundColor Red
        return 1
    }
    if (-not $warned) {
        Write-Host "`n$skipped code shape finding(s) not judged, because their rule doesn't apply to this app (see each notice)." -ForegroundColor Yellow
        return 0
    }
    Write-Host "`n$warned code shape finding(s), shown as warnings because their rule is a should rule; they'd fail the check at must$notJudged." -ForegroundColor Yellow
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution) { throw 'Give the solution to check, with -Solution.' }
    $result = Invoke-CodeShapeCheck -Solution $Solution -KitRoot (Join-Path $PSScriptRoot '..')
    exit (Write-CodeShapeResult -ExitCode $result.ExitCode -Output $result.Output -RuleStrengthPath $RuleStrengthPath)
}
