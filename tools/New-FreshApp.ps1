#Requires -Version 7.6
<#
.SYNOPSIS
    Writes a fresh app of one app type from the kit at one commit, with a probe project of that type, for the kit's
    CI to check (GAP-049, ADR-0095). It creates no GitHub repo.

.DESCRIPTION
    Exports the app with Export-KitApp.ps1, as New-KitApp does, with an app profile whose answers are the intake's
    defaults and whose app type is -Type. Kit only: an app never gets this script.

.EXAMPLE
    ./tools/New-FreshApp.ps1 -Type web-api -Destination ../fresh-web-api
#>
[CmdletBinding()]
param(
    [string] $Type,
    [string] $Destination,
    [string] $KitRef = 'HEAD',
    [string] $KitRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'KitIntake.psm1') -Force

# New-KitApp's first commit, so a fresh app's history starts as a real app's does (CRF-003). Loaded in a child scope, so
# New-KitApp's parameters don't replace this script's, then defined here with the git helper it calls.
$script:KitAppFunctions = & {
    . (Join-Path $PSScriptRoot 'New-KitApp.ps1')
    @{ 'New-KitAppFirstCommit' = ${function:New-KitAppFirstCommit}; 'Invoke-KitGit' = ${function:Invoke-KitGit} }
}
foreach ($function in $script:KitAppFunctions.GetEnumerator()) { Set-Item -Path "function:script:$($function.Key)" -Value $function.Value }
# Export-KitApp's pattern for a labelled package group, loaded the same way.
$script:PackageGroupPattern = & { . (Join-Path $PSScriptRoot 'Export-KitApp.ps1'); ${function:Get-KitPackageGroupPattern} }
Set-Item -Path 'function:script:Get-KitPackageGroupPattern' -Value $script:PackageGroupPattern

# The probe for each app type the job checks: the kit's own reference app of that type (ADR-0095). Name is the app's
# name; From is the kit folder whose src/ and tests/ become the app's; PackageGroups are the labelled groups of the
# kit's Directory.Packages.props that Export-KitApp leaves out and the probe uses; RepoFiles are the kit repo's own files
# the probe needs as an app has them: the sample's license entries (.config/package-licenses.json, ADR-0098), which a
# server app on SQL Server adds for itself.
$script:Probes = [ordered]@{
    'web-api' = @{ Name = 'Fresh.WebApi'; From = 'sample'; PackageGroups = @('Sample app'); RepoFiles = @('.config/package-licenses.json') }
    'blazor'  = @{ Name = 'Fresh.Blazor'; From = 'fixtures/WebUi'; PackageGroups = @(); RepoFiles = @() }
}

# App types in docs/standards/app-types.yml that have no probe yet, and why (GAP-049 stays open for them).
$script:Waiting = @{
    'maui' = "MAUI's leg needs the Windows and macOS jobs proven first (GAP-028), and the owner put MAUI after the practice run"
}

# Refuses a type with no probe, saying why.
function Assert-FreshAppType {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Type)

    if ($script:Probes.Contains($Type)) { return }
    $reason = if ($script:Waiting.ContainsKey($Type)) { ": $($script:Waiting[$Type])" } else { '' }
    throw "There's no fresh-app probe for the app type '$Type'$reason. Types with a probe: $($script:Probes.Keys -join ', ')."
}

# The intake's answers for a fresh app: the app type's own option, and every other card's default as the new-app skill
# would show it with no developer preferences, so a run on any machine gives the app CI checks.
function Get-FreshAppAnswer {
    param(
        [Parameter(Mandatory)] [Collections.IDictionary] $Intake,
        [Parameter(Mandatory)] [string] $Type
    )

    $defaults = @(Get-KitIntakeDefault -Intake $Intake -Preference @())
    $appType = @($Intake['cards'] | Where-Object { $_['id'] -ceq 'appType' })
    $option = @($appType | ForEach-Object { $_['options'] } | Where-Object { @($_['appTypes']).Count -eq 1 -and @($_['appTypes'])[0] -ceq $Type })
    if ($option.Count -ne 1) { throw "The intake's appType card has no option for the app type '$Type' alone." }

    $answers = [ordered]@{ appType = $option[0]['id'] }
    foreach ($card in $Intake['cards'] | Where-Object { $_['id'] -cne 'appType' }) {
        $id = $card['id']
        $row = if ($card.Contains('dependsOn')) {
            @($defaults | Where-Object { $_.Choice -ceq $id -and $_.When -ceq $answers[$card['dependsOn']] })
        }
        else { @($defaults | Where-Object { $_.Choice -ceq $id -and -not $_.When }) }
        # A card with a default of its own, such as the budget, takes it when the answers leave it out.
        if ($row -and $row[0].Pick) { $answers[$id] = $row[0].Pick }
    }
    $answers
}

# Copies the probe's src/ and tests/ into the app, from a clean checkout of the commit, as Export-KitApp copies the
# kit's files, so an unfinished local edit can't reach the app. Lock files stay behind: the app's first restore writes
# its own, against the app's own Directory.Packages.props.
function Copy-FreshAppProbe {
    param(
        [Parameter(Mandatory)] [string] $KitRoot,
        [Parameter(Mandatory)] [string] $Commit,
        [Parameter(Mandatory)] [string] $From,
        [Parameter(Mandatory)] [string] $Destination,
        # Files at the kit repo's root that the probe needs, copied to the same path in the app.
        [string[]] $RepoFiles = @()
    )

    $files = @(git -C $KitRoot ls-tree -r --name-only $Commit -- "$From/src" "$From/tests" |
            Where-Object { $_ -notmatch '(^|/)packages\.lock\.json$' })
    if ($LASTEXITCODE -ne 0) { throw "git ls-tree failed for $Commit in $KitRoot." }
    if (-not $files) { throw "The kit at $Commit has no $From/src or $From/tests." }

    $checkout = Join-Path ([IO.Path]::GetTempPath()) "kit-probe-$([guid]::NewGuid().ToString('N'))"
    git -C $KitRoot worktree add --quiet --detach $checkout $Commit
    if ($LASTEXITCODE -ne 0) { throw "Couldn't check out $Commit from $KitRoot." }
    try {
        foreach ($file in $files) {
            $target = Join-Path $Destination $file.Substring($From.Length + 1)
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath (Join-Path $checkout $file) -Destination $target
        }
        foreach ($file in $RepoFiles) {
            $source = Join-Path $checkout $file
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "The kit at $Commit has no $file." }
            $target = Join-Path $Destination $file
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
        }
    }
    finally {
        git -C $KitRoot worktree remove --force $checkout
    }
}

# Puts the kit's labelled package groups, each with its comment, back into an app's Directory.Packages.props, before
# its closing tag.
function Add-FreshAppPackageGroup {
    param(
        [Parameter(Mandatory)] [string] $PropsText,
        [Parameter(Mandatory)] [string] $KitPropsText,
        [string[]] $Label = @()
    )

    $groups = foreach ($name in $Label) {
        $match = [regex]::Match($KitPropsText, (Get-KitPackageGroupPattern -Label $name))
        if (-not $match.Success) { throw "The kit's Directory.Packages.props has no ItemGroup labelled '$name'." }
        $match.Value.TrimEnd()
    }
    if (-not $groups) { return $PropsText }
    $close = [regex]::Match($PropsText, '(?m)^</Project>\s*$')
    if (-not $close.Success) { throw "The app's Directory.Packages.props has no closing </Project> line." }
    $newline = if ($PropsText.Contains("`r`n")) { "`r`n" } else { "`n" }
    $text = $PropsText.Substring(0, $close.Index) + (($groups -join "$newline$newline") -replace '\r?\n', $newline) + "$newline$newline" + $PropsText.Substring($close.Index)
    [xml] $text | Out-Null # still well-formed
    $text
}

# The app's solution with every project under src/ and tests/, in a folder for each, as an app's first task would list
# them. The export's solution has no projects (ADR-0032), so the whole file is written.
function Get-FreshAppSolutionText {
    param([Parameter(Mandatory)] [string] $Destination)

    $lines = @('<Solution>')
    foreach ($folder in 'src', 'tests') {
        $projects = @(Get-ChildItem -LiteralPath (Join-Path $Destination $folder) -Recurse -Filter *.csproj -ErrorAction SilentlyContinue |
                ForEach-Object { [IO.Path]::GetRelativePath($Destination, $_.FullName).Replace('\', '/') } | Sort-Object)
        if (-not $projects) { continue }
        $lines += "  <Folder Name=""/$folder/"">"
        $lines += @($projects | ForEach-Object { "    <Project Path=""$([Security.SecurityElement]::Escape($_))"" />" })
        $lines += '  </Folder>'
    }
    (($lines + '</Solution>') -join "`n") + "`n"
}

function New-FreshApp {
    param(
        [Parameter(Mandatory)] [string] $Type,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $KitRoot
    )

    Assert-FreshAppType -Type $Type
    $probe = $script:Probes[$Type]
    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)
    $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    $commit = (git -C $KitRoot rev-parse --verify --quiet "$KitRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "'$KitRef' isn't a commit or tag in $KitRoot." }

    # The intake at the same commit as the files, as New-KitApp reads it.
    $intakeText = git -C $KitRoot show "${commit}:templates/app-intake.json" 2>$null | Out-String
    if ($LASTEXITCODE -ne 0 -or -not $intakeText.Trim()) { throw "The kit at $commit has no templates/app-intake.json." }
    $intake = Get-KitIntake -Text $intakeText
    $resolved = Resolve-KitIntakeAnswer -Intake $intake -Answers (Get-FreshAppAnswer -Intake $intake -Type $Type)
    # ADR-0090: the profile answers each condition the kit lists, as New-KitApp's does.
    $profileText = ConvertTo-KitAppProfile -Resolved $resolved -Name $probe.Name -KitCommit $commit -Conditions (Get-KitCondition -KitRoot $KitRoot -Commit $commit)

    # Export-KitApp refuses a folder that isn't empty, and removes what it wrote when it fails itself.
    $created = -not (Test-Path -LiteralPath $Destination)
    & (Join-Path $PSScriptRoot 'Export-KitApp.ps1') -Name $probe.Name -Destination $Destination -KitRef $commit -KitRoot $KitRoot -AppProfile $profileText
    if ($LASTEXITCODE -ne 0) { throw 'Export-KitApp failed.' }
    try {
        New-KitAppFirstCommit -Path $Destination

        # The probe, as an app's first task would add its projects, after the first commit.
        Copy-FreshAppProbe -KitRoot $KitRoot -Commit $commit -From $probe.From -Destination $Destination -RepoFiles $probe.RepoFiles
        $props = Join-Path $Destination 'Directory.Packages.props'
        $kitProps = git -C $KitRoot show "${commit}:Directory.Packages.props" | Out-String
        if ($LASTEXITCODE -ne 0) { throw "The kit at $commit has no Directory.Packages.props." }
        $text = Add-FreshAppPackageGroup -PropsText ([IO.File]::ReadAllText($props)) -KitPropsText $kitProps -Label $probe.PackageGroups
        [IO.File]::WriteAllText($props, $text, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $Destination "$($probe.Name).slnx"), (Get-FreshAppSolutionText -Destination $Destination), [Text.UTF8Encoding]::new($false))
    }
    catch {
        # A half-written app would block the rerun; remove only what this run made, as Export-KitApp does.
        if ($created) { Remove-Item -LiteralPath $Destination -Recurse -Force }
        else { Get-ChildItem -LiteralPath $Destination -Force | Remove-Item -Recurse -Force }
        throw
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $KitRoot) { $KitRoot = Split-Path -Path $PSScriptRoot -Parent }
    try {
        New-FreshApp -Type $Type -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
