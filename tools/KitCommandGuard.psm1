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

# One argument of a PowerShell command as the command receives it: a string with its quotes and backtick escapes
# resolved, a parameter by its name (and ":value"), anything computed at run time (a variable, an expression) as
# written.
function ConvertTo-PowerShellWord {
    param([Parameter(Mandatory)] [Management.Automation.Language.Ast] $Element)

    if ($Element -is [Management.Automation.Language.StringConstantExpressionAst] -or
        $Element -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
        return $Element.Value
    }
    if ($Element -is [Management.Automation.Language.CommandParameterAst]) {
        # The parser keeps a backtick inside a parameter's name ("-Mo`de"); PowerShell binds it without one.
        $word = '-' + ($Element.ParameterName -replace '`(.)', '$1')
        if ($Element.Argument) { $word += ':' + (ConvertTo-PowerShellWord -Element $Element.Argument) }
        return $word
    }
    $Element.Extent.Text
}

# Each command in a PowerShell command line, from PowerShell's own parser: Words holds the command as it will run
# ("&" or "." first when it's invoked with one). Throws when the text doesn't parse, since PowerShell won't run it
# either and nothing it holds can be resolved.
function Get-PowerShellCommand {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command)

    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Command, [ref] $tokens, [ref] $errors)
    if ($errors.Count) { throw "PowerShell can't parse it: $($errors[0].Message)" }

    foreach ($commandAst in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
        $words = [Collections.Generic.List[string]]::new()
        switch ($commandAst.InvocationOperator) {
            'Ampersand' { $words.Add('&') }
            'Dot' { $words.Add('.') }
        }
        foreach ($element in $commandAst.CommandElements) { $words.Add((ConvertTo-PowerShellWord -Element $element)) }
        $name = $words[$words.Count - $commandAst.CommandElements.Count]
        $inner = $commandAst.Find({ param($node) $node.GetType() -in $script:ComputedArgumentAst }, $true)
        [pscustomobject]@{
            Words  = $words.ToArray()
            Native = -not (Test-PowerShellCommandName -Name $name)
            Nested = if ($inner) { $inner.Extent.Text } else { $null }
        }
    }
}

# The parts of a PowerShell command that compute a value when it runs: ( ), @( ), $( ) (in a string too) and { }.
# Any command can sit inside one, and Claude Code's docs don't say it checks commands there, so a wide allow such as
# "git commit *" would cover whatever they hold. A value built from expressions ('--for'+'ce') is no easier to read.
$script:ComputedArgumentAst = @(
    [Management.Automation.Language.ParenExpressionAst], [Management.Automation.Language.ArrayExpressionAst],
    [Management.Automation.Language.SubExpressionAst], [Management.Automation.Language.ScriptBlockExpressionAst]
)

# Whether a command name is PowerShell's own (a Verb-Noun cmdlet or function, or a .ps1 or .psm1 script), which binds
# "-fd" to one parameter, rather than a native program such as git or gh, which may read it as "-f -d".
function Test-PowerShellCommandName {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Name)

    $Name -match '\.psm?1$' -or $Name -match '^[A-Za-z]+-[A-Za-z0-9]+$'
}

# The spellings of one resolved command that the ask rules are matched against: its words joined by spaces, and for a
# native command also with each cluster of short options split up ("-qf" as "-q -f"), as git's and gh's option
# parsers read it. Both are kept, so a rule written for the cluster ("-uf") still matches.
function Get-CommandSpelling {
    param([Parameter(Mandatory)] [pscustomobject] $Resolved)

    $Resolved.Words -join ' '
    if ($Resolved.Native) {
        $split = foreach ($word in $Resolved.Words) {
            if ($word -cmatch '^-[A-Za-z][A-Za-z0-9]+$') { ($word.Substring(1).ToCharArray() | ForEach-Object { "-$_" }) -join ' ' } else { $word }
        }
        $split -join ' '
    }
}

# Why the command guard asks before a command runs, or $null when it leaves the command to Claude Code's own rules.
# It resolves the command as the shell will and asks when an ask rule covers the result, so a spelling the rule's
# text misses ("git push --for'ce'") still prompts.
function Get-CommandGuardDecision {
    param(
        [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $AskRules
    )

    try { $commands = @(Get-PowerShellCommand -Command $Command) }
    catch { return "The command guard (ADR-0076) can't resolve this command, so it asks: $($_.Exception.Message)" }
    foreach ($resolved in $commands) {
        if ($resolved.Nested) {
            return "The command guard (ADR-0076) asks because this command computes an argument inside ( ), @( ), `$( ) or { }, which Claude Code's rules may not check: $($resolved.Nested)"
        }
        foreach ($spelling in Get-CommandSpelling -Resolved $resolved) {
            foreach ($rule in $AskRules) {
                if (Test-PermissionRuleMatch -Rule $rule -Tool $Tool -Command $spelling -IgnoreCase:($Tool -eq 'PowerShell')) {
                    return "The command guard (ADR-0076) resolved this command to ""$spelling"", which the ask rule ""$rule"" covers."
                }
            }
        }
    }
    $null
}

Export-ModuleMember -Function Test-PermissionRuleMatch, Get-CommandGuardDecision
