#Requires -Version 7.6
<#
.SYNOPSIS
    The git settings every repo a test makes runs with (TestGit.Tests.ps1).

.DESCRIPTION
    Set-TestGitEnvironment sets them in the environment, so they reach the scripts under test and the processes
    they start. Restore-TestGitEnvironment puts back what was there before. Call the first in a test file's
    BeforeAll and the second in its AfterAll, passing Restore the very hashtable Set returned: Restore finds the
    run's template folder by it, so a copy restores the variables but leaves the folder behind. If Set fails, it
    puts everything back and reports its own error; if putting things back fails too, it warns about that. Restore
    given Set's $null result does nothing. Needs the kit's PowerShell, 7.6 or later (ADR-0040);
    [IO.Directory]::CreateTempSubdirectory itself needs .NET 7.
    - Nothing git reads from the parent environment: every GIT_* variable is removed while tests run (GIT_CONFIG,
      GIT_DIR, GIT_DEFAULT_HASH, GIT_CONFIG_PARAMETERS, GIT_CONFIG_COUNT, a date...). Only GIT_TRACE* stays, which
      records what git does without changing it.
    - No git config, ignore or attributes file from this machine: no global or system config
      (GIT_CONFIG_GLOBAL=/dev/null, GIT_CONFIG_NOSYSTEM), no system attributes (GIT_ATTR_NOSYSTEM), and the default
      per-user ignore and attributes files replaced by an empty one (core.excludesFile and core.attributesFile).
    - No template: GIT_TEMPLATE_DIR points at an empty directory of this run's own, which Restore removes. It's
      private to this account: 0700 on Linux and macOS, and on Windows as private as the account's own %TEMP%.
      A test repo's .git so has no sample hooks, info/exclude or description; nothing here uses them.
    - The fixture identity, in GIT_AUTHOR_* and GIT_COMMITTER_*, which outrank every identity config key.
    - The rest through GIT_CONFIG_COUNT, GIT_CONFIG_KEY_<n> and GIT_CONFIG_VALUE_<n>, which outrank a repo's own
      config too: no signing, no background maintenance, no file-system monitor.
    So a global hook, a team template, or a ".vscode/" line in ~/.config/git/ignore can't change a test. A fixture
    commit once started git's background maintenance, whose repack raced the test's next lookups of the fixture
    commit (New-KitApp.Tests on Windows, PR 23).

    With no global or system config, a safe.directory entry there doesn't apply either: a checkout owned by another
    account makes git stop with "dubious ownership". Run the tests from a checkout of your own. A test that reads
    the checkout itself (its file list, say) does so before calling Set-TestGitEnvironment, with its own config.

    One exception: for a push or fetch through a local path, git strips GIT_CONFIG_COUNT from the receive-pack or
    upload-pack it starts. Only receive-pack runs maintenance, so New-TestGitRemote makes a bare repo for a test to
    push into, with the setting receive-pack needs in its own config.

    Test-RepoGitIgnore says whether a repo's root .gitignore ignores a path, judging that file alone: the kit's
    tests use it to check that a file stays out of commits in every clone and every app, which a line in this
    clone's .git/info/exclude or this machine's excludes would otherwise hide.
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
    'commit.gpgsign'      = 'false'
    'tag.gpgsign'         = 'false'
    'maintenance.auto'    = 'false'
    'gc.auto'             = '0'
    'core.fsmonitor'      = 'false' # a daemon per repo, holding handles in TestDrive
    # With no global config, git would still read its default per-user files, $XDG_CONFIG_HOME/git/ignore and
    # git/attributes; pointing these at an empty file leaves those out too.
    'core.excludesFile'   = '/dev/null'
    'core.attributesFile' = '/dev/null'
}

# The template directory each Set made, by the hashtable it returned, so Restore removes exactly that one and
# only directories this module made, whatever GIT_TEMPLATE_DIR says by then and in whatever order Restores come.
$script:Templates = [System.Collections.Generic.Dictionary[object, string]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance)

function Get-GitConfigVariableName([int] $Count) {
    'GIT_CONFIG_COUNT'
    foreach ($i in 0..($Count - 1)) { "GIT_CONFIG_KEY_$i"; "GIT_CONFIG_VALUE_$i" }
}

function Set-TestGitEnvironment {
    [OutputType([hashtable])]
    param()

    $inherited = @(Get-ChildItem -Path env: | Where-Object { $_.Name -like 'GIT_*' -and $_.Name -notlike 'GIT_TRACE*' } | ForEach-Object Name)
    $count = $script:Settings.Count

    $saved = @{}
    foreach ($name in $inherited + @(Get-GitConfigVariableName $count) + $script:Variables.Keys + 'GIT_TEMPLATE_DIR') {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
    }

    # Made before anything changes, so if it can't be made, nothing has. A new, uniquely named directory, made in
    # one step and private to this account (0700 on Linux and macOS): nobody else can make it first or put a hook
    # or config in it, and two runs at once can't collide.
    $template = [IO.Directory]::CreateTempSubdirectory('dotnet-agent-kit-git-template-').FullName
    $script:Templates[$saved] = $template
    try {
        foreach ($name in $inherited) { Remove-Item -LiteralPath "env:$name" }
        Set-Item -LiteralPath 'env:GIT_TEMPLATE_DIR' -Value $template
        foreach ($variable in $script:Variables.GetEnumerator()) { Set-Item -LiteralPath "env:$($variable.Key)" -Value $variable.Value }
        $i = 0
        foreach ($setting in $script:Settings.GetEnumerator()) {
            Set-Item -LiteralPath "env:GIT_CONFIG_KEY_$i" -Value $setting.Key
            Set-Item -LiteralPath "env:GIT_CONFIG_VALUE_$i" -Value $setting.Value
            $i++
        }
        Set-Item -LiteralPath 'env:GIT_CONFIG_COUNT' -Value ([string] $count)
    }
    catch {
        # The step that failed is the error people need; if putting things back fails too, that's a warning.
        $failure = $_
        try { Restore-TestGitEnvironment -Saved $saved }
        catch { Write-Warning "Couldn't put the git environment back after Set-TestGitEnvironment failed: $_" }
        throw $failure
    }
    $saved
}

function Restore-TestGitEnvironment {
    # $null when Set failed: the file's AfterAll then adds no second error to the one people need to see.
    param([Parameter(Mandatory)] [AllowNull()] [hashtable] $Saved)

    if ($null -eq $Saved) { return }
    $template = $null
    if ($script:Templates.Remove($Saved, [ref] $template)) { Remove-Item -LiteralPath $template -Recurse -Force -ErrorAction SilentlyContinue }

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

function Test-RepoGitIgnore {
    [OutputType([bool])]
    param([Parameter(Mandatory)] [string] $RepoRoot, [Parameter(Mandatory)] [string] $Path)

    # Whether the repo's root .gitignore, as it stands in the work tree, ignores Path. That's the file every clone
    # gets, and every app (Export-KitApp copies it); this clone's .git/info/exclude and this machine's excludes
    # aren't, so it's judged on its own, copied into a repo made with the test settings.
    $gitignore = Join-Path $RepoRoot '.gitignore'
    if (-not (Test-Path -LiteralPath $gitignore -PathType Leaf)) { throw "There's no .gitignore in $RepoRoot." }
    $scratch = [IO.Directory]::CreateTempSubdirectory('dotnet-agent-kit-ignore-').FullName
    $saved = $null
    try {
        Copy-Item -LiteralPath $gitignore -Destination $scratch
        $saved = Set-TestGitEnvironment
        $init = git init -q $scratch 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Couldn't make the repo that judges .gitignore: $($init.Trim())" }
        git -C $scratch check-ignore --no-index -q -- $Path
        $code = $LASTEXITCODE
    }
    finally {
        Restore-TestGitEnvironment -Saved $saved
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
    switch ($code) {
        0 { $true }
        1 { $false }
        default { throw "git check-ignore failed for '$Path' (exit $code)" }
    }
}

Export-ModuleMember -Function Set-TestGitEnvironment, Restore-TestGitEnvironment, New-TestGitRemote, Test-RepoGitIgnore
