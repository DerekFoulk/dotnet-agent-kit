#Requires -Version 7.6
[CmdletBinding()]
param([string] $Solution, [string] $Policy, [string] $PackagesFolder)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-PackageLicenseCheck {
    [CmdletBinding()]
    param([string] $Solution, [string] $Policy, [string] $PackagesFolder)

    0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-PackageLicenseCheck -Solution $Solution -Policy $Policy -PackagesFolder $PackagesFolder)
}
