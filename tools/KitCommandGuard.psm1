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
    Test-WildcardMatch -Pattern $pattern -Text $Command -IgnoreCase:$IgnoreCase
}

# Whether text matches a rule's wildcard pattern, where '*' matches any text (newlines too) and every other character
# is itself.
function Test-WildcardMatch {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Pattern, [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text, [switch] $IgnoreCase)

    $regex = '\A' + (($Pattern.Split('*') | ForEach-Object { [regex]::Escape($_) }) -join '.*') + '\z'
    $options = [Text.RegularExpressions.RegexOptions]::Singleline -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant
    if ($IgnoreCase) { $options = $options -bor [Text.RegularExpressions.RegexOptions]::IgnoreCase }
    [regex]::IsMatch($Text, $regex, $options)
}

# The commands the ask rules name for a tool, by program and, where the rule names one, subcommand: "*git *push*"
# names git and push, "Bash(git clean *)" git and clean, "PowerShell(./tools/New-KitApp*)" that script alone. The
# program is the rule's first word (after "&" or "."), as a wildcard, cut after its first literal part when more
# follows ("*Initialize-DevMachine*-I*", one word, names *Initialize-DevMachine*); the subcommand is the plain text that
# starts its second word, unless that's an option. A value built when a command runs could make it an asked form only
# if the command is one of these.
function Get-AskedCommand {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $AskRules, [Parameter(Mandatory)] [string] $Tool)

    foreach ($rule in $AskRules) {
        if (-not $rule.StartsWith("$Tool(", [StringComparison]::Ordinal) -or -not $rule.EndsWith(')', [StringComparison]::Ordinal)) { continue }
        $pattern = $rule.Substring($Tool.Length + 1, $rule.Length - $Tool.Length - 2)
        if ($pattern.EndsWith(':*', [StringComparison]::Ordinal)) { $pattern = $pattern.Substring(0, $pattern.Length - 2) }
        $parts = @($pattern.Split(' ') | Where-Object { $_ })
        if ($parts.Count -and $parts[0] -cin '&', '.') { $parts = @($parts | Select-Object -Skip 1) }
        if (-not $parts.Count) { continue }
        # Up to the first literal part with a name in it: ./*playwright.ps1 is one program, not "./*".
        $program = [regex]::Match($parts[0], '\A(?:[^*A-Za-z0-9]*\*)*[^*]*[A-Za-z0-9][^*]*\*')
        $subcommand = if ($parts.Count -gt 1) { $parts[1].TrimStart('*').Split('*')[0] }
        [pscustomobject]@{
            Program    = if ($program.Success) { $program.Value } else { $parts[0] }
            Subcommand = if ($subcommand -and -not $subcommand.StartsWith('-')) { $subcommand }
        }
    }
}

# Whether a resolved command could be one the ask rules name (Get-AskedCommand): its program, by any of its spellings
# (Get-PlainPathWord, with a short name or a glob resolved in WorkingDirectory), matches an asked program, and the rule
# names no subcommand, or one of the command's words is that subcommand (a path by its last part: .../playwright.ps1),
# or the subcommand's place holds a word built when the command runs. That place is the first word after the program
# that isn't an option, read both ways: with every option taking no value (git --no-pager $p) and with each taking the
# next word (git -C . $p). A program that is itself built could be anything.
function Test-AskedCommand {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Resolved, [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool,
        [AllowEmptyCollection()] [object[]] $Asked, [string] $WorkingDirectory
    )

    $words = $Resolved.Words
    $start = Get-InnerStart -Words $words -Tool $Tool
    if ($start -ge $words.Count) { return $false }
    if ($Resolved.Built[$start]) { return $true }
    $names = @($words[$start]) + @(Get-PlainPathWord -Tool $Tool -Words @($words[$start]) -WorkingDirectory $WorkingDirectory)
    $rest = @($words | Select-Object -Skip ($start + 1))
    $places = @(Get-SubcommandPlace -Words $words -Start ($start + 1))
    $builtSubcommand = [bool] @($places | Where-Object { $Resolved.Built[$_] }).Count
    foreach ($command in $Asked) {
        if (-not @($names | Where-Object { Test-WildcardMatch -Pattern $command.Program -Text $_ -IgnoreCase }).Count) { continue }
        if (-not $command.Subcommand -or $builtSubcommand) { return $true }
        $leaves = $rest | ForEach-Object { $_.Substring($_.Replace('\', '/').LastIndexOf('/') + 1) }
        if (@($leaves | Where-Object { [string]::Equals($_, $command.Subcommand, [StringComparison]::OrdinalIgnoreCase) }).Count) { return $true }
    }
    $false
}

# Where a command's subcommand may be, from Start: the first word that isn't an option, with every option taking no
# value, and again with each option that has no "=" taking the next word as its value.
function Get-SubcommandPlace {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Words, [Parameter(Mandatory)] [int] $Start)

    foreach ($valued in $false, $true) {
        $i = $Start
        while ($i -lt $Words.Count -and $Words[$i].StartsWith('-')) {
            $i += if ($valued -and -not $Words[$i].Contains('=') -and $i + 1 -lt $Words.Count -and -not $Words[$i + 1].StartsWith('-')) { 2 } else { 1 }
        }
        if ($i -lt $Words.Count) { $i }
    }
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
# ("&" or "." first when it's invoked with one), and Built, beside each word, the variable that makes it a value known
# only when the command runs (or $null). Runs names code that runs inside an argument: ( ), @( ), $( ) or { }, or a
# variable the input fills from a command's output. Throws when the text doesn't parse, since PowerShell won't run it
# either and nothing it holds can be resolved.
function Get-PowerShellCommand {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command)

    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Command, [ref] $tokens, [ref] $errors)
    if ($errors.Count) { throw "PowerShell can't parse it: $($errors[0].Message)" }

    $fromCommand = Get-PowerShellFilledVariable -Ast $ast
    $isCommand = { param($node) $node -is [Management.Automation.Language.CommandAst] }
    # A variable that names a provider path, such as ${C:\repo\.env}, reads that item as the input runs, as Get-Content
    # would, wherever it sits: in an argument, in an assignment a later argument uses, or alone, as the output. Every
    # command the input holds asks for it, and so does an input with no command.
    $readsItem = $ast.Find({ param($node) Test-PowerShellProviderRead -Node $node }, $true)
    $commandAsts = @($ast.FindAll($isCommand, $true))
    if ($readsItem -and -not $commandAsts.Count) {
        return [pscustomobject]@{ Words = @($readsItem.Extent.Text); PlainWords = @($readsItem.Extent.Text); Built = @(, $null); Native = $false; Runs = $readsItem.Extent.Text }
    }

    foreach ($commandAst in $commandAsts) {
        $words = [Collections.Generic.List[string]]::new()
        $built = [Collections.Generic.List[string]]::new()
        switch ($commandAst.InvocationOperator) {
            'Ampersand' { $words.Add('&'); $built.Add($null) }
            'Dot' { $words.Add('.'); $built.Add($null) }
        }
        $plainWords = [Collections.Generic.List[string]]::new($words)
        $nameAt = $words.Count
        $stopped = $false
        foreach ($element in $commandAst.CommandElements) {
            if ($stopped) {
                Add-PowerShellStopParsedWord -Text $element.Value -Words $words -PlainWords $plainWords -Built $built
                break
            }
            # The stop-parsing token itself doesn't reach the program; the parser holds the rest of the line in the
            # next element.
            $stopped = $element -is [Management.Automation.Language.StringConstantExpressionAst] -and
                $element.StringConstantType -eq 'BareWord' -and $element.Value -ceq '--%'
            if ($stopped) { continue }
            $words.Add((ConvertTo-PowerShellWord -Element $element))
            $plain = ConvertTo-PowerShellPlainWord -Element $element
            if ($null -ne $plain) { $plainWords.Add($plain) }
            # Any variable: the tool keeps none between calls, so its value comes from this input or the environment,
            # and either way is known only when the command runs. So is any other value that isn't written out as
            # text, such as a method call, an index or a list on a literal ('--forXe'.Replace('X','c')).
            $variable = $element.Find({ param($node) $node -is [Management.Automation.Language.VariableExpressionAst] }, $true)
            # Assigned first: $( ) of an if that writes nothing would add an empty entry, not $null.
            $builtBy = if ($variable) { $variable.Extent.Text } elseif (-not (Test-PowerShellLiteral -Element $element)) { $element.Extent.Text } else { $null }
            $built.Add($builtBy)
        }
        $name = $words[$nameAt]
        $runs = $commandAst.Find({ param($node) $node.GetType() -in $script:ComputedArgumentAst }, $true)
        if (-not $runs) { $runs = $readsItem }
        if (-not $runs) {
            $runs = $commandAst.Find({ param($node) $node -is [Management.Automation.Language.VariableExpressionAst] -and $fromCommand.Contains((Get-PowerShellVariableName -Variable $node)) }, $true)
        }
        [pscustomobject]@{
            Words      = $words.ToArray()
            PlainWords = $plainWords.ToArray()
            Built      = $built.ToArray()
            Native     = -not (Test-PowerShellCommandName -Name $name)
            Runs       = if ($runs) { $runs.Extent.Text } else { $null }
        }
    }
}

# The words a native program receives from the text after PowerShell's stop-parsing token (--%), which PowerShell
# passes as written but for each %NAME%, expanded to an environment variable's value (about_Parsing): split at white
# space with its double quotes taken out, as the program's own argument parser reads it. A word with a %NAME% is a
# value known only as the command runs.
function Add-PowerShellStopParsedWord {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        # Not mandatory: Built holds $null beside each word that isn't built, which a mandatory list refuses.
        [Collections.Generic.List[string]] $Words, [Collections.Generic.List[string]] $PlainWords, [Collections.Generic.List[string]] $Built
    )

    foreach ($word in $Text -split '\s+') {
        if (-not $word) { continue }
        $Words.Add($word.Replace('"', ''))
        $PlainWords.Add($word.Replace('"', ''))
        $variable = [regex]::Match($word, '%[^%\s]+%')
        if ($variable.Success) { $Built.Add($variable.Value) } else { $Built.Add($null) }
    }
}

# Whether a PowerShell command's argument is written out as the text it passes: a string or a number, or a parameter
# with no value or such a value. A string's own expansions are variables or code inside it, which are seen apart.
function Test-PowerShellLiteral {
    param([Parameter(Mandatory)] [Management.Automation.Language.Ast] $Element)

    if ($Element -is [Management.Automation.Language.CommandParameterAst]) {
        return -not $Element.Argument -or (Test-PowerShellLiteral -Element $Element.Argument)
    }
    $Element -is [Management.Automation.Language.StringConstantExpressionAst] -or
    $Element -is [Management.Automation.Language.ExpandableStringExpressionAst] -or
    $Element -is [Management.Automation.Language.ConstantExpressionAst]
}

# The variables a PowerShell input fills from a command's output: an assignment or a foreach over one; a common
# parameter such as -OutVariable that names the variable a command fills; and a pipeline's Tee-Object -Variable, or
# Set-Variable or New-Variable after a "|", where each name it's given counts (its value comes from the pipe).
function Get-PowerShellFilledVariable {
    param([Parameter(Mandatory)] [Management.Automation.Language.Ast] $Ast)

    $filled = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $isCommand = { param($node) $node -is [Management.Automation.Language.CommandAst] }
    foreach ($node in $Ast.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -or $node -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
        $target, $source = if ($node -is [Management.Automation.Language.ForEachStatementAst]) { $node.Variable, $node.Condition } else { $node.Left, $node.Right }
        if (-not $source.Find($isCommand, $true)) { continue }
        foreach ($variable in $target.FindAll({ param($v) $v -is [Management.Automation.Language.VariableExpressionAst] }, $true)) {
            [void] $filled.Add((Get-PowerShellVariableName -Variable $variable))
        }
    }
    foreach ($commandAst in $Ast.FindAll($isCommand, $true)) {
        $elements = $commandAst.CommandElements
        $piped = $commandAst.Parent -is [Management.Automation.Language.PipelineAst] -and $commandAst.Parent.PipelineElements.IndexOf($commandAst) -gt 0
        $tee = $piped -and $commandAst.GetCommandName() -match '^(?i:Tee-Object|tee)$'
        $setter = $piped -and $commandAst.GetCommandName() -match '^(?i:Set-Variable|sv|New-Variable|nv)$'
        for ($i = 1; $i -lt $elements.Count; $i++) {
            $parameter = if ($elements[$i] -is [Management.Automation.Language.CommandParameterAst]) { $elements[$i].ParameterName }
            $names = $parameter -and ($parameter -match '^(?i:OutV|ov$|PipelineV|pv$|ErrorV|ev$|WarningV|wv$|InformationV|iv$)' -or ($tee -and 'Variable'.StartsWith($parameter, [StringComparison]::OrdinalIgnoreCase)))
            $value = $null
            if ($names) { $value = if ($elements[$i].Argument) { $elements[$i].Argument } elseif ($i + 1 -lt $elements.Count) { $elements[$i + 1] } }
            elseif ($setter) { $value = if ($parameter) { $elements[$i].Argument } else { $elements[$i] } }
            if ($value -is [Management.Automation.Language.StringConstantExpressionAst]) { [void] $filled.Add($value.Value.TrimStart('+')) }
        }
    }
    , $filled
}

# Whether a node is a variable that names a provider path and so reads an item when it runs (about_Variables, "Variable syntax with provider paths"):
# a drive-qualified name other than env:, such as ${C:\repo\.env} or ${function:x}. A scope ($global:x) or the
# variable: drive names an ordinary variable, and env: an environment variable, which are values, not reads.
function Test-PowerShellProviderRead {
    param([Parameter(Mandatory)] [Management.Automation.Language.Ast] $Node)

    $Node -is [Management.Automation.Language.VariableExpressionAst] -and $Node.VariablePath.IsDriveQualified -and
    $Node.VariablePath.DriveName -ne 'env'
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
# PlainWords (an unset variable is empty). Built, beside each word, names what makes it a value Bash builds when it
# runs (or $null): a brace expansion, ${...} with an operator, $((...)), a $( ) or backquote substitution other than cat
# reading a quoted heredoc (whose output is fixed text), or a variable, whose value comes from this input or the environment. Redirections and heredoc
# bodies aren't words. Throws when a quote, substitution or parenthesis isn't closed, since Bash won't run that either.
# Bash runs nothing inside an argument that Claude Code doesn't check: its rules apply inside a substitution.
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
        Words = [Collections.Generic.List[string]]::new(); PlainWords = [Collections.Generic.List[string]]::new(); Built = [Collections.Generic.List[string]]::new()
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
# builds when it runs, which no rule can read.
function Add-BashExpansion {
    param([Parameter(Mandatory)] [pscustomobject] $Builder, [Parameter(Mandatory)] [string] $Text, [switch] $Computed)

    [void] $Builder.Word.Append($Text)
    [void] $Builder.Unquoted.Append("`0")
    $Builder.InWord = $true
    if ($Computed -and -not $Builder.WordComputed) { $Builder.WordComputed = $Text }
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
   $Builder.Built.Add($Builder.WordComputed)
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
                Built = $Builder.Built.ToArray()
            })
        $Builder.Words.Clear()
        $Builder.PlainWords.Clear()
       $Builder.Built.Clear()
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
        Add-BashExpansion -Builder $Builder -Text (Read-BashBracketed -Reader $Reader -Open '{' -Close '}') -Computed
        return
    }
    $name = [regex]::Match($text.Substring($start + 1), '^(?:[A-Za-z_][A-Za-z0-9_]*|[0-9#?@*!$-])')
    if ($name.Success) {
        $Reader.Index += 1 + $name.Length
        Add-BashExpansion -Builder $Builder -Text "`$$($name.Value)" -Computed
        return
    }
    $Reader.Index++
    Add-BashText -Builder $Builder -Text '$' -Quoted:$Quoted
}

# Whether a $( ) substitution's output is fixed text: cat reading a heredoc whose delimiter is quoted, so nothing in
# its body expands, and nothing after the heredoc but the closing ')'. This is how Claude Code writes a multi-line
# commit message. The body ends, as Bash ends it, at the first line that is the delimiter (with "<<-", after its
# leading tabs), so a second delimiter line can't hide a command after the first.
function Test-BashFixedSubstitution {
    param([Parameter(Mandatory)] [string] $Text)

    $header = [regex]::Match($Text, '\A\$\(\s*cat\s+<<(?<strip>-?)\s*(?:''(?<d>[^''\n]+)''|"(?<d>[^"\n]+)")[ \t]*\r?\n')
    if (-not $header.Success) { return $false }
    $lines = $Text.Substring($header.Length).Split("`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd("`r")
        if ($header.Groups['strip'].Value) { $line = $line.TrimStart("`t") }
        if ($line -ceq $header.Groups['d'].Value) {
            return (($lines | Select-Object -Skip ($i + 1)) -join "`n") -match '\A\s*\)\z'
        }
    }
    $false
}

# $((...)) or ${...}, kept as written: from the '$' to the bracket that closes the first one. Bash runs the $( ) and
# backquote substitutions inside it as it expands it (${X:-$(cmd)}), so their commands are read as commands of their own.
function Read-BashBracketed {
    param([Parameter(Mandatory)] [pscustomobject] $Reader, [Parameter(Mandatory)] [char] $Open, [Parameter(Mandatory)] [char] $Close)

    $text = $Reader.Text
    $start = $Reader.Index
    $depth = 0
    for ($i = $start + 1; $i -lt $text.Length; $i++) {
        $substitution = $text[$i] -eq '$' -and $i + 1 -lt $text.Length -and $text[$i + 1] -eq '(' -and -not ($i + 2 -lt $text.Length -and $text[$i + 2] -eq '(')
        if ($substitution) { $Reader.Index = $i; [void] (Read-BashSubstitution -Reader $Reader); $i = $Reader.Index - 1 }
        elseif ($text[$i] -eq '`') { $Reader.Index = $i + 1; [void] (Read-BashBackquote -Reader $Reader); $i = $Reader.Index - 1 }
        elseif ($text[$i] -eq $Open) { $depth++ }
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
    $before = $Reader.Commands.Count
    $Reader.Index += 2
    Read-BashList -Reader $Reader -Close ')'
    $text = $Reader.Text.Substring($start, $Reader.Index - $start)
    Add-BashRedirectOnly -Commands $Reader.Commands -Before $before -Text $text
    $text
}

# A substitution that holds a redirection but no command, such as "$(<.env)", Bash's faster "$(cat .env)" (its
# manual, Command Substitution): it reads or writes a file with no subcommand for Claude Code's rules, or its Read
# deny rules on cat, to check. It's added as a command of its own that runs code, so the guard asks.
function Add-BashRedirectOnly {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [Collections.Generic.List[object]] $Commands,
        [Parameter(Mandatory)] [int] $Before, [Parameter(Mandatory)] [string] $Text
    )

    if ($Commands.Count -ne $Before -or $Text -notmatch '[<>]') { return }
    $Commands.Add([pscustomobject]@{ Words = @($Text); PlainWords = @($Text); Built = @(, $null); Native = $true; Runs = $Text })
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
    $before = $Reader.Commands.Count
    Read-BashList -Reader $sub -Close ''
    $text = '`' + $inner.ToString() + '`'
    Add-BashRedirectOnly -Commands $Reader.Commands -Before $before -Text $text
    $text
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

# Where a command's program is in its words: past PowerShell's "&" or "." invocation operator, or past what Claude
# Code's permissions page says it strips from a Bash command before matching a rule (Get-BashInnerStart).
function Get-InnerStart {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Words, [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool)

    if ($Tool -eq 'Bash') { return Get-BashInnerStart -Words $Words }
    [int] ($Words.Count -and $Words[0] -cin '&', '.')
}

# The kit scripts that run words of their own arguments as a command: Invoke-WithPlaywrightImage.ps1 runs the words
# after its parameters on the host when no project uses Playwright.
$script:CommandRunnerScript = @('Invoke-WithPlaywrightImage.ps1')

# The commands a kit runner script (CommandRunnerScript) may run, when a resolved command's program is one, directly or
# through pwsh -File, by any spelling Get-PlainPathWord gives it (a short name, a glob, its case). Each word after the
# script that isn't an option could start it, since the script's switches and parameters, and a "--", may come in any
# order before it; each comes out as a command of its own, so the ask rules and the built-value check see it.
function Get-RunnerCommand {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Resolved, [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool,
        [string] $WorkingDirectory
    )

    $words = $Resolved.Words
    $leaf = { param($word) $word.Replace('\', '/').Substring($word.Replace('\', '/').LastIndexOf('/') + 1) }
    $start = Get-InnerStart -Words $words -Tool $Tool
    if ($start -ge $words.Count) { return }
    # pwsh runs as its script the word after -File, or its first argument that isn't an option: any later word may be it.
    $places = if ((& $leaf $words[$start]) -match '^(?i:pwsh(\.exe)?)$') { @(($start + 1)..($words.Count - 1)) } else { @($start) }
    $isRunner = { param($word) @(Get-PlainPathWord -Tool $Tool -Words @('-', $word) -WorkingDirectory $WorkingDirectory | Select-Object -Skip 1 | Where-Object { (& $leaf $_) -in $script:CommandRunnerScript }).Count }
    $i = @($places | Where-Object { $_ -lt $words.Count -and (& $isRunner $words[$_]) } | Select-Object -First 1)
    if (-not $i.Count) { return }
    $i = $i[0]
    for ($j = $i + 1; $j -lt $words.Count; $j++) {
        if ($words[$j].StartsWith('-')) { continue }
        $command = [string[]] @($words[$j..($words.Count - 1)])
        [pscustomobject]@{
            Words      = $command
            PlainWords = $command
            # By index: a pipeline would drop the list's empty entries and shift the rest.
            Built      = @($Resolved.Built[$j..($words.Count - 1)])
            Native     = -not (Test-PowerShellCommandName -Name $command[0])
        }
    }
}

# Where a Bash command's program is, past what Claude Code's permissions page says it strips before matching a rule:
# the wrappers timeout, time, nice, nohup, stdbuf, command (not "command -v", a lookup), builtin, noglob and bare xargs
# (not xargs with options), each with its own options; any leading NAME=value assignment, which an ask rule matches
# past; and a reserved word that opens a control-flow body or group ("then", "do", "{", "!"), whose body Claude Code
# checks too.
function Get-BashInnerStart {
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
    $i
}

# The forms of one resolved command's words that the ask rules are matched against: as resolved, and past what Claude
# Code strips before matching, which is Bash's wrappers, assignments and reserved words, or PowerShell's "&" or "."
# (Get-InnerStart); and each of those with its paths and program name in their plain form (Get-PlainPathWord).
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
        $inner = @($words | Select-Object -Skip (Get-InnerStart -Words $words -Tool $Tool))
        $forms = @(, $words) + @(if ($inner.Count -and $inner.Count -ne $words.Count) { , [string[]] $inner })
        foreach ($form in $forms) {
            , $form
            # Each word's plain spelling, once: the program as Get-PlainPathWord names it, the rest as arguments.
            $plainOf = @(for ($i = 0; $i -lt $form.Count; $i++) {
                    $one = if ($i -eq 0) { @(Get-PlainPathWord -Tool $Tool -Words @($form[0]) -WorkingDirectory $WorkingDirectory) }
                    else { @(Get-PlainPathWord -Tool $Tool -Words @('-', $form[$i]) -WorkingDirectory $WorkingDirectory | Select-Object -Skip 1) }
                    , [string[]] $one
                })
            # A bracket glob that matches several files is also tried with each one alone in its place, as the shell
            # runs it where only that one matches: the guard reads a bracket more widely than Bash (ConvertFrom-BashGlob).
            # A '*' or '?' it reads nearly as the shell does, so its files stay together, in the order it sorts them.
            $tried = 0
            for ($i = 0; $i -lt $form.Count; $i++) {
                if (-not $form[$i].Contains('[') -or $plainOf[$i].Count -lt 2) { continue }
                # Each match tried alone costs more with each other file, and a hook that times out checks nothing, so
                # past 200 files across the command's bracket globs the guard asks instead.
                $tried += $plainOf[$i].Count
                if ($tried -gt 200) {
                    throw "its bracket globs (from $($form[$i])) match more than 200 files, more than it tries one by one."
                }
                foreach ($file in $plainOf[$i]) {
                    , [string[]] @(for ($j = 0; $j -lt $form.Count; $j++) { if ($j -eq $i) { $file } else { $plainOf[$j] } })
                }
            }
            $plain = [string[]] @($plainOf | ForEach-Object { $_ })
            if (($plain -join "`0") -cne ($form -join "`0")) { , $plain }
        }
    }
}

# A command's words with each path in one plain spelling, as the file system reads it: "\" as "/", and "/./" and "//"
# as "/" (./tools/./New-KitApp.ps1 runs ./tools/New-KitApp.ps1). A path with a glob in its last part is expanded
# against the working directory, as the shell expands it, and left as it is when nothing matches. A program named by
# its path or with ".exe" (C:\Git\cmd\git.exe, /usr/bin/git) is also named by its bare name, as the rules name it.
function Get-PlainPathWord {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Words,
        [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool, [string] $WorkingDirectory
    )

    for ($i = 0; $i -lt $Words.Count; $i++) {
        $word = $Words[$i]
        if ($word -match '[/\\]') {
            # Bash passes a '\' as written: only a Windows program reading a path takes it as a folder separator. So in
            # Bash it's one only where no part before the last '\' holds a pattern's character, as a regex does
            # (v[0-9]+\..), whose '\' is an escape.
            $before = $word.Substring(0, [Math]::Max(0, $word.LastIndexOf('\')))
            if ($Tool -eq 'PowerShell' -or $before -notmatch '[\[\]*?+^$|(){}]') { $word = $word.Replace('\', '/') }
            while ($word.Contains('/./')) { $word = $word.Replace('/./', '/') }
            $word = [regex]::Replace($word, '(?<=.)/{2,}', '/')
        }
        if ($word.Contains('/') -and $word.Contains('~') -and $WorkingDirectory) { $word = Expand-ShortPathName -Path $word -WorkingDirectory $WorkingDirectory }
        if ($word.Contains('/') -and $WorkingDirectory) {
            # Bash splits a glob only at '/', so there a '\' (quoted, in a bracket: [N\\]) is part of a name, not a folder.
            $globs = @($word) + @(if ($Words[$i].Contains('\') -and $Words[$i] -match '[*?[]') { [regex]::Replace($Words[$i].Replace('/./', '/'), '(?<=.)/{2,}', '/') })
            $expanded = @($globs | ForEach-Object { Expand-PathGlob -Path $_ -WorkingDirectory $WorkingDirectory } | Select-Object -Unique)
            if ($expanded.Count) { $expanded; continue }
        }
        if ($i -eq 0) {
            $leaf = [regex]::Match($word.Substring($word.LastIndexOf('/') + 1), '^(?<name>[^.]+)(?<exe>\.exe)?$', 'IgnoreCase')
            if ($leaf.Success -and ($leaf.Value -ne $word -or $leaf.Groups['exe'].Success)) { $leaf.Groups['name'].Value; continue }
        }
        $word
    }
}

# A path with each part that may be a Windows 8.3 short name (one with "~", such as NEW-KI~1.PS1) in its long form,
# where that file or folder exists: Path.GetFullPath expands a short name to the long one, as its docs say. Other
# parts keep their spelling, and on Linux and macOS, which have no short names, so does the whole path.
function Expand-ShortPathName {
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [string] $WorkingDirectory)

    $parts = $Path.Split('/')
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if (-not $parts[$i].Contains('~')) { continue }
        try { $parts[$i] = Split-Path -Leaf ([IO.Path]::GetFullPath(($parts[0..$i] -join '/'), $WorkingDirectory)) }
        catch { continue }
    }
    $parts -join '/'
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
        # A file either shell would expand the glob to: PowerShell's wildcards or Bash's pattern matching, whose
        # bracket expressions also negate ([!x], [^x]) and name classes ([[:upper:]]), read as a superset by
        # ConvertFrom-BashGlob. Both ignore case here, as Windows opens a file whatever its case, so the guard tries
        # every file either could mean.
        $pattern = [Management.Automation.WildcardPattern]::new($leaf, [Management.Automation.WildcardOptions]::IgnoreCase)
        $bash = @(ConvertFrom-BashGlob -Glob $leaf)
        Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop |
            # A pattern PowerShell can't read matches nothing for PowerShell, and leaves Bash's readings to decide.
            Where-Object { $name = $_.Name; (& { try { $pattern.IsMatch($name) } catch { $false } }) -or @($bash | Where-Object { [regex]::IsMatch($name, $_, 'IgnoreCase, CultureInvariant') }).Count } |
            Sort-Object Name | ForEach-Object { $folder + $_.Name }
    }
    catch { return }
}

# Regexes that together match every name Bash could expand one path part to (pattern matching, Bash's manual
# 3.5.8.1), as a superset: '*' and '?' as Bash reads them, and each bracket expression as any one character, closed at
# any later ']' or left as a literal '['. Bash's own reading of a bracket (negation, classes, [=c=], [.c.], and a
# quoted ']' inside it, whose quotes are gone by now) is always one of these, so a glob can make the guard try more
# files, never fewer. Past 64 readings, one regex that matches any name.
function ConvertFrom-BashGlob {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Glob, [hashtable] $Read = [hashtable]::new([StringComparer]::Ordinal))

    # Each tail of the glob is read once (Read holds them), so many brackets cost no more than their readings.
    if ($Read.ContainsKey($Glob)) { return $Read[$Glob] }
    $prefix = ''
    for ($i = 0; $i -lt $Glob.Length; $i++) {
        $c = $Glob[$i]
        if ($c -ne '[') { $prefix += switch ($c) { '*' { '.*' } '?' { '.' } default { [regex]::Escape([string] $c) } }; continue }
        # Each later ']' could close this bracket, which then matches one character, or the '[' is literal; the rest
        # of the glob is read again from there.
        $tails = @(for ($k = $i + 1; $k -lt $Glob.Length; $k++) { if ($Glob[$k] -eq ']') { , @('.', ($k + 1)) } }) + , @('\[', ($i + 1))
        $readings = @(foreach ($tail in $tails) {
                foreach ($rest in ConvertFrom-BashGlob -Glob $Glob.Substring($tail[1]) -Read $Read) { "\A$prefix$($tail[0])$($rest.Substring(2, $rest.Length - 4))\z" }
            }) | Select-Object -Unique
        $Read[$Glob] = if (@($readings).Count -gt 64) { '\A.*\z' } else { $readings }
        return $Read[$Glob]
    }
    $Read[$Glob] = "\A$prefix\z"
    $Read[$Glob]
}

# The spellings of one resolved command that the ask rules are matched against: each of its word forms joined by
# spaces, and for a native command also with each cluster of short options split up ("-qf" as "-q -f"), as git's and
# gh's option parsers read it. Both are kept, so a rule written for the cluster ("-uf") still matches. A form with a
# word that holds white space is also spelled with that word in double quotes, as a rule may write it
# (pwsh -NoProfile -Command "Install-PSResource *), since any quoting of the word reaches the program as the same text.
function Get-CommandSpelling {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Resolved, [Parameter(Mandatory)] [ValidateSet('Bash', 'PowerShell')] [string] $Tool,
        [string] $WorkingDirectory
    )

    foreach ($words in Get-CommandWordForm -Resolved $Resolved -Tool $Tool -WorkingDirectory $WorkingDirectory) {
        $words -join ' '
        if (@($words | Where-Object { $_ -match '\s' }).Count) {
            ($words | ForEach-Object { if ($_ -match '\s') { """$_""" } else { $_ } }) -join ' '
        }
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
    $commands = @($commands | ForEach-Object { $_; Get-RunnerCommand -Resolved $_ -Tool $Tool -WorkingDirectory $WorkingDirectory })
    $asked = @(Get-AskedCommand -AskRules $AskRules -Tool $Tool)
    foreach ($resolved in $commands) {
        if ($resolved.PSObject.Properties['Runs'] -and $resolved.Runs) {
            return "The command guard (ADR-0077) asks because this command builds an argument when it runs, from code inside it that Claude Code's rules may not check: $($resolved.Runs)"
        }
        $built = @($resolved.Built | Where-Object { $_ })
        if ($built.Count -and (Test-AskedCommand -Resolved $resolved -Tool $Tool -Asked $asked -WorkingDirectory $WorkingDirectory)) {
            return "The command guard (ADR-0077) asks because this command, which an ask rule names, builds an argument when it runs, which no rule can read: $($built[0])"
        }
        try { $spellings = @(Get-CommandSpelling -Resolved $resolved -Tool $Tool -WorkingDirectory $WorkingDirectory) }
        catch { return "The command guard (ADR-0077) can't check this command, so it asks: $($_.Exception.Message)" }
        foreach ($spelling in $spellings | Select-Object -Unique) {
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
        $cwd = [string] $hookInput['cwd']
        $directory = if ($ProjectDir) { $ProjectDir } else { $cwd }
        # A glob expands where the shell runs the command: the input's cwd, or the project when there's none.
        $workingDirectory = if ($cwd) { $cwd } else { $directory }
        $reason = Get-CommandGuardDecision -Tool $tool -Command $command -AskRules @(Get-ProjectAskRule -ProjectDir $directory) -WorkingDirectory $workingDirectory
    }
    catch {
        $reason = "The command guard (ADR-0077) failed, so it asks: $($_.Exception.Message)"
    }
    if ($reason) { ConvertTo-AskDecision -Reason $reason }
}

Export-ModuleMember -Function Test-PermissionRuleMatch, Get-CommandGuardDecision, Invoke-CommandGuard
