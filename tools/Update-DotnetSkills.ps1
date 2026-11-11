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

    ''
}
