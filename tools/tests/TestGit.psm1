#Requires -Version 7.0
<#
.SYNOPSIS
    The git settings every repo a test makes runs with (TestGit.Tests.ps1).

.DESCRIPTION
    Set-TestGitEnvironment applies them through git's GIT_CONFIG_COUNT, GIT_CONFIG_KEY_<n> and GIT_CONFIG_VALUE_<n>
    environment variables. Those rank above every config file, so this machine's identity or signing can't change a
    test, and they reach the scripts under test and every process they start. They also turn off git's background
    maintenance: a fixture commit could start a repack that raced the test's next lookups (New-KitApp.Tests on
    Windows, PR 23). Restore-TestGitEnvironment puts back what was there before. Call the first in a test file's
    BeforeAll and the second in its AfterAll. New-TestGitRemote makes a bare repo for a test to push into, with
    the one setting a push's receive-pack needs in the remote's own config.
#>

Set-StrictMode -Version Latest

$script:Settings = [ordered]@{
    'user.name'        = 'fixture'
    'user.email'       = 'fixture@example.invalid'
    'commit.gpgsign'   = 'false'
    'tag.gpgsign'      = 'false'
    'maintenance.auto' = 'false'
    'gc.auto'          = '0'
}

function Get-GitConfigVariableName([int] $Count) {
    'GIT_CONFIG_COUNT'
    foreach ($i in 0..($Count - 1)) { "GIT_CONFIG_KEY_$i"; "GIT_CONFIG_VALUE_$i" }
}

function Set-TestGitEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param()

    # Settings already given this way are kept, ahead of the test's own, and come back with Restore-TestGitEnvironment.
    $existing = 0
    [void] [int]::TryParse([Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT'), [ref] $existing)
    $count = $existing + $script:Settings.Count

    $saved = @{}
    foreach ($name in (Get-GitConfigVariableName $count)) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
    if (-not $PSCmdlet.ShouldProcess('git settings for test repos', 'Set')) { return $saved }

    $i = $existing
    foreach ($setting in $script:Settings.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_KEY_$i", $setting.Key)
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_VALUE_$i", $setting.Value)
        $i++
    }
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', [string] $count)
    $saved
}

function New-TestGitRemote {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Path)

    # A bare repo a test pushes into, as if it were GitHub. git strips GIT_CONFIG_COUNT from the receive-pack a
    # local push starts, so Set-TestGitEnvironment can't reach it: the remote gets the setting in its own config.
    if (-not $PSCmdlet.ShouldProcess($Path, 'Create a bare git repo')) { return $Path }
    git init -q --bare $Path
    git -C $Path config receive.autoGC false
    $Path
}

function Restore-TestGitEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)] [hashtable] $Saved)

    if (-not $PSCmdlet.ShouldProcess('git settings for test repos', 'Restore')) { return }
    # A variable that wasn't set is removed. PowerShell would pass $null to SetEnvironmentVariable as '', and git
    # reads an empty GIT_CONFIG_COUNT as an error.
    foreach ($name in $Saved.Keys) {
        if ($null -eq $Saved[$name]) { Remove-Item -LiteralPath "env:$name" -ErrorAction SilentlyContinue }
        else { Set-Item -LiteralPath "env:$name" -Value $Saved[$name] }
    }
}

Export-ModuleMember -Function Set-TestGitEnvironment, Restore-TestGitEnvironment, New-TestGitRemote
