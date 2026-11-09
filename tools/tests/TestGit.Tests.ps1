#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# TestGit.psm1 gives every git repo a test makes the same settings, through environment variables that reach the
# scripts under test and the processes they start. The one exception: git strips the GIT_CONFIG_COUNT settings (and
# only those) from the receive-pack or upload-pack a push or fetch through a local path starts.
# Without them, a fixture commit could start git's background maintenance, whose repack raced New-KitApp.Tests'
# lookups of the fixture commit on Windows: 11 tests failed, but only for some file contents, since git's "enough
# loose objects?" estimate depends on hashes.

Describe 'TestGit.psm1' {
    BeforeAll {
        $module = Join-Path $PSScriptRoot 'TestGit.psm1'
        if (Test-Path $module) { Import-Module $module -Force }

        function Get-GitConfigEnvironment {
            $names = @('GIT_CONFIG_COUNT') + (0..15 | ForEach-Object { "GIT_CONFIG_KEY_$_"; "GIT_CONFIG_VALUE_$_" })
            $values = [ordered]@{}
            foreach ($name in $names) { $values[$name] = [Environment]::GetEnvironmentVariable($name) }
            $values
        }

        # Review 2 of PR 24: the checks below read a file through PowerShell's own parser, so a comment or a string
        # is never taken for a command, and an option's position doesn't matter.
        function Get-FileAst([System.IO.FileInfo] $File) {
            [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref] $null, [ref] $null)
        }

        # Every git command (or a file's own Invoke-Git* wrapper) under an AST, with its arguments.
        # Command names are matched as PowerShell resolves them: in any case, by file name when given as a path,
        # with or without .exe or .cmd. A command named only at run time (& $git, git @args) can't be read.
        function Get-GitCall([System.Management.Automation.Language.Ast] $Root) {
            $commands = $Root.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -and
                    (Split-Path -Leaf $node.GetCommandName()) -match '^(git|Invoke-Git\w*)(\.exe|\.cmd)?$'
                }, $true)
            foreach ($command in $commands) {
                [pscustomobject]@{
                    Ast       = $command
                    Arguments = @($command.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text.Trim('''', '"') })
                }
            }
        }

        # git's subcommand: the first argument that isn't an option or an option's value (git -C <path> init).
        # Review 5 of PR 24: matching any argument took "git log --grep init" for making a repo.
        function Get-GitSubcommand([string[]] $Arguments) {
            for ($i = 0; $i -lt $Arguments.Count; $i++) {
                if ($Arguments[$i] -cin '-C', '-c', '--git-dir', '--work-tree', '--namespace', '--config-env', '--attr-source') { $i++; continue }
                if ($Arguments[$i].StartsWith('-')) { continue }
                return $Arguments[$i]
            }
        }

        # git itself by its subcommand; a file's own Invoke-Git* wrapper by any argument, since a wrapper may take
        # arguments of its own first (Invoke-GitAt <date> init; review 6 of PR 24).
        function Test-MakesRepo($Call) {
            $name = Split-Path -Leaf $Call.Ast.GetCommandName()
            if ($name -match '^git(\.exe|\.cmd)?$') { (Get-GitSubcommand $Call.Arguments) -cin 'init', 'clone' }
            else { $Call.Arguments -ccontains 'init' -or $Call.Arguments -ccontains 'clone' }
        }

        # Whether a command runs while Pester discovers the tests: anywhere outside an It, a Before*/After* block
        # or a function (a Describe or Context body, BeforeDiscovery, the file's top level). It errs toward
        # flagging: a script block stored in a Describe body and run only in an It, or a module-qualified Pester\It,
        # counts as discovery. A function defined and called in a Describe body doesn't count. No file does either.
        function Test-RunsAtDiscovery([System.Management.Automation.Language.Ast] $Node) {
            for ($parent = $Node.Parent; $parent; $parent = $parent.Parent) {
                if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $false }
                if ($parent -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and
                    $parent.Parent -is [System.Management.Automation.Language.CommandAst] -and
                    $parent.Parent.GetCommandName() -in 'It', 'BeforeAll', 'AfterAll', 'BeforeEach', 'AfterEach') { return $false }
            }
            $true
        }

        # The names of the commands the file's own BeforeAll or AfterAll (the one outside every Describe) runs
        # itself; a call inside a function it only defines doesn't count.
        function Get-FileLevelSetup([System.IO.FileInfo] $File, [string] $Block) {
            $root = Get-FileAst $File
            $blocks = $root.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq $Block }, $true)
            foreach ($call in $blocks) {
                $scope = $call.Parent
                while ($scope -isnot [System.Management.Automation.Language.ScriptBlockAst]) { $scope = $scope.Parent }
                if ($scope -ne $root) { continue }
                foreach ($body in $call.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }) {
                    $direct = $body.ScriptBlock.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | Where-Object {
                        $node = $_.Parent
                        while ($node -ne $body.ScriptBlock -and $node -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { $node = $node.Parent }
                        $node -eq $body.ScriptBlock
                    }
                    $direct | ForEach-Object { $_.GetCommandName() }
                }
            }
        }

        # Every GIT_* variable, name to value, to compare the whole set before and after (review 8 of PR 24).
        function Get-GitVariable {
            $variables = @{}
            Get-ChildItem -Path env: | Where-Object Name -Like 'GIT_*' | ForEach-Object { $variables[$_.Name] = $_.Value }
            $variables
        }

        # Puts the GIT_* variables back to a snapshot from Get-GitVariable, without the module (whose Restore a test
        # may have mocked).
        function Set-GitVariable([hashtable] $Snapshot) {
            Get-ChildItem -Path env: | Where-Object { $_.Name -like 'GIT_*' -and -not $Snapshot.ContainsKey($_.Name) } |
                ForEach-Object { Remove-Item -LiteralPath "env:$($_.Name)" }
            foreach ($name in $Snapshot.Keys) { Set-Item -LiteralPath "env:$name" -Value $Snapshot[$name] }
        }

        # Makes the last change Set makes fail, once, and records the template folder Set makes; every other
        # Set-Item runs as normal, Restore's own included. The folder is recorded rather than found by listing
        # %TEMP%, so another run's folder is never mistaken for this one (review 9 of PR 24).
        function Use-FailingLastStep {
            $script:probeFailed = $false
            $script:madeTemplate = $null
            Mock -ModuleName TestGit Set-Item { Microsoft.PowerShell.Management\Set-Item @PesterBoundParameters }
            # Only a write Set itself makes, never Restore's: Restore writes the caller's folder back the same way, from
            # Set's undo or a test's own cleanup (reviews 10 and 11).
            Mock -ModuleName TestGit Set-Item {
                $callers = @(Get-PSCallStack | ForEach-Object Command)
                if ($callers -contains 'Set-TestGitEnvironment' -and $callers -notcontains 'Restore-TestGitEnvironment') { $script:madeTemplate = $Value }
                Microsoft.PowerShell.Management\Set-Item @PesterBoundParameters
            } -ParameterFilter { $LiteralPath -eq 'env:GIT_TEMPLATE_DIR' }
            Mock -ModuleName TestGit Set-Item {
                if ($script:probeFailed) { Microsoft.PowerShell.Management\Set-Item @PesterBoundParameters }
                else { $script:probeFailed = $true; throw 'probe failure' }
            } -ParameterFilter { $LiteralPath -eq 'env:GIT_CONFIG_COUNT' }
        }

        # Removes the folder Use-FailingLastStep recorded, if a test left it, and only if it's one of the module's own:
        # a dotnet-agent-kit-git-template-* folder directly in the temp folder.
        function Remove-MadeTemplate {
            $made = $script:madeTemplate
            if (-not $made -or -not (Test-Path -LiteralPath $made)) { return }
            $own = (Split-Path -Leaf $made) -like 'dotnet-agent-kit-git-template-*' -and
                [IO.Path]::GetFullPath((Split-Path -Parent $made)).TrimEnd('\', '/') -eq [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
            if ($own) { Remove-Item -LiteralPath $made -Recurse -Force }
        }

        function New-TestRepo {
            $repo = Join-Path $TestDrive "repo-$(New-Guid)"
            git init -q -b main $repo
            $repo
        }
    }

    AfterAll {
        Remove-Module TestGit -ErrorAction SilentlyContinue
    }

    It 'turns off git''s background maintenance in every repo a test makes, so a repack can''t race the test' {
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $saved = Set-TestGitEnvironment
        try {
            $repo = New-TestRepo
            git -C $repo config --get maintenance.auto | Should -Be 'false'
            git -C $repo config --get gc.auto | Should -Be '0'
        }
        finally { Restore-TestGitEnvironment -Saved $saved }
    }

    It 'keeps this machine''s global and system git config out of every test repo, and puts it back after' {
        # Review 2 of PR 24: the settings above cover a handful of keys; any other global setting, such as a
        # core.hooksPath whose commit-msg hook rejects every commit, still reached every test repo.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $hooks = Join-Path $TestDrive "machine-hooks-$(New-Guid)"
        New-Item -ItemType Directory -Path $hooks | Out-Null
        $hook = Join-Path $hooks 'commit-msg'
        [IO.File]::WriteAllText($hook, "#!/bin/sh`necho 'machine hook rejected the commit' >&2`nexit 1`n")
        # Review 3 of PR 24: git skips a hook that isn't executable, so off Windows this half couldn't fail.
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($hook, 'UserRead, UserWrite, UserExecute') }
        $global = Join-Path $TestDrive "machine-global-$(New-Guid).gitconfig"
        $system = Join-Path $TestDrive "machine-system-$(New-Guid).gitconfig"
        [IO.File]::WriteAllText($global, "[core]`n`thooksPath = $($hooks -replace '\\', '/')`n[probe]`n`tglobal = machine`n")
        [IO.File]::WriteAllText($system, "[probe]`n`tsystem = machine`n")
        $machine = @{ GIT_CONFIG_GLOBAL = $global; GIT_CONFIG_SYSTEM = $system; GIT_CONFIG_NOSYSTEM = $null }
        $outer = @{}
        foreach ($name in $machine.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name) }
        Restore-TestGitEnvironment -Saved $machine
        try {
            $saved = Set-TestGitEnvironment
            try {
                $repo = New-TestRepo
                git -C $repo config --get probe.global | Should -BeNullOrEmpty -Because 'the machine''s global config is left out'
                git -C $repo config --get probe.system | Should -BeNullOrEmpty -Because 'the machine''s system config is left out'
                git -C $repo commit -q --allow-empty -m 'chore: fixture' 2>&1 | Out-Null
                $LASTEXITCODE | Should -Be 0 -Because 'the machine''s global hook doesn''t run'
            }
            finally { Restore-TestGitEnvironment -Saved $saved }

            foreach ($name in $machine.Keys) { [Environment]::GetEnvironmentVariable($name) | Should -Be $machine[$name] -Because "$name comes back" }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'keeps this machine''s default ignore and attributes files out of every test repo' {
        # Review 4 of PR 24: with no global config, git still reads its default per-user files
        # ($XDG_CONFIG_HOME/git/ignore and git/attributes) and the system attributes file. A ".vscode/" line there
        # failed 19 Export-KitApp tests, since the fixture's git add skipped the kit's .vscode files.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $xdg = Join-Path $TestDrive "machine-xdg-$(New-Guid)"
        New-Item -ItemType Directory -Path (Join-Path $xdg 'git') | Out-Null
        [IO.File]::WriteAllText((Join-Path $xdg 'git' 'ignore'), "machine-ignored.txt`n")
        [IO.File]::WriteAllText((Join-Path $xdg 'git' 'attributes'), "*.txt probeattr=machine`n")
        $outer = @{ XDG_CONFIG_HOME = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME') }
        Set-Item -LiteralPath 'env:XDG_CONFIG_HOME' -Value $xdg
        # The system attributes file can't be pointed elsewhere; where it sets an attribute (Git for Windows gives
        # *.doc diff=astextplain), that attribute mustn't reach a test repo. Its path is read before Set, which
        # hides it (review 5 of PR 24: read after, the check never ran).
        $system = "$(git var GIT_ATTR_SYSTEM 2>$null)"
        $systemSetsDocDiff = $system -and (Test-Path -LiteralPath $system) -and (Get-Content -Raw -LiteralPath $system) -match '(?m)^\*\.doc\s+diff=astextplain'
        try {
            $saved = Set-TestGitEnvironment
            try {
                $repo = New-TestRepo
                git -C $repo check-ignore -q --no-index machine-ignored.txt
                $LASTEXITCODE | Should -Be 1 -Because 'the machine''s ignore file is left out'
                git -C $repo check-attr probeattr -- a.txt | Should -Be 'a.txt: probeattr: unspecified' -Because 'the machine''s attributes files are left out'
                if ($systemSetsDocDiff) {
                    git -C $repo check-attr diff -- probe.doc | Should -Be 'probe.doc: diff: unspecified' -Because 'the machine''s system attributes file is left out'
                }
            }
            finally { Restore-TestGitEnvironment -Saved $saved }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'leaves out a template directory and config handed down from a parent git, and puts both back after' {
        # Review 5 of PR 24: git init copied the GIT_TEMPLATE_DIR template (its hooks, info/exclude, config) into
        # every test repo, and a GIT_CONFIG_PARAMETERS a parent git passes on (git -c, aliases) outranks the rest.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $template = Join-Path $TestDrive "machine-template-$(New-Guid)"
        New-Item -ItemType Directory -Path (Join-Path $template 'info'), (Join-Path $template 'hooks') | Out-Null
        [IO.File]::WriteAllText((Join-Path $template 'info' 'exclude'), "template-ignored.txt`n")
        $hook = Join-Path $template 'hooks' 'commit-msg'
        [IO.File]::WriteAllText($hook, "#!/bin/sh`necho 'template hook rejected the commit' >&2`nexit 1`n")
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($hook, 'UserRead, UserWrite, UserExecute') }
        $machine = @{ GIT_TEMPLATE_DIR = $template; GIT_CONFIG_PARAMETERS = "'probe.inherited'='machine'" }
        $outer = @{}
        foreach ($name in $machine.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name) }
        Restore-TestGitEnvironment -Saved $machine
        try {
            $saved = Set-TestGitEnvironment
            try {
                $repo = New-TestRepo
                git -C $repo check-ignore -q --no-index template-ignored.txt
                $LASTEXITCODE | Should -Be 1 -Because 'the machine''s template is left out'
                git -C $repo config --get probe.inherited | Should -BeNullOrEmpty -Because 'config handed down from a parent git is left out'
                git -C $repo commit -q --allow-empty -m 'chore: fixture' 2>&1 | Out-Null
                $LASTEXITCODE | Should -Be 0 -Because 'the template''s hook doesn''t run'
            }
            finally { Restore-TestGitEnvironment -Saved $saved }

            foreach ($name in $machine.Keys) { [Environment]::GetEnvironmentVariable($name) | Should -Be $machine[$name] -Because "$name comes back" }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'lets no git variable from the parent environment reach a test repo, and puts every one back after' {
        # Review 6 of PR 24, after five rounds that each found one more: GIT_CONFIG made New-TestGitRemote write
        # into another file, GIT_DIR made git init re-initialize the outer repo, GIT_DEFAULT_HASH changed the hash.
        # Set now removes every GIT_* variable while tests run, rather than a list of known ones.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $outerRepo = Join-Path $TestDrive "outer-$(New-Guid)"
        git init -q $outerRepo
        $legacy = Join-Path $TestDrive "legacy-$(New-Guid).gitconfig"
        [IO.File]::WriteAllText($legacy, "[probe]`n`tlegacy = machine`n")
        $machine = @{
            GIT_CONFIG = $legacy; GIT_DIR = (Join-Path $outerRepo '.git'); GIT_DEFAULT_HASH = 'sha256'
            GIT_COMMITTER_DATE = '2001-02-03T04:05:06Z'
        }
        $outer = @{}
        foreach ($name in $machine.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name) }
        Restore-TestGitEnvironment -Saved $machine
        try {
            $saved = Set-TestGitEnvironment
            try {
                $repo = New-TestRepo
                Join-Path $repo '.git' | Should -Exist -Because 'git init made the test repo, not the outer one again'
                git -C $repo rev-parse --show-object-format | Should -Be 'sha1'
                git -C $repo config --get probe.legacy | Should -BeNullOrEmpty -Because 'the parent''s GIT_CONFIG is left out'
                git -C $repo commit -q --allow-empty -m 'chore: fixture'
                git -C $repo log -1 --format=%cI | Should -Not -BeLike '2001-*'
                $remote = New-TestGitRemote -Path (Join-Path $TestDrive "remote-$(New-Guid).git")
                git config --file (Join-Path $remote 'config') --get receive.autogc | Should -Be 'false' -Because 'the setting lands in the remote''s own config'
            }
            finally { Restore-TestGitEnvironment -Saved $saved }

            foreach ($name in $machine.Keys) { [Environment]::GetEnvironmentVariable($name) | Should -Be $machine[$name] -Because "$name comes back" }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'gives each run its own empty template directory, private to this account, and removes it after' {
        # Review 6 of PR 24: one shared path in the temp folder could be made first by another account on Linux,
        # which could then put a hook or config in it, and two first runs at once collided.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $templates = foreach ($run in 1, 2) {
            $saved = Set-TestGitEnvironment
            try {
                $template = $env:GIT_TEMPLATE_DIR
                $template | Should -Exist
                @(Get-ChildItem -LiteralPath $template -Force) | Should -BeNullOrEmpty
                if (-not $IsWindows) { [IO.File]::GetUnixFileMode($template) | Should -Be ([IO.UnixFileMode] 'UserRead, UserWrite, UserExecute') }
                $template
            }
            finally { Restore-TestGitEnvironment -Saved $saved }
        }

        $templates[0] | Should -Not -Be $templates[1]
        $templates | ForEach-Object { $_ | Should -Not -Exist -Because 'Restore removes the run''s template' }
    }

    It 'keeps git''s trace variables, so a whole test run can still be traced' {
        # Review 7 of PR 24: GIT_TRACE* records what git does without changing it; tracing a whole run is how this
        # PR's root cause was found.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $trace = Join-Path $TestDrive "run-trace-$(New-Guid).jsonl"
        $outer = @{ GIT_TRACE2_EVENT = $env:GIT_TRACE2_EVENT }
        $env:GIT_TRACE2_EVENT = $trace
        try {
            $saved = Set-TestGitEnvironment
            try {
                $env:GIT_TRACE2_EVENT | Should -Be $trace
                New-TestRepo | Out-Null
                $trace | Should -Exist -Because 'git traced the test''s init'
            }
            finally { Restore-TestGitEnvironment -Saved $saved }
            $env:GIT_TRACE2_EVENT | Should -Be $trace
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'removes the template its own Set made, whatever GIT_TEMPLATE_DIR says by then, and never another folder' {
        # Review 7 of PR 24: Restore removed the folder GIT_TEMPLATE_DIR named at Restore time, so a test that
        # changed it, or Restores out of order, left the module's folder behind.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $foreign = Join-Path $TestDrive "foreign-template-$(New-Guid)"
        New-Item -ItemType Directory -Path $foreign | Out-Null

        $saved = Set-TestGitEnvironment
        $own = $env:GIT_TEMPLATE_DIR
        $env:GIT_TEMPLATE_DIR = $foreign
        Restore-TestGitEnvironment -Saved $saved
        $own | Should -Not -Exist -Because 'Restore removes the folder its Set made'
        $foreign | Should -Exist -Because 'Restore never removes a folder it didn''t make'

        # In order: Restoring the inner Set removes only its own folder (review 8 of PR 24).
        $first = Set-TestGitEnvironment
        $firstTemplate = $env:GIT_TEMPLATE_DIR
        $second = Set-TestGitEnvironment
        $secondTemplate = $env:GIT_TEMPLATE_DIR
        Restore-TestGitEnvironment -Saved $second
        $firstTemplate | Should -Exist -Because 'the outer Set''s folder is still in use'
        $secondTemplate | Should -Not -Exist
        Restore-TestGitEnvironment -Saved $first
        $firstTemplate | Should -Not -Exist

        $first = Set-TestGitEnvironment
        $firstTemplate = $env:GIT_TEMPLATE_DIR
        $second = Set-TestGitEnvironment
        $secondTemplate = $env:GIT_TEMPLATE_DIR
        Restore-TestGitEnvironment -Saved $first
        Restore-TestGitEnvironment -Saved $second
        # Out of order, the environment ends as the first Set left it; $first holds what was there before both.
        Restore-TestGitEnvironment -Saved $first
        $firstTemplate, $secondTemplate | ForEach-Object { $_ | Should -Not -Exist -Because 'Restores out of order still remove each folder' }
    }

    It 'changes nothing when Set fails, so the caller''s git variables are still there' {
        # Review 7 of PR 24: Set removed the inherited variables before making the template; when that threw, the
        # caller never got what Set saved, so the variables were gone for the rest of the session.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $notAFolder = Join-Path $TestDrive "not-a-folder-$(New-Guid)"
        Set-Content -LiteralPath $notAFolder -Value 'a file, so no temp folder can be made under it'
        $machine = @{ GIT_PROBE_KEEP = 'kept'; TMP = $notAFolder; TEMP = $notAFolder; TMPDIR = $notAFolder }
        $outer = @{}
        foreach ($name in $machine.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name) }
        Restore-TestGitEnvironment -Saved $machine
        try {
            # The whole set, so a GIT_CONFIG_COUNT a parent passes is expected to stay too (review 8 of PR 24).
            $before = Get-GitVariable
            { Set-TestGitEnvironment } | Should -Throw
            $env:GIT_PROBE_KEEP | Should -Be 'kept'
            $after = Get-GitVariable
            @($after.Keys) | Sort-Object | Should -Be (@($before.Keys) | Sort-Object)
            foreach ($name in $before.Keys) { $after[$name] | Should -Be $before[$name] -Because "$name is as it was" }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'undoes every change when a step after the template fails, and removes the template' {
        # Review 8 of PR 24: the test above fails before Set changes anything, so Set's own undo never ran.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Use-FailingLastStep
        # The caller has a template folder of their own, as a team might (review 10 of PR 24: Restore's write putting
        # it back was taken for Set's, and the test's cleanup deleted the caller's folder).
        $theirs = Join-Path $TestDrive "their-template-$(New-Guid)"
        New-Item -ItemType Directory -Path $theirs | Out-Null
        Set-Content -LiteralPath (Join-Path $theirs 'keep.txt') -Value 'their file'
        $outer = @{ GIT_PROBE_KEEP = $env:GIT_PROBE_KEEP; GIT_TEMPLATE_DIR = $env:GIT_TEMPLATE_DIR }
        $env:GIT_PROBE_KEEP = 'kept'
        $env:GIT_TEMPLATE_DIR = $theirs
        $before = Get-GitVariable
        try {
            { Set-TestGitEnvironment } | Should -Throw '*probe failure*'
            $after = Get-GitVariable
            @($after.Keys) | Sort-Object | Should -Be (@($before.Keys) | Sort-Object)
            foreach ($name in $before.Keys) { $after[$name] | Should -Be $before[$name] -Because "$name is as it was" }
            $script:madeTemplate | Should -Not -BeNullOrEmpty -Because 'Set got as far as making its template'
            $script:madeTemplate | Should -Not -Be $theirs -Because 'the recorded folder is the one Set made'
            $script:madeTemplate | Should -Not -Exist -Because 'the template is removed'
        }
        finally {
            Set-GitVariable $before; Restore-TestGitEnvironment -Saved $outer; Remove-MadeTemplate
        }
        # After the cleanup, not in it, so a failure above keeps its own message (review 11 of PR 24).
        Join-Path $theirs 'keep.txt' | Should -Exist -Because 'the caller''s own template folder is never touched'
    }

    It 'has a test cleanup that removes only the module''s own template folders, directly in the temp folder' {
        # Review 11 of PR 24: nothing pinned Remove-MadeTemplate's guard, the backstop if a recording is ever wrong.
        $temp = Join-Path $TestDrive "temp-$(New-Guid)"
        New-Item -ItemType Directory -Path $temp | Out-Null
        $outer = @{ TMP = $env:TMP; TEMP = $env:TEMP; TMPDIR = $env:TMPDIR }
        try {
            # Review 12 of PR 24: inside the try, so the finally puts the temp folder back even if this fails partway.
            Restore-TestGitEnvironment -Saved @{ TMP = $temp; TEMP = $temp; TMPDIR = $temp }
            $otherName = New-Item -ItemType Directory -Path (Join-Path $temp 'someone-elses-folder')
            $otherPlace = New-Item -ItemType Directory -Path (Join-Path $TestDrive "dotnet-agent-kit-git-template-$(New-Guid)")
            $own = New-Item -ItemType Directory -Path (Join-Path $temp "dotnet-agent-kit-git-template-$(New-Guid)")
            foreach ($folder in $otherName, $otherPlace) {
                $script:madeTemplate = $folder.FullName
                Remove-MadeTemplate
                $folder.FullName | Should -Exist -Because 'it isn''t one of the module''s own'
            }
            $script:madeTemplate = $own.FullName
            Remove-MadeTemplate
            $own.FullName | Should -Not -Exist
        }
        finally { $script:madeTemplate = $null; Restore-TestGitEnvironment -Saved $outer }
    }

    It 'reports the step that failed, and warns when putting things back fails too' {
        # Review 8 of PR 24: an error from the undo in Set's catch replaced the one that caused it. Review 9: the
        # warning it now gives was untested, and showed up in every run's output.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Use-FailingLastStep
        Mock -ModuleName TestGit Restore-TestGitEnvironment { throw 'restore failure' }
        $before = Get-GitVariable
        try {
            $script:setError = $null
            $warnings = & { try { Set-TestGitEnvironment } catch { $script:setError = $_ } } 3>&1
            "$script:setError" | Should -BeLike '*probe failure*' -Because 'the step that failed is the error'
            "$warnings" | Should -BeLike '*restore failure*' -Because 'the failed undo is a warning'
        }
        finally { Set-GitVariable $before; Remove-MadeTemplate }
    }

    It 'adds no second error when Set failed, so the first one is the one people see' {
        # Review 6 of PR 24: a file's AfterAll then called Restore with nothing, and failed again.
        { Restore-TestGitEnvironment -Saved $null } | Should -Not -Throw
    }

    It 'starts no file-system monitor daemon for a test repo, even where this machine turns it on' {
        # Review of PR 24: with core.fsmonitor=true, every test repo got a daemon holding handles in TestDrive.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $saved = Set-TestGitEnvironment
        try {
            $repo = New-TestRepo
            git -C $repo config core.fsmonitor true
            git -C $repo config --get core.fsmonitor | Should -Be 'false'
        }
        finally { Restore-TestGitEnvironment -Saved $saved }
    }

    It 'makes a bare "remote" that a test can push into without starting background maintenance' {
        # git strips GIT_CONFIG_COUNT from the receive-pack a local push starts, so the remote needs its own config.
        # git's trace shows every git process a push starts, receive-pack's own included.
        Get-Command New-TestGitRemote -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $saved = Set-TestGitEnvironment
        $trace = Join-Path $TestDrive "push-trace-$(New-Guid).jsonl"
        $outerTrace = $env:GIT_TRACE2_EVENT
        try {
            $remote = New-TestGitRemote -Path (Join-Path $TestDrive "remote-$(New-Guid).git")
            $repo = New-TestRepo
            git -C $repo commit -q --allow-empty -m 'chore: fixture'
            $env:GIT_TRACE2_EVENT = $trace
            git -C $repo push -q $remote main 2>&1 | Out-Null
            $pushExit = $LASTEXITCODE
            $env:GIT_TRACE2_EVENT = $outerTrace

            $pushExit | Should -Be 0
            git -C $remote rev-parse --verify --quiet refs/heads/main | Should -Not -BeNullOrEmpty -Because 'the push landed'
            $started = @(Get-Content -LiteralPath $trace | ConvertFrom-Json | Where-Object event -EQ 'start' | ForEach-Object { $_.argv -join ' ' })
            $started | Should -Not -BeNullOrEmpty -Because 'the trace recorded the push'
            $started | Where-Object { $_ -match ' (maintenance|gc|repack)( |$)' } | Should -BeNullOrEmpty
        }
        finally { $env:GIT_TRACE2_EVENT = $outerTrace; Restore-TestGitEnvironment -Saved $saved }
    }

    It 'stops with git''s reason when it can''t make the remote, rather than handing back a path to nothing' {
        # Review of PR 24: git's exit codes were ignored, so a later push failed far from the cause.
        Get-Command New-TestGitRemote -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $taken = Join-Path $TestDrive "taken-$(New-Guid).git"
        Set-Content -LiteralPath $taken -Value 'a file, not a folder'

        { New-TestGitRemote -Path $taken } | Should -Throw "*Couldn't make the test remote at*"
    }

    It 'is how every test file makes a bare remote' {
        # init or clone with --bare or --mirror, anywhere in the call (git --bare init too).
        $byHand = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' | Where-Object {
            $_.Name -ne 'TestGit.Tests.ps1' -and
            @(Get-GitCall (Get-FileAst $_) | Where-Object { (Test-MakesRepo $_) -and ($_.Arguments -ccontains '--bare' -or $_.Arguments -ccontains '--mirror') }).Count -gt 0
        }

        @($byHand.Name) | Should -BeNullOrEmpty -Because 'New-TestGitRemote gives a remote the settings a push needs'
    }

    It 'commits as the fixture, unsigned, whatever this machine''s own git identity and signing are' {
        # Review of PR 24: author.* and committer.* config, and the GIT_AUTHOR_* and GIT_COMMITTER_* variables, all
        # rank above user.name, so a machine that sets any of them changed every fixture commit.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $machine = @{ GIT_AUTHOR_NAME = 'Env Author'; GIT_AUTHOR_EMAIL = 'env@example.invalid'; GIT_COMMITTER_NAME = 'Env Committer'; GIT_COMMITTER_EMAIL = 'env@example.invalid' }
        $outer = @{}
        foreach ($name in $machine.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name); Set-Item -LiteralPath "env:$name" -Value $machine[$name] }
        try {
            $saved = Set-TestGitEnvironment
            try {
                $repo = New-TestRepo
                git -C $repo config user.name 'someone else'
                git -C $repo config author.name 'Config Author'
                git -C $repo config committer.email 'config@example.invalid'
                git -C $repo config commit.gpgsign true
                git -C $repo commit -q --allow-empty -m 'chore: fixture'

                $LASTEXITCODE | Should -Be 0 -Because 'no signing key is needed'
                git -C $repo log -1 --format='%an <%ae> %cn <%ce>' | Should -Be 'fixture <fixture@example.invalid> fixture <fixture@example.invalid>'
            }
            finally { Restore-TestGitEnvironment -Saved $saved }

            foreach ($name in $machine.Keys) { [Environment]::GetEnvironmentVariable($name) | Should -Be $machine[$name] -Because "$name comes back" }
        }
        finally {
            foreach ($name in $machine.Keys) {
                if ($null -eq $outer[$name]) { Remove-Item -LiteralPath "env:$name" -ErrorAction SilentlyContinue }
                else { Set-Item -LiteralPath "env:$name" -Value $outer[$name] }
            }
        }
    }

    It 'leaves out settings a parent process passed the same way, since they come from outside the test too' {
        # Found in review 5 of PR 24: Set kept GIT_CONFIG_COUNT settings it found, so they reached every test repo.
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $before = @{ GIT_CONFIG_COUNT = '1'; GIT_CONFIG_KEY_0 = 'probe.inheritedCount'; GIT_CONFIG_VALUE_0 = 'machine' }
        $outer = @{}
        foreach ($name in $before.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name) }
        Restore-TestGitEnvironment -Saved $before
        try {
            $saved = Set-TestGitEnvironment
            try {
                git -C (New-TestRepo) config --get probe.inheritedCount | Should -BeNullOrEmpty
            }
            finally { Restore-TestGitEnvironment -Saved $saved }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'puts back exactly the environment it found, including settings someone else set the same way' {
        Get-Command Set-TestGitEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $before = @{ GIT_CONFIG_COUNT = '1'; GIT_CONFIG_KEY_0 = 'core.example'; GIT_CONFIG_VALUE_0 = 'kept' }
        # Review of PR 24: put back whatever the person running the tests had, rather than deleting it.
        $outer = @{}
        foreach ($name in $before.Keys) { $outer[$name] = [Environment]::GetEnvironmentVariable($name); Set-Item -LiteralPath "env:$name" -Value $before[$name] }
        try {
            $expected = Get-GitConfigEnvironment

            Restore-TestGitEnvironment -Saved (Set-TestGitEnvironment)

            (Get-GitConfigEnvironment).GetEnumerator() | ForEach-Object { $_.Value | Should -Be $expected[$_.Key] -Because $_.Key }
        }
        finally { Restore-TestGitEnvironment -Saved $outer }
    }

    It 'makes no git repo while Pester discovers the tests, which runs before the setup and has no TestDrive' {
        # Reviews 4 and 5 of PR 24: discovery only builds test data, and a repo made then (in BeforeDiscovery, a
        # Describe or Context body, or at the file's top level) would get none of the settings.
        $inDiscovery = foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1') {
            if (@(Get-GitCall (Get-FileAst $file) | Where-Object { (Test-MakesRepo $_) -and (Test-RunsAtDiscovery $_.Ast) }).Count -gt 0) { $file.Name }
        }

        @($inDiscovery) | Should -BeNullOrEmpty
    }

    It 'is used by every test file that makes a git repo' {
        # A repo is made by git init or git clone, directly or through a file's own Invoke-Git wrapper; its commits
        # then run with the settings.
        # The setup runs in the file's own BeforeAll and AfterAll, so it wraps every Describe. TestGit.Tests.ps1 is
        # the exception: it tests the helper, setting and restoring it in each test.
        $makesRepos = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' | Where-Object {
            $_.Name -ne 'TestGit.Tests.ps1' -and @(Get-GitCall (Get-FileAst $_) | Where-Object { Test-MakesRepo $_ }).Count -gt 0
        }

        @($makesRepos).Count | Should -BeGreaterThan 5
        foreach ($file in $makesRepos) {
            @(Get-FileLevelSetup $file 'BeforeAll') | Should -Contain 'Set-TestGitEnvironment' -Because "$($file.Name) makes git repos"
            @(Get-FileLevelSetup $file 'AfterAll') | Should -Contain 'Restore-TestGitEnvironment' -Because "$($file.Name) must put the environment back"
        }
    }
}
