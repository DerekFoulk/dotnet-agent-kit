#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when a C# project in the solution holds no code of its own, or keeps the class library template's empty
    Class1 (ARC-009, ADR-0052). While ARC-009 is proposed, each problem is a GitHub warning annotation and the check
    passes; once it's accepted, the same problems fail it (ADR-0089). -RuleStatusPath names another rule-status.json
    than the one beside this script.

.EXAMPLE
    ./tools/Test-EmptyProjects.ps1 -Solution dotnet-agent-kit.slnx
#>
[CmdletBinding()]
param(
    [string] $Solution,
    [string] $RuleStatusPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'KitSolution.psm1') -Force
Import-Module -Name (Join-Path $PSScriptRoot 'KitRuleStatus.psm1') -Force

# Where the build writes output and generated C# by default (BaseOutputPath and BaseIntermediateOutputPath): not the
# project's own source.
$script:BuildFolders = 'bin', 'obj'

# The check reads C# projects only; other kinds (a database, compose or JavaScript project) hold other files.
$script:ProjectExtension = '.csproj'

# What counts as a C# project's own code: C#, Razor components and pages (a Razor class library may hold only those),
# and .proto files, which Grpc.Tools turns into C# at build time.
$script:SourceExtensions = '.cs', '.razor', '.cshtml', '.proto'

# Rule is the rule a problem breaks, whose status decides whether it fails the check (ADR-0089); a broken solution
# breaks none and always fails.
function New-Problem {
    param([string] $Message, [string] $Rule = 'ARC-009')
    [pscustomobject]@{ Message = $Message; Rule = $Rule }
}

# True for the file `dotnet new classlib` writes, Class1.cs with an empty class Class1, in either namespace style.
function Test-PlaceholderFile {
    param([Parameter(Mandatory)] [IO.FileInfo] $File)

    $File.Name -eq 'Class1.cs' -and (Get-Content -LiteralPath $File.FullName -Raw) -match '\bclass\s+Class1\s*\{\s*\}'
}

# The project's own source files: under its folder, outside its bin/ and obj/, and outside any subfolder that holds a
# project of its own (a console tool's tests can sit beneath it). One scan, which doesn't follow links, then the
# folders to leave out are dropped by path: walking folder by folder was 34 times slower under a node_modules.
function Get-ProjectSourceFile {
    param([Parameter(Mandatory)] [string] $Folder)

    $Folder = [IO.Path]::GetFullPath($Folder).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $all = @(Get-ChildItem -LiteralPath $Folder -Recurse -File)
    $excluded = @($script:BuildFolders | ForEach-Object { Join-Path $Folder $_ }) +
        @($all | Where-Object { $_.Extension -like '.*proj' -and $_.DirectoryName -ne $Folder } | ForEach-Object DirectoryName)
    $prefixes = @($excluded | Sort-Object -Unique | ForEach-Object { $_ + [IO.Path]::DirectorySeparatorChar })
    $all | Where-Object Extension -In $script:SourceExtensions | Where-Object {
        $path = $_.FullName
        -not ($prefixes | Where-Object { $path.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })
    }
}

function Get-EmptyProjectProblem {
    param([Parameter(Mandatory)] [string] $Solution)

    $projects = @(Get-SolutionProject -Solution $Solution)
    # The file system's own path, not a PowerShell drive's (TestDrive:\, a mapped drive), which .NET can't read.
    $solutionFolder = Split-Path -Parent (Resolve-Path -LiteralPath $Solution).ProviderPath
    foreach ($project in $projects) {
        # Messages name the project as the solution does, with / on every platform.
        $relative = $project.Path.Replace('\', '/')
        if ([IO.Path]::GetExtension($relative) -ne $script:ProjectExtension) {
            continue
        }
        if (-not (Test-Path -LiteralPath $project.FullPath -PathType Leaf)) {
            New-Problem -Message "$relative is in the solution but isn't there" -Rule ''
            continue
        }
        $projectFolder = Split-Path -Parent $project.FullPath
        $files = @(Get-ProjectSourceFile -Folder $projectFolder)
        $placeholders = @($files | Where-Object { Test-PlaceholderFile -File $_ })
        if ($files.Count -eq $placeholders.Count) {
            New-Problem -Message "$relative has no source files of its own"
            continue
        }
        foreach ($placeholder in $placeholders) {
            $path = [IO.Path]::GetRelativePath($solutionFolder, $placeholder.FullName).Replace('\', '/')
            New-Problem -Message "$path is the class library template's empty placeholder"
        }
    }
}

# Prints every problem and returns 0 when every project holds code of its own, otherwise 1. While ARC-009 is
# proposed, each of its problems is a warning and doesn't fail the check (ADR-0089); a project the solution lists but
# that isn't there is a broken solution, and fails it whatever ARC-009's status.
function Invoke-EmptyProjectsCheck {
    param([Parameter(Mandatory)] [string] $Solution, [string] $RuleStatusPath)

    $problems = @(Get-EmptyProjectProblem -Solution $Solution)
    $counted = @($problems | Where-Object {
            if ($_.Rule) { Write-RuleFinding -Id $_.Rule -Message $_.Message -Path $RuleStatusPath }
            else { Write-Host $_.Message -ForegroundColor Red; $true }
        }).Count

    if ($counted) {
        $more = if ($problems.Count -gt $counted) { "; $($problems.Count - $counted) more were warnings, because ARC-009 is proposed" } else { '' }
        Write-Host "`n$counted empty-project problem(s) in $Solution$more. Remove a project until its first real type needs it (ARC-009)." -ForegroundColor Red
        return 1
    }
    if ($problems) {
        Write-Host "`n$($problems.Count) empty-project problem(s) in $Solution, shown as warnings because ARC-009 is proposed; they'll fail the check once it's accepted." -ForegroundColor Yellow
        return 0
    }

    Write-Host "Every project in $Solution holds code of its own." -ForegroundColor Green
    0
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-EmptyProjectsCheck -Solution $Solution -RuleStatusPath $RuleStatusPath)
}
