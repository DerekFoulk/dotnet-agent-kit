#Requires -Version 7.0
<#
.SYNOPSIS
    The git settings every repo a test makes runs with (TestGit.Tests.ps1).

.DESCRIPTION
    Set-TestGitEnvironment sets them in the environment, so they reach the scripts under test and the processes
    they start:
    - no git config, ignore or attributes file from this machine: no global or system config
      (GIT_CONFIG_GLOBAL=/dev/null, GIT_CONFIG_NOSYSTEM), no system attributes (GIT_ATTR_NOSYSTEM), and the
      default per-user ignore and attributes files replaced by an empty one (core.excludesFile and
      core.attributesFile below). A global hook, or a ".vscode/" line in ~/.config/git/ignore, can't change a test;
    - the fixture identity, in GIT_AUTHOR_* and GIT_COMMITTER_*, which outrank every identity config key;
    - the rest through GIT_CONFIG_COUNT, GIT_CONFIG_KEY_<n> and GIT_CONFIG_VALUE_<n>, which outrank a repo's own
      config too: no signing, no background maintenance, no file-system monitor, those empty ignore and
      attributes files.
    A fixture commit once started git's background maintenance, whose repack raced the test's next lookups of the
    fixture commit (New-KitApp.Tests on Windows, PR 23). Restore-TestGitEnvironment puts back what was there before.
    Call the first in a test file's BeforeAll and the second in its AfterAll.

    With no global or system config, a safe.directory entry there doesn't apply either: a checkout owned by another
    account makes git stop with "dubious ownership". Run the tests from a checkout of your own. A test that reads
    the checkout itself (its file list, say) does so before calling Set-TestGitEnvironment, with its own config.

    One exception: for a push or fetch through a local path, git strips GIT_CONFIG_COUNT from the receive-pack or
    upload-pack it starts. Only receive-pack runs maintenance, so New-TestGitRemote makes a bare repo for a test to
    push into, with the setting receive-pack needs in its own config.
#>

Set-StrictMode -Version Latest

$script:Variables = [ordered]@{
    GIT_AUTHOR_NAME     = 'fixture'
    GIT_AUTHOR_EMAIL    = 'fixture@example.invalid'
    GIT_COMMITTER_NAME  = 'fixture'
    GIT_COMMITTER_EMAIL = 'fixture@example.invalid'
    # No global or system config at all: git reads /dev/null as an empty file, on Windows too.
    GIT_CONFIG_GLOBAL   = '/dev/null'
    GIT_CONFIG_NOSYSTEM = '1'
    # Nor the system attributes file, which GIT_CONFIG_NOSYSTEM doesn't cover.
    GIT_ATTR_NOSYSTEM   = '1'
}

$script:Settings = [ordered]@{
    'commit.gpgsign'   = 'false'
    'tag.gpgsign'      = 'false'
    'maintenance.auto' = 'false'
    'gc.auto'          = '0'
    'core.fsmonitor'   = 'false' # a daemon per repo, holding handles in TestDrive
    # With no global config, git would still read its default per-user files, $XDG_CONFIG_HOME/git/ignore and
    # git/attributes; pointing these at an empty file leaves those out too.
    'core.excludesFile'   = '/dev/null'
    'core.attributesFile' = '/dev/null'
}

function Get-GitConfigVariableName([int] $Count) {
    'GIT_CONFIG_COUNT'
    foreach ($i in 0..($Count - 1)) { "GIT_CONFIG_KEY_$i"; "GIT_CONFIG_VALUE_$i" }
}

function Set-TestGitEnvironment {
    [OutputType([hashtable])]
    param()

    # Settings already given this way are kept, ahead of the test's own, and come back with Restore-TestGitEnvironment.
    $existing = 0
    [void] [int]::TryParse([Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT'), [ref] $existing)
    $count = $existing + $script:Settings.Count

    $saved = @{}
    foreach ($name in @(Get-GitConfigVariableName $count) + $script:Variables.Keys) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }

    foreach ($variable in $script:Variables.GetEnumerator()) { Set-Item -LiteralPath "env:$($variable.Key)" -Value $variable.Value }
    $i = $existing
    foreach ($setting in $script:Settings.GetEnumerator()) {
        Set-Item -LiteralPath "env:GIT_CONFIG_KEY_$i" -Value $setting.Key
        Set-Item -LiteralPath "env:GIT_CONFIG_VALUE_$i" -Value $setting.Value
        $i++
    }
    Set-Item -LiteralPath 'env:GIT_CONFIG_COUNT' -Value ([string] $count)
    $saved
}

function Restore-TestGitEnvironment {
    param([Parameter(Mandatory)] [hashtable] $Saved)

    # A variable that wasn't set is removed. PowerShell would pass $null to SetEnvironmentVariable as '', and git
    # reads an empty GIT_CONFIG_COUNT as an error.
    foreach ($name in $Saved.Keys) {
        if ($null -eq $Saved[$name]) { Remove-Item -LiteralPath "env:$name" -ErrorAction SilentlyContinue }
        else { Set-Item -LiteralPath "env:$name" -Value $Saved[$name] }
    }
}

function New-TestGitRemote {
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Path)

    # A bare repo a test pushes into, as if it were GitHub.
    foreach ($arguments in @(('init', '-q', '--bare', $Path), ('-C', $Path, 'config', 'receive.autoGC', 'false'))) {
        $output = git @arguments 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Couldn't make the test remote at ${Path}: $($output.Trim())" }
    }
    $Path
}

Export-ModuleMember -Function Set-TestGitEnvironment, Restore-TestGitEnvironment, New-TestGitRemote
