#Requires -Version 7.6
# The command guard (ADR-0076): a Claude Code PreToolUse hook that resolves each Bash or PowerShell command the way the
# shell will, then applies the ask rules of .claude/settings.json to what it resolved.

Set-StrictMode -Version Latest

# Whether a permission rule such as "Bash(git push *)" covers a command, as Claude Code's permissions page describes
# the syntax: '*' matches any text (newlines too), a trailing ' *' that is the rule's only wildcard also matches the
# bare command, and a trailing ':*' is the older prefix form, whose text before it is literal. '[', ']', '?' and '`'
# are literal. Only rules for the given tool count. Matching is case-sensitive unless -IgnoreCase; Claude Code
# matches PowerShell rules case-insensitively.
function Test-PermissionRuleMatch {
    param(
        [Parameter(Mandatory)] [string] $Rule,
        [Parameter(Mandatory)] [string] $Tool,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [switch] $IgnoreCase
    )

    $open = "$Tool("
    if (-not $Rule.StartsWith($open, [StringComparison]::Ordinal) -or -not $Rule.EndsWith(')', [StringComparison]::Ordinal)) { return $false }
    $pattern = $Rule.Substring($open.Length, $Rule.Length - $open.Length - 1)
    $comparison = if ($IgnoreCase) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

    if ($pattern.EndsWith(':*', [StringComparison]::Ordinal) -and $pattern.Length -gt 2) {
        $prefix = $pattern.Substring(0, $pattern.Length - 2)
        return [string]::Equals($Command, $prefix, $comparison) -or $Command.StartsWith("$prefix ", $comparison)
    }
    if ($pattern -match '^([^*]+) \*$' -and [string]::Equals($Command, $Matches[1], $comparison)) { return $true }

    $regex = '\A' + (($pattern.Split('*') | ForEach-Object { [regex]::Escape($_) }) -join '.*') + '\z'
    $options = [Text.RegularExpressions.RegexOptions]::Singleline -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant
    if ($IgnoreCase) { $options = $options -bor [Text.RegularExpressions.RegexOptions]::IgnoreCase }
    [regex]::IsMatch($Command, $regex, $options)
}

Export-ModuleMember -Function Test-PermissionRuleMatch
