#Requires -Version 7.6
<#
.SYNOPSIS
    The command guard (ADR-0076): Claude Code's PreToolUse hook for the Bash and PowerShell tools.

.DESCRIPTION
    Claude Code runs this before each Bash or PowerShell call, with the call as JSON on stdin (its hooks page). It
    resolves the command the way the shell will (PowerShell's own parser; a POSIX tokenizer for Bash) and applies the
    ask rules of .claude/settings.json and .claude/settings.local.json to what it resolved, so a quoted spelling, joined
    short options or a parent segment still prompts. It also asks for a PowerShell argument computed inside ( ), @( ),
    $( ) or { }. When it asks, it prints the decision as JSON; otherwise it prints nothing and the call goes through
    Claude Code's own rules. It reads the project from CLAUDE_PROJECT_DIR, or the input's cwd. It exits 0 either way:
    a failure inside the guard asks, and only a guard that can't start leaves the call to the rules alone.

.EXAMPLE
    '{"tool_name":"Bash","tool_input":{"command":"git push --for''ce''"}}' | pwsh -NoProfile -File ./tools/Invoke-CommandGuard.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot 'KitCommandGuard.psm1') -Force

# Read as UTF-8 whatever the console's code page; the decision is written in ASCII.
$reader = [IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.UTF8Encoding]::new($false))
$hookInput = $reader.ReadToEnd()
$decision = Invoke-CommandGuard -InputJson $hookInput -ProjectDir ([string] $env:CLAUDE_PROJECT_DIR)
if ($decision) { [Console]::Out.Write($decision) }
exit 0
