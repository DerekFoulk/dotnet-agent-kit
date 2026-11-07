#Requires -Version 7.0
<#
.SYNOPSIS
    Creates an app repo on GitHub with the kit's files, settings and "main protection" ruleset (PR D2b, ADR-0033).

.DESCRIPTION
    Exports the app's files with Export-KitApp, commits them, creates the repo on your own GitHub account
    with the kit's merge settings, pushes main, then adds the ruleset. The app is public, with secret scanning
    and push protection, unless -Private says otherwise. The settings and the ruleset come from
    templates/github at the same kit commit as the files.

.EXAMPLE
    ./tools/New-KitApp.ps1 -Name Contoso.Orders -KitRef v0.1.0 -WhatIf

.EXAMPLE
    ./tools/New-KitApp.ps1 -Name ContosoOrders -RepoName contoso-orders -Private
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Name,
    [string] $RepoName,
    [string] $KitRef,
    [string] $Destination,
    [switch] $Private,
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

    $all = if ($PSBoundParameters.ContainsKey('InputText')) { $InputText | & gh @Arguments 2>&1 } else { & gh @Arguments 2>&1 }
    $exitCode = $LASTEXITCODE
    # stderr lines arrive as ErrorRecords. Keeping them apart means a warning can't corrupt the JSON on stdout.
    $errors = @($all | Where-Object { $_ -is [Management.Automation.ErrorRecord] })
    $output = @($all | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] })
    [pscustomobject]@{
        ExitCode = $exitCode
        Output   = ($output | Out-String).Trim()
        Error    = ($errors | ForEach-Object { $_.Exception.Message } | Out-String).Trim()
    }
}

# The body of POST /user/repos: the kit's settings (templates/github/repo.json), the repo name, and private.
function Get-KitAppRepoRequest {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $SettingsText
    )

    $request = [ordered]@{}
    foreach ($setting in ($SettingsText | ConvertFrom-Json -AsHashtable).GetEnumerator()) {
        $request[$setting.Key] = $setting.Value
    }
    # Set last, so the settings file can't rename the repo or make it public. A public app is made public
    # by a later step.
    $request['name'] = $Name
    $request['private'] = $true
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
    if ($result.ExitCode -ne 0) { throw "gh $($Arguments -join ' ') failed: $(($result.Error, $result.Output | Where-Object { $_ }) -join ' ')" }
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
        [string] $RepoName,
        [string] $KitRef,
        [string] $Destination,
        [Parameter(Mandatory)] [string] $KitRoot,
        [switch] $Private
    )

    # The repo is named after the app unless -RepoName says otherwise: a repo name may have hyphens, which a
    # .NET namespace can't. GitHub allows letters, digits, '-', '_' and '.', up to 100 characters.
    if (-not $RepoName) { $RepoName = $Name }
    if ($RepoName -notmatch '^[A-Za-z0-9._-]{1,100}$' -or $RepoName -in '.', '..') {
        throw "The repo name '$RepoName' isn't one GitHub allows: up to 100 letters, digits, '-', '_' and '.'."
    }

    $KitRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KitRoot)
    # By default, a folder named after the repo next to the kit's, as git clone would name it.
    if (-not $Destination) { $Destination = Join-Path (Split-Path -Path $KitRoot -Parent) $RepoName }
    $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)

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
        throw "gh isn't signed in to GitHub: $($signIn.Error)`nSigning in is your step: run 'gh auth login', then run this again."
    }
    $owner = Invoke-KitGhChecked -Arguments 'api', 'user', '--jq', '.login'
    $repo = "$owner/$RepoName"
    $existing = Invoke-KitGh -Arguments 'api', "repos/$repo"
    if ($existing.ExitCode -eq 0) { throw "$repo already exists. New-KitApp only creates new repos, so it never changes an existing one's settings." }
    if ($existing.Error -notmatch 'HTTP 404') { throw "Couldn't check whether $repo exists: $($existing.Error)" }
    # The settings and ruleset come from the same kit commit as the files.
    $github = @{}
    foreach ($file in 'repo.json', 'main-protection.json', 'public.json') {
        $text = git -C $KitRoot show "${commit}:templates/github/$file" 2>$null | Out-String
        if ($LASTEXITCODE -ne 0 -or -not $text.Trim()) {
            throw "The kit at $KitRef has no templates/github/$file, so it predates New-KitApp. Pass a newer -KitRef."
        }
        $github[$file] = $text
    }
    $settingsText = $github['repo.json']
    $rulesetText = $github['main-protection.json']
    $publicText = $github['public.json']

    # The steps, in order. Each runs in this function's scope (dot-sourced), so later steps see what earlier
    # ones set. -WhatIf lists them instead.
    $steps = @(
        [pscustomobject]@{ Description = "Export the kit's files at $commit"; Action = {
                & (Join-Path $PSScriptRoot 'Export-KitApp.ps1') -Name $Name -Destination $Destination -KitRef $KitRef -KitRoot $KitRoot
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
        # Always private at first: a public app is made public only once main is pushed and protected, so a
        # failure before then leaves a private repo.
        [pscustomobject]@{ Description = "Create the private repo with the kit's merge settings"; Action = {
                $request = Get-KitAppRepoRequest -Name $RepoName -SettingsText $settingsText | ConvertTo-Json
                $createAttempted = $true
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
        # Public unless -Private: CI is free on public repos, and GitHub Free enforces rulesets only there
        # (ADR-0033). A public repo gets what the kit has (README, "GitHub settings on this repo"): secret
        # scanning and push protection, free on public repos, and no fork PR runs until the owner approves it.
        if (-not $Private) {
            [pscustomobject]@{ Description = 'Make the repo public'; Action = {
                    Invoke-KitGhChecked -Arguments 'api', "repos/$repo", '--method', 'PATCH', '--input', '-' -InputText '{ "private": false }' | Out-Null
                }
            }
            [pscustomobject]@{ Description = 'Turn on secret scanning and push protection, and require approval for fork PRs'; Action = {
                    $publicSettings = $publicText | ConvertFrom-Json
                    $security = @{ security_and_analysis = $publicSettings.security_and_analysis } | ConvertTo-Json -Depth 4
                    Invoke-KitGhChecked -Arguments 'api', "repos/$repo", '--method', 'PATCH', '--input', '-' -InputText $security | Out-Null
                    $approval = $publicSettings.fork_pr_contributor_approval | ConvertTo-Json
                    Invoke-KitGhChecked -Arguments 'api', "repos/$repo/actions/permissions/fork-pr-contributor-approval", '--method', 'PUT', '--input', '-' -InputText $approval | Out-Null
                }
            }
        }
        # The commit-msg hook rejects a subject that isn't a Conventional Commit (ADR-0027).
        [pscustomobject]@{ Description = 'Turn the commit hook on in the local copy'; Action = {
                Invoke-KitGit -Path $Destination -Arguments 'config', '--local', 'core.hooksPath', '.githooks'
            }
        }
    )

    $created = $null
    $createAttempted = $false
    for ($i = 0; $i -lt $steps.Count; $i++) {
        $step = $steps[$i]
        if (-not $PSCmdlet.ShouldProcess("$repo, $Destination", $step.Description)) { continue }
        Write-Host $step.Description
        try { . $step.Action }
        catch {
            # Stop here. Undoing is left to the owner: deleting a GitHub repo can't be undone.
            $done = if ($i -gt 0) { ($steps[0..($i - 1)].Description) -join '; ' } else { 'nothing' }
            $left = ($steps[$i..($steps.Count - 1)].Description) -join '; '
            $kept = if ($created) {
                "`n$($created.html_url) was created and is kept: finish the steps left by hand, or delete the repo on GitHub and the folder $Destination, then run this again."
            }
            elseif ($i -gt 0) {
                # The export ran; a rerun refuses a folder that isn't empty. If the create call was made, GitHub may
                # have made the repo before gh failed, so say where to look rather than that there's none.
                $check = if ($createAttempted) { " New-KitApp got no repo back from GitHub; check https://github.com/$repo, and delete it there if it exists." } else { '' }
                "`nThe folder $Destination is kept: delete it, then run this again.$check"
            }
            else { '' }
            throw "$($step.Description) failed: $($_.Exception.Message)`nDone: $done.`nLeft: $left.$kept"
        }
    }
    if (-not $WhatIfPreference) { Write-Host "Created $($created.html_url)" }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $KitRoot) { $KitRoot = Split-Path -Path $PSScriptRoot -Parent }
    $arguments = @{ Name = $Name; KitRoot = $KitRoot; Private = $Private; WhatIf = $WhatIfPreference }
    if ($RepoName) { $arguments.RepoName = $RepoName }
    if ($KitRef) { $arguments.KitRef = $KitRef }
    if ($Destination) { $arguments.Destination = $Destination }
    try {
        New-KitApp @arguments
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
