#Requires -Version 7.6
<#
.SYNOPSIS
    Copies the kit's curated skills from Microsoft's dotnet/skills repo at one commit, and records that commit
    (ADR-0042).

.DESCRIPTION
    tools/dotnet-skills.json lists the curated skills, each with its folder upstream. The script fetches only the
    chosen commit (no GitHub sign-in), replaces each listed skill's folder in .claude/skills with upstream's files,
    byte for byte, and rewrites the lock with the commit, today's date and git's blob id for every file. The kit's
    own skills are never touched. It changes nothing when a listed skill isn't at the commit, holds a symbolic link
    or submodule, or when a curated copy has an edit the update would overwrite.

    Then read the diff: upstream text becomes instructions every agent follows. docs/dotnet-skills.md has the rest
    of the steps.

.PARAMETER Commit
    The upstream commit SHA, branch or tag. Defaults to main.

.EXAMPLE
    ./tools/Update-DotnetSkills.ps1
.EXAMPLE
    ./tools/Update-DotnetSkills.ps1 -Commit 96c3d68dad2855e3ab5178aa1a262789d86a1466
#>
[CmdletBinding()]
param(
    [string] $Commit = 'main',
    # Defaults to the url in the lock.
    [string] $RepositoryUrl,
    # Defaults to the repo this script is in.
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The upstream repo, the pinned commit and each copied file's blob id, relative to the repo root.
$script:LockPath = 'tools/dotnet-skills.json'

# git's blob id for a file: the SHA-1 of "blob <length>\0" and the bytes, with CRLF read as LF.
function Get-DotnetSkillBlobId {
    param([Parameter(Mandatory)] [string] $Path)

    # Bytes, not text: decoding and re-encoding could change a byte-order mark or an invalid byte, and the id is of
    # the exact bytes git stores. git stores this text with LF line endings (upstream's .gitattributes says
    # eol=lf), while a Windows checkout may give CRLF.
    $bytes = [IO.File]::ReadAllBytes($Path)
    $lf = [Collections.Generic.List[byte]]::new($bytes.Length)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 13 -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { continue }
        $lf.Add($bytes[$i])
    }
    $header = [Text.Encoding]::ASCII.GetBytes("blob $($lf.Count)`0")
    [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([byte[]] ($header + $lf.ToArray()))).ToLowerInvariant()
}

# How each curated skill's folder differs from the lock: a file changed, missing, or not upstream. Folders of skills
# the lock doesn't name, such as the kit's own, aren't looked at, and neither are files git ignores.
function Get-DotnetSkillDrift {
    param(
        [Parameter(Mandatory)] [string] $SkillsRoot,
        [Parameter(Mandatory)] [Collections.IDictionary] $Lock
    )

    foreach ($skill in $Lock['skills']) {
        $folder = Join-Path $SkillsRoot $skill['name']
        $listed = $skill['files']
        foreach ($file in @($listed.Keys | Sort-Object -Culture ([cultureinfo]::InvariantCulture))) {
            $path = Join-Path $folder $file
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { "$($skill['name'])/$file is missing" }
            elseif ((Get-DotnetSkillBlobId -Path $path) -ne $listed[$file]) { "$($skill['name'])/$file differs from the upstream commit" }
        }
        if (Test-Path -LiteralPath $folder -PathType Container) {
            $present = Get-ChildItem -LiteralPath $folder -Recurse -File -Force |
                ForEach-Object { [IO.Path]::GetRelativePath($folder, $_.FullName) -replace '\\', '/' } |
                Sort-Object -Culture ([cultureinfo]::InvariantCulture)
            $extra = @($present | Where-Object { -not $listed.Contains($_) })
            # Files git ignores, such as .DS_Store or an editor's swap file, never reach a commit. Outside a git repo
            # check-ignore fails and reports nothing, so every extra file counts. The paths go as arguments: piped,
            # PowerShell on Windows would end each with CRLF, and git would read the CR as part of the name.
            $ignored = if ($extra) { @(git -C $folder check-ignore -- @extra 2>$null) } else { @() }
            foreach ($file in $extra) {
                if ($file -notin $ignored) { "$($skill['name'])/$file isn't in the upstream commit" }
            }
        }
    }
}

# Copies every skill tools/dotnet-skills.json lists from the upstream repo at one commit into .claude/skills, and
# rewrites the lock with that commit, the date and each file's blob id.
function Update-DotnetSkill {
    param(
        [Parameter(Mandatory)] [string] $RepoRoot,
        [Parameter(Mandatory)] [string] $Commit,
        [Parameter(Mandatory)] [string] $RepositoryUrl,
        [Parameter(Mandatory)] [string] $Retrieved
    )

    $lock = Read-DotnetSkillLock -RepoRoot $RepoRoot
    $skillsRoot = Join-Path $RepoRoot '.claude' 'skills'

    # The update replaces each curated skill's folder, so an edit there would be lost. A missing file is fine: it's
    # what a newly listed skill looks like.
    $edits = @(Get-DotnetSkillDrift -SkillsRoot $skillsRoot -Lock $lock | Where-Object { $_ -notmatch ' is missing$' })
    if ($edits) {
        throw "These curated files differ from the pinned commit, and the update would overwrite them. Commit or discard the edits first:`n$($edits -join "`n")"
    }

    $work = Join-Path ([IO.Path]::GetTempPath()) "dotnet-skills-$([guid]::NewGuid().ToString('N'))"
    try {
        # A throwaway repo that fetches only the one commit: no clone of upstream's history, and no GitHub sign-in.
        git init -q $work
        if ($LASTEXITCODE -ne 0) { throw "Couldn't make a temporary repo in $work." }
        git -C $work fetch -q --depth 1 --no-tags $RepositoryUrl $Commit
        if ($LASTEXITCODE -ne 0) { throw "Couldn't fetch '$Commit' from $RepositoryUrl." }
        $sha = (git -C $work rev-parse --verify --quiet 'FETCH_HEAD^{commit}' 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw "'$Commit' isn't a commit in $RepositoryUrl. Nothing was changed." }

        # Every file of every listed skill at the commit, before anything changes.
        $plan = foreach ($skill in $lock['skills']) {
            $source = $skill['source'].TrimEnd('/')
            # -z: paths unquoted, as UTF-8, each entry ending in NUL. By default git would quote a non-ASCII path.
            # PowerShell decodes git's output with the console's encoding, which may be a legacy code page.
            $saved = [Console]::OutputEncoding
            try {
                [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
                $listing = (git -C $work ls-tree -r -z --full-tree $sha -- "$source/") -join "`n"
            }
            finally { [Console]::OutputEncoding = $saved }
            $entries = @($listing -split "`0" | Where-Object { $_ } | ForEach-Object {
                    $info, $path = $_ -split "`t", 2
                    $mode, $type, $id = $info -split ' '
                    [pscustomobject]@{ Mode = $mode; Type = $type; Id = $id; File = $path.Substring($source.Length + 1) }
                })
            [pscustomobject]@{ Skill = $skill; Source = $source; Entries = $entries }
        }
        $gone = @($plan | Where-Object { -not $_.Entries } | ForEach-Object { $_.Source })
        if ($gone) {
            throw "These skills aren't at $sha in ${RepositoryUrl}: $($gone -join ', '). Nothing was changed; remove them from $script:LockPath or pick another commit."
        }
        # Plain files only: a symbolic link or a submodule could point outside the skill's folder.
        $odd = @($plan | ForEach-Object { $skill = $_.Skill['name']; $_.Entries | Where-Object { $_.Type -ne 'blob' -or $_.Mode -notin '100644', '100755' } | ForEach-Object { "$skill/$($_.File)" } })
        if ($odd) {
            throw "These aren't plain files, which the kit doesn't copy: $($odd -join ', '). Nothing was changed."
        }

        # git checks files out into a separate folder, which must exist first.
        $stage = Join-Path $work 'stage'
        New-Item -ItemType Directory -Path $stage | Out-Null
        $sources = @($plan | ForEach-Object { $_.Source })
        # No line-ending conversion: the copies are upstream's bytes.
        git -c core.autocrlf=false -C $work --work-tree $stage checkout -q $sha -- @($sources)
        if ($LASTEXITCODE -ne 0) { throw "Couldn't check out the skills at $sha." }

        foreach ($step in $plan) {
            $folder = Join-Path $skillsRoot $step.Skill['name']
            if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            Copy-Item -Path (Join-Path $stage $step.Source '*') -Destination $folder -Recurse -Force
            $files = [ordered]@{}
            foreach ($entry in $step.Entries) { $files[$entry.File] = $entry.Id }
            $step.Skill['files'] = $files
        }
        $lock['commit'] = $sha
        $lock['retrieved'] = $Retrieved
        Write-DotnetSkillLock -RepoRoot $RepoRoot -Lock $lock
    }
    finally {
        if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    }
}

function Read-DotnetSkillLock {
    param([Parameter(Mandatory)] [string] $RepoRoot)

    # -DateKind String keeps the retrieval date as written.
    Get-Content -Raw -LiteralPath (Join-Path $RepoRoot $script:LockPath) | ConvertFrom-Json -AsHashtable -DateKind String
}

function Write-DotnetSkillLock {
    param([Parameter(Mandatory)] [string] $RepoRoot, [Parameter(Mandatory)] [Collections.IDictionary] $Lock)

    $json = ($Lock | ConvertTo-Json -Depth 5) -replace "`r`n", "`n"
    [IO.File]::WriteAllText((Join-Path $RepoRoot $script:LockPath), "$json`n", [Text.UTF8Encoding]::new($false))
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $RepoRoot) { $RepoRoot = Split-Path -Path $PSScriptRoot -Parent }
    try {
        if (-not $RepositoryUrl) { $RepositoryUrl = (Read-DotnetSkillLock -RepoRoot $RepoRoot)['url'] }
        Update-DotnetSkill -RepoRoot $RepoRoot -Commit $Commit -RepositoryUrl $RepositoryUrl -Retrieved (Get-Date -Format 'yyyy-MM-dd')
        $lock = Read-DotnetSkillLock -RepoRoot $RepoRoot
        Write-Host "Copied $(@($lock['skills']).Count) skills from $RepositoryUrl at $($lock['commit']). Read the diff, then follow docs/dotnet-skills.md."
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    exit 0
}
