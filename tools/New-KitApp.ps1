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

# The kit's newest release tag (vX.Y.Z), compared as versions, so v0.10.0 is newer than v0.9.0.
function Get-KitLatestRelease {
    param([Parameter(Mandatory)] [string] $KitRoot)

    $releases = @(git -C $KitRoot tag --list 'v*' | Where-Object { $_ -cmatch '^v\d+\.\d+\.\d+$' })
    if (-not $releases) {
        throw "The kit at $KitRoot has no release tag (vX.Y.Z) yet. Pass -KitRef with the kit commit or tag to start from."
    }
    $releases | Sort-Object { [version] $_.Substring(1) } | Select-Object -Last 1
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
        [string] $KitRef,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRoot,
        [switch] $Public
    )

    $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)

    # Checks first. They only read, so they run with -WhatIf too, and a refusal leaves nothing behind.
    # Export-KitApp's name check, loaded in a child scope so its parameters don't replace this function's.
    $assertName = & { . (Join-Path $PSScriptRoot 'Export-KitApp.ps1'); ${function:Assert-KitAppName} }
    & $assertName -Name $Name
    if ((Test-Path -LiteralPath $Destination) -and @(Get-ChildItem -LiteralPath $Destination -Force).Count -gt 0) {
        throw "$Destination isn't empty. Choose a new or empty folder, so no existing file is overwritten."
    }
    if (-not $KitRef) { $KitRef = Get-KitLatestRelease -KitRoot $KitRoot }
    $commit = (git -C $KitRoot rev-parse --verify --quiet "$KitRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "'$KitRef' isn't a commit or tag in $KitRoot." }
    $signIn = Invoke-KitGh -Arguments 'auth', 'status'
    if ($signIn.ExitCode -ne 0) {
        throw "gh isn't signed in to GitHub: $($signIn.Output)`nSigning in is your step: run 'gh auth login', then run this again."
    }
    $owner = Invoke-KitGhChecked -Arguments 'api', 'user', '--jq', '.login'
    $repo = "$owner/$Name"
    $existing = Invoke-KitGh -Arguments 'api', "repos/$repo"
    if ($existing.ExitCode -eq 0) { throw "$repo already exists. New-KitApp only creates new repos, so it never changes an existing one's settings." }
    if ($existing.Output -notmatch 'HTTP 404') { throw "Couldn't check whether $repo exists: $($existing.Output)" }
    # The settings and ruleset come from the same kit commit as the files.
    $settingsText = git -C $KitRoot show "${commit}:templates/github/repo.json" | Out-String
    $rulesetText = git -C $KitRoot show "${commit}:templates/github/main-protection.json" | Out-String

    # The steps, in order. Each runs in this function's scope (dot-sourced), so later steps see what earlier
    # ones set. -WhatIf lists them instead.
    $steps = @(
        [pscustomobject]@{ Description = "Export the kit's files at $commit"; Action = {
                & (Join-Path $KitRoot 'tools/Export-KitApp.ps1') -Name $Name -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot
                if ($LASTEXITCODE -ne 0) { throw 'Export-KitApp failed.' }
            }
        }
        [pscustomobject]@{ Description = 'Make the first commit'; Action = {
                $version = (Get-Content -Raw -LiteralPath (Join-Path $Destination '.kit/manifest.json') | ConvertFrom-Json).kitVersion
                Invoke-KitGit -Path $Destination -Arguments 'init', '-q', '-b', 'main'
                Invoke-KitGit -Path $Destination -Arguments 'add', '-A'
                # Windows doesn't record the executable bit, and git on Linux and macOS skips a hook without it.
                Invoke-KitGit -Path $Destination -Arguments 'add', '--chmod=+x', '.githooks/commit-msg'
                Invoke-KitGit -Path $Destination -Arguments 'commit', '-q', '-m', "chore: start from dotnet-agent-kit $version"
            }
        }
        [pscustomobject]@{ Description = "Create the $(if ($Public) { 'public' } else { 'private' }) repo with the kit's merge settings"; Action = {
                $request = Get-KitAppRepoRequest -Name $Name -SettingsText $settingsText -Public:$Public | ConvertTo-Json
                $created = Invoke-KitGhChecked -Arguments 'api', 'user/repos', '--method', 'POST', '--input', '-' -InputText $request | ConvertFrom-Json
            }
        }
        [pscustomobject]@{ Description = 'Push main'; Action = {
                Invoke-KitGit -Path $Destination -Arguments 'remote', 'add', 'origin', $created.clone_url
                Invoke-KitGit -Path $Destination -Arguments 'push', '-q', '-u', 'origin', 'main'
            }
        }
        # After the push: before it, the ruleset would reject the first push.
        [pscustomobject]@{ Description = "Add the 'main protection' ruleset"; Action = {
                Invoke-KitGhChecked -Arguments 'api', "repos/$repo/rulesets", '--method', 'POST', '--input', '-' -InputText $rulesetText | Out-Null
            }
        }
        # The commit-msg hook rejects a subject that isn't a Conventional Commit (ADR-0027).
        [pscustomobject]@{ Description = 'Turn the commit hook on in the local copy'; Action = {
                Invoke-KitGit -Path $Destination -Arguments 'config', '--local', 'core.hooksPath', '.githooks'
            }
        }
    )

    $created = $null
    for ($i = 0; $i -lt $steps.Count; $i++) {
        $step = $steps[$i]
        if (-not $PSCmdlet.ShouldProcess("$repo, $Destination", $step.Description)) { continue }
        Write-Host $step.Description
        try { . $step.Action }
        catch {
            # Stop here. Undoing is left to the owner: deleting a GitHub repo can't be undone.
            $done = if ($i -gt 0) { ($steps[0..($i - 1)].Description) -join '; ' } else { 'nothing' }
            $left = ($steps[$i..($steps.Count - 1)].Description) -join '; '
            $kept = if ($created) { "`n$($created.html_url) was created and is kept: finish the steps left by hand, or delete the repo on GitHub and the folder $Destination, then run this again." } else { '' }
            throw "$($step.Description) failed: $($_.Exception.Message)`nDone: $done.`nLeft: $left.$kept"
        }
    }
    if (-not $WhatIfPreference) { Write-Host "Created $($created.html_url)" }
}
