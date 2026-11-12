#Requires -Version 7.6
<#
.SYNOPSIS
    Fails when the same C# code appears in more than one place, which usually means one piece of knowledge kept twice
    (CRF-003, ADR-0051).

.DESCRIPTION
    Takes the solution's hand-written C# files, the same files the code shape check reads (Test-CodeShape.ps1; generated
    code is skipped by the compiler's own test), and runs PMD's copy-paste detector, CPD, over them. CPD is tuned for
    knowledge, not looks: at least 100 tokens must repeat, and using directives, attributes and runs of literals (data
    tables) are ignored. Each place a duplication occurs prints in MSBuild's error format, naming the other places, so
    setup-dotnet's problem matcher annotates the PR. Code that looks alike but changes for different reasons stays as it
    is between "// CPD-OFF <reason>" and "// CPD-ON" comments (craft.md, "Exceptions"). CPD needs Java; the shared CI
    workflow downloads a pinned PMD release and checks its hash. Run it from the repo root. Exit code: 0 when no code
    repeats, otherwise 1.

.EXAMPLE
    ./tools/Test-Duplication.ps1 -Solution dotnet-agent-kit.slnx -Pmd ~/pmd-bin-7.29.0/bin/pmd
#>
[CmdletBinding()]
param(
    [string] $Solution,
    [string] $Pmd
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Its functions read the solution's files. Dot-sourcing binds its own -Solution parameter in this scope, so pass ours
# on, or it would be reset.
. (Join-Path $PSScriptRoot 'Test-CodeShape.ps1') -Solution $Solution

# The fewest tokens a repeat must have to count. Below about 100, CPD finds look-alike code: argument checks, small
# test arrangements, property lists (ADR-0051).
$script:MinimumTokens = 100

# CPD's command line for C#, tuned to find repeated knowledge rather than code that only looks alike (ADR-0051).
function Get-CpdArgument {
    param([Parameter(Mandatory)] [string] $FileList)

    @(
        'cpd', '--language', 'cs', '--minimum-tokens', $script:MinimumTokens,
        '--ignore-usings', '--ignore-annotations', '--ignore-literal-sequences',
        '--file-list', $FileList, '--format', 'xml', '--no-fail-on-violation'
    )
}

# Each duplication in a CPD XML report, with every place it occurs.
function Get-Duplication {
    param([Parameter(Mandatory)] [string] $Report)

    $xml = [xml] (Get-Content -Raw -LiteralPath $Report)
    $namespaces = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
    $namespaces.AddNamespace('cpd', 'https://pmd-code.org/schema/cpd-report')
    foreach ($duplication in $xml.SelectNodes('/cpd:pmd-cpd/cpd:duplication', $namespaces)) {
        [pscustomobject]@{
            Lines  = [int] $duplication.lines
            Tokens = [int] $duplication.tokens
            Places = @($duplication.SelectNodes('cpd:file', $namespaces) | ForEach-Object {
                    [pscustomobject]@{ Path = $_.path; Line = [int] $_.line; EndLine = [int] $_.endline; Column = [int] $_.column }
                })
        }
    }
}

function Get-SkippedFile { param([string] $Report) }
function Format-SkippedFile { param([Parameter(ValueFromPipeline)] $Skipped, [string] $Solution) process { } }

# One MSBuild-format error line per place a duplication occurs, naming the other places.
function Format-Duplication {
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $Duplication,
        [Parameter(Mandatory)] [string] $Solution
    )

    process {
        foreach ($place in $Duplication.Places) {
            $others = ($Duplication.Places | Where-Object { $_ -ne $place } | ForEach-Object { "$($_.Path) lines $($_.Line)-$($_.EndLine)" }) -join ', '
            "$($place.Path)($($place.Line),$($place.Column)): error CRF003: $($Duplication.Lines) lines ($($Duplication.Tokens) tokens) repeat $others; keep the knowledge in one place (CRF-003). [$Solution]"
        }
    }
}

# Runs CPD over the solution's hand-written C# files and returns its exit code and output.
function Invoke-DuplicationCheck {
    param(
        [Parameter(Mandatory)] [string] $Solution,
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $Pmd
    )

    $work = Join-Path ([IO.Path]::GetTempPath()) "duplication-$(New-Guid)"
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        $manifest = Join-Path $work 'manifest.json'
        $fileList = Join-Path $work 'files.txt'
        $report = Join-Path $work 'cpd.xml'
        ConvertTo-Json -InputObject @(Get-CodeShapeProject -Solution $Solution) -Depth 4 | Set-Content -LiteralPath $manifest
        $files = @(Invoke-KitCodeShape -KitRoot $KitRoot -Argument '--files', $manifest)
        if ($LASTEXITCODE -ne 0) { throw "Kit.CodeShape couldn't list the files: $($files -join "`n")" }
        $files | Set-Content -LiteralPath $fileList

        & $Pmd @(Get-CpdArgument -FileList $fileList) | Set-Content -LiteralPath $report
        if ($LASTEXITCODE -ne 0) { throw "CPD failed with exit code $LASTEXITCODE (1: an exception, 2: a usage error, 5: a file it couldn't read)." }

        $lines = @(Get-Duplication -Report $report | Format-Duplication -Solution $Solution)
        if ($lines) {
            return [pscustomobject]@{ ExitCode = 1; Output = $lines -join "`n" }
        }

        [pscustomobject]@{ ExitCode = 0; Output = "Duplicate code (CRF-003): $($files.Count) files, nothing repeats in $script:MinimumTokens tokens or more." }
    }
    finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction Ignore
    }
}

# Run when invoked as a script; stay quiet when dot-sourced (the tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Solution -or -not $Pmd) { throw 'Give the solution to check, with -Solution, and the PMD launcher, with -Pmd.' }
    $result = Invoke-DuplicationCheck -Solution $Solution -KitRoot (Join-Path $PSScriptRoot '..') -Pmd $Pmd
    $result.Output
    exit $result.ExitCode
}
