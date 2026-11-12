#Requires -Version 7.6
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Duplication { param([string] $Report) }
function Format-Duplication { param([Parameter(ValueFromPipeline)] $Duplication, [string] $Solution) process { } }
function Get-CpdArgument { param([string] $FileList) @('none') }
