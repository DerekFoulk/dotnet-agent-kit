#Requires -Version 7.6
# The command guard (ADR-0077): a Claude Code PreToolUse hook that resolves each Bash or PowerShell command the way the
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

    # The PowerShell tool keeps no variables between calls, so one the input assigns or loops over holds a value the
    # input chose; a command that uses it builds an argument no rule can read.
    $setHere = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($node in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -or $node -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
        $target = if ($node -is [Management.Automation.Language.ForEachStatementAst]) { $node.Variable } else { $node.Left }
        foreach ($variable in $target.FindAll({ param($v) $v -is [Management.Automation.Language.VariableExpressionAst] }, $true)) {
            [void] $setHere.Add((Get-PowerShellVariableName -Variable $variable))
        }
    }

    foreach ($commandAst in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
        $words = [Collections.Generic.List[string]]::new()
        switch ($commandAst.InvocationOperator) {
            'Ampersand' { $words.Add('&') }
            'Dot' { $words.Add('.') }
        }
        $plainWords = [Collections.Generic.List[string]]::new($words)
        foreach ($element in $commandAst.CommandElements) {
            $words.Add((ConvertTo-PowerShellWord -Element $element))
            $plain = ConvertTo-PowerShellPlainWord -Element $element
            if ($null -ne $plain) { $plainWords.Add($plain) }
        }
        $name = $words[$words.Count - $commandAst.CommandElements.Count]
        $inner = $commandAst.Find({ param($node) $node.GetType() -in $script:ComputedArgumentAst }, $true)
        if (-not $inner) {
            $inner = $commandAst.Find({ param($node) $node -is [Management.Automation.Language.VariableExpressionAst] -and $setHere.Contains((Get-PowerShellVariableName -Variable $node)) }, $true)
        }
        [pscustomobject]@{
            Words      = $words.ToArray()
            PlainWords = $plainWords.ToArray()
            Native     = -not (Test-PowerShellCommandName -Name $name)
            Computed   = if ($inner) { $inner.Extent.Text } else { $null }
        }
    }
}

# A variable's name without its scope ($script:f is f); a drive-qualified one keeps its drive ($env:F).
function Get-PowerShellVariableName {
    param([Parameter(Mandatory)] [Management.Automation.Language.VariableExpressionAst] $Variable)

    $Variable.VariablePath.UserPath -replace '^(?i:global|local|script|private|using|variable):', ''
}

# One argument of a PowerShell command with its variables taken out, as if each were empty: a string's nested
# expressions removed ("--for${null}ce" is "--force"), and $null for an argument that is only a variable.
function ConvertTo-PowerShellPlainWord {
    param([Parameter(Mandatory)] [Management.Automation.Language.Ast] $Element)

    if ($Element -is [Management.Automation.Language.VariableExpressionAst]) { return $null }
    if ($Element -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
        $value = $Element.Value
        foreach ($nested in $Element.NestedExpressions) { $value = $value.Replace($nested.Extent.Text, '') }
        return $value
    }
    ConvertTo-PowerShellWord -Element $Element
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
# text) stay as written in Words, since their values are known only when the command runs, and are taken out in
# PlainWords (an unset variable is empty). Computed names the first word whose value Bash builds when it runs: a brace
# expansion, ${...} with an operator, $((...)), or a $( ) or backquote substitution other than cat reading a quoted
# heredoc, whose output is fixed text. Redirections and heredoc bodies aren't words. Throws when a quote, substitution
# or parenthesis isn't closed, since Bash won't run that either.
function Get-BashCommand {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command)

    $reader = New-BashReader -Text $Command -Commands ([Collections.Generic.List[object]]::new())
    Read-BashList -Reader $reader -Close ''
    # The Bash tool keeps no variables between calls, so one the input sets holds a value the input chose; a command
    # that uses it builds an argument no rule can read.
    $setHere = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($resolved in $reader.Commands) { foreach ($name in Get-BashAssignedName -Words $resolved.Words) { [void] $setHere.Add($name) } }
    foreach ($resolved in $reader.Commands) {
        $used = @($resolved.Variables | Where-Object { $setHere.Contains($_) })
        if ($used.Count -and -not $resolved.Computed) { $resolved.Computed = "`$$($used[0])" }
    }
    $reader.Commands
}

# The variables a Bash command sets: its leading NAME=value assignments, a for loop's variable, read's names, and the
# names export, declare, local, readonly and typeset give.
function Get-BashAssignedName {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Words)

    $name = '^([A-Za-z_][A-Za-z0-9_]*)(\+?=|$)'
    $i = 0
    while ($i -lt $Words.Count -and $Words[$i] -match '^([A-Za-z_][A-Za-z0-9_]*)\+?=') { $Matches[1]; $i++ }
    if ($i -ge $Words.Count) { return }
    $operands = @($Words | Select-Object -Skip ($i + 1) | Where-Object { -not $_.StartsWith('-') })
    if ($Words[$i] -ceq 'for' -and $operands.Count) { $operands[0] }
    elseif ($Words[$i] -cin 'read', 'export', 'declare', 'local', 'readonly', 'typeset') {
        foreach ($operand in $operands) { if ($operand -match $name) { $Matches[1] } }
    }
}

function New-BashReader {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text, [Parameter(Mandatory)] [AllowEmptyCollection()] [Collections.Generic.List[object]] $Commands)

    [pscustomobject]@{ Text = $Text; Index = 0; Commands = $Commands; Heredocs = [Collections.Generic.List[object]]::new() }
}

# Reads commands up to the end of the text or, when Close is ')', up to the unquoted ')' that ends a $( ) or <( ).
function Read-BashList {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [AllowEmptyString()] [string] $Close)

    $builder = New-BashBuilder
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
        elseif ($c -eq '"') { $Reader.Index++; Read-BashDoubleQuoted -Reader $Reader -Builder $builder }
        elseif ($c -eq '$') { Read-BashDollar -Reader $Reader -Builder $builder }
        elseif ($c -eq '`') { $Reader.Index++; Add-BashExpansion -Builder $builder -Text (Read-BashBackquote -Reader $Reader) -Computed }
        # A process substitution's value is the name of a pipe, which no option can be.
        elseif ($c -in '<', '>' -and $next -eq '(') { Add-BashExpansion -Builder $builder -Text (Read-BashSubstitution -Reader $Reader) }
        elseif ($c -in '<', '>') { Read-BashRedirect -Reader $Reader -Builder $builder }
        elseif ($c -eq '&' -and $next -eq '>') { Add-BashWord -Reader $Reader -Builder $builder; $Reader.Index++; Read-BashRedirect -Reader $Reader -Builder $builder }
        elseif ($builder.InPattern -and $c -in '|', '(', ')') {
            # In a case statement's pattern list, '|' separates patterns and ')' ends the list.
            Add-BashWord -Reader $Reader -Builder $builder
            if ($c -eq ')') { $builder.InPattern = $false }
            $Reader.Index++
        }
        elseif ($c -in '&', '|', ';') {
            Complete-BashCommand -Reader $Reader -Builder $builder
            $operator = foreach ($candidate in ';;&', '&&', '||', '|&', ';;', ';&', [string] $c) {
                if ($text.Substring($Reader.Index).StartsWith($candidate, [StringComparison]::Ordinal)) { $candidate; break }
            }
            $Reader.Index += $operator.Length
            # ";;", ";&" and ";;&" end a case item; the next pattern list follows.
            if ($operator -like ';[;&]*' -and $builder.CaseDepth -gt 0) { $builder.InPattern = $true }
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

# What one list of commands is reading: the current word (as Bash resolves it, with its expansions taken out, and its
# unquoted characters, where a quoted one is "\0"), the current command's words, and where a case statement stands.
function New-BashBuilder {
    [pscustomobject]@{
        Words = [Collections.Generic.List[string]]::new(); PlainWords = [Collections.Generic.List[string]]::new(); Computed = $null
        Variables = [Collections.Generic.List[string]]::new(); WordVariables = [Collections.Generic.List[string]]::new()
        Word = [Text.StringBuilder]::new(); PlainWord = [Text.StringBuilder]::new(); Unquoted = [Text.StringBuilder]::new()
        InWord = $false; Quoted = $false; WordComputed = $null; Redirect = $null; Depth = 0; CaseDepth = 0; InPattern = $false
    }
}

function Add-BashText {
    param([Parameter(Mandatory)] [pscustomobject] $Builder, [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text, [switch] $Quoted)

    [void] $Builder.Word.Append($Text)
    [void] $Builder.PlainWord.Append($Text)
    [void] $Builder.Unquoted.Append($(if ($Quoted) { "`0" } else { $Text }))
    $Builder.InWord = $true
    if ($Quoted) { $Builder.Quoted = $true }
}

# An expansion in the current word, kept as written and left out of its plain form. -Computed marks a value Bash
# builds when it runs, which no rule can read; -Variable names the variable a $name or ${name} expands.
function Add-BashExpansion {
    param([Parameter(Mandatory)] [pscustomobject] $Builder, [Parameter(Mandatory)] [string] $Text, [switch] $Computed, [string] $Variable)

    [void] $Builder.Word.Append($Text)
    [void] $Builder.Unquoted.Append("`0")
    $Builder.InWord = $true
    if ($Computed -and -not $Builder.WordComputed) { $Builder.WordComputed = $Text }
    if ($Variable) { $Builder.WordVariables.Add($Variable) }
}

# Ends the current word: a command's word, a redirection's target (dropped), or a heredoc's delimiter. An unquoted
# brace expression with a comma or "..", such as {x,-f} or {1..3}, makes the word one Bash builds when it runs.
function Add-BashWord {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder)

    if (-not $Builder.InWord) { return }
    $word = $Builder.Word.ToString()
    if (-not $Builder.WordComputed -and $Builder.Unquoted.ToString() -match '\{[^{}\s]*(,|\.\.)[^{}\s]*\}') { $Builder.WordComputed = $word }
    if ($Builder.Redirect -like 'heredoc*') {
        $Reader.Heredocs.Add([pscustomobject]@{ Delimiter = $word; Quoted = $Builder.Quoted; StripTabs = $Builder.Redirect -eq 'heredoc-strip' })
    }
    elseif (-not $Builder.Redirect) { Add-BashCommandWord -Reader $Reader -Builder $Builder -Word $word -PlainWord $Builder.PlainWord.ToString() }
    $Builder.Redirect = $null
    foreach ($part in $Builder.Word, $Builder.PlainWord, $Builder.Unquoted) { [void] $part.Clear() }
    $Builder.InWord = $false
    $Builder.Quoted = $false
    $Builder.WordComputed = $null
    $Builder.WordVariables.Clear()
}

# Adds a word to the command being read, except where a case statement makes it something else: "case WORD in" ends
# a command of its own and starts the patterns, a pattern isn't a command's word, and "esac" ends the statement.
function Add-BashCommandWord {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Word, [Parameter(Mandatory)] [AllowEmptyString()] [string] $PlainWord
    )

    $keyword = -not $Builder.Quoted -and $Builder.Words.Count -eq 0
    if ($keyword -and $Word -ceq 'esac' -and $Builder.CaseDepth -gt 0) {
        $Builder.CaseDepth--
        $Builder.InPattern = $false
        return
    }
    if ($Builder.InPattern) { return }
    $Builder.Words.Add($Word)
    $Builder.PlainWords.Add($PlainWord)
    $Builder.Variables.AddRange($Builder.WordVariables)
    if ($Builder.WordComputed -and -not $Builder.Computed) { $Builder.Computed = $Builder.WordComputed }
    if ($Builder.Words.Count -eq 3 -and $Builder.Words[0] -ceq 'case' -and $Word -ceq 'in' -and -not $Builder.Quoted) {
        Add-BashCommand -Reader $Reader -Builder $Builder
        $Builder.CaseDepth++
        $Builder.InPattern = $true
    }
}

function Complete-BashCommand {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder)

    Add-BashWord -Reader $Reader -Builder $Builder
    $Builder.Redirect = $null
    Add-BashCommand -Reader $Reader -Builder $Builder
}

# Moves the words read so far, if any, into a command of their own.
function Add-BashCommand {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder)

    if ($Builder.Words.Count) {
        $Reader.Commands.Add([pscustomobject]@{
                Words = $Builder.Words.ToArray(); PlainWords = $Builder.PlainWords.ToArray(); Native = $true
                Computed = $Builder.Computed; Variables = $Builder.Variables.ToArray()
            })
        $Builder.Words.Clear()
        $Builder.PlainWords.Clear()
        $Builder.Variables.Clear()
    }
    $Builder.Computed = $null
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

# A double-quoted string, after its opening quote, added to the current word with its escapes resolved. A heredoc's
# body reads the same way, except that '"' is literal there and the body ends with the text.
function Read-BashDoubleQuoted {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder, [switch] $Heredoc)

    $text = $Reader.Text
    Add-BashText -Builder $Builder -Text '' -Quoted
    while ($Reader.Index -lt $text.Length) {
        $c = $text[$Reader.Index]
        $next = if ($Reader.Index + 1 -lt $text.Length) { $text[$Reader.Index + 1] } else { [char] 0 }
        if ($c -eq '"' -and -not $Heredoc) { $Reader.Index++; return }
        if ($c -eq '\' -and ($next -in '$', '`', '\' -or ($next -eq '"' -and -not $Heredoc))) { Add-BashText -Builder $Builder -Text $next -Quoted; $Reader.Index += 2 }
        elseif ($c -eq '\' -and $next -eq "`n") { $Reader.Index += 2 }
        elseif ($c -eq '$') { Read-BashDollar -Reader $Reader -Builder $Builder -Quoted }
        elseif ($c -eq '`') { $Reader.Index++; Add-BashExpansion -Builder $Builder -Text (Read-BashBackquote -Reader $Reader) -Computed }
        else { Add-BashText -Builder $Builder -Text $c -Quoted; $Reader.Index++ }
    }
    if (-not $Heredoc) { throw "Bash can't read it: a double quote isn't closed." }
}

# What a '$' starts, added to the current word: $'...' and $"..." quoting, resolved (inside double quotes or a heredoc,
# -Quoted, they're a literal '$'); a $( ) substitution, its commands read; and $((...)), ${...} and $name. All but
# the quoting are expansions. A substitution (except cat reading a quoted heredoc), $((...)) and ${...} with an
# operator are values Bash builds when it runs.
function Read-BashDollar {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [pscustomobject] $Builder, [switch] $Quoted)

    $text = $Reader.Text
    $start = $Reader.Index
    $next = if ($start + 1 -lt $text.Length) { $text[$start + 1] } else { [char] 0 }
    if ($next -eq "'" -and -not $Quoted) { $Reader.Index += 2; Add-BashText -Builder $Builder -Text (Read-BashAnsiC -Reader $Reader) -Quoted; return }
    if ($next -eq '"' -and -not $Quoted) { $Reader.Index += 2; Read-BashDoubleQuoted -Reader $Reader -Builder $Builder; return }
    if ($next -eq '(' -and $start + 2 -lt $text.Length -and $text[$start + 2] -eq '(') {
        Add-BashExpansion -Builder $Builder -Text (Read-BashBracketed -Reader $Reader -Open '(' -Close ')') -Computed
        return
    }
    if ($next -eq '(') {
        $substitution = Read-BashSubstitution -Reader $Reader
        Add-BashExpansion -Builder $Builder -Text $substitution -Computed:(-not (Test-BashFixedSubstitution -Text $substitution))
        return
    }
    if ($next -eq '{') {
        $parameter = Read-BashBracketed -Reader $Reader -Open '{' -Close '}'
        $plain = $parameter -match '^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$'
        Add-BashExpansion -Builder $Builder -Text $parameter -Computed:(-not $plain) -Variable $(if ($plain) { $Matches[1] })
        return
    }
    $name = [regex]::Match($text.Substring($start + 1), '^(?:[A-Za-z_][A-Za-z0-9_]*|[0-9#?@*!$-])')
    if ($name.Success) {
        $Reader.Index += 1 + $name.Length
        Add-BashExpansion -Builder $Builder -Text "`$$($name.Value)" -Variable $name.Value
        return
    }
    $Reader.Index++
    Add-BashText -Builder $Builder -Text '$' -Quoted:$Quoted
}

# Whether a $( ) substitution's output is fixed text: cat reading a heredoc whose delimiter is quoted, so nothing in
# its body expands. This is how Claude Code writes a multi-line commit message.
function Test-BashFixedSubstitution {
    param([Parameter(Mandatory)] [string] $Text)

    $Text -match '(?s)\A\$\(\s*cat\s+<<-?\s*(?:''(?<d>[^''\n]+)''|"(?<d>[^"\n]+)")[ \t]*\r?\n.*?\n[ \t]*\k<d>[ \t]*\r?\n\s*\)\z'
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
            # The body is the command's input, not a word, so only the commands its substitutions run matter.
            $bodyReader = New-BashReader -Text $body.ToString() -Commands $Reader.Commands
            Read-BashDoubleQuoted -Reader $bodyReader -Builder (New-BashBuilder) -Heredoc
        }
    }
    $Reader.Heredocs.Clear()
}

# The words of a Bash command past what Claude Code's permissions page says it strips before matching a rule: the
# wrappers timeout, time, nice, nohup, stdbuf, command (not "command -v", a lookup), builtin, noglob and bare xargs
# (not xargs with options), each with its own options; any leading NAME=value assignment, which an ask rule matches
# past; and a reserved word that opens a control-flow body or group ("then", "do", "{", "!"), whose body Claude Code
# checks too.
function Get-BashInnerWord {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Words)

    $reserved = '!', '{', '}', 'if', 'then', 'else', 'elif', 'fi', 'do', 'done', 'while', 'until'
    # Each wrapper's options that take the next word as their value, and whether a bare operand (timeout's duration)
    # follows them.
    $wrappers = @{
        timeout = @{ Valued = '-s', '--signal', '-k', '--kill-after'; Operand = $true }
        time    = @{ Valued = @(); Operand = $false }
        nice    = @{ Valued = '-n', '--adjustment'; Operand = $false }
        nohup   = @{ Valued = @(); Operand = $false }
        stdbuf  = @{ Valued = '-i', '-o', '-e'; Operand = $false }
        command = @{ Valued = @(); Operand = $false }
        builtin = @{ Valued = @(); Operand = $false }
        noglob  = @{ Valued = @(); Operand = $false }
        xargs   = @{ Valued = @(); Operand = $false }
    }
    $i = 0
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        $next = if ($i + 1 -lt $Words.Count) { $Words[$i + 1] } else { '' }
        if ($word -cin $reserved -or $word -match '^[A-Za-z_][A-Za-z0-9_]*\+?=') { $i++; continue }
        if (-not $wrappers.ContainsKey($word) -or ($word -ceq 'command' -and $next -cin '-v', '-V') -or ($word -ceq 'xargs' -and $next.StartsWith('-'))) { break }
        $wrapper = $wrappers[$word]
        $i++
        while ($i -lt $Words.Count -and $Words[$i].StartsWith('-') -and $Words[$i] -ne '-') {
            $i += if ($Words[$i] -cin $wrapper.Valued) { 2 } else { 1 }
        }
        if ($wrapper.Operand) { $i++ }
    }
    @($Words | Select-Object -Skip $i)
}

# The forms of one resolved command's words that the ask rules are matched against: as resolved, and past what Claude
# Code strips before matching, which is Bash's wrappers, assignments and reserved words (Get-BashInnerWord), or
# PowerShell's "&" or "." invocation operator; and each of those with its paths and program name in their plain form
# (Get-PlainPathWord).
function Get-CommandWordForm {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Resolved, [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool,
        [string] $WorkingDirectory
    )

    $bases = [Collections.Generic.List[string[]]]::new()
    $bases.Add($Resolved.Words)
    # With its expansions taken out too: an unset variable, or PowerShell's ${null}, is empty when it runs.
    if (($Resolved.PlainWords -join "`0") -cne ($Resolved.Words -join "`0")) { $bases.Add($Resolved.PlainWords) }
    foreach ($words in $bases) {
        $inner = @(if ($Tool -eq 'Bash') { Get-BashInnerWord -Words $words } else { $words | Select-Object -Skip ([int] ($words[0] -cin '&', '.')) })
        $forms = @(, $words) + @(if ($inner.Count -and $inner.Count -ne $words.Count) { , [string[]] $inner })
        foreach ($form in $forms) {
            , $form
            $plain = @(Get-PlainPathWord -Words $form -WorkingDirectory $WorkingDirectory)
            if (($plain -join "`0") -cne ($form -join "`0")) { , [string[]] $plain }
        }
    }
}

# A command's words with each path in one plain spelling, as the file system reads it: "\" as "/", and "/./" and "//"
# as "/" (./tools/./New-KitApp.ps1 runs ./tools/New-KitApp.ps1). A path with a glob in its last part is expanded
# against the working directory, as the shell expands it, and left as it is when nothing matches. A program named by
# its path or with ".exe" (C:\Git\cmd\git.exe, /usr/bin/git) is also named by its bare name, as the rules name it.
function Get-PlainPathWord {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Words, [string] $WorkingDirectory)

    for ($i = 0; $i -lt $Words.Count; $i++) {
        $word = $Words[$i]
        if ($word -match '[/\\]') {
            $word = $word.Replace('\', '/')
            while ($word.Contains('/./')) { $word = $word.Replace('/./', '/') }
            $word = [regex]::Replace($word, '(?<=.)/{2,}', '/')
        }
        if ($word.Contains('/') -and $WorkingDirectory) {
            $expanded = @(Expand-PathGlob -Path $word -WorkingDirectory $WorkingDirectory)
            if ($expanded.Count) { $expanded; continue }
        }
        if ($i -eq 0) {
            $leaf = [regex]::Match($word.Substring($word.LastIndexOf('/') + 1), '^(?<name>[^.]+)(?<exe>\.exe)?$', 'IgnoreCase')
            if ($leaf.Success -and ($leaf.Value -ne $word -or $leaf.Groups['exe'].Success)) { $leaf.Groups['name'].Value; continue }
        }
        $word
    }
}

# The files a path with a glob (*, ? or [) in its last part names, relative to the working directory and spelled with
# the path's own folder, sorted; nothing when its last part has no glob or no file matches.
function Expand-PathGlob {
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [string] $WorkingDirectory)

    $folder = $Path.Substring(0, $Path.LastIndexOf('/') + 1)
    $leaf = $Path.Substring($folder.Length)
    if ($leaf -notmatch '[*?[]' -or $folder -match '[*?[]') { return }
    $directory = Join-Path $WorkingDirectory $folder
    try {
        $pattern = [Management.Automation.WildcardPattern]::new($leaf, [Management.Automation.WildcardOptions]::IgnoreCase)
        Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop | Where-Object { $pattern.IsMatch($_.Name) } | Sort-Object Name | ForEach-Object { $folder + $_.Name }
    }
    catch { return }
}

# The spellings of one resolved command that the ask rules are matched against: each of its word forms joined by
# spaces, and for a native command also with each cluster of short options split up ("-qf" as "-q -f"), as git's and
# gh's option parsers read it. Both are kept, so a rule written for the cluster ("-uf") still matches.
function Get-CommandSpelling {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Resolved, [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool,
        [string] $WorkingDirectory
    )

    foreach ($words in Get-CommandWordForm -Resolved $Resolved -Tool $Tool -WorkingDirectory $WorkingDirectory) {
        $words -join ' '
        if ($Resolved.Native) {
            $split = foreach ($word in $words) {
                if ($word -cmatch '^-[A-Za-z][A-Za-z0-9]+$') { ($word.Substring(1).ToCharArray() | ForEach-Object { "-$_" }) -join ' ' } else { $word }
            }
            $split -join ' '
        }
    }
}

# Why the command guard asks before a command runs, or $null when it leaves the command to Claude Code's own rules.
# It resolves the command as the shell will and asks when an ask rule covers the result, so a spelling the rule's
# text misses ("git push --for'ce'") still prompts. It matches without regard to case, for both shells: Windows opens
# ./tools/new-kitapp.ps1 and runs GIT as readily as their usual spellings. WorkingDirectory is where a glob expands.
function Get-CommandGuardDecision {
    param(
        [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $AskRules,
        [string] $WorkingDirectory
    )

    try { $commands = if ($Tool -eq 'Bash') { @(Get-BashCommand -Command $Command) } else { @(Get-PowerShellCommand -Command $Command) } }
    catch { return "The command guard (ADR-0077) can't resolve this command, so it asks: $($_.Exception.Message)" }
    foreach ($resolved in $commands) {
        if ($resolved.Computed) {
            return "The command guard (ADR-0077) asks because this command builds an argument when it runs, which no rule can read: $($resolved.Computed)"
        }
        foreach ($spelling in Get-CommandSpelling -Resolved $resolved -Tool $Tool -WorkingDirectory $WorkingDirectory | Select-Object -Unique) {
            foreach ($rule in $AskRules) {
                if (Test-PermissionRuleMatch -Rule $rule -Tool $Tool -Command $spelling -IgnoreCase) {
                    return "The command guard (ADR-0077) resolved this command to ""$spelling"", which the ask rule ""$rule"" covers."
                }
            }
        }
    }
    $null
}

# The ask rules in force for the project: .claude/settings.json's, and .claude/settings.local.json's when it exists
# (review mode adds its asks there, ADR-0035). Throws when either can't be read, since the guard can't check anything
# without them.
function Get-ProjectAskRule {
    param([Parameter(Mandatory)] [string] $ProjectDir)

    foreach ($name in 'settings.json', 'settings.local.json') {
        $path = Join-Path $ProjectDir '.claude' $name
        if ($name -eq 'settings.local.json' -and -not (Test-Path -LiteralPath $path)) { continue }
        $settings = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        # Assigned, not taken from an if expression, which would unwrap a one-rule list into its string.
        $ask = $null
        if ($settings -is [Collections.IDictionary] -and $settings['permissions'] -is [Collections.IDictionary]) { $ask = $settings['permissions']['ask'] }
        if ($null -eq $ask) { continue }
        if ($ask -isnot [Collections.IList] -or @($ask | Where-Object { $_ -isnot [string] }).Count) {
            throw "permissions.ask in .claude/$name isn't a list of rules."
        }
        $ask
    }
}

# The hook's answer for Claude Code: "ask" with the reason, as hookSpecificOutput (Claude Code's hooks page), in ASCII
# so the console's code page can't change it.
function ConvertTo-AskDecision {
    param([Parameter(Mandatory)] [string] $Reason)

    @{ hookSpecificOutput = [ordered]@{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = $Reason } } |
        ConvertTo-Json -Compress -EscapeHandling EscapeNonAscii
}

# Answers one PreToolUse hook call: the JSON to print, or $null to leave a Bash or PowerShell call to Claude Code's
# permission rules (and any other tool's call alone). ProjectDir is where .claude/ is; when it's empty, the input's
# cwd. Anything that goes wrong asks, so a failure never lets a command through unchecked.
function Invoke-CommandGuard {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $InputJson, [Parameter(Mandatory)] [AllowEmptyString()] [string] $ProjectDir)

    try {
        $hookInput = $InputJson | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        $tool = if ($hookInput -is [Collections.IDictionary]) { $hookInput['tool_name'] }
        if ($tool -cnotin 'Bash', 'PowerShell') { return $null }
        $command = if ($hookInput['tool_input'] -is [Collections.IDictionary]) { $hookInput['tool_input']['command'] }
        if ($command -isnot [string]) { throw "the $tool call's tool_input.command isn't a string." }
        $directory = if ($ProjectDir) { $ProjectDir } else { [string] $hookInput['cwd'] }
        $reason = Get-CommandGuardDecision -Tool $tool -Command $command -AskRules @(Get-ProjectAskRule -ProjectDir $directory)
    }
    catch {
        $reason = "The command guard (ADR-0077) failed, so it asks: $($_.Exception.Message)"
    }
    if ($reason) { ConvertTo-AskDecision -Reason $reason }
}

Export-ModuleMember -Function Test-PermissionRuleMatch, Get-CommandGuardDecision, Invoke-CommandGuard
