#Requires -Version 7.6
# The command guard (ADR-0076): a Claude Code PreToolUse hook that resolves each Bash or PowerShell command the way the
# shell will, then applies the ask rules of .claude/settings.json to what it resolved.

Set-StrictMode -Version Latest

function Test-PermissionRuleMatch {
    param(
        [Parameter(Mandatory)] [string] $Rule,
        [Parameter(Mandatory)] [string] $Tool,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [switch] $IgnoreCase
    )

    $false
}

Export-ModuleMember -Function Test-PermissionRuleMatch
