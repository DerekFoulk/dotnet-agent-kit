#Requires -Version 7.0
<#
.SYNOPSIS
    Creates an app repo on GitHub with the kit's files, settings and "main protection" ruleset (PR D2b, ADR-0033).

.DESCRIPTION
    Exports the app's files with Export-KitApp, commits them, creates the repo on your own GitHub account
    with the kit's merge settings, pushes main, then adds the ruleset. The settings and the ruleset come from
    templates/github at the same kit commit as the files.

.EXAMPLE
    ./tools/New-KitApp.ps1 -Name Contoso.Orders -KitRef v0.1.0 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Name,
    [string] $KitRef,
    [string] $Destination,
    [switch] $Public,
    [string] $KitRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Every GitHub call goes through here, using the owner's existing gh sign-in; the tests replace it.
function Invoke-KitGh {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [string] $InputText
    )

    $output = if ($PSBoundParameters.ContainsKey('InputText')) { $InputText | & gh @Arguments 2>&1 } else { & gh @Arguments 2>&1 }
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output | Out-String).Trim() }
}

# The body of POST /user/repos: the app's name and visibility, plus the kit's settings (templates/github/repo.json).
function Get-KitAppRepoRequest {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $SettingsText,
        [switch] $Public
    )

    $request = [ordered]@{ name = $Name; private = -not $Public }
    foreach ($setting in ($SettingsText | ConvertFrom-Json -AsHashtable).GetEnumerator()) {
        $request[$setting.Key] = $setting.Value
    }
    $request
}

# Calls gh, failing with its output when it fails.
function Invoke-KitGhChecked {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [string] $InputText
    )

    $result = Invoke-KitGh @PSBoundParameters
    if ($result.ExitCode -ne 0) { throw "gh $($Arguments -join ' ') failed: $($result.Output)" }
    $result.Output
}

# Runs git in the app's folder, failing with its output when it fails.
function Invoke-KitGit {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string[]] $Arguments
    )

    $output = & git -C $Path @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output.Trim())" }
}

function New-KitApp {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $KitRef,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRoot,
        [switch] $Public
    )

    $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)

    $commit = (git -C $KitRoot rev-parse --verify --quiet "$KitRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "'$KitRef' isn't a commit or tag in $KitRoot." }
    $owner = Invoke-KitGhChecked -Arguments 'api', 'user', '--jq', '.login'
    $repo = "$owner/$Name"
    # The settings and ruleset come from the same kit commit as the files.
    $settingsText = git -C $KitRoot show "${commit}:templates/github/repo.json" | Out-String
    $rulesetText = git -C $KitRoot show "${commit}:templates/github/main-protection.json" | Out-String

    $export = Join-Path $KitRoot 'tools/Export-KitApp.ps1'
    & $export -Name $Name -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot
    if ($LASTEXITCODE -ne 0) { throw 'Export-KitApp failed.' }

    $version = (Get-Content -Raw -LiteralPath (Join-Path $Destination '.kit/manifest.json') | ConvertFrom-Json).kitVersion
    Invoke-KitGit -Path $Destination -Arguments 'init', '-q', '-b', 'main'
    Invoke-KitGit -Path $Destination -Arguments 'add', '-A'
    # Windows doesn't record the executable bit, and git on Linux and macOS skips a hook without it.
    Invoke-KitGit -Path $Destination -Arguments 'add', '--chmod=+x', '.githooks/commit-msg'
    Invoke-KitGit -Path $Destination -Arguments 'commit', '-q', '-m', "chore: start from dotnet-agent-kit $version"

    $request = Get-KitAppRepoRequest -Name $Name -SettingsText $settingsText -Public:$Public | ConvertTo-Json
    $created = Invoke-KitGhChecked -Arguments 'api', 'user/repos', '--method', 'POST', '--input', '-' -InputText $request | ConvertFrom-Json

    Invoke-KitGit -Path $Destination -Arguments 'remote', 'add', 'origin', $created.clone_url
    Invoke-KitGit -Path $Destination -Arguments 'push', '-q', '-u', 'origin', 'main'

    Invoke-KitGhChecked -Arguments 'api', "repos/$repo/rulesets", '--method', 'POST', '--input', '-' -InputText $rulesetText | Out-Null
    Write-Host "Created $($created.html_url)"
}
