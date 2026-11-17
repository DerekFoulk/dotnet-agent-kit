#Requires -Version 7.6
[CmdletBinding()]
param([string] $ConfigPath = 'nuget.config')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-TrustedSignerCheck {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $ConfigPath)

    0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-TrustedSignerCheck -ConfigPath $ConfigPath)
}
