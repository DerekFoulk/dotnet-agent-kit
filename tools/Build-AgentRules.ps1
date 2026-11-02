#Requires -Version 7.0
<#
.SYNOPSIS
    Generates the agents' path-scoped rule files from docs/standards (checkpoint §2).
#>
[CmdletBinding()]
param(
    [string] $RepoRoot,
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name 'powershell-yaml' -MinimumVersion '0.4.12'

function Get-AgentRuleFile {
    param([Parameter(Mandatory)] [string] $StandardsPath)
    [pscustomobject]@{ Path = 'stub'; Content = '' }
}
