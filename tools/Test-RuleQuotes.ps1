#Requires -Version 7.6
<#
.SYNOPSIS
    Re-reads every page a rule quotes and reports each stored quote the page no longer says (ADR-0083).

.DESCRIPTION
    Not implemented yet.
#>
[CmdletBinding()]
param([string] $StandardsPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RuleQuote { param([string] $StandardsPath) }
function Test-RuleQuote { param([object[]] $Quote, [scriptblock] $GetPage) foreach ($q in $Quote) { [pscustomobject]@{ State = 'NotChecked'; Detail = '' } } }
function Invoke-RuleQuoteCheck { param([string] $StandardsPath, [scriptblock] $GetPage) -1 }

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-RuleQuoteCheck -StandardsPath $StandardsPath)
}
