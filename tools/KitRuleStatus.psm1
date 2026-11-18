#Requires -Version 7.6
# Tells a check whether the rule it enforces is in force (ADR-0089).

Set-StrictMode -Version Latest

function Get-RuleStatus {
    param([Parameter(Mandatory)] [string] $Id, [string] $Path)
}
