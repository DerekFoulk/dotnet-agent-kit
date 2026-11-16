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

# Each simple command in a Bash command line, with the words it receives: POSIX token recognition (XCU 2.3) and quote
# removal (2.6.7), plus Bash's $'...' and $"..." quoting. The commands inside $( ), backquotes, <( ), >( ) and an
# unquoted heredoc's body come out as commands of their own. Expansions ($x, ${x}, $((...)), a substitution's own
# text) stay as written, since their values are known only when the command runs; redirections and heredoc bodies
# aren't words. Throws when a quote, substitution or parenthesis isn't closed, since Bash won't run that either.
function Get-BashCommand {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command)

    $reader = New-BashReader -Text $Command -Commands ([Collections.Generic.List[object]]::new())
    Read-BashList -Reader $reader -Close ''
    $reader.Commands
}

function New-BashReader {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text, [Parameter(Mandatory)] [AllowEmptyCollection()] [Collections.Generic.List[object]] $Commands)

    [pscustomobject]@{ Text = $Text; Index = 0; Commands = $Commands; Heredocs = [Collections.Generic.List[object]]::new() }
}

# Reads commands up to the end of the text or, when Close is ')', up to the unquoted ')' that ends a $( ) or <( ).
function Read-BashList {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [AllowEmptyString()] [string] $Close)

    $builder = [pscustomobject]@{ Words = [Collections.Generic.List[string]]::new(); Word = [Text.StringBuilder]::new(); InWord = $false; Quoted = $false; Redirect = $null; Depth = 0 }
    $text = $Reader.Text
    while ($Reader.Index -lt $text.Length) {
        $c = $text[$Reader.Index]
        $next = if ($Reader.Index + 1 -lt $text.Length) { $text[$Reader.Index + 1] } else { [char] 0 }
        if ($c -in ' ', "`t", "`r") { Add-BashWord -Reader $Reader -Builder $builder; $Reader.Index++ }
        elseif ($c -eq "`n") {
            Complete-BashCommand -Reader $Reader -Builder $builder
            $Reader.Index++
            Read-BashHeredocBody -Reader $Reader
        }
        elseif ($c -eq '#' -and -not $builder.InWord) {
            $end = $text.IndexOf("`n", $Reader.Index)
            $Reader.Index = if ($end -lt 0) { $text.Length } else { $end }
        }
        elseif ($c -eq '\') {
            if ($next -eq "`n") { $Reader.Index += 2; continue }
            if ($next -eq [char] 0) { Add-BashText -Builder $builder -Text '\'; $Reader.Index++; continue }
            Add-BashText -Builder $builder -Text $next -Quoted
            $Reader.Index += 2
        }
        elseif ($c -eq "'") { $Reader.Index++; Add-BashText -Builder $builder -Text (Read-BashSingleQuoted -Reader $Reader) -Quoted }
        elseif ($c -eq '"') { $Reader.Index++; Add-BashText -Builder $builder -Text (Read-BashDoubleQuoted -Reader $Reader) -Quoted }
        elseif ($c -eq '$') { Add-BashText -Builder $builder -Text (Read-BashDollar -Reader $Reader) -Quoted:($next -in "'", '"') }
        elseif ($c -eq '`') { $Reader.Index++; Add-BashText -Builder $builder -Text (Read-BashBackquote -Reader $Reader) }
        elseif ($c -in '<', '>' -and $next -eq '(') { Add-BashText -Builder $builder -Text (Read-BashSubstitution -Reader $Reader) }
        elseif ($c -in '<', '>') { Read-BashRedirect -Reader $Reader -Builder $builder }
        elseif ($c -eq '&' -and $next -eq '>') { Add-BashWord -Reader $Reader -Builder $builder; $Reader.Index++; Read-BashRedirect -Reader $Reader -Builder $builder }
        elseif ($c -in '&', '|', ';') {
            Complete-BashCommand -Reader $Reader -Builder $builder
            $Reader.Index += if ("$c$next" -in '&&', '||', '|&', ';;', ';&') { 2 } else { 1 }
        }
        elseif ($c -eq '(') { Complete-BashCommand -Reader $Reader -Builder $builder; $builder.Depth++; $Reader.Index++ }
        elseif ($c -eq ')') {
            Complete-BashCommand -Reader $Reader -Builder $builder
            $Reader.Index++
            if ($builder.Depth -gt 0) { $builder.Depth-- }
            elseif ($Close -eq ')') { return }
            else { throw "Bash can't read it: a ')' at character $($Reader.Index) closes nothing." }
        }
        else { Add-BashText -Builder $builder -Text $c; $Reader.Index++ }
    }
    if ($Close) { throw "Bash can't read it: a `$( ), <( ) or >( ) isn't closed." }
    Complete-BashCommand -Reader $Reader -Builder $builder
}

function Add-BashText {
    param([Parameter(Mandatory)] [pscustomobject] $Builder, [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text, [switch] $Quoted)

    [void] $Builder.Word.Append($Text)
    $Builder.InWord = $true
    if ($Quoted) { $Builder.Quoted = $true }
}

# Ends the current word: a command's word, a redirection's target (dropped), or a heredoc's delimiter.
function Add-BashWord {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder)

    if (-not $Builder.InWord) { return }
    $word = $Builder.Word.ToString()
    if ($Builder.Redirect -like 'heredoc*') {
        $Reader.Heredocs.Add([pscustomobject]@{ Delimiter = $word; Quoted = $Builder.Quoted; StripTabs = $Builder.Redirect -eq 'heredoc-strip' })
    }
    elseif (-not $Builder.Redirect) { $Builder.Words.Add($word) }
    $Builder.Redirect = $null
    [void] $Builder.Word.Clear()
    $Builder.InWord = $false
    $Builder.Quoted = $false
}

function Complete-BashCommand {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder)

    Add-BashWord -Reader $Reader -Builder $Builder
    $Builder.Redirect = $null
    if ($Builder.Words.Count) {
        $Reader.Commands.Add([pscustomobject]@{ Words = $Builder.Words.ToArray(); Native = $true; Nested = $null })
        $Builder.Words.Clear()
    }
}

# A redirection operator ("2>&1", ">>", "<<-"): a file descriptor's digits before it aren't a word, and the word after
# it is the redirection's target, or a heredoc's delimiter.
function Read-BashRedirect {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder)

    if ($Builder.InWord -and -not $Builder.Quoted -and $Builder.Word.ToString() -match '^\d+$') {
        [void] $Builder.Word.Clear()
        $Builder.InWord = $false
    }
    Add-BashWord -Reader $Reader -Builder $Builder
    $rest = $Reader.Text.Substring($Reader.Index)
    $operator = foreach ($candidate in '<<<', '<<-', '<<', '<>', '<&', '>>', '>&', '>|', '<', '>') {
        if ($rest.StartsWith($candidate, [StringComparison]::Ordinal)) { $candidate; break }
    }
    $Reader.Index += $operator.Length
    $Builder.Redirect = switch ($operator) { '<<' { 'heredoc' } '<<-' { 'heredoc-strip' } default { 'target' } }
}

function Read-BashSingleQuoted {
    param([Parameter(Mandatory)] [pscustomobject] $Reader)

    $end = $Reader.Text.IndexOf("'", $Reader.Index)
    if ($end -lt 0) { throw "Bash can't read it: a single quote isn't closed." }
    $value = $Reader.Text.Substring($Reader.Index, $end - $Reader.Index)
    $Reader.Index = $end + 1
    $value
}

# The text of a double-quoted string, after its opening quote, with its escapes resolved. A heredoc's body reads the
# same way, except that '"' is literal there and the body ends with the text.
function Read-BashDoubleQuoted {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [switch] $Heredoc)

    $text = $Reader.Text
    $value = [Text.StringBuilder]::new()
    while ($Reader.Index -lt $text.Length) {
        $c = $text[$Reader.Index]
        $next = if ($Reader.Index + 1 -lt $text.Length) { $text[$Reader.Index + 1] } else { [char] 0 }
        if ($c -eq '"' -and -not $Heredoc) { $Reader.Index++; return $value.ToString() }
        if ($c -eq '\' -and ($next -in '$', '`', '\' -or ($next -eq '"' -and -not $Heredoc))) { [void] $value.Append($next); $Reader.Index += 2 }
        elseif ($c -eq '\' -and $next -eq "`n") { $Reader.Index += 2 }
        elseif ($c -eq '$') { [void] $value.Append((Read-BashDollar -Reader $Reader)) }
        elseif ($c -eq '`') { $Reader.Index++; [void] $value.Append((Read-BashBackquote -Reader $Reader)) }
        else { [void] $value.Append($c); $Reader.Index++ }
    }
    if (-not $Heredoc) { throw "Bash can't read it: a double quote isn't closed." }
    $value.ToString()
}

# What a '$' starts: $'...' and $"..." quoting (resolved), $( ) (its commands read, its text kept), and $((...)),
# ${...} and $name (kept as written).
function Read-BashDollar {
    param([Parameter(Mandatory)] [pscustomobject] $Reader)

    $text = $Reader.Text
    $start = $Reader.Index
    $next = if ($start + 1 -lt $text.Length) { $text[$start + 1] } else { [char] 0 }
    if ($next -eq "'") { $Reader.Index += 2; return Read-BashAnsiC -Reader $Reader }
    if ($next -eq '"') { $Reader.Index += 2; return Read-BashDoubleQuoted -Reader $Reader }
    if ($next -eq '(' -and $start + 2 -lt $text.Length -and $text[$start + 2] -eq '(') { return Read-BashBracketed -Reader $Reader -Open '(' -Close ')' }
    if ($next -eq '(') { return Read-BashSubstitution -Reader $Reader }
    if ($next -eq '{') { return Read-BashBracketed -Reader $Reader -Open '{' -Close '}' }
    $Reader.Index++
    '$'
}

# $((...)) or ${...}, kept as written: from the '$' to the bracket that closes the first one.
function Read-BashBracketed {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [char] $Open, [Parameter(Mandatory)] [char] $Close)

    $text = $Reader.Text
    $start = $Reader.Index
    $depth = 0
    for ($i = $start + 1; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq $Open) { $depth++ }
        elseif ($text[$i] -eq $Close -and --$depth -eq 0) {
            $Reader.Index = $i + 1
            return $text.Substring($start, $Reader.Index - $start)
        }
    }
    throw "Bash can't read it: a `$$Open isn't closed."
}

# $( ), <( ) or >( ): reads the commands inside as commands of their own and returns the substitution's text.
function Read-BashSubstitution {
    param([Parameter(Mandatory)] [pscustomobject] $Reader)

    $start = $Reader.Index
    $Reader.Index += 2
    Read-BashList -Reader $Reader -Close ')'
    $Reader.Text.Substring($start, $Reader.Index - $start)
}

# A backquoted substitution, after its opening backquote: inside it, '\' escapes only '`', '\' and '$'; its commands
# are read as commands of their own.
function Read-BashBackquote {
    param([Parameter(Mandatory)] [pscustomobject] $Reader)

    $text = $Reader.Text
    $inner = [Text.StringBuilder]::new()
    while ($true) {
        if ($Reader.Index -ge $text.Length) { throw "Bash can't read it: a backquote isn't closed." }
        $c = $text[$Reader.Index]
        $next = if ($Reader.Index + 1 -lt $text.Length) { $text[$Reader.Index + 1] } else { [char] 0 }
        if ($c -eq '`') { $Reader.Index++; break }
        if ($c -eq '\' -and $next -in '`', '\', '$') { [void] $inner.Append($next); $Reader.Index += 2 }
        else { [void] $inner.Append($c); $Reader.Index++ }
    }
    $sub = New-BashReader -Text $inner.ToString() -Commands $Reader.Commands
    Read-BashList -Reader $sub -Close ''
    '`' + $inner.ToString() + '`'
}

# A $'...' string, after its opening quote, with Bash's backslash escapes resolved.
function Read-BashAnsiC {
    param([Parameter(Mandatory)] [pscustomobject] $Reader)

    $text = $Reader.Text
    $value = [Text.StringBuilder]::new()
    while ($Reader.Index -lt $text.Length) {
        $c = $text[$Reader.Index]
        if ($c -eq "'") { $Reader.Index++; return $value.ToString() }
        if ($c -ne '\' -or $Reader.Index + 1 -ge $text.Length) { [void] $value.Append($c); $Reader.Index++; continue }
        $Reader.Index += 2
        [void] $value.Append((Read-BashAnsiCEscape -Reader $Reader -Letter $text[$Reader.Index - 1]))
    }
    throw "Bash can't read it: a `$'...' string isn't closed."
}

# The character a $'...' escape stands for, given the letter after its backslash; any digits it takes are read too.
function Read-BashAnsiCEscape {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [char] $Letter)

    $simple = [string] $Letter
    $named = 'abeEfnrtv'.IndexOf($Letter)
    if ($named -ge 0) { return "`a`b`e`e`f`n`r`t`v"[$named] }
    if ($simple -in '\', "'", '"', '?') { return $simple }
    # \nnn (octal, up to three digits, the letter being the first), \xHH, \uHHHH and \UHHHHHHHH.
    $number = switch -CaseSensitive -Regex ($simple) {
        '[0-7]' { $Reader.Index--; @{ Digits = '[0-7]{1,3}'; Base = 8 } }
        'x' { @{ Digits = '[0-9A-Fa-f]{1,2}'; Base = 16 } }
        'u' { @{ Digits = '[0-9A-Fa-f]{1,4}'; Base = 16 } }
        'U' { @{ Digits = '[0-9A-Fa-f]{1,8}'; Base = 16 } }
    }
    if ($number) {
        $run = [regex]::Match($Reader.Text.Substring($Reader.Index), "^$($number.Digits)")
        if ($run.Success) {
            $Reader.Index += $run.Length
            return [char]::ConvertFromUtf32([Convert]::ToInt32($run.Value, $number.Base))
        }
    }
    if ($Letter -ceq 'c' -and $Reader.Index -lt $Reader.Text.Length) {
        $Reader.Index++
        return [string] [char] ([int] [char]::ToUpperInvariant($Reader.Text[$Reader.Index - 1]) -bxor 64)
    }
    "\$Letter"
}

# The bodies of the heredocs started on the line just read, which follow it line by line up to each delimiter. An
# unquoted delimiter's body expands like a double-quoted string, so the commands in its $( ) are read too.
function Read-BashHeredocBody {
    param([Parameter(Mandatory)] [pscustomobject] $Reader)

    $text = $Reader.Text
    foreach ($heredoc in @($Reader.Heredocs)) {
        $body = [Text.StringBuilder]::new()
        while ($Reader.Index -lt $text.Length) {
            $end = $text.IndexOf("`n", $Reader.Index)
            $line = if ($end -lt 0) { $text.Substring($Reader.Index) } else { $text.Substring($Reader.Index, $end - $Reader.Index) }
            $Reader.Index = if ($end -lt 0) { $text.Length } else { $end + 1 }
            $compared = if ($heredoc.StripTabs) { $line.TrimStart("`t") } else { $line }
            if ($compared.TrimEnd("`r") -ceq $heredoc.Delimiter) { break }
            [void] $body.Append($line).Append("`n")
        }
        if (-not $heredoc.Quoted) {
            $bodyReader = New-BashReader -Text $body.ToString() -Commands $Reader.Commands
            [void] (Read-BashDoubleQuoted -Reader $bodyReader -Heredoc)
        }
    }
    $Reader.Heredocs.Clear()
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

    try { $commands = if ($Tool -eq 'Bash') { @(Get-BashCommand -Command $Command) } else { @(Get-PowerShellCommand -Command $Command) } }
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

function Invoke-CommandGuard {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $InputJson, [Parameter(Mandatory)] [AllowEmptyString()] [string] $ProjectDir)

    $null
}

Export-ModuleMember -Function Test-PermissionRuleMatch, Get-CommandGuardDecision, Invoke-CommandGuard
