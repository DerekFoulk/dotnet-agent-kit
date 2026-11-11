#Requires -Version 7.6
<#
.SYNOPSIS
    Copies the kit's curated skills from Microsoft's dotnet/skills repo at one commit, and records that commit
    (ADR-0042).
#>
[CmdletBinding()]
param()

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
# the lock doesn't name, such as the kit's own, aren't looked at.
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
            foreach ($file in $present) {
                if (-not $listed.Contains($file)) { "$($skill['name'])/$file isn't in the upstream commit" }
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
        $sha = (git -C $work rev-parse --verify 'FETCH_HEAD^{commit}' | Out-String).Trim()

        # Every file of every listed skill at the commit, before anything changes.
        $plan = foreach ($skill in $lock['skills']) {
            $source = $skill['source'].TrimEnd('/')
            $entries = @(git -C $work ls-tree -r --full-tree $sha -- "$source/" | ForEach-Object {
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
