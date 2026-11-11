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
